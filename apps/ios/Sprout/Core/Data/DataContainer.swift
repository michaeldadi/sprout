import SwiftData
import Foundation

@MainActor
class DataContainer: ObservableObject {
    let container: ModelContainer
    let modelContext: ModelContext
    
    init() throws {
        let schema = Schema([
            Transaction.self,
            TransactionLocation.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none // Disable iCloud sync, we use our own sync
        )
        
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            modelContext = container.mainContext
            
            // Configure for better performance
            modelContext.autosaveEnabled = true
            
        } catch {
            throw DataError.failedToInitializeContainer(error)
        }
    }
    
    func save() throws {
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }
    
    func fetchTransactions(
        predicate: Predicate<Transaction>? = nil,
        sortBy: [SortDescriptor<Transaction>] = [SortDescriptor(\.date, order: .reverse)]
    ) throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: sortBy
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    func fetchUnsyncedTransactions() throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor<Transaction>(\.date, order: .reverse)]
        )
        let allTransactions = try modelContext.fetch(descriptor)
        return allTransactions.filter { $0.syncStatus != TransactionSyncStatus.synced }
    }
    
    func deleteTransaction(_ transaction: Transaction) throws {
        transaction.isDeleted = true
        transaction.syncStatus = TransactionSyncStatus.pending
        transaction.locallyModifiedAt = Date()
        try save()
    }

    func clearUserData() async {
            do {
                // Delete all transactions
                let transactionDescriptor = FetchDescriptor<Transaction>()
                let allTransactions = try modelContext.fetch(transactionDescriptor)
                for transaction in allTransactions {
                    modelContext.delete(transaction)
                }

                // Delete all transaction locations
                let locationDescriptor = FetchDescriptor<TransactionLocation>()
                let allLocations = try modelContext.fetch(locationDescriptor)
                for location in allLocations {
                    modelContext.delete(location)
                }

                // Save the deletions
                try save()

                print("✅ All user data cleared from local storage")
            } catch {
                print("❌ Error clearing user data: \(error)")
            }
        }
}

enum DataError: LocalizedError {
    case failedToInitializeContainer(Error)
    case failedToSave(Error)
    case failedToFetch(Error)
    
    var errorDescription: String? {
        switch self {
        case .failedToInitializeContainer(let error):
            return "Failed to initialize data container: \(error.localizedDescription)"
        case .failedToSave(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .failedToFetch(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        }
    }
}
