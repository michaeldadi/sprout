import AppIntents
import Foundation

// Preserve the existing intent identifier and parameters. Saving happens only
// after review in the authenticated app's normal ExpenseDraft/outbox flow.
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Expense"
    static var description = IntentDescription("Review and add an expense in Sprout")
    static var openAppWhenRun = true
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(title: "Amount") var amount: Double
    @Parameter(title: "Category", default: .other) var category: ExpenseCategory
    @Parameter(title: "Description") var expenseDescription: String?
    @Parameter(title: "Currency", default: .usd) var currency: Currency
    @Parameter(title: "Merchant") var merchant: String?
    @Parameter(title: "Date") var date: Date?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount.isFinite, amount > 0, currency == .usd else { throw ExpenseShortcutError.invalid }
        let format = DateFormatter(); format.calendar = Calendar(identifier: .gregorian); format.locale = Locale(identifier: "en_US_POSIX"); format.dateFormat = "yyyy-MM-dd"
        let input = try ExpenseShortcutInput(fields: ["amount": String(amount), "currency": "USD", "category": category == .transportation ? "Transport" : category.displayName, "merchant": merchant ?? "", "notes": expenseDescription ?? "", "date": format.string(from: date ?? .now)])
        try ExpenseShortcutHandoff.save(input)
        return .result(dialog: "Review the expense in Sprout, then save it to Activity.")
    }
}
