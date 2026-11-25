import Foundation

struct MoneyAmount: Codable, Equatable {
    var minor: Int64
    var currency = "USD"
    var formatted: String {
        (Decimal(minor) / 100).formatted(.currency(code: currency))
    }

    static func parse(_ text: String) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = trimmed.hasPrefix("$") ? String(trimmed.dropFirst()) : trimmed
        guard raw.range(of: #"^\d+(\.\d{1,2})?$"#, options: .regularExpression) != nil,
              let value = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")), value > 0,
              value <= Decimal(90_071_992_547_409) else { return nil }
        return NSDecimalNumber(decimal: value * 100).int64Value
    }
}

struct MoneyTransaction: Codable, Identifiable, Hashable {
    var id: String
    var amount: MoneyAmount
    var date: String
    var merchant: String
    var category: String
    var type: String
    var source: String
    var accountId: String
    var description: String
    var pending: Bool
    var excluded: Bool
    var version: Int = 0
    var updatedAt: String = ""
    var providerId: String?
    var pendingTransactionId: String?
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id); hasher.combine(version)
    }

    var commandValue: [String: Any] {
        ["id": id, "amount": ["minor": amount.minor, "currency": amount.currency], "date": date,
         "merchant": merchant, "category": category, "type": type, "source": source,
         "accountId": accountId, "description": description, "pending": pending, "excluded": excluded]
    }
}

extension MoneyAmount: Hashable {}

struct MoneyProfile: Codable {
    var name = ""
    var onboarding = "welcome"
    var monthlyTargetMinor: Int64?
    var timezone = TimeZone.current.identifier
    var appearance = "system"
    var renewalAlerts = false
    var priceAlerts = false
    var weeklyDigest = false
    var budgetAlerts: Bool?
    var forecastAlerts: Bool?
    var quietHours: MoneyQuietHours?
}

struct MoneyQuietHours: Codable, Equatable { var enabled = true; var startMinute = 1260; var endMinute = 480 }

struct MoneyRecord<T: Codable>: Codable, Identifiable {
    var id: String
    var version: Int
    var updatedAt: String
    var deleted: Bool
    var data: T
}

struct MoneyGoal: Codable, Identifiable { var id: String; var name: String; var target: MoneyAmount; var allocated: MoneyAmount; var targetDate: String?; var archived: Bool
    var commandValue: [String: Any] { ["id": id, "name": name, "target": ["minor": target.minor, "currency": target.currency], "allocated": ["minor": allocated.minor, "currency": allocated.currency], "targetDate": targetDate as Any? ?? NSNull(), "archived": archived] }
}

struct MoneyBudget: Codable {
    var id: String; var category: String; var month: String; var limit: MoneyAmount
    static func categoryKey(_ value: String) -> String {
        value.precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Locale(identifier: "en_US_POSIX"))
    }
}
struct MoneyCategoryPace: Codable, Identifiable {
    var id: String; var category: String; var spentMinor: Int64; var plannedMinor: Int64
    var remainingMinor: Int64; var dailyMinor: Int64; var aheadOfPace: Bool
}

struct MoneyBudgetSummary: Codable {
    var month: String; var daysLeft: Int; var spentMinor: Int64; var plannedMinor: Int64; var categories: [MoneyCategoryPace]; var state: String?; var remainingMinor: Int64?
}

struct MoneySnapshot: Codable {
    var revision: Int; var asOf: String; var balanceMinor: Int64?; var heroLabel: String; var heroMinor: Int64?
    var monthlySubscriptionsMinor: Int64; var budget: MoneyBudgetSummary; var coverage: String
}

struct MoneySubscription: Codable, Identifiable, Hashable {
    struct Charge: Codable, Hashable { var date: String; var minor: Int64 }
    var id: String; var merchant: String; var accountId: String; var amountMinor: Int64; var cadence: String
    var monthlyMinor: Int64; var nextDate: String; var confidence: String; var evidenceIds: [String]
    var charges: [Charge]; var evidenceHash: String; var decision: String; var decisionVersion: Int
}

struct MoneyInsight: Codable, Identifiable {
    var id: String; var kind: String; var title: String; var detail: String; var evidenceIds: [String]
}

struct MoneyEntitlements: Codable { var plus: Bool; var connectionLimit: Int; var aiAllowance: Int; var cancellationAllowance: Int }
struct MoneyCapabilities: Codable { var linking: Bool; var cancellation: Bool; var ai: Bool; var forecasts: Bool; var notifications: Bool; var scanAssistance: Bool }
struct MoneyAction: Codable { var subscriptionId: String; var merchant: String; var state: String; var evidenceHash: String; var approvalExpiresAt: String? }
struct MoneyReminder: Codable { var subscriptionId: String; var enabled: Bool; var daysBefore: Int; var renewalDate: String; var status: String }
struct MoneyConversation: Codable {
    struct Answer: Codable { struct Reference: Codable { var id: String; var text: String; var evidenceIds: [String] }; var message: String; var references: [Reference]; var assumptions: [String]; var proposalIds: [String] }
    var question: String; var context: String?; var answer: Answer; var createdAt: String
}

