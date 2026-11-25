import Foundation
import SwiftUI

/// Immutable values shown for one conflict decision, including its reviewed version.
struct MoneyBudgetConflictReview: Identifiable {
    let id = UUID()
    let mutationId: String
    let payload: Data
    let local: MoneyBudget
    let server: MoneyRecord<MoneyBudget>?

    static func capture(mutationId: String, payload: Data, budgets: [MoneyRecord<MoneyBudget>]) -> Self? {
        guard let envelope = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let command = envelope["command"] as? [String: Any], command["type"] as? String == "budget.upsert",
              let object = command["budget"], let data = try? JSONSerialization.data(withJSONObject: object),
              let local = try? JSONDecoder().decode(MoneyBudget.self, from: data),
              !local.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              local.month.range(of: #"^\d{4}-(0[1-9]|1[0-2])$"#, options: .regularExpression) != nil,
              local.limit.currency == "USD", local.limit.minor > 0 else { return nil }
        let available = budgets.filter { !$0.deleted }
        let server = available.first { $0.id == local.id } ?? available.first { $0.data.month == local.month && MoneyBudget.categoryKey($0.data.category) == MoneyBudget.categoryKey(local.category) }
        return Self(mutationId: mutationId, payload: payload, local: local, server: server)
    }

    func command() throws -> [String: Any] {
        guard let server else { throw MoneyAPIError(code: "REVIEW_REQUIRED", message: "Refresh and review your plan before adding a new limit.") }
        return ["type": "budget.upsert", "budget": ["id": server.id, "category": local.category, "month": local.month, "limit": ["minor": local.limit.minor, "currency": "USD"]], "expectedVersion": server.version]
    }
}

struct MoneyBudgetConflictsSection: View {
    @EnvironmentObject private var store: MoneyStore
    @State private var selected: MoneyBudgetConflictReview?
    private var conflicts: [MoneyMutation] { store.mutations.filter { $0.conflict && $0.entityKey.hasPrefix("budget:") } }
    var body: some View {
        if !conflicts.isEmpty {
            MoneyCard {
                Text("Budget changes need review").font(.headline)
                ForEach(conflicts, id: \.id) { mutation in
                    if let review = MoneyBudgetConflictReview.capture(mutationId: mutation.id, payload: mutation.payload, budgets: store.workspace?.budgets ?? []) {
                        Text("\(review.local.category) · \(review.local.month)")
                        Button("Review budget change") { selected = review }.disabled(store.refreshing).accessibilityLabel("Review \(review.local.category) budget for \(review.local.month)")
                    } else { Text("A saved budget edit could not be opened. It remains on this device; you can discard it in Profile.").font(.footnote) }
                }
            }.sheet(item: $selected) { MoneyBudgetConflictSheet(review: $0).environmentObject(store) }
        }
    }
}

private struct MoneyBudgetConflictSheet: View {
    @EnvironmentObject private var store: MoneyStore
    @Environment(\.dismiss) private var dismiss
    let review: MoneyBudgetConflictReview
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Your saved edit") { Text(review.local.category); Text(review.local.month); Text(review.local.limit.formatted).monospacedDigit() }
                Section("Latest synced budget") {
                    if let current = review.server?.data { Text(current.category); Text(current.month); Text(current.limit.formatted).monospacedDigit() }
                    else { Text("This budget is no longer available. Refresh and review your plan before adding a new limit.") }
                }
                Text("Compare both before choosing. Closing this sheet keeps your edit on this device.").font(.footnote)
                if let error { Text(error).foregroundStyle(SproutColor.error) }
                Button("Keep my budget edit") { do { try store.keepBudgetEdit(review); dismiss() } catch { self.error = error.localizedDescription } }.disabled(review.server == nil)
                Button(review.server == nil ? "Discard this edit" : "Use synced budget", role: .destructive) { do { try store.discardBudgetEdit(review); dismiss() } catch { self.error = error.localizedDescription } }
            }.navigationTitle("Review budget change").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}
