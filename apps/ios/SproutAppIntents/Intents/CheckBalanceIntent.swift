import AppIntents

// There is no verified account balance source in the extension. In particular,
// a missing shared-defaults value must never be presented as a zero balance.
struct CheckBalanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Balance"
    static var description = IntentDescription("Check your Sprout account balance")
    static var isDiscoverable: Bool = false

    @Parameter(title: "Account") var accountName: String?
    @Parameter(title: "Currency", default: .usd) var currency: Currency

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Balance shortcuts are unavailable until Sprout can verify your account data.")
    }
}