struct MoneyJobResult: Codable { var fileId: String?; var bucketId: String?; var generatedAt: String?; var status: String? }
struct MoneyImportProgress: Codable { var total: Int; var processed: Int; var imported: Int; var preserved: Int }
struct MoneyJob: Codable, Identifiable { var id: String; var type: String; var status: String; var error: String?; var result: MoneyJobResult?; var batchId: String?; var progress: MoneyImportProgress?; var updatedAt: String? }
struct MoneyConnection: Codable { var status: String; var sourceAsOf: String? }
struct MoneyReceipt: Codable, Identifiable { var id: String; var version: Int; var transactionId: String; var status: String; var sha256: String; var bytes: Int; var fileId: String?; var bucketId: String?; var updatedAt: String }
struct MoneyWorkspace: Codable {
    var changeChannel: String?
    var projectionVersion: Int?
    var accountId: String?
    var cursor: String?
    var contractVersion: Int; var revision: Int; var today: String; var profile: MoneyProfile; var profileVersion: Int
    var transactions: [MoneyTransaction]; var budgets: [MoneyRecord<MoneyBudget>]; var subscriptions: [MoneySubscription]
    var reminders: [MoneyRecord<MoneyReminder>]; var actions: [MoneyRecord<MoneyAction>]
    var insights: [MoneyInsight]; var entitlements: MoneyEntitlements; var capabilities: MoneyCapabilities; var snapshot: MoneySnapshot
    var conversations: [MoneyRecord<MoneyConversation>]?
    var budgetPeriods: [MoneyBudgetSummary]?
    var goals: [MoneyRecord<MoneyGoal>]?
    var jobs: [MoneyJob]?
    var connections: [MoneyRecord<MoneyConnection>]?
    var receipts: [MoneyReceipt]?
}

/// Accumulate a bounded sync cycle privately. Only the final payload is committed
/// with its cursor; interrupted pages leave the prior cache and outbox intact.
struct MoneySyncCycle {
    private var snapshot: [String: Any]
    private var items: [String: [String: Any]]
    private var sequence: Int
    private var through: Int?
    private let owner: String
    private var first = true
    init(base: Data, owner: String) throws {
        guard let value = try JSONSerialization.jsonObject(with: base) as? [String: Any], value["accountId"] as? String == owner, let revision = value["revision"] as? Int, let transactions = value["transactions"] as? [[String: Any]] else { throw Self.invalid() }
        snapshot = value; items = [:]; sequence = revision; self.owner = owner
        for item in transactions { guard let id = item["id"] as? String, items[id] == nil else { throw Self.invalid() }; items[id] = item }
    }
    mutating func append(_ data: Data) throws -> (cursor: String, result: Data?) {
        guard let page = try JSONSerialization.jsonObject(with: data) as? [String: Any], page["accountId"] as? String == owner, page["contractVersion"] as? Int == 1, let ceiling = page["throughRevision"] as? Int, ceiling >= sequence, let cursor = page["nextCursor"] as? String, !cursor.isEmpty, let events = page["events"] as? [[String: Any]], let more = page["hasMore"] as? Bool else { throw Self.invalid() }
        if let through, through != ceiling { throw Self.invalid() }
        through = ceiling
        if page["unchanged"] as? Bool == true {
            guard first, ceiling == sequence, events.isEmpty, !more else { throw Self.invalid() }
        } else if first {
            guard let projection = page["projection"] as? [String: Any], projection["accountId"] as? String == owner, projection["revision"] as? Int == ceiling, let financial = projection["snapshot"] as? [String: Any], financial["revision"] as? Int == ceiling else { throw Self.invalid() }
            snapshot = projection
        } else if !(page["projection"] is NSNull) { throw Self.invalid() }
        for event in events {
            guard event["sequence"] as? Int == sequence + 1, sequence < ceiling, let changes = event["changes"] as? [[String: Any]] else { throw Self.invalid() }
            sequence += 1
            for change in changes {
                guard change["kind"] as? String == "transactions", let record = change["record"] as? [String: Any], let id = record["id"] as? String, let version = record["version"] as? Int, version > (items[id]?["version"] as? Int ?? 0), let deleted = record["deleted"] as? Bool else { throw Self.invalid() }
                if deleted { items.removeValue(forKey: id) } else {
                    guard var item = record["data"] as? [String: Any], item["id"] as? String == id else { throw Self.invalid() }
                    item["version"] = version; item["updatedAt"] = record["updatedAt"]; items[id] = item
                }
            }
        }
        first = false
        if more { guard sequence < ceiling, !events.isEmpty else { throw Self.invalid() }; return (cursor, nil) }
        guard sequence == ceiling else { throw Self.invalid() }
        snapshot["transactions"] = items.values.sorted { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") }
        snapshot["cursor"] = cursor; snapshot["capabilities"] = page["capabilities"]
        return (cursor, try JSONSerialization.data(withJSONObject: snapshot))
    }
    private static func invalid() -> MoneyAPIError { MoneyAPIError(code: "CURSOR_INVALID", message: "A fresh account snapshot is required. Pending changes are preserved.") }
}

struct ExpenseDraft: Identifiable {
    var id = UUID().uuidString.lowercased()
    var source = "manual"
    var amount = ""
    var merchant = ""
    var category = "Other"
    var date = Date()
    var accountId = "cash"
    var notes = ""
    var transcript = ""
    var attachmentReferences: [String] = []
    var expectedVersion = 0
    var excluded = false
    var receiptJPEG: Data?
    var keepReceipt = false
    var receiptId = UUID().uuidString.lowercased()
    static func shortcut(_ input: ExpenseShortcutInput) throws -> ExpenseDraft {
        let input = try input.validated()
        var draft = ExpenseDraft(id: input.id, source: "shortcut", amount: input.amount, merchant: input.merchant, category: input.category, notes: input.notes)
        if let date = input.date {
            let format = DateFormatter(); format.calendar = Calendar(identifier: .gregorian); format.locale = Locale(identifier: "en_US_POSIX"); format.dateFormat = "yyyy-MM-dd"; format.isLenient = false
            guard let parsed = format.date(from: date) else { throw ExpenseShortcutError.invalid }; draft.date = parsed
        }
        return draft
    }
    static func editing(_ item: MoneyTransaction) -> ExpenseDraft? {
        guard item.source != "plaid", item.providerId == nil, item.type == "expense", item.amount.minor < 0 else { return nil }
        let format = DateFormatter(); format.calendar = Calendar(identifier: .gregorian); format.dateFormat = "yyyy-MM-dd"; format.locale = Locale(identifier: "en_US_POSIX")
        guard let date = format.date(from: item.date) else { return nil }
        return ExpenseDraft(id: item.id, source: item.source, amount: NSDecimalNumber(decimal: Decimal(-item.amount.minor) / 100).stringValue, merchant: item.merchant, category: item.category, date: date, accountId: item.accountId, notes: item.description, expectedVersion: item.version, excluded: item.excluded)
    }

