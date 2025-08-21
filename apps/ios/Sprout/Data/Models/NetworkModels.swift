import Foundation

// Network Error types
enum NetworkError: LocalizedError {
    case invalidResponse
    case invalidData
    case unauthorized
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidData:
            return "Invalid data received"
        case .unauthorized:
            return "Unauthorized access"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

// Sync request/response models
struct TransactionSyncData: Codable {
    let id: String
    let userId: String
    let amount: Double
    let currency: String
    let category: String
    let subcategory: String?
    let merchant: String?
    let description: String?
    let date: Date
    let type: String
    let paymentMethod: String?
    let receiptUrl: String?
    let tags: [String]
    let notes: String?
    let location: LocationData?
    let isRecurring: Bool
    let recurringFrequency: String?
    let attachments: [String]
    let locallyModifiedAt: Date
    let remoteVersion: Int
    
    init(from transaction: Transaction) {
        self.id = transaction.id
        self.userId = transaction.userId
        self.amount = transaction.amount
        self.currency = transaction.currency
        self.category = transaction.category
        self.subcategory = transaction.subcategory
        self.merchant = transaction.merchant
        self.description = transaction.transactionDescription
        self.date = transaction.date
        self.type = transaction.type.rawValue
        self.paymentMethod = transaction.paymentMethod
        self.receiptUrl = transaction.receiptUrl
        self.tags = transaction.tags
        self.notes = transaction.notes
        self.location = transaction.location != nil ? LocationData(from: transaction.location!) : nil
        self.isRecurring = transaction.isRecurring
        self.recurringFrequency = transaction.recurringFrequency
        self.attachments = transaction.attachments
        self.locallyModifiedAt = transaction.locallyModifiedAt
        self.remoteVersion = transaction.remoteVersion
    }
}

struct LocationData: Codable {
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let postalCode: String?
    
    init(from location: TransactionLocation) {
        self.latitude = location.latitude
        self.longitude = location.longitude
        self.address = location.address
        self.city = location.city
        self.state = location.state
        self.country = location.country
        self.postalCode = location.postalCode
    }
}

struct SyncResponse: Codable {
    let id: String
    let version: Int
    let updatedAt: Date
}

struct SyncDataResponse: Codable {
    let transactions: [RemoteTransaction]
    let lastSync: Date
    let hasMore: Bool
    let nextCursor: String?
}

struct ReceiptUploadResponse: Codable {
    let receiptUrl: String
    let uploadedAt: Date
}
