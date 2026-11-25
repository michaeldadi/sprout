import AppIntents

struct SproutExpenseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddExpenseIntent(), phrases: ["Add an expense with \(.applicationName)"], shortTitle: "Add expense", systemImageName: "plus.circle")
    }
}
