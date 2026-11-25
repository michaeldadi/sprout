import XCTest
@testable import FoundationReviewHost

final class ActivityPresentationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_600_000)

    func testTypePeriodAndSearchPreserveSourceAmount() {
        let items = [
            item("pay", "Payroll deposit", .income, daysAgo: 1),
            item("transfer", "Transfer to savings", .transfer, daysAgo: 2),
            item("market", "North Market", .expense, daysAgo: 3),
            item("old", "Cinema", .expense, daysAgo: 60)
        ]
        XCTAssertEqual(ActivityFilter(kind: .expense, now: now).apply(to: items).map(\.id), ["market"])
        XCTAssertEqual(ActivityFilter(kind: .transfer, now: now).apply(to: items).map(\.id), ["transfer"])
        XCTAssertEqual(ActivityFilter(query: "north", now: now).apply(to: items).first?.amount, Decimal(string: "84.27"))
        XCTAssertEqual(ActivityFilter(period: .all, now: now).apply(to: items).count, 4)
        XCTAssertEqual(items.count, 4)
    }

    func testHomeUsesOnlyRecentSavedRecordsAndKeepsOlderCount() {
        let latest = item("latest", "North Market", .expense, daysAgo: 1)
        let older = item("older", "Cinema", .expense, daysAgo: 60)
        let snapshot = HomeSnapshot(items: [older, latest], now: now)
        XCTAssertEqual(snapshot.allCount, 2)
        XCTAssertEqual(snapshot.recent.map(\.id), ["latest"])
        XCTAssertEqual(snapshot.latest?.amount, latest.amount)
        XCTAssertTrue(HomeSnapshot(items: [older], now: now).recent.isEmpty)
    }

    private func item(_ id: String, _ title: String, _ kind: ActivityKind, daysAgo: TimeInterval) -> ActivityItem {
        ActivityItem(id: id, title: title, category: "Test", amount: Decimal(string: "84.27")!,
            currencyCode: "USD", date: now.addingTimeInterval(-daysAgo * 86_400), kind: kind,
            syncState: .synced, lastSyncedAt: nil, paymentMethod: nil, notes: nil)
    }
}