    func transaction() -> MoneyTransaction? {
        let merchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minor = MoneyAmount.parse(amount), !merchant.isEmpty, merchant.utf16.count <= 160, !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, category.utf16.count <= 80, notes.utf16.count <= 1000 else { return nil }
        let format = DateFormatter(); format.calendar = Calendar(identifier: .gregorian); format.dateFormat = "yyyy-MM-dd"; format.locale = Locale(identifier: "en_US_POSIX")
        return MoneyTransaction(id: id, amount: MoneyAmount(minor: -minor), date: format.string(from: date), merchant: merchant.trimmingCharacters(in: .whitespaces), category: category, type: "expense", source: source, accountId: accountId, description: notes, pending: false, excluded: excluded)
    }

    static func explicitAmounts(in text: String) -> [String] {
        guard text.utf16.count <= 4000,
              text.range(of: SproutCaptureRules.corrections, options: [.regularExpression, .caseInsensitive]) == nil,
              text.range(of: SproutCaptureRules.unsupportedCurrency, options: [.regularExpression, .caseInsensitive]) == nil,
              let regex = try? NSRegularExpression(pattern: SproutCaptureRules.amounts, options: .caseInsensitive) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        let remaining = regex.stringByReplacingMatches(in: text, range: range, withTemplate: " ")
        guard remaining.range(of: SproutCaptureRules.unparsedMinorUnits, options: [.regularExpression, .caseInsensitive]) == nil else { return [] }
        var values: [String] = []
        for match in matches {
            func group(_ number: Int) -> String? { Range(match.range(at: number), in: text).map { String(text[$0]) } }
            let minor: Int64
            if let cents = group(4) {
                guard let value = Int64(cents), value > 0, value <= 9_007_199_254_740_900 else { return [] }
                minor = value
            } else {
                guard var value = group(1) ?? group(3) else { return [] }
                value = value.replacingOccurrences(of: ",", with: "")
                if let cents = group(2) {
                    guard !value.contains(".") else { return [] }
                    value += "." + (cents.count == 1 ? "0" : "") + cents
                }
                guard let value = MoneyAmount.parse(value) else { return [] }
                minor = value
            }
            values.append("\(minor / 100)." + String(format: "%02lld", minor % 100))
        }
        return values
    }
}

enum MoneyTab: String, CaseIterable, Identifiable {
    case home, budget, activity, insights, profile
    var id: String {
        rawValue
    }

    var title: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self { case .home: "house"; case .budget: "chart.pie"; case .activity: "list.bullet"; case .insights: "sparkles"; case .profile: "person.crop.circle" }
    }
}

enum MoneyRoute: Hashable { case subscriptions, subscription(String), transaction(String), action(String), connection, privacy(String), importTransactions }
