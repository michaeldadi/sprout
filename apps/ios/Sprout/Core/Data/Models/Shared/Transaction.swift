import Foundation
import SwiftData

public enum TransactionSyncStatus: String, Codable {
    case synced
    case pending
    case syncing
    case failed
    case conflict
}

// MARK: - SwiftData Model (for main app)
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

// MARK: - Codable Version for App Intents
// This is a simplified, Codable version for sharing data with extensions
public struct TransactionDTO: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let amount: Double
    public let currency: String
    public let category: String
    public let subcategory: String?
    public let merchant: String?
    public let transactionDescription: String?
    public let date: Date
    public let type: TransactionType
    public let paymentMethod: String?
    public let tags: [String]
    public let notes: String?
    public let location: TransactionLocationDTO?
    public let isRecurring: Bool
    public let recurringFrequency: String?
    public let syncStatus: TransactionSyncStatus
    public let lastSyncedAt: Date?
    public let remoteVersion: Int

    public init(
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
        tags: [String] = [],
        notes: String? = nil,
        location: TransactionLocationDTO? = nil,
        isRecurring: Bool = false,
        recurringFrequency: String? = nil,
        syncStatus: TransactionSyncStatus = .pending,
        lastSyncedAt: Date? = nil,
        remoteVersion: Int = 0
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
        self.tags = tags
        self.notes = notes
        self.location = location
        self.isRecurring = isRecurring
        self.recurringFrequency = recurringFrequency
        self.syncStatus = syncStatus
        self.lastSyncedAt = lastSyncedAt
        self.remoteVersion = remoteVersion
    }
}

// MARK: - Codable Location for DTOs
public struct TransactionLocationDTO: Codable {
    public let latitude: Double?
    public let longitude: Double?
    public let address: String?
    public let city: String?
    public let state: String?
    public let country: String?
    public let postalCode: String?

    public init(
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

// MARK: - Supporting Types
public enum TransactionType: String, Codable, CaseIterable {
    case income = "income"
    case expense = "expense"
    case transfer = "transfer"
}

public enum ConflictResolution: String, Codable {
    case keepLocal = "keep_local"
    case keepRemote = "keep_remote"
    case merge = "merge"
}

// MARK: - SwiftData TransactionLocation (for main app)
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

// MARK: - Conversion Extensions
extension Transaction {
    /// Convert SwiftData model to Codable DTO for sharing with extensions
    func toDTO() -> TransactionDTO {
        let locationDTO = location.map { loc in
            TransactionLocationDTO(
                latitude: loc.latitude,
                longitude: loc.longitude,
                address: loc.address,
                city: loc.city,
                state: loc.state,
                country: loc.country,
                postalCode: loc.postalCode
            )
        }

        return TransactionDTO(
            id: id,
            userId: userId,
            amount: amount,
            currency: currency,
            category: category,
            subcategory: subcategory,
            merchant: merchant,
            transactionDescription: transactionDescription,
            date: date,
            type: type,
            paymentMethod: paymentMethod,
            tags: tags,
            notes: notes,
            location: locationDTO,
            isRecurring: isRecurring,
            recurringFrequency: recurringFrequency,
            syncStatus: syncStatus,
            lastSyncedAt: lastSyncedAt,
            remoteVersion: remoteVersion
        )
    }
}

extension TransactionDTO {
    /// Create a new SwiftData Transaction from DTO
    func toTransaction() -> Transaction {
        let location = self.location.map { loc in
            TransactionLocation(
                latitude: loc.latitude,
                longitude: loc.longitude,
                address: loc.address,
                city: loc.city,
                state: loc.state,
                country: loc.country,
                postalCode: loc.postalCode
            )
        }

        return Transaction(
            id: id,
            userId: userId,
            amount: amount,
            currency: currency,
            category: category,
            subcategory: subcategory,
            merchant: merchant,
            transactionDescription: transactionDescription,
            date: date,
            type: type,
            paymentMethod: paymentMethod,
            tags: tags,
            notes: notes,
            location: location,
            isRecurring: isRecurring,
            recurringFrequency: recurringFrequency,
            syncStatus: syncStatus,
            lastSyncedAt: lastSyncedAt,
            remoteVersion: remoteVersion
        )
    }
}
