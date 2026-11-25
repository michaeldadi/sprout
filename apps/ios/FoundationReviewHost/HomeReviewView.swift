import SwiftUI

private enum HomeReviewScene: String, CaseIterable, Identifiable {
    case records = "Records", empty = "Empty", older = "Older", loading = "Loading"
    case error = "Error", stale = "Stale", offline = "Offline"
    var id: String { rawValue }
}

private enum HomeReviewTab: Hashable { case home, activity }

/// Debug-only, fixed fictional states. The production DashboardView never reads these records.
struct HomeReviewView: View {
    @State private var scene: HomeReviewScene = .records
    @State private var selectedTab: HomeReviewTab = .home
    @State private var requestedID: String?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: SproutSpacing.xs) {
                Text("DEMO DATA · 8 NOV 2026 · NEW YORK")
                    .font(.caption2.weight(.bold)).foregroundStyle(SproutColor.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(HomeReviewScene.allCases) { option in
                            Button(option.rawValue) { scene = option; selectedTab = .home }
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .foregroundStyle(scene == option ? SproutColor.onAction : SproutColor.action)
                                .background(scene == option ? SproutColor.action : SproutColor.actionSubtle, in: Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, SproutSpacing.screen).padding(.vertical, SproutSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SproutColor.surface)

            TabView(selection: $selectedTab) {
                HomeOrientationView(
                    state: state,
                    isOffline: scene == .offline,
                    syncError: nil,
                    lastSyncDate: lastSyncDate,
                    now: ReviewFixture.now,
                    retry: { scene = .records },
                    onViewActivity: { selectedTab = .activity }
                )
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(HomeReviewTab.home)

                ActivityJourneyView(
                    state: state,
                    isOffline: scene == .offline,
                    syncError: nil,
                    lastSyncDate: lastSyncDate,
                    now: ReviewFixture.now,
                    retry: { scene = .records },
                    requestedTransactionID: $requestedID
                )
                .tabItem { Label("Activity", systemImage: "list.bullet") }
                .tag(HomeReviewTab.activity)
            }
            .tint(SproutColor.action)
        }
    }

    private var lastSyncDate: Date? {
        scene == .stale ? ReviewFixture.now.addingTimeInterval(-5 * 86_400)
            : ReviewFixture.now.addingTimeInterval(-600)
    }

    private var state: ActivityLoadState {
        switch scene {
        case .records, .stale, .offline: .ready(ReviewFixture.items)
        case .empty: .ready([])
        case .older: .ready(ReviewFixture.items.filter { $0.id == "demo-old" })
        case .loading: .loading
        case .error: .failed("Saved activity could not be read. Try again.")
        }
    }
}
