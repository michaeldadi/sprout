import SwiftUI

struct ActivityJourneyView: View {
    let state: ActivityLoadState
    let isOffline: Bool
    let syncError: String?
    let lastSyncDate: Date?
    let now: Date
    let retry: () -> Void
    @Binding var requestedTransactionID: String?

    @State private var query = ""
    @State private var kind: ActivityKind = .all
    @State private var period: ActivityPeriod = .recent
    @State private var path: [String] = []

    private var items: [ActivityItem] {
        if case .ready(let items) = state { return items }
        return []
    }
    private var filtered: [ActivityItem] {
        ActivityFilter(query: query, kind: kind, period: period, now: now).apply(to: items)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: SproutSpacing.md) {
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
                .padding(.horizontal, SproutSpacing.screen)
                .padding(.top, SproutSpacing.lg)
                .padding(.bottom, SproutSpacing.xl)
            }
            .background(SproutColor.canvas)
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { id in
                if let item = items.first(where: { $0.id == id }) {
                    ActivityDetailView(item: item)
                } else {
                    SproutStatePanel(title: "Transaction unavailable", detail: "This record is no longer available in your saved activity.")
                        .padding(SproutSpacing.lg)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .background(SproutColor.canvas)
                }
            }
            .onAppear(perform: consumeDeepLink)
            .onChange(of: requestedTransactionID) { _, _ in consumeDeepLink() }
            .onChange(of: items.map(\.id)) { _, _ in consumeDeepLink() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SproutSpacing.xs) {
            Text("Activity").font(SproutType.screenTitle).foregroundStyle(SproutColor.textPrimary)
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
            SproutStatePanel(title: "Loading activity", detail: "Reading saved transactions on this device.", isLoading: true)
        case .failed(let message):
            VStack(spacing: SproutSpacing.md) {
                SproutStatePanel(title: "Activity unavailable", detail: message, kind: .error)
                SproutActionButton(title: "Try again", action: retry)
            }
        case .ready(let allItems):
            if allItems.isEmpty {
                SproutStatePanel(title: "No saved transactions", detail: "Your saved transactions will appear here when available.")
            } else {
                filters
                Text("\(filtered.count) of \(allItems.count) saved transactions")
                    .font(SproutType.detail).foregroundStyle(SproutColor.textSecondary)
                let unsyncedCount = allItems.filter { $0.syncState != .synced }.count
                if unsyncedCount > 0 {
                    SproutStatusLine(
                        text: "\(unsyncedCount) Sprout \(unsyncedCount == 1 ? "record needs" : "records need") sync · See row details",
                        kind: .warning
                    )
                }
                if filtered.isEmpty {
                    SproutStatePanel(title: "No matches", detail: "Try a different search, type, or period.")
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { item in
                            NavigationLink(value: item.id) { ActivityListRow(item: item) }
                                .buttonStyle(.plain)
                            if item.id != filtered.last?.id {
                                Divider().overlay(SproutColor.separator)
                            }
                        }
                    }
                }
            }
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: SproutSpacing.sm) {
            SproutSearchField(title: "Search activity", text: $query)
            Picker("Period", selection: $period) {
                ForEach(ActivityPeriod.allCases) { option in Text(option.rawValue).tag(option) }
            }
            .pickerStyle(.segmented)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SproutSpacing.xs) {
                    ForEach(ActivityKind.allCases) { option in
                        Button(option.rawValue) { kind = option }
                            .font(SproutType.label)
                            .foregroundStyle(kind == option ? SproutColor.onAction : SproutColor.action)
                            .padding(.horizontal, SproutSpacing.md)
                            .frame(minHeight: 44)
                            .background(kind == option ? SproutColor.action : SproutColor.actionSubtle, in: Capsule())
                            .accessibilityAddTraits(kind == option ? .isSelected : [])
                    }
                }
            }
        }
    }

    private func consumeDeepLink() {
        guard let id = requestedTransactionID, !id.isEmpty else { return }
        guard case .ready = state else { return }
        path = [id]
        requestedTransactionID = nil
    }
}

private struct ActivityListRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: ActivityItem

    var body: some View {
        VStack(alignment: .leading, spacing: SproutSpacing.xs) {
            HStack(alignment: .center, spacing: SproutSpacing.sm) {
                identity
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: SproutSpacing.xs)
                    amount
                }
            }
            if dynamicTypeSize.isAccessibilitySize {
                amount.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, SproutSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 64)
        .accessibilityElement(children: .combine)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: SproutSpacing.xxs) {
            Text(item.title).font(SproutType.rowTitle).foregroundStyle(SproutColor.textPrimary)
            Text(metadata)
                .font(SproutType.detail).foregroundStyle(SproutColor.textSecondary)
            if let label = item.syncState.label {
                Text(label).font(SproutType.label)
                    .foregroundStyle(item.syncState == .failed || item.syncState == .conflict ? SproutColor.error : SproutColor.warning)
            }
        }
    }

    private var metadata: String {
        let category = item.category.localizedCaseInsensitiveCompare(item.kindLabel) == .orderedSame
            ? nil : item.category
        return ([item.kindLabel, category, item.date.formatted(date: .abbreviated, time: .omitted)]
            .compactMap { $0 }).joined(separator: " · ")
    }

    private var amount: some View {
        VStack(alignment: .trailing, spacing: 2) {
            SproutAmountText(amount: item.amount, currencyCode: item.currencyCode)
                .multilineTextAlignment(.trailing)
            Text(item.currencyCode).font(SproutType.label).foregroundStyle(SproutColor.textSecondary)
        }
    }
}

private struct ActivityDetailView: View {
    let item: ActivityItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SproutSpacing.lg) {
                VStack(alignment: .leading, spacing: SproutSpacing.sm) {
                    Text(item.title).font(SproutType.screenTitle).foregroundStyle(SproutColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(item.kindLabel).font(SproutType.detail).foregroundStyle(SproutColor.textSecondary)
                    SproutAmountText(amount: item.amount, currencyCode: item.currencyCode, isLarge: true)
                    Text("\(item.currencyCode) · Source amount")
                        .font(SproutType.label).foregroundStyle(SproutColor.textSecondary)
                }
                if let label = item.syncState.label {
                    SproutStatusLine(
                        text: "Sprout \(label.lowercased()) · Bank status not shown",
                        kind: item.syncState == .failed || item.syncState == .conflict ? .error : .warning
                    )
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(details.enumerated()), id: \.offset) { index, detail in
                        detailLine(detail.0, detail.1)
                        if index < details.count - 1 {
                            Divider().overlay(SproutColor.separator)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SproutSpacing.screen)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SproutColor.canvas)
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: SproutSpacing.xxs) {
            Text(label).font(SproutType.label).foregroundStyle(SproutColor.textSecondary)
            Text(value).font(SproutType.body).foregroundStyle(SproutColor.textPrimary)
        }
        .padding(.vertical, SproutSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private var details: [(String, String)] {
        var result = [("Date · device time zone", fullDate(item.date)), ("Category", item.category)]
        if let method = item.paymentMethod, !method.isEmpty {
            result.append(("Payment method", method))
        }
        result.append(("Last Sprout record sync", item.lastSyncedAt.map(fullDate) ?? "Unavailable"))
        if let notes = item.notes, !notes.isEmpty {
            result.append(("Notes", notes))
        }
        return result
    }

    private func fullDate(_ date: Date) -> String {
        let timeZone = TimeZone.current.abbreviation(for: date) ?? TimeZone.current.identifier
        return "\(date.formatted(date: .complete, time: .shortened)) \(timeZone)"
    }
}
