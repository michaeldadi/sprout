import Foundation
import Darwin

private let expenseShortcutNotification: CFNotificationCallback = { _, _, _, _, _ in
    NotificationCenter.default.post(name: Notification.Name("sprout.expenseShortcutReady"), object: nil)
}

enum ExpenseShortcutError: LocalizedError {
    case invalid, pending, unavailable
    var errorDescription: String? {
        switch self {
        case .invalid: "Review the expense. Use a positive USD amount with at most two decimal places, a valid date, and a supported category."
        case .pending: "Review the expense already waiting in Sprout before starting another."
        case .unavailable: "Expense handoff is unavailable. Open Sprout and add the expense there."
        }
    }
}

/// Shared by the app and its intents extension. Contains user-supplied draft
/// fields only; no account credentials, balances, or authorization to save.
struct ExpenseShortcutInput: Codable {
    let id: String
    let amount: String
    let merchant: String
    let category: String
    let date: String?
    let notes: String

    init(fields: [String: String], id: String = UUID().uuidString.lowercased()) throws {
        guard UUID(uuidString: id) != nil, fields["currency", default: "USD"] == "USD" else { throw ExpenseShortcutError.invalid }
        let raw = fields["amount", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = raw.hasPrefix("$") ? String(raw.dropFirst()) : raw
        if !raw.isEmpty {
            guard value.range(of: #"^\d+(\.\d{1,2})?$"#, options: .regularExpression) != nil,
                  let decimal = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")), decimal > 0, decimal <= Decimal(90_071_992_547_409) else { throw ExpenseShortcutError.invalid }
        }
        let merchant = fields["merchant", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = fields["notes", default: ""]
        let category = fields["category", default: "Other"]
        guard merchant.utf16.count <= 160, notes.utf16.count <= 1000, ["Food", "Groceries", "Transport", "Shopping", "Health", "Entertainment", "Bills", "Other"].contains(category) else { throw ExpenseShortcutError.invalid }
        if let date = fields["date"] {
            let format = DateFormatter(); format.locale = Locale(identifier: "en_US_POSIX"); format.calendar = Calendar(identifier: .gregorian); format.dateFormat = "yyyy-MM-dd"; format.isLenient = false
            guard date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil, let parsed = format.date(from: date), format.string(from: parsed) == date else { throw ExpenseShortcutError.invalid }
        }
        self.id = id; amount = value; self.merchant = merchant; self.category = category; self.date = fields["date"]; self.notes = notes
    }

    func validated() throws -> Self {
        var fields = ["amount": amount, "merchant": merchant, "category": category, "notes": notes, "currency": "USD"]
        fields["date"] = date
        return try Self(fields: fields, id: id)
    }
}

enum ExpenseShortcutHandoff {
    static let ready = Notification.Name("sprout.expenseShortcutReady")
    private static let darwinName = "com.michaeldadi.Sprout.expenseShortcutReady"
    @MainActor private static let observer = NSObject()
    @MainActor private static var observing = false

    @MainActor static func startObserving() {
        guard !observing else { return }; observing = true
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(observer).toOpaque(), expenseShortcutNotification, darwinName as CFString, nil, .deliverImmediately)
    }

    private static func directory(_ supplied: URL?) throws -> URL {
        if let supplied { return supplied }
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.michaeldadi.Sprout") else { throw ExpenseShortcutError.unavailable }
        var directory = group.appendingPathComponent("ExpenseShortcuts", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        var values = URLResourceValues(); values.isExcludedFromBackup = true; try directory.setResourceValues(values)
        return directory
    }

    private static func withLock<T>(_ directory: URL, operation: () throws -> T) throws -> T {
        let descriptor = Darwin.open(directory.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw ExpenseShortcutError.unavailable }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw ExpenseShortcutError.unavailable }
        defer { flock(descriptor, LOCK_UN) }
        return try operation()
    }

    static func save(_ input: ExpenseShortcutInput, directory supplied: URL? = nil) throws {
        let value = try input.validated(), directory = try Self.directory(supplied)
        let temporary = directory.appendingPathComponent(UUID().uuidString + ".tmp")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try JSONEncoder().encode(value).write(to: temporary, options: [.atomic, .completeFileProtection])
        // A hard link publishes a complete file atomically without replacing an
        // existing pending draft, including simultaneous intent invocations.
        do { try withLock(directory) { try FileManager.default.linkItem(at: temporary, to: directory.appendingPathComponent("pending.json")) } }
        catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError { throw ExpenseShortcutError.pending }
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(darwinName as CFString), nil, nil, true)
    }

    static func load(directory supplied: URL? = nil) throws -> ExpenseShortcutInput? {
        let file = try directory(supplied).appendingPathComponent("pending.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let data = try Data(contentsOf: file); guard data.count <= 20_000 else { throw ExpenseShortcutError.invalid }
        return try JSONDecoder().decode(ExpenseShortcutInput.self, from: data).validated()
    }

    static func clear(id: String, directory supplied: URL? = nil) throws {
        let directory = try Self.directory(supplied)
        try withLock(directory) {
            guard try load(directory: directory)?.id == id else { return }
            try FileManager.default.removeItem(at: directory.appendingPathComponent("pending.json"))
        }
    }
}
