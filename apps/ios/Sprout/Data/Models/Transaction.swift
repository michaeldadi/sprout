import Foundation
import SwiftData

public enum TransactionSyncStatus: String, Codable {
    case synced
    case pending
    case syncing
    case failed
    case conflict
}

@Model
final class Transaction {
    var id: String
    var userId: String
    var amount: Double
    var currency: String
    var category: String
    var subcategory: String?
    var merchant: String?
    var transactionDescription: String?
    var date: Date
    var type: TransactionType
    var paymentMethod: String?
    var receiptUrl: String?
    var tags: [String]
    var notes: String?
    var location: TransactionLocation?
    var isRecurring: Bool
    var recurringFrequency: String?
    var attachments: [String]
    
    // Sync metadata
    var syncStatus: TransactionSyncStatus
    var lastSyncedAt: Date?
    var locallyModifiedAt: Date
    var remoteVersion: Int
    var conflictResolution: ConflictResolution?
    
    // Offline support
    var isDeleted: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        amount: Double,
        currency: String = "USD",
        category: String,
        subcategory: String? = nil,
        merchant: String? = nil,
        transactionDescription: String? = nil,
        date: Date = Date(),
        type: TransactionType,
        paymentMethod: String? = nil,
        receiptUrl: String? = nil,
        tags: [String] = [],
        notes: String? = nil,
        location: TransactionLocation? = nil,
        isRecurring: Bool = false,
        recurringFrequency: String? = nil,
        attachments: [String] = [],
        syncStatus: TransactionSyncStatus = .pending,
        lastSyncedAt: Date? = nil,
        locallyModifiedAt: Date = Date(),
        remoteVersion: Int = 0,
        conflictResolution: ConflictResolution? = nil,
        isDeleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.amount = amount
        self.currency = currency
        self.category = category
        self.subcategory = subcategory
        self.merchant = merchant
        self.transactionDescription = transactionDescription
        self.date = date
        self.type = type
        self.paymentMethod = paymentMethod
        self.receiptUrl = receiptUrl
        self.tags = tags
        self.notes = notes
        self.location = location
        self.isRecurring = isRecurring
        self.recurringFrequency = recurringFrequency
        self.attachments = attachments
        self.syncStatus = syncStatus
        self.lastSyncedAt = lastSyncedAt
        self.locallyModifiedAt = locallyModifiedAt
        self.remoteVersion = remoteVersion
        self.conflictResolution = conflictResolution
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Supporting Types
enum TransactionType: String, Codable, CaseIterable {
    case income = "income"
    case expense = "expense"
    case transfer = "transfer"
}

enum SyncStatus: String, Codable, CaseIterable {
    case synced = "synced"
    case pending = "pending"
    case syncing = "syncing"
    case failed = "failed"
    case conflict = "conflict"
}

enum ConflictResolution: String, Codable {
    case keepLocal = "keep_local"
    case keepRemote = "keep_remote"
    case merge = "merge"
}

@Model
final class TransactionLocation {
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var city: String?
    var state: String?
    var country: String?
    var postalCode: String?
    
    init(
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil,
        city: String? = nil,
        state: String? = nil,
        country: String? = nil,
        postalCode: String? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.city = city
        self.state = state
        self.country = country
        self.postalCode = postalCode
    }
}
