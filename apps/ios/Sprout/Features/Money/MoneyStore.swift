import Appwrite
import AppwriteEnums
import Combine
import CryptoKit
import Foundation
import SwiftData

@Model final class MoneyCache {
    @Attribute(.unique) var key: String
    var data: Data
    init(key: String, data: Data) {
        self.key = key; self.data = data
    }
}

@Model final class MoneyMutation {
    @Attribute(.unique) var id: String
    // `entity` collides with Core Data's NSEntityDescription accessor. Preserve
    // existing outbox values through SwiftData's lightweight rename migration.
    @Attribute(originalName: "entity") var entityKey: String
    var payload: Data
    var createdAt: Date
    var conflict: Bool
    init(id: String, entity: String, payload: Data) {
        self.id = id; entityKey = entity; self.payload = payload; createdAt = .now; conflict = false
    }
}

struct MoneyAPIError: LocalizedError {
    var code: String; var message: String
    var errorDescription: String? {
        message
    }
}

@MainActor final class MoneyStore: ObservableObject {
    private static weak var current: MoneyStore?
    @Published private(set) var workspace: MoneyWorkspace?
    @Published private(set) var mutations: [MoneyMutation] = []
    @Published private(set) var refreshing = false
    @Published var message: String?
    @Published private(set) var storageReady = false
    let identity: AppwriteAccountIdentity
    private var context: ModelContext?
    private var container: ModelContainer?
    private var active = true
    private var refreshRequested = false
    private(set) var reviewMode = false

    #if DEBUG
        convenience init(review: MoneyWorkspace) {
            self.init(identity: AppwriteAccountIdentity(id: "design-review", email: "alex@example.invalid", name: "Alex"))
            reviewMode = true; workspace = review; mutations = []; context = nil; container = nil
        }
    #endif

    init(identity: AppwriteAccountIdentity) {
        self.identity = identity
        Self.current = self
        do {
            let project = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_PROJECT_ID") as? String ?? "unconfigured"
            let endpoint = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_ENDPOINT") as? String ?? "unconfigured"
            let scope = SHA256.hash(data: Data("\(endpoint)/\(project)/\(identity.id)".utf8)).map { String(format: "%02x", $0) }.joined()
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("SproutMoney", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            let config = ModelConfiguration(url: directory.appendingPathComponent("v1-\(scope).store"), cloudKitDatabase: .none)
            let container = try ModelContainer(for: MoneyCache.self, MoneyMutation.self, configurations: config)
            self.container = container; context = ModelContext(container); storageReady = true
            workspace = try context?.fetch(FetchDescriptor<MoneyCache>()).first.flatMap { try JSONDecoder().decode(MoneyWorkspace.self, from: $0.data) }
            reloadMutations()
            try? MoneyReceiptArchive.prune(owner: identity.id, keeping: Set(mutations.compactMap { MoneyReceiptArchive.reference($0.payload) }))
        } catch { message = "The local store could not open. Your existing records have been preserved. Restart Sprout or contact support." }
    }

    static func eraseLocal(owner: String) throws {
        if let store = current, store.identity.id == owner, let context = store.context {
            store.active = false
            for cache in try context.fetch(FetchDescriptor<MoneyCache>()) { context.delete(cache) }
            for mutation in try context.fetch(FetchDescriptor<MoneyMutation>()) { context.delete(mutation) }
            try context.save(); store.workspace = nil; store.mutations = []
        } else {
            let project = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_PROJECT_ID") as? String ?? ""
            let endpoint = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_ENDPOINT") as? String ?? ""
            let scope = SHA256.hash(data: Data("\(endpoint)/\(project)/\(owner)".utf8)).map { String(format: "%02x", $0) }.joined()
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("SproutMoney")
            for url in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] where url.lastPathComponent.hasPrefix("v1-\(scope).store") { try FileManager.default.removeItem(at: url) }
        }
        try MoneyReceiptArchive.erase(owner: owner)
        let project = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_PROJECT_ID") as? String ?? ""
        let endpoint = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_ENDPOINT") as? String ?? ""
        let scope = SHA256.hash(data: Data("\(endpoint)/\(project)/\(owner)".utf8)).map { String(format: "%02x", $0) }.joined()
        let exports = FileManager.default.temporaryDirectory.appendingPathComponent("sprout-exports/\(scope)")
        if FileManager.default.fileExists(atPath: exports.path) { try FileManager.default.removeItem(at: exports) }
    }

