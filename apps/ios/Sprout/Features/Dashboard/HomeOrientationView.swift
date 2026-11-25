import SwiftUI

struct HomeSnapshot {
    let allCount: Int
    let recent: [ActivityItem]

    init(items: [ActivityItem], now: Date) {
        allCount = items.count
        recent = ActivityFilter(period: .recent, now: now).apply(to: items)
    }

    var latest: ActivityItem? { recent.first }
    var unsyncedCount: Int { recent.filter { $0.syncState != .synced }.count }
}

struct HomeOrientationView: View {
    let state: ActivityLoadState
    let isOffline: Bool
    let syncError: String?
    let lastSyncDate: Date?
    let now: Date
    let retry: () -> Void
    let onViewActivity: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SproutSpacing.lg) {
                header
                if isOffline {
                    SproutStatusBanner(title: "Offline", detail: "Showing records saved on this device. Changes may not be current.", kind: .warning)
                } else if let syncError {
                    SproutStatusBanner(title: "Could not update activity", detail: syncError, kind: .error)
                } else if let lastSyncDate, now.timeIntervalSince(lastSyncDate) > 86_400 {
                    SproutStatusBanner(title: "May be out of date", detail: "Last full sync \(lastSyncDate.formatted(date: .abbreviated, time: .shortened)).", kind: .warning)
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SproutSpacing.screen)
            .padding(.top, SproutSpacing.lg)
            .padding(.bottom, SproutSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SproutColor.canvas)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SproutSpacing.xs) {
            Text("Home").font(SproutType.screenTitle).foregroundStyle(SproutColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Your Sprout account")
                .font(SproutType.detail).foregroundStyle(SproutColor.textSecondary)
            Text(lastSyncDate.map { "Last full sync \($0.formatted(date: .abbreviated, time: .shortened))" }
                 ?? "Full sync time unavailable")
                .font(SproutType.label).foregroundStyle(SproutColor.textSecondary)
        }
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            SproutStatePanel(title: "Loading home", detail: "Reading saved transactions on this device.", isLoading: true)
        case .failed(let message):
            SproutStatePanel(title: "Home unavailable", detail: message, kind: .error)
            SproutActionButton(title: "Try again", action: retry)
        case .ready(let items):
            let snapshot = HomeSnapshot(items: items, now: now)
            if let latest = snapshot.latest {
                VStack(alignment: .leading, spacing: SproutSpacing.sm) {
                    Text("Latest saved transaction").font(SproutType.sectionTitle)
                        .foregroundStyle(SproutColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(snapshot.recent.count) saved \(snapshot.recent.count == 1 ? "transaction" : "transactions") · Last 30 days")
                        .font(SproutType.detail).foregroundStyle(SproutColor.textSecondary)
                    VStack(alignment: .leading, spacing: SproutSpacing.xs) {
                        Text(latest.title).font(SproutType.rowTitle)
                            .foregroundStyle(SproutColor.textPrimary)
                        SproutAmountText(amount: latest.amount, currencyCode: latest.currencyCode, isLarge: true)
                        Text("\(latest.kindLabel) · \(latest.date.formatted(date: .abbreviated, time: .omitted)) · \(latest.currencyCode)")
                            .font(SproutType.detail).foregroundStyle(SproutColor.textSecondary)
                    }
                    .padding(.top, SproutSpacing.xs)
                }
                SproutActionButton(title: "View activity", action: onViewActivity)
                if snapshot.unsyncedCount > 0 {
                    SproutStatusLine(
                        text: "\(snapshot.unsyncedCount) recent Sprout \(snapshot.unsyncedCount == 1 ? "record needs" : "records need") sync · Details in Activity",
                        kind: .warning
                    )
                }
            } else {
                SproutStatePanel(
                    title: snapshot.allCount == 0 ? "No saved transactions" : "No recent saved transactions",
                    detail: snapshot.allCount == 0
                        ? "Your saved transactions will appear here when available."
                        : "View older transactions in Activity. Choose All time."
                )
                SproutActionButton(title: "View activity", action: onViewActivity)
            }
        }
    }
}
