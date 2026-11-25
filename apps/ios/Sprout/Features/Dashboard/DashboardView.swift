import SwiftUI

/// Home presents only records belonging to the authenticated user.
struct DashboardView: View {
    @EnvironmentObject private var dataContainer: DataContainer
    @EnvironmentObject private var syncService: SyncService
    @StateObject private var authService = AuthService.shared
    @State private var state: ActivityLoadState = .loading

    let onViewActivity: () -> Void

    var body: some View {
        HomeOrientationView(
            state: state,
            isOffline: !syncService.isOnline,
            syncError: syncService.syncError?.localizedDescription,
            lastSyncDate: syncService.lastSyncDate,
            now: Date(),
            retry: load,
            onViewActivity: onViewActivity
        )
        .onAppear(perform: load)
        .onChange(of: syncService.isSyncing) { wasSyncing, isSyncing in
            if wasSyncing && !isSyncing { load() }
        }
        .onChange(of: authService.currentUser?.id) { _, _ in load() }
    }

    private func load() {
        guard authService.isAuthenticated, let userID = authService.currentUser?.id else {
            state = .failed("Account identity is unavailable. Sign in again to view saved activity.")
            return
        }
        do {
            state = .ready(try ActivityRecordSource.load(from: dataContainer, userID: userID))
        } catch {
            state = .failed("Saved activity could not be read. \(error.localizedDescription)")
        }
    }
}
