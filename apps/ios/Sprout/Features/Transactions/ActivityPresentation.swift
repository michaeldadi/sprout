import Foundation

enum ActivityKind: String, CaseIterable, Identifiable {
    case all = "All", income = "Income", expense = "Expenses", transfer = "Transfers"
    var id: String { rawValue }
}

enum ActivityPeriod: String, CaseIterable, Identifiable {
    case recent = "Last 30 days", all = "All time"
    var id: String { rawValue }
}

enum ActivitySyncState: String {
    case synced, pending, syncing, failed, conflict
    var label: String? {
        switch self {
        case .synced: nil
        case .pending: "Pending sync"
        case .syncing: "Syncing"
        case .failed: "Sync failed"
        case .conflict: "Sync conflict"
        }
    }
}

struct ActivityItem: Identifiable {
    let id: String
    let title: String
    let category: String
    let amount: Decimal
    let currencyCode: String
    let date: Date
    let kind: ActivityKind
    let syncState: ActivitySyncState
    let lastSyncedAt: Date?
    let paymentMethod: String?
    let notes: String?
    var kindLabel: String {
        switch kind {
        case .income: "Income"
        case .expense: "Expense"
        case .transfer: "Transfer"
        case .all: "Transaction"
        }
    }
}

enum ActivityLoadState {
    case loading, ready([ActivityItem]), failed(String)
}

struct ActivityFilter {
    var query = ""
    var kind: ActivityKind = .all
    var period: ActivityPeriod = .recent
    var now = Date()

    func apply(to items: [ActivityItem]) -> [ActivityItem] {
        let start = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? .distantPast
        return items.filter { item in
            (kind == .all || item.kind == kind)
                && (period == .all || (item.date >= start && item.date <= now))
                && (query.isEmpty || item.title.localizedStandardContains(query)
                    || item.category.localizedStandardContains(query))
        }.sorted { $0.date > $1.date }
    }
}
