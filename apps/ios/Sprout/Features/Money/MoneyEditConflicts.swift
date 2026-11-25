import Foundation
import SwiftUI

/// A decision is bound to the two displayed versions, never to a later refresh.
struct MoneyEditConflictReview: Identifiable {
    let id = UUID()
    let mutationId: String
    let payload: Data
    let entityId: String
    let kind: String
    let localSummary: String
    let serverSummary: String?
    let serverVersion: Int?

    static func capture(mutationId: String, payload: Data, workspace: MoneyWorkspace?) -> Self? {
        guard let value = try? JSONSerialization.jsonObject(with: payload) as? [String: Any], let command = value["command"] as? [String: Any], let type = command["type"] as? String else { return nil }
        if type == "transaction.upsert", var object = command["transaction"] as? [String: Any] {
            object["version"] = 0; object["updatedAt"] = ""
            guard let data = try? JSONSerialization.data(withJSONObject: object), let local = try? JSONDecoder().decode(MoneyTransaction.self, from: data) else { return nil }
            let server = workspace?.transactions.first { $0.id == local.id && $0.source != "plaid" && $0.providerId == nil }
            return Self(mutationId: mutationId, payload: payload, entityId: local.id, kind: "expense", localSummary: summary(local), serverSummary: server.map(summary), serverVersion: server?.version)
        }
        if type == "goal.upsert", let object = command["goal"], let data = try? JSONSerialization.data(withJSONObject: object), let local = try? JSONDecoder().decode(MoneyGoal.self, from: data) {
            let server = workspace?.goals?.first { $0.id == local.id && !$0.deleted }
            return Self(mutationId: mutationId, payload: payload, entityId: local.id, kind: "goal", localSummary: summary(local), serverSummary: server.map { summary($0.data) }, serverVersion: server?.version)
        }
        return nil
    }
    func command() throws -> [String: Any] {
        guard let serverVersion, serverVersion > 0, let value = try JSONSerialization.jsonObject(with: payload) as? [String: Any], var command = value["command"] as? [String: Any] else { throw MoneyAPIError(code: "REVIEW_REQUIRED", message: "The synced record is unavailable. Refresh before making a new edit.") }
        command["expectedVersion"] = serverVersion; return command
    }
    func currentVersion(in workspace: MoneyWorkspace?) -> Int? {
        if kind == "expense" { return workspace?.transactions.first { $0.id == entityId && $0.source != "plaid" && $0.providerId == nil }?.version }
        return workspace?.goals?.first { $0.id == entityId && !$0.deleted }?.version
    }
    private static func summary(_ item: MoneyTransaction) -> String { "\(item.merchant)\n\(item.amount.formatted) · \(item.type)\n\(item.date) · \(item.category)\n\(item.excluded ? "Excluded from totals" : "Included in totals")\n\(item.description)" }
    private static func summary(_ item: MoneyGoal) -> String { "\(item.name)\n\(item.allocated.formatted) allocated of \(item.target.formatted)\nTarget date: \(item.targetDate ?? "none")\n\(item.archived ? "Archived" : "Active")" }
}

struct MoneyEditConflictButton: View {
    @EnvironmentObject private var store: MoneyStore
    let mutation: MoneyMutation
    @State private var selected: MoneyEditConflictReview?
    var body: some View {
        Button("Review saved edit") { selected = MoneyEditConflictReview.capture(mutationId: mutation.id, payload: mutation.payload, workspace: store.workspace) }.disabled(store.refreshing)
            .accessibilityIdentifier("money.conflict.\(mutation.entityKey)")
            .sheet(item: $selected) { MoneyEditConflictSheet(review: $0).environmentObject(store) }
    }
}

private struct MoneyEditConflictSheet: View {
    @EnvironmentObject private var store: MoneyStore
    @Environment(\.dismiss) private var dismiss
    let review: MoneyEditConflictReview
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Your saved edit") { Text(review.localSummary) }
                Section("Latest synced \(review.kind)") { Text(review.serverSummary ?? "This record is no longer available. Your edit remains on this device; it cannot replace a missing record.") }
                Text("Compare both versions before choosing. Closing this review preserves your saved edit.").font(.footnote)
                if let error { Text(error).foregroundStyle(SproutColor.error) }
                Button("Keep my \(review.kind) edit") { do { try store.keepReviewedEdit(review); dismiss() } catch { self.error = error.localizedDescription } }.disabled(review.serverVersion == nil || store.refreshing)
                Button(review.serverVersion == nil ? "Discard this edit" : "Use synced \(review.kind)", role: .destructive) { do { try store.discardReviewedEdit(review); dismiss() } catch { self.error = error.localizedDescription } }
            }.navigationTitle("Review \(review.kind) change").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}
