import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject private var dataContainer: DataContainer
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var deepLinkManager: DeepLinkManager
    @StateObject private var authService = AuthService.shared

    @State private var state: ActivityLoadState = .loading

    var body: some View {
        ActivityJourneyView(
            state: state,
            isOffline: !syncService.isOnline,
            syncError: syncService.syncError?.localizedDescription,
            lastSyncDate: syncService.lastSyncDate,
            now: Date(),
            retry: load,
            requestedTransactionID: $deepLinkManager.activeTransactionId
        )
        .onAppear(perform: load)
        .onChange(of: syncService.isSyncing) { wasSyncing, isSyncing in
            if wasSyncing && !isSyncing { load() }
        }
        .onChange(of: authService.currentUser?.id) { _, _ in load() }
    }

    private func load() {
        guard authService.isAuthenticated, let userID = authService.currentUser?.id else {
            state = .ready([])
            return
        }
        do {
            state = .ready(try ActivityRecordSource.load(from: dataContainer, userID: userID))
        } catch {
            state = .failed("Saved transactions could not be read. \(error.localizedDescription)")
        }
    }
}
