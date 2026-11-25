@testable import Sprout
import XCTest
import Appwrite
import Security
import UIKit
import CryptoKit

final class MoneyDomainTests: XCTestCase {
    func testIdentityCacheBeforeCredentialMetadataRemainsReadable() throws {
        let old=try JSONDecoder().decode(AppwriteAccountIdentity.self,from:Data("{\"id\":\"owner\",\"email\":\"qa@example.invalid\",\"name\":\"QA\"}".utf8));XCTAssertEqual(old.id,"owner");XCTAssertNil(old.hasPassword)
        let new=try JSONDecoder().decode(AppwriteAccountIdentity.self,from:Data("{\"id\":\"owner\",\"email\":\"qa@example.invalid\",\"name\":\"QA\",\"hasPassword\":true}".utf8));XCTAssertEqual(new.hasPassword,true)
    }
    func testPrivateExportRejectsChangedOrCrossBucketReceiptReferences() throws {
        let image = Data([255,216,255,1,2,3,255,217]), id = UUID().uuidString.lowercased()
        let checksum = SHA256.hash(data: image).map { String(format: "%02x", $0) }.joined()
        func json(bucket: String = "private", status: String = "ready") throws -> Data { try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "revision": 7, "exportedAt": "2026-11-10T10:00:00.000Z", "records": ["receipts": [["id": id, "deleted": false, "data": ["status": status, "fileId": "file", "bucketId": bucket, "sha256": checksum, "bytes": image.count]]]]]) }
        let receipt = try XCTUnwrap(MoneyExportArchive.receipts(in: json(), bucket: "private").first)
        XCTAssertNoThrow(try MoneyExportArchive.verify(image, receipt: receipt))
        XCTAssertThrowsError(try MoneyExportArchive.verify(Data([1,2,3]), receipt: receipt))
        XCTAssertThrowsError(try MoneyExportArchive.receipts(in: json(bucket: "other"), bucket: "private"))
        XCTAssertTrue(try MoneyExportArchive.receipts(in: json(status: "uploading"), bucket: "private").isEmpty)
        var archive = MoneyExportArchive.ZIP(); try archive.append(name: "sprout-export.json", data: json()); try archive.append(name: "receipts/\(id).jpg", data: image)
        XCTAssertThrowsError(try archive.append(name: "../escape", data: image)); XCTAssertThrowsError(try archive.append(name: "receipts/\(id).jpg", data: image))
        XCTAssertEqual(Array(archive.finish().prefix(4)), [80,75,3,4])
    }
    func testNotificationPreferencesPreserveLegacyCacheAndRoundTripLocalTimes() throws {
        let legacy = try JSONEncoder().encode(MoneyProfile())
        XCTAssertNil(try JSONDecoder().decode(MoneyProfile.self,from:legacy).quietHours)
        var reviewed = MoneyProfile(); reviewed.timezone = "America/Los_Angeles"; reviewed.quietHours = MoneyQuietHours(enabled:false,startMinute:1230,endMinute:450); reviewed.budgetAlerts = false
        let restored = try JSONDecoder().decode(MoneyProfile.self,from:JSONEncoder().encode(reviewed))
        XCTAssertEqual(restored.quietHours,reviewed.quietHours);XCTAssertEqual(restored.timezone,reviewed.timezone);XCTAssertEqual(restored.budgetAlerts,false)
    }
    func testReceiptOutboxKeepsPrivateFilesOutsideItsSmallReplayRecord() throws {
        let owner = "receipt-test-" + UUID().uuidString.lowercased(), other = "receipt-peer-" + UUID().uuidString.lowercased(), id = UUID().uuidString.lowercased(), data = Data("synthetic receipt bytes".utf8)
        defer { try? MoneyReceiptArchive.erase(owner: owner); try? MoneyReceiptArchive.erase(owner: other) }
        try MoneyReceiptArchive.save(id: id, jpeg: data, owner: owner)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let saved = try JSONSerialization.data(withJSONObject: ["mutationId": "save", "attachmentFile": id + ".jpg", "command": ["type": "receipt.attach", "id": id, "transactionId": "expense", "sha256": hash]])
        XCTAssertLessThan(saved.count, 1000); XCTAssertFalse(String(decoding: saved, as: UTF8.self).contains(data.base64EncodedString()))
        XCTAssertThrowsError(try MoneyReceiptArchive.read(id: id, owner: other))
        let wire = try XCTUnwrap(JSONSerialization.jsonObject(with: MoneyReceiptArchive.wire(saved, owner: owner)) as? [String: Any])
        XCTAssertNil(wire["attachmentFile"]); XCTAssertEqual((wire["command"] as? [String: Any])?["jpegBase64"] as? String, data.base64EncodedString())
        try MoneyReceiptArchive.prune(owner: owner, keeping: [id]); XCTAssertEqual(try MoneyReceiptArchive.read(id: id, owner: owner), data)
        try MoneyReceiptArchive.prune(owner: owner, keeping: []); XCTAssertThrowsError(try MoneyReceiptArchive.wire(saved, owner: owner))
    }
    func testReceiptReferenceCannotEscapeItsOwnerDirectory() throws {
        let owner = "receipt-test-" + UUID().uuidString.lowercased(); defer { try? MoneyReceiptArchive.erase(owner: owner) }
        XCTAssertThrowsError(try MoneyReceiptArchive.read(id: "../another-user", owner: owner))
        let saved = try JSONSerialization.data(withJSONObject: ["attachmentFile": "../another-user.jpg", "command": ["type": "receipt.attach", "id": UUID().uuidString.lowercased(), "sha256": "wrong"]])
        XCTAssertThrowsError(try MoneyReceiptArchive.wire(saved, owner: owner))
    }
    func testExpenseConflictCannotApproveAnUndisplayedLaterVersion() throws {
        var view = MoneyDesignFixture.workspace
        var server = try XCTUnwrap(view.transactions.first); server.version = 4; server.description = "Server note"
        view.transactions = [server]
        var local = server; local.description = "My note"; local.amount.minor = -2222
        let payload = try JSONSerialization.data(withJSONObject: ["command": ["type": "transaction.upsert", "transaction": local.commandValue, "expectedVersion": 1]])
        let review = try XCTUnwrap(MoneyEditConflictReview.capture(mutationId: "local", payload: payload, workspace: view))
        XCTAssertTrue(review.localSummary.contains("My note")); XCTAssertTrue(try XCTUnwrap(review.serverSummary).contains("Server note"))
        view.transactions[0].version = 5
        XCTAssertEqual(try review.command()["expectedVersion"] as? Int, 4); XCTAssertEqual(review.currentVersion(in: view), 5)
        XCTAssertEqual(MoneyEditConflictReview.capture(mutationId: "local", payload: payload, workspace: view)?.serverVersion, 5)
    }
    func testGoalConflictCannotRecreateAMissingOrDeletedRecord() throws {
        var view = MoneyDesignFixture.workspace
        let local = MoneyGoal(id: "goal-conflict", name: "Reserve", target: MoneyAmount(minor: 50000), allocated: MoneyAmount(minor: 10000), archived: false)
        let payload = try JSONSerialization.data(withJSONObject: ["command": ["type": "goal.upsert", "goal": local.commandValue, "expectedVersion": 1]])
        view.goals = [MoneyRecord(id: local.id, version: 4, updatedAt: "", deleted: false, data: local)]
        let review = try XCTUnwrap(MoneyEditConflictReview.capture(mutationId: "local", payload: payload, workspace: view))
        view.goals?[0].deleted = true
        XCTAssertEqual(try review.command()["expectedVersion"] as? Int, 4); XCTAssertNil(review.currentVersion(in: view))
        let missing = try XCTUnwrap(MoneyEditConflictReview.capture(mutationId: "local", payload: payload, workspace: view))
        XCTAssertThrowsError(try missing.command())
    }
    func testBankFactConflictCannotBecomeAManualReplacement() throws {
        var view = MoneyDesignFixture.workspace
        var server = try XCTUnwrap(view.transactions.first)
        let payload = try JSONSerialization.data(withJSONObject: ["command": ["type": "transaction.upsert", "transaction": server.commandValue, "expectedVersion": 1]])
        server.source = "plaid"; server.providerId = "bank-fact"; view.transactions = [server]
        let review = try XCTUnwrap(MoneyEditConflictReview.capture(mutationId: "local", payload: payload, workspace: view))
        XCTAssertNil(review.serverVersion); XCTAssertThrowsError(try review.command())
    }
    func testSharedCSVReviewAndStableIdentity() throws {
        struct Case: Decodable { let name: String; let csv: String; let rowCount: Int?; let selectedCount: Int?; let amounts: [Int64?]?; let batchId: String }
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: "transaction-import", withExtension: "json") ?? bundle.url(forResource: "transaction-import", withExtension: "json", subdirectory: "Fixtures"))
        for item in try JSONDecoder().decode([Case].self, from: Data(contentsOf: url)) {
            guard let count = item.rowCount else { XCTAssertThrowsError(try MoneyCSVImport.parse(Data(item.csv.utf8)), item.name); continue }
            let batch = try MoneyCSVImport.parse(Data(item.csv.utf8))
            XCTAssertEqual(batch.rows.count, count, item.name); XCTAssertEqual(batch.rows.filter(\.selected).count, item.selectedCount, item.name)
            XCTAssertEqual(batch.batchId, item.batchId, item.name)
            XCTAssertEqual(batch.rows.map { $0.transaction(batchId: batch.batchId)?.amount.minor }, item.amounts, item.name)
            if item.selectedCount == 0 { XCTAssertThrowsError(try batch.command(), item.name) } else { XCTAssertNoThrow(try batch.command(), item.name) }
        }
        XCTAssertThrowsError(try MoneyCSVImport.parse(Data([0xff,0xfe])))
        XCTAssertThrowsError(try MoneyCSVImport.parse(Data(repeating: 65, count: 500001)))
        let batch = try MoneyCSVImport.parse(Data(MoneyCSVImport.template.utf8)); let existing = try XCTUnwrap(batch.rows[0].transaction(batchId: batch.batchId))
        XCTAssertFalse(try MoneyCSVImport.parse(Data(MoneyCSVImport.template.utf8), existing: [existing]).rows[0].selected)
    }
    @MainActor func testVisionReadsReceiptPixelsBeforeReview() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 700)).image { renderer in
            UIColor.white.setFill(); renderer.fill(CGRect(x: 0, y: 0, width: 1200, height: 700))
            for (index, line) in ["SPROUT CAFE", "11/09/2026", "SUBTOTAL $5.00", "TAX $0.40", "TOTAL $5.40"].enumerated() {
                (line as NSString).draw(at: CGPoint(x: 60, y: 60 + index * 100), withAttributes: [.font: UIFont.systemFont(ofSize: 48), .foregroundColor: UIColor.black])
            }
        }
        let text = try await MoneyReceiptOCR.recognize(XCTUnwrap(image.pngData()))
        let result = MoneyReceiptExtraction.parse(text)
        XCTAssertEqual(result.totals, [540]); XCTAssertEqual(result.merchant, "SPROUT CAFE"); XCTAssertEqual(result.date, "2026-11-09")
    }
    func testSharedReceiptSuggestionsSeparateTaxAndAmbiguousTotals() throws {
        struct Case: Decodable { let name: String; let text: String; let amountMinor: Int64?; let merchant: String?; let date: String? }
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: "receipt-text", withExtension: "json") ?? bundle.url(forResource: "receipt-text", withExtension: "json", subdirectory: "Fixtures"))
        for row in try JSONDecoder().decode([Case].self, from: Data(contentsOf: url)) {
            let result = MoneyReceiptExtraction.parse(row.text)
            XCTAssertEqual(result.totals.count == 1 ? result.totals[0] : nil, row.amountMinor, row.name)
            XCTAssertEqual(result.merchant, row.merchant, row.name)
            XCTAssertEqual(result.date, row.date, row.name)
        }
        let excessive = MoneyReceiptExtraction.parse(String(repeating: "x", count: 12001) + "\nTOTAL $12.34")
        XCTAssertTrue(excessive.totals.isEmpty); XCTAssertNil(excessive.merchant); XCTAssertNil(excessive.date)
    }
    func testOfflineBudgetConflictTargetsTheReviewedLogicalBudget() throws {
        let local = MoneyBudget(id: "offline", category: "Ｆｏｏｄ", month: "2026-11", limit: MoneyAmount(minor: 2222))
        let payload = try JSONSerialization.data(withJSONObject: ["command": ["type": "budget.upsert", "budget": ["id": local.id, "category": local.category, "month": local.month, "limit": ["minor": local.limit.minor, "currency": "USD"]], "expectedVersion": 0]])
        var server = MoneyRecord(id: "winner", version: 4, updatedAt: "", deleted: false, data: MoneyBudget(id: "winner", category: "Food", month: "2026-11", limit: MoneyAmount(minor: 3333)))
        let review = try XCTUnwrap(MoneyBudgetConflictReview.capture(mutationId: "saved-local-edit", payload: payload, budgets: [server]))
        let command = try review.command(); let budget = try XCTUnwrap(command["budget"] as? [String: Any])
        XCTAssertEqual(budget["id"] as? String, "winner"); XCTAssertEqual(command["expectedVersion"] as? Int, 4)
        let amount = try XCTUnwrap(budget["limit"] as? [String: Any]); XCTAssertEqual(amount["minor"] as? Int64, 2222)
        server.version = 5; server.data.limit.minor = 4444
        let later = try XCTUnwrap(MoneyBudgetConflictReview.capture(mutationId: "saved-local-edit", payload: payload, budgets: [server]))
        XCTAssertEqual(try later.command()["expectedVersion"] as? Int, 5)
        XCTAssertEqual(try review.command()["expectedVersion"] as? Int, 4)
        XCTAssertEqual(review.server?.data.limit.minor, 3333)
    }

    func testMissingServerBudgetCannotBeRecreatedByConflictApproval() throws {
        let payload = try JSONSerialization.data(withJSONObject: ["command": ["type": "budget.upsert", "budget": ["id": "removed", "category": "Food", "month": "2026-11", "limit": ["minor": 2222, "currency": "USD"]]]])
        let review = try XCTUnwrap(MoneyBudgetConflictReview.capture(mutationId: "saved", payload: payload, budgets: []))
        XCTAssertNil(review.server); XCTAssertThrowsError(try review.command())
    }

    func testSharedExpenseTextAmountsRequireUnambiguousReviewedUsd() throws {
        struct Case: Decodable { let text: String; let amountMinor: Int64? }
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: "expense-text", withExtension: "json") ?? bundle.url(forResource: "expense-text", withExtension: "json", subdirectory: "Fixtures"))
        for row in try JSONDecoder().decode([Case].self, from: Data(contentsOf: url)) {
            let values = ExpenseDraft.explicitAmounts(in: row.text)
            XCTAssertEqual(values.count == 1 ? MoneyAmount.parse(values[0]) : nil, row.amountMinor, row.text)
        }
    }

    func testUnreadablePrivacyReceiptCannotBecomeAnAbsentRequest() throws {
        XCTAssertNil(try MoneyDeletionReceiptRead.decode(status: errSecItemNotFound, data: nil))
        XCTAssertThrowsError(try MoneyDeletionReceiptRead.decode(status: errSecInteractionNotAllowed, data: nil))
        XCTAssertThrowsError(try MoneyDeletionReceiptRead.decode(status: errSecSuccess, data: Data("broken".utf8)))
        let saved = MoneyDeletionReceipt(owner: "synthetic", requestId: UUID().uuidString, receipt: String(repeating: "a", count: 43), accepted: true)
        XCTAssertTrue(try XCTUnwrap(MoneyDeletionReceiptRead.decode(status: errSecSuccess, data: JSONEncoder().encode(saved))).accepted)
        var invalid = saved; invalid.receipt = "short"
        XCTAssertThrowsError(try MoneyDeletionReceiptRead.decode(status: errSecSuccess, data: JSONEncoder().encode(invalid)))
    }

    @MainActor func testUnconfirmedDeletionSurvivesRestartAndKeepsOriginalConsent() throws {
        let service = "sprout.tests.privacy." + UUID().uuidString
        defer { SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as CFDictionary) }
        let first = MoneyDeletionState(service: service)
        let receipt = try first.prepare(owner: "synthetic-owner")
        XCTAssertFalse(try XCTUnwrap(first.active).accepted)
        let restored = MoneyDeletionState(service: service)
        XCTAssertFalse(restored.blocked)
        XCTAssertFalse(try XCTUnwrap(restored.active).accepted)
        let retry = try restored.prepare(owner: "synthetic-owner")
        XCTAssertEqual(retry.requestId, receipt.requestId)
        XCTAssertEqual(retry.receipt, receipt.receipt)
        XCTAssertThrowsError(try restored.prepare(owner: "another-owner"))
        XCTAssertEqual(restored.active?.owner, "synthetic-owner")
    }

    func testAnalyticsRejectsFinancialAndFreeFormValues() {
        XCTAssertNil(SproutAnalyticsPolicy.sanitize(name: "merchant_secret", parameters: [:]))
        let fields: [String: Any] = ["screen_name": "home", "amount": 123.45, "merchant": "Sensitive", "accountId": "user123", "transcript": "my salary", "url": "https://private.example"]
        XCTAssertEqual(SproutAnalyticsPolicy.sanitize(name: "screen_view", parameters: fields), ["screen_name": "home"])
        XCTAssertEqual(SproutAnalyticsPolicy.sanitize(name: "screen_view", parameters: ["screen_name": "My private merchant"]), [:])
        XCTAssertEqual(SproutAnalyticsPolicy.sanitize(name: "transaction_added", parameters: ["source": "scan", "type": "expense", "amount": -123]), ["source": "scan", "type": "expense"])
    }

    @MainActor func testLiveSDKEmailAuthentication() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["SPROUT_LIVE_TEST_PHASE"] == "sdk-auth", let email = env["SPROUT_LIVE_TEST_EMAIL"], let password = env["SPROUT_LIVE_TEST_PASSWORD"] else { throw XCTSkip("Opt-in staging SDK diagnosis") }
        let client = Client().setEndpoint("https://nyc.cloud.appwrite.io/v1").setProject("6af0f72200383d2f1084")
        let account = Account(client)
        _ = try await account.createEmailPasswordSession(email: email, password: password)
        let user = try await account.get()
        XCTAssertTrue(user.email == email, "The authenticated identity must match the supplied test account.")
        try await account.deleteSession(sessionId: "current")
        AppwriteConnection.clearSessionCookies()
    }

    func testExpiredSessionCleanupPreservesOtherProjectsAndNonSessionCookies() {
        let values = ["a_session_staging=expired; Path=/; Secure", "a_session_staging_legacy=expired; Path=/", "a_session_production=keep; Secure", "a_session_staging_other=keep", "consent=keep", "malformed"]
        XCTAssertEqual(AppwriteSessionCookies.removing(project: "staging", from: values), Array(values.dropFirst(2)))
    }
    func testSharedShortcutReviewCases() throws {
        struct Case: Decodable { let name: String; let fields: [String: String]; let valid: Bool; let minor: Int64? }
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: "shortcut-inputs", withExtension: "json") ?? bundle.url(forResource: "shortcut-inputs", withExtension: "json", subdirectory: "Fixtures"))
        for value in try JSONDecoder().decode([Case].self, from: Data(contentsOf: url)) {
            if value.valid {
                let input = try ExpenseShortcutInput(fields: value.fields)
                let draft = try ExpenseDraft.shortcut(input)
                XCTAssertEqual(draft.source, "shortcut", value.name)
                XCTAssertEqual(draft.id, input.id, value.name)
                XCTAssertEqual(draft.transaction()?.amount.minor, value.minor.map { -$0 }, value.name)
                if let date = value.fields["date"], draft.transaction() != nil { XCTAssertEqual(draft.transaction()?.date, date, value.name) }
            } else { XCTAssertThrowsError(try ExpenseShortcutInput(fields: value.fields), value.name) }
        }
    }

    func testShortcutHandoffPreservesWaitingDraftAndRequiresMatchingAcknowledgment() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try ExpenseShortcutInput(fields: ["amount": "0.29", "merchant": "First"])
        let second = try ExpenseShortcutInput(fields: ["amount": "9.50", "merchant": "Second"])
        try ExpenseShortcutHandoff.save(first, directory: directory)
        XCTAssertThrowsError(try ExpenseShortcutHandoff.save(second, directory: directory))
        try ExpenseShortcutHandoff.clear(id: second.id, directory: directory)
        XCTAssertEqual(try ExpenseShortcutHandoff.load(directory: directory)?.id, first.id)
        try ExpenseShortcutHandoff.clear(id: first.id, directory: directory)
        XCTAssertNil(try ExpenseShortcutHandoff.load(directory: directory))
    }

    func testSyncPublishesOnlyCompleteBoundedProjectionAndAppliesTombstones() throws {
        var base = MoneyDesignFixture.workspace; base.accountId = "alice"; base.cursor = "old"
        let item = try XCTUnwrap(base.transactions.first)
        var projection = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(base)) as? [String: Any])
        projection.removeValue(forKey: "transactions"); projection["revision"] = base.revision + 2
        var snapshot = try XCTUnwrap(projection["snapshot"] as? [String: Any]); snapshot["revision"] = base.revision + 2; projection["snapshot"] = snapshot
        let deletion: [String: Any] = ["kind": "transactions", "record": ["id": item.id, "version": item.version + 1, "deleted": true, "updatedAt": "2026-11-09T00:00:00Z", "data": NSNull()]]
        func page(_ sequence: Int, more: Bool, changes: [[String: Any]], projection: Any) throws -> Data {
            try JSONSerialization.data(withJSONObject: ["contractVersion": 1, "accountId": "alice", "throughRevision": base.revision + 2, "events": [["sequence": sequence, "changes": changes]], "hasMore": more, "unchanged": false, "projection": projection, "nextCursor": more ? "next" : "stable", "capabilities": try JSONSerialization.jsonObject(with: JSONEncoder().encode(base.capabilities))])
        }
        var cycle = try MoneySyncCycle(base: JSONEncoder().encode(base), owner: "alice")
        XCTAssertNil(try cycle.append(page(base.revision + 1, more: true, changes: [deletion], projection: projection)).result)
        let result = try XCTUnwrap(cycle.append(page(base.revision + 2, more: false, changes: [], projection: NSNull())).result)
        let value = try JSONDecoder().decode(MoneyWorkspace.self, from: result)
        XCTAssertEqual(value.revision, base.revision + 2); XCTAssertEqual(value.cursor, "stable")
        XCTAssertFalse(value.transactions.contains { $0.id == item.id }); XCTAssertEqual(base.transactions.count, value.transactions.count + 1)
        XCTAssertThrowsError(try MoneySyncCycle(base: JSONEncoder().encode(base), owner: "bob"))
        var broken = try MoneySyncCycle(base: JSONEncoder().encode(base), owner: "alice")
        XCTAssertThrowsError(try broken.append(page(base.revision + 2, more: false, changes: [], projection: projection)))
    }

    func testMoneyUsesExactCentsAndRejectsAmbiguousPrecision() {
        XCTAssertEqual(MoneyAmount.parse("0.29"), 29)
        XCTAssertEqual(MoneyAmount.parse("$1234.56"), 123_456)
        for text in ["1.005", "1$2", "-10", "NaN", "900719925474100", "0"] {
            XCTAssertNil(MoneyAmount.parse(text), text)
        }
    }

    func testCaptureDoesNotTreatDatesOrTheFirstNumberAsTheExpenseTotal() {
        XCTAssertEqual(ExpenseDraft.explicitAmounts(in: "On November 9 I spent $12.50 at lunch"), ["12.50"])
        XCTAssertEqual(ExpenseDraft.explicitAmounts(in: "Subtotal $12 and tax $1.20").count, 2)
        XCTAssertTrue(ExpenseDraft.explicitAmounts(in: "Dinner on the 18th").isEmpty)
        XCTAssertTrue(ExpenseDraft.explicitAmounts(in: "Total $12.345").isEmpty)
    }

    func testReviewedDraftUsesStableIdentityAndSignedMinorUnits() {
        var draft = ExpenseDraft(); draft.amount = "0.29"; draft.merchant = "Coffee"
        XCTAssertEqual(draft.transaction()?.amount.minor, -29)
        XCTAssertEqual(draft.transaction()?.id, draft.id)
        draft.merchant = " "; XCTAssertNil(draft.transaction())
    }

    func testSharedWorkspaceDecodesWithoutFabricatedBalances() {
        let fixture = MoneyDesignFixture.workspace
        XCTAssertNil(fixture.snapshot.balanceMinor)
        XCTAssertEqual(fixture.subscriptions.first?.merchant, "Stream Club")
        XCTAssertEqual(fixture.snapshot.monthlySubscriptionsMinor, 1599)
        XCTAssertEqual(fixture.snapshot.heroMinor, 201_283)
    }

    func testEditingPinsTheReviewedVersionAndPreservesFinancialMetadata() throws {
        var item = MoneyDesignFixture.workspace.transactions[0]; item.version = 7; item.excluded = true
        var draft = try XCTUnwrap(ExpenseDraft.editing(item))
        XCTAssertEqual(draft.expectedVersion, 7); XCTAssertEqual(draft.transaction()?.id, item.id)
        XCTAssertEqual(draft.transaction()?.date, item.date); XCTAssertEqual(draft.transaction()?.amount, item.amount)
        XCTAssertEqual(draft.transaction()?.excluded, true); XCTAssertEqual(draft.transaction()?.source, item.source)
        item.version = 8; draft.merchant = "Reviewed correction"
        XCTAssertEqual(draft.expectedVersion, 7)
        item.source = "plaid"; XCTAssertNil(ExpenseDraft.editing(item))
    }
}
