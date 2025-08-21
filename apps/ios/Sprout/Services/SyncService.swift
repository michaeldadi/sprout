import Foundation
import SwiftData
import Network
import Combine

@MainActor
class SyncService: ObservableObject {
    private let dataContainer: DataContainer
    private let networkManager: NetworkManager
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    @Published var isOnline = true
    
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init(dataContainer: DataContainer, networkManager: NetworkManager) {
        self.dataContainer = dataContainer
        self.networkManager = networkManager
        
        setupNetworkMonitoring()
        setupAutoSync()
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                if path.status == .satisfied {
                    // Network is back, try to sync
                    Task { [weak self] in
                        try await self?.syncData()
                    }
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    private func setupAutoSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { [weak self] in
                guard let self = self else { return }
                let online = await MainActor.run { self.isOnline }
                guard online else { return }
                try? await self.syncData()
            }
        }
    }
    
    func syncData() async throws {
        guard !isSyncing else { return }
        guard isOnline else { 
            throw SyncError.offline 
        }
        
        isSyncing = true
        syncError = nil
        
        defer { isSyncing = false }
        
        do {
            // 1. Upload pending changes
            try await uploadPendingChanges()
            
            // 2. Download remote changes
            try await downloadRemoteChanges()
            
            // 3. Resolve conflicts
            try await resolveConflicts()
            
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
            
        } catch {
            syncError = error
            throw error
        }
    }
    
    private func uploadPendingChanges() async throws {
        let unsyncedTransactions = try dataContainer.fetchUnsyncedTransactions()
        
        for transaction in unsyncedTransactions where transaction.syncStatus == TransactionSyncStatus.pending {
            transaction.syncStatus = TransactionSyncStatus.syncing
            try dataContainer.save()
            
            do {
                if transaction.isDeleted {
                    // Delete from remote
                    try await networkManager.deleteTransaction(transactionId: transaction.id)
                } else {
                    // Create or update on remote
                    let response = try await networkManager.syncTransaction(transaction)
                    transaction.remoteVersion = response.version
                    transaction.lastSyncedAt = Date()
                }
                
                transaction.syncStatus = TransactionSyncStatus.synced
                
            } catch {
                transaction.syncStatus = TransactionSyncStatus.failed
                throw error
            }
            
            try dataContainer.save()
        }
    }
    
    private func downloadRemoteChanges() async throws {
        let lastSync = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date ?? Date.distantPast
        
        let syncData = try await networkManager.fetchSyncData(since: lastSync)
        
        for remoteTransaction in syncData.transactions {
            // Check if we have this transaction locally
            let predicate = #Predicate<Transaction> { transaction in
                transaction.id == remoteTransaction.id
            }
            
            let localTransactions = try dataContainer.fetchTransactions(predicate: predicate)
            
            if let localTransaction = localTransactions.first {
                // Update existing transaction if remote is newer
                if remoteTransaction.updatedAt > localTransaction.updatedAt {
                    updateLocalTransaction(localTransaction, from: remoteTransaction)
                }
            } else {
                // Create new transaction
                createLocalTransaction(from: remoteTransaction)
            }
        }
        
        try dataContainer.save()
    }
    
    private func resolveConflicts() async throws {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor<Transaction>(\.date, order: .reverse)]
        )
        let allTransactions = try dataContainer.modelContext.fetch(descriptor)
        let conflictedTransactions = allTransactions.filter { $0.syncStatus == TransactionSyncStatus.conflict }
        
        for transaction in conflictedTransactions {
            // Apply conflict resolution strategy
            switch transaction.conflictResolution {
            case .keepLocal:
                // Force upload local version
                transaction.syncStatus = TransactionSyncStatus.pending
            case .keepRemote:
                // Already handled in downloadRemoteChanges
                transaction.syncStatus = TransactionSyncStatus.synced
            case .merge:
                // Custom merge logic here
                try await mergeConflict(transaction)
            case .none:
                // Default to last-write-wins (keep remote)
                transaction.syncStatus = TransactionSyncStatus.synced
            }
        }
        
        try dataContainer.save()
    }
    
    private func updateLocalTransaction(_ local: Transaction, from remote: RemoteTransaction) {
        local.amount = remote.amount
        local.category = remote.category
        local.transactionDescription = remote.description
        local.date = remote.date
        local.updatedAt = remote.updatedAt
        local.remoteVersion = remote.version
        local.syncStatus = TransactionSyncStatus.synced
        local.lastSyncedAt = Date()
    }
    
    private func createLocalTransaction(from remote: RemoteTransaction) {
        let transaction = Transaction(
            id: remote.id,
            userId: remote.userId,
            amount: remote.amount,
            category: remote.category,
            transactionDescription: remote.description,
            date: remote.date,
            type: TransactionType.expense, // Default, should come from remote
            syncStatus: TransactionSyncStatus.synced,
            lastSyncedAt: Date(),
            remoteVersion: remote.version
        )
        
        dataContainer.modelContext.insert(transaction)
    }
    
    private func mergeConflict(_ transaction: Transaction) async throws {
        // Implement custom merge logic
        // For now, just mark as synced
        transaction.syncStatus = TransactionSyncStatus.synced
    }
    
    deinit {
        syncTimer?.invalidate()
        monitor.cancel()
    }
}

enum SyncError: LocalizedError {
    case offline
    case syncInProgress
    case conflictResolutionFailed
    
    var errorDescription: String? {
        switch self {
        case .offline:
            return "Device is offline. Changes will be synced when connection is restored."
        case .syncInProgress:
            return "Sync is already in progress"
        case .conflictResolutionFailed:
            return "Failed to resolve sync conflicts"
        }
    }
}

// Remote transaction model
struct RemoteTransaction: Codable {
    let id: String
    let userId: String
    let amount: Double
    let category: String
    let description: String?
    let date: Date
    let updatedAt: Date
    let version: Int
}
