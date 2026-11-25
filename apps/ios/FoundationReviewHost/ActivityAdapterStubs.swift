import Foundation
import Combine

// The isolated review host compiles the production Activity adapter without starting
// auth, network, chat, analytics, or notification services.
@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()
    struct User { let id: String }
    @Published var isAuthenticated = false
    @Published var currentUser: User?
}

@MainActor
final class SyncService: ObservableObject {
    @Published var isOnline = true
    @Published var isSyncing = false
    @Published var syncError: Error?
    @Published var lastSyncDate: Date?
}

@MainActor
final class DeepLinkManager: ObservableObject {
    @Published var activeTransactionId: String?
}
