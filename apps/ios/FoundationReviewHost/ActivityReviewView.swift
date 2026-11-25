import SwiftUI

private enum ReviewScene: String, CaseIterable, Identifiable {
    case populated = "Records", empty = "Empty", loading = "Loading", error = "Error", stale = "Stale", offline = "Offline"
    var id: String { rawValue }
}

struct ActivityReviewView: View {
    @State private var scene: ReviewScene = .populated
    @State private var requestedID: String?

    private let now = ReviewFixture.now

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("DEMO DATA · 8 NOV 2026 · NEW YORK")
                    .font(.caption2.weight(.bold)).foregroundStyle(SproutColor.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(ReviewScene.allCases) { option in
                            Button(option.rawValue) { scene = option }
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .foregroundStyle(scene == option ? SproutColor.onAction : SproutColor.action)
                                .background(scene == option ? SproutColor.action : SproutColor.actionSubtle, in: Capsule())
                        }
                        Button("Open demo transaction link") { requestedID = "demo-ride" }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .foregroundStyle(SproutColor.action)
                            .background(SproutColor.actionSubtle, in: Capsule())
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SproutColor.surface)
            ActivityJourneyView(
                state: loadState,
                isOffline: scene == .offline,
                syncError: scene == .error ? "The latest sync failed. Saved records may still be available." : nil,
                lastSyncDate: scene == .stale ? now.addingTimeInterval(-5 * 86_400) : now.addingTimeInterval(-600),
                now: now,
                retry: { scene = .populated },
                requestedTransactionID: $requestedID
            )
        }
    }

    private var loadState: ActivityLoadState {
        switch scene {
        case .populated, .stale, .offline: .ready(ReviewFixture.items)
        case .empty: .ready([])
        case .loading: .loading
        case .error: .failed("Saved activity could not be read. Try again.")
        }
    }

}

enum ReviewFixture {
    static let now = Calendar(identifier: .gregorian).date(from: DateComponents(
        timeZone: TimeZone(identifier: "America/New_York"), year: 2026, month: 11, day: 8, hour: 9, minute: 41
    ))!

    static let items: [ActivityItem] = {
        let formatter = ISO8601DateFormatter()
        func date(_ value: String) -> Date { formatter.date(from: value)! }
        return [
            ActivityItem(id: "demo-grocery", title: "North Market", category: "Groceries", amount: Decimal(string: "84.27")!, currencyCode: "USD", date: date("2026-11-07T18:30:00Z"), kind: .expense, syncState: .synced, lastSyncedAt: date("2026-11-08T14:31:00Z"), paymentMethod: "Checking · 1034", notes: nil),
            ActivityItem(id: "demo-pay", title: "Payroll deposit", category: "Pay", amount: Decimal(string: "2480.00")!, currencyCode: "USD", date: date("2026-11-06T15:00:00Z"), kind: .income, syncState: .synced, lastSyncedAt: date("2026-11-08T14:31:00Z"), paymentMethod: "Checking · 1034", notes: nil),
            ActivityItem(id: "demo-transfer", title: "Transfer to rainy day savings", category: "Transfer", amount: Decimal(string: "350.00")!, currencyCode: "USD", date: date("2026-11-05T12:15:00Z"), kind: .transfer, syncState: .pending, lastSyncedAt: nil, paymentMethod: nil, notes: "Internal transfer"),
            ActivityItem(id: "demo-ride", title: "Metro ride", category: "Transit", amount: Decimal(string: "21.40")!, currencyCode: "USD", date: date("2026-11-04T23:10:00Z"), kind: .expense, syncState: .failed, lastSyncedAt: nil, paymentMethod: "Card · 7742", notes: nil),
            ActivityItem(id: "demo-old", title: "Cinema", category: "Entertainment", amount: Decimal(string: "16.00")!, currencyCode: "USD", date: date("2026-09-01T21:20:00Z"), kind: .expense, syncState: .synced, lastSyncedAt: date("2026-09-02T14:00:00Z"), paymentMethod: "Card · 7742", notes: nil)
        ]
    }()
}