    func deactivate() {
        active = false; workspace = nil; mutations = []
    }

    private func reloadMutations() {
        mutations = (try? context?.fetch(FetchDescriptor<MoneyMutation>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    var transactions: [MoneyTransaction] {
        var items = workspace?.transactions ?? []
        for mutation in mutations where !mutation.conflict {
            guard let body = try? JSONSerialization.jsonObject(with: mutation.payload) as? [String: Any], let command = body["command"] as? [String: Any] else { continue }
            if command["type"] as? String == "transaction.upsert", var object = command["transaction"] as? [String: Any] {
                object["version"] = 0; object["updatedAt"] = ""
                guard let data = try? JSONSerialization.data(withJSONObject: object), var item = try? JSONDecoder().decode(MoneyTransaction.self, from: data) else { continue }
                item.version = (command["expectedVersion"] as? Int ?? 0) + 1
                items.removeAll { $0.id == item.id }; items.append(item)
            } else if command["type"] as? String == "transaction.delete", let id = command["id"] as? String {
                items.removeAll { $0.id == id }
            }
        }
        return items.sorted { $0.date == $1.date ? $0.id > $1.id : $0.date > $1.date }
    }

    var goals: [MoneyRecord<MoneyGoal>] {
        var items = workspace?.goals ?? []
        for mutation in mutations where !mutation.conflict {
            guard let body = try? JSONSerialization.jsonObject(with: mutation.payload) as? [String: Any], let command = body["command"] as? [String: Any], command["type"] as? String == "goal.upsert", let object = command["goal"], let data = try? JSONSerialization.data(withJSONObject: object), let item = try? JSONDecoder().decode(MoneyGoal.self, from: data) else { continue }
            items.removeAll { $0.id == item.id }
            items.append(MoneyRecord(id: item.id, version: (command["expectedVersion"] as? Int ?? 0) + 1, updatedAt: "", deleted: false, data: item))
        }
        return items.sorted { $0.data.name.localizedCaseInsensitiveCompare($1.data.name) == .orderedAscending }
    }

    func pendingGoal(_ id: String) -> Bool { mutations.contains { $0.entityKey == "goal:\(id)" } }

    func pending(_ id: String) -> Bool {
        mutations.contains { $0.entityKey == "transaction:\(id)" }
    }

    func enqueue(_ command: [String: Any], entity: String, mutationId: String = UUID().uuidString.lowercased()) throws {
        guard active, let context, storageReady else { throw MoneyAPIError(code: "LOCAL_STORE", message: "The local store is unavailable. This change has not been saved.") }
        guard !mutations.contains(where: { $0.entityKey == entity }) else { throw MoneyAPIError(code: "PENDING", message: "This record already has a pending change. Sync or resolve it first.") }
        let payload = try JSONSerialization.data(withJSONObject: ["mutationId": mutationId, "command": command])
        context.insert(MoneyMutation(id: mutationId, entity: entity, payload: payload)); try context.save(); reloadMutations()
        Task { await refresh() }
    }

    func save(_ draft: ExpenseDraft) throws {
        guard let item = draft.transaction() else { throw MoneyAPIError(code: "INVALID_EXPENSE", message: "Enter a positive amount and merchant, then review the date and category.") }
        let financial: [String: Any] = ["type": "transaction.upsert", "transaction": item.commandValue, "expectedVersion": draft.expectedVersion]
        let mutationId = draft.expectedVersion == 0 ? item.id : UUID().uuidString.lowercased()
        if draft.keepReceipt {
            guard active, storageReady, let context, let jpeg = draft.receiptJPEG, jpeg.count <= 650_000 else { throw MoneyAPIError(code: "INVALID_RECEIPT", message: "Choose a receipt again before retaining its compressed copy.") }
            let financialEntity = "transaction:\(item.id)", receiptEntity = "receipt-upload:\(draft.receiptId)"
            guard !mutations.contains(where: { $0.entityKey == financialEntity || $0.entityKey == receiptEntity }) else { throw MoneyAPIError(code: "PENDING", message: "This transaction already has a pending change. Sync or resolve it first.") }
            let hash = SHA256.hash(data: jpeg).map { String(format: "%02x", $0) }.joined()
            let receipt: [String: Any] = ["type": "receipt.attach", "id": draft.receiptId, "transactionId": item.id, "sha256": hash]
            let financialData = try JSONSerialization.data(withJSONObject: ["mutationId": mutationId, "command": financial])
            let receiptId = UUID().uuidString.lowercased(), receiptData = try JSONSerialization.data(withJSONObject: ["mutationId": receiptId, "command": receipt, "attachmentFile": draft.receiptId + ".jpg"])
            try MoneyReceiptArchive.save(id: draft.receiptId, jpeg: jpeg, owner: identity.id)
            context.insert(MoneyMutation(id: mutationId, entity: financialEntity, payload: financialData)); context.insert(MoneyMutation(id: receiptId, entity: receiptEntity, payload: receiptData))
            do { try context.save() } catch { context.rollback(); try? MoneyReceiptArchive.remove(id: draft.receiptId, owner: identity.id); reloadMutations(); throw error }
            reloadMutations(); Task { await refresh() }
        } else { try enqueue(financial, entity: "transaction:\(item.id)", mutationId: mutationId) }
        AnalyticsManager.shared.trackCustom(name: "expense_reviewed", parameters: ["source": draft.source])
    }

    func saveProfile(_ profile: MoneyProfile, expectedVersion: Int? = nil) throws {
        let data = try JSONEncoder().encode(profile)
        var value = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        if value["monthlyTargetMinor"] == nil {
            value["monthlyTargetMinor"] = NSNull()
        }
        try enqueue(["type": "profile.update", "profile": value, "expectedVersion": expectedVersion ?? workspace?.profileVersion ?? 0], entity: "profile")
    }

    func refresh() async {
        guard active, !reviewMode, storageReady else { return }
        refreshRequested = true
        guard !refreshing else { return }
        refreshing = true; defer { refreshing = false }
        repeat {
            refreshRequested = false
            await refreshOnce()
        } while active && refreshRequested
    }

    /// Realtime is only a wake-up signal. Cursor sync validates and commits facts.
    func observeChanges(channel: String) async {
        guard active, !reviewMode, channel.range(of: #"^tablesdb\.[A-Za-z0-9_-]+\.tables\.sync_heads\.rows\.[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil,
              let client = try? AppwriteConnection.client() else { return }
        let realtime = Realtime(client)
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        // Reconnects may span missed events; always retrieve from our saved cursor.
        realtime.onOpen { continuation.yield(()) }
        defer { continuation.finish(); Task { try? await realtime.disconnect() } }
        do {
            _ = try await realtime.subscribe(channels: [channel]) { _ in continuation.yield(()) }
            guard !Task.isCancelled else { return }
            for await _ in stream {
                try await Task.sleep(nanoseconds: 400_000_000)
                guard active, !Task.isCancelled else { return }
                await refresh()
            }
        } catch { /* Resume/pull-to-refresh and the bounded freshness timer recover missed signals. */ }
    }

    private func download() async throws -> Data {
        guard let workspace, workspace.projectionVersion == 3, var cursor = workspace.cursor else { return try await request(path: "/v1/bootstrap") }
        do {
            var cycle = try MoneySyncCycle(base: JSONEncoder().encode(workspace), owner: identity.id)
            for _ in 0 ..< 400 {
                let page = try await request(path: "/v1/sync?cursor=\(cursor)")
                guard active else { throw CancellationError() }
                let step = try cycle.append(page); cursor = step.cursor
                if let result = step.result { return result }
            }
            throw MoneyAPIError(code: "SYNC_LIMIT", message: "This account needs a fresh snapshot. Pending changes are preserved.")
        } catch let error as MoneyAPIError where ["CURSOR_INVALID", "CURSOR_EXPIRED", "SYNC_LIMIT"].contains(error.code) {
            return try await request(path: "/v1/bootstrap")
        }
    }

    private func refreshOnce() async {
        guard active, let context else { return }
        do {
            var acknowledged: [(id: String, payload: Data)] = []
            let pending = mutations.filter { !$0.conflict }.map { (id: $0.id, entityKey: $0.entityKey, payload: $0.payload) }
            for mutation in pending.sorted(by: { ($0.entityKey.hasPrefix("receipt-upload:") ? 1 : 0) < ($1.entityKey.hasPrefix("receipt-upload:") ? 1 : 0) }) {
                guard active else { return }
                guard mutations.contains(where: { $0.id == mutation.id && $0.payload == mutation.payload && !$0.conflict }) else { continue }
                do {
                    let payload = mutation.entityKey.hasPrefix("receipt-upload:") ? try MoneyReceiptArchive.wire(mutation.payload, owner: identity.id) : mutation.payload
                    _ = try await request(path: "/v1/commands", body: payload)
                    guard active else { return }
                    acknowledged.append((mutation.id, mutation.payload))
                } catch let error as MoneyAPIError where ["VERSION_CONFLICT", "STALE_EVIDENCE", "STALE_APPROVAL", "INVALID_REQUEST", "IMPORT_CHANGED", "PAYLOAD_TOO_LARGE", "RECEIPT_CHANGED", "RECEIPT_REMOVED", "INVALID_RECEIPT", "RECEIPT_SCOPE", "RECEIPT_LIMIT", "RECEIPT_LOCAL_MISSING", "RECEIPT_LOCAL_CHANGED", "ATTACHMENT_TARGET_GONE", "PROVIDER_OWNED", "NOT_FOUND", "PLUS_REQUIRED", "UNSUPPORTED_MERCHANT", "ACCOUNT_DELETING"].contains(error.code) {
                    if let current = mutations.first(where: { $0.id == mutation.id && $0.payload == mutation.payload }) { current.conflict = true; try context.save() }
                }
            }
            reloadMutations()
            let result = try await download()
            guard active else { return }
            let value = try JSONDecoder().decode(MoneyWorkspace.self, from: result)
            guard value.accountId == identity.id else { throw MoneyAPIError(code: "ACCOUNT_CHANGED", message: "The account changed during sync. No downloaded records were saved.") }
            guard value.contractVersion == 1 else { throw MoneyAPIError(code: "UPDATE_REQUIRED", message: "Update Sprout to sync this account.") }
            let records = try context.fetch(FetchDescriptor<MoneyCache>())
            if let record = records.first {
                record.data = result
            } else {
                context.insert(MoneyCache(key: "workspace", data: result))
            }
            // Keep local overlays until the acknowledged canonical records and
            // cursor are durably saved together. A failed download must never
            // make a just-saved expense disappear from the offline view.
            let uploadedReceipts = acknowledged.compactMap { MoneyReceiptArchive.reference($0.payload) }
            for mutation in acknowledged { if let current = mutations.first(where: { $0.id == mutation.id && $0.payload == mutation.payload }) { context.delete(current) } }
            do { try context.save() } catch { context.rollback(); throw error }
            workspace = value; reloadMutations()
            for id in uploadedReceipts { try? MoneyReceiptArchive.remove(id: id, owner: identity.id) }
            message = mutations.contains(where: \.conflict) ? "A record changed on another device. Review the pending change before retrying." : nil
        } catch { reloadMutations(); message = (error as? MoneyAPIError)?.message ?? "Can't reach Sprout. Saved records are available and pending changes will retry." }
    }

    /// Explicitly discard a conflict only after the user reviews the server record.
    func useServerVersion(_ mutation: MoneyMutation) throws {
        guard active, let context, mutations.contains(where: { $0.id == mutation.id && $0.payload == mutation.payload }) else { return }
        let receipt = MoneyReceiptArchive.reference(mutation.payload)
        if let receipt {
            let id = UUID().uuidString.lowercased(), payload = try JSONSerialization.data(withJSONObject: ["mutationId": id, "command": ["type": "receipt.cancel", "id": receipt]])
            context.insert(MoneyMutation(id: id, entity: "receipt-cancel:\(receipt)", payload: payload))
        }
        context.delete(mutation)
        do { try context.save() } catch { context.rollback(); reloadMutations(); throw error }
        if let receipt { try? MoneyReceiptArchive.remove(id: receipt, owner: identity.id) }
        reloadMutations()
        Task { await refresh() }
    }

    func pendingExpenseDescription(_ mutation: MoneyMutation) -> String {
        guard let value = try? JSONSerialization.jsonObject(with: mutation.payload) as? [String: Any], let command = value["command"] as? [String: Any], let expense = command["transaction"] as? [String: Any], let merchant = expense["merchant"] as? String, let amount = expense["amount"] as? [String: Any], let minor = amount["minor"] as? Int64 else { return "A saved change needs review before it can sync." }
        return "Your edit: \(merchant) · \(MoneyAmount(minor: minor).formatted) · \(expense["date"] as? String ?? "")"
    }

    func goalConflictDescription(_ mutation: MoneyMutation) -> String {
        guard let value = try? JSONSerialization.jsonObject(with: mutation.payload) as? [String: Any], let command = value["command"] as? [String: Any], let object = command["goal"], let data = try? JSONSerialization.data(withJSONObject: object), let goal = try? JSONDecoder().decode(MoneyGoal.self, from: data) else { return "Your saved goal needs review." }
        return "Your edit: \(goal.name), \(goal.allocated.formatted) allocated of \(goal.target.formatted), date \(goal.targetDate ?? "none"), \(goal.archived ? "archived" : "active")."
    }
    func discardBudgetEdit(_ review: MoneyBudgetConflictReview) throws {
        guard active, let mutation = mutations.first(where: { $0.id == review.mutationId && $0.payload == review.payload && $0.conflict }) else { throw MoneyAPIError(code: "REVIEW_REQUIRED", message: "This saved edit changed. Reopen the review.") }
        try useServerVersion(mutation)
    }

    func keepBudgetEdit(_ review: MoneyBudgetConflictReview) throws {
        guard active, let context, let original = mutations.first(where: { $0.id == review.mutationId && $0.payload == review.payload && $0.conflict }), let target = review.server else { throw MoneyAPIError(code: "REVIEW_REQUIRED", message: "Refresh and review the saved budget edit first.") }
        guard workspace?.budgets.first(where: { $0.id == target.id })?.version == target.version else { throw MoneyAPIError(code: "REVIEW_REQUIRED", message: "This budget changed again. Reopen the review before choosing.") }
        let entity = "budget:\(target.id)"
        guard !mutations.contains(where: { $0.id != original.id && $0.entityKey == entity }) else { throw MoneyAPIError(code: "PENDING", message: "This budget already has a pending edit. Sync or resolve it first.") }
        let next = UUID().uuidString.lowercased()
        let data = try JSONSerialization.data(withJSONObject: ["mutationId": next, "command": review.command()])
        context.delete(original); context.insert(MoneyMutation(id: next, entity: entity, payload: data))
        do { try context.save() } catch { context.rollback(); reloadMutations(); throw error }
        reloadMutations(); Task { await refresh() }
    }

    func discardReviewedEdit(_ review: MoneyEditConflictReview) throws {
        guard active, let original = mutations.first(where: { $0.id == review.mutationId && $0.payload == review.payload && $0.conflict }) else { throw MoneyAPIError(code: "REVIEW_REQUIRED", message: "This saved edit changed. Reopen the review.") }
        try useServerVersion(original)
    }

    func keepReviewedEdit(_ review: MoneyEditConflictReview) throws {
        guard active, let context, !refreshing, let original = mutations.first(where: { $0.id == review.mutationId && $0.payload == review.payload && $0.conflict }), let version = review.serverVersion, review.currentVersion(in: workspace) == version else { throw MoneyAPIError(code: "REVIEW_REQUIRED", message: "This record changed again. Reopen the review before choosing.") }
        let next = UUID().uuidString.lowercased()
        let data = try JSONSerialization.data(withJSONObject: ["mutationId": next, "command": review.command()])
        context.delete(original); context.insert(MoneyMutation(id: next, entity: original.entityKey, payload: data))
        do { try context.save() } catch { context.rollback(); reloadMutations(); throw error }
        reloadMutations(); Task { await refresh() }
    }

    func request(path: String, body: Data? = nil, function: String = "sprout-api") async throws -> Data {
        try AppwriteTransportTestFault.check()
        guard active, AppwriteNativeSession.shared.identity?.id == identity.id else { throw MoneyAPIError(code: "UNAUTHENTICATED", message: "Sign in again to continue.") }
        var scopedBody = body
        if let body, var value = try JSONSerialization.jsonObject(with: body) as? [String: Any] {
            value["_account"] = identity.id; scopedBody = try JSONSerialization.data(withJSONObject: value)
        }
        let execution = try await Functions(AppwriteConnection.client()).createExecution(functionId: function, body: scopedBody.flatMap { String(data: $0, encoding: .utf8) }, async: false, path: path, method: body == nil ? .gET : .pOST, headers: ["x-sprout-account": identity.id])
        let data = Data(execution.responseBody.utf8)
        guard (200 ..< 300).contains(execution.responseStatusCode) else {
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let error = object?["error"] as? [String: Any]
            throw MoneyAPIError(code: error?["code"] as? String ?? "SERVICE_UNAVAILABLE", message: error?["message"] as? String ?? "This service is unavailable. Try again shortly.")
        }
        return data
    }
}
