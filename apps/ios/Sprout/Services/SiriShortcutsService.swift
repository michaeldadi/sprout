import Foundation
import Intents
import IntentsUI
import SwiftUI

@MainActor
class SiriShortcutsService: ObservableObject {
    static let shared = SiriShortcutsService()
    
    @Published var isSetupComplete = false
    @Published var availableShortcuts: [SproutShortcut] = []
    
    private init() {
        setupAvailableShortcuts()
    }
    
    private func setupAvailableShortcuts() {
        availableShortcuts = [
            SproutShortcut(
                identifier: "add_expense",
                title: "Add Expense",
                subtitle: "Quickly log a new expense",
                systemImageName: "minus.circle.fill",
                intentType: .addExpense,
                suggestedPhrase: "Add expense to Sprout"
            ),
            SproutShortcut(
                identifier: "check_balance",
                title: "Check Balance",
                subtitle: "View account balances",
                systemImageName: "dollarsign.circle.fill",
                intentType: .checkBalance,
                suggestedPhrase: "Show my balance in Sprout"
            ),
            SproutShortcut(
                identifier: "recent_transactions",
                title: "Recent Transactions",
                subtitle: "View latest spending",
                systemImageName: "list.bullet.rectangle.fill",
                intentType: .recentTransactions,
                suggestedPhrase: "Show recent transactions"
            ),
            SproutShortcut(
                identifier: "monthly_spending",
                title: "Monthly Spending",
                subtitle: "View this month's expenses",
                systemImageName: "chart.bar.fill",
                intentType: .monthlySpending,
                suggestedPhrase: "How much did I spend this month"
            ),
            SproutShortcut(
                identifier: "search_transactions",
                title: "Search Transactions",
                subtitle: "Find specific transactions",
                systemImageName: "magnifyingglass.circle.fill",
                intentType: .searchTransactions,
                suggestedPhrase: "Search transactions in Sprout"
            ),
            SproutShortcut(
                identifier: "financial_goals",
                title: "Financial Goals",
                subtitle: "Check goal progress",
                systemImageName: "target",
                intentType: .financialGoals,
                suggestedPhrase: "Check my financial goals"
            )
        ]
    }
    
    func donateShortcut(_ shortcut: SproutShortcut) {
        let intent = createIntent(for: shortcut.intentType)
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.identifier = shortcut.identifier
        
        interaction.donate { error in
            if let error = error {
                print("Failed to donate interaction: \(error)")
            } else {
                print("Successfully donated \(shortcut.title) shortcut")
            }
        }
    }
    
    func donateAllShortcuts() {
        for shortcut in availableShortcuts {
            donateShortcut(shortcut)
        }
        isSetupComplete = true
    }
    
    private func createIntent(for type: SproutIntentType) -> INIntent {
        switch type {
        case .addExpense:
            let intent = AddExpenseIntent()
            intent.suggestedInvocationPhrase = "Add expense to Sprout"
            return intent
        case .checkBalance:
            let intent = CheckBalanceIntent()
            intent.suggestedInvocationPhrase = "Show my balance in Sprout"
            return intent
        case .recentTransactions:
            let intent = RecentTransactionsIntent()
            intent.suggestedInvocationPhrase = "Show recent transactions"
            return intent
        case .monthlySpending:
            let intent = MonthlySpendingIntent()
            intent.suggestedInvocationPhrase = "How much did I spend this month"
            return intent
        case .searchTransactions:
            let intent = SearchTransactionsIntent()
            intent.suggestedInvocationPhrase = "Search transactions in Sprout"
            return intent
        case .financialGoals:
            let intent = FinancialGoalsIntent()
            intent.suggestedInvocationPhrase = "Check my financial goals"
            return intent
        }
    }
    
    func presentShortcutSetup(for shortcut: SproutShortcut) -> INUIAddVoiceShortcutViewController? {
        let intent = createIntent(for: shortcut.intentType)
        
        guard let shortcutToAdd = INShortcut(intent: intent) else {
            return nil
        }
        
        let viewController = INUIAddVoiceShortcutViewController(shortcut: shortcutToAdd)
        return viewController
    }
    
    func handleIncomingIntent(_ intent: INIntent) -> SproutIntentType? {
        switch intent {
        case is AddExpenseIntent:
            return .addExpense
        case is CheckBalanceIntent:
            return .checkBalance
        case is RecentTransactionsIntent:
            return .recentTransactions
        case is MonthlySpendingIntent:
            return .monthlySpending
        case is SearchTransactionsIntent:
            return .searchTransactions
        case is FinancialGoalsIntent:
            return .financialGoals
        default:
            return nil
        }
    }
}

struct SproutShortcut: Identifiable {
    let id = UUID()
    let identifier: String
    let title: String
    let subtitle: String
    let systemImageName: String
    let intentType: SproutIntentType
    let suggestedPhrase: String
}

enum SproutIntentType: CaseIterable {
    case addExpense
    case checkBalance
    case recentTransactions
    case monthlySpending
    case searchTransactions
    case financialGoals
    
    var displayName: String {
        switch self {
        case .addExpense: return "Add Expense"
        case .checkBalance: return "Check Balance"
        case .recentTransactions: return "Recent Transactions"
        case .monthlySpending: return "Monthly Spending"
        case .searchTransactions: return "Search Transactions"
        case .financialGoals: return "Financial Goals"
        }
    }
}

class AddExpenseIntent: INIntent {
    @objc dynamic var amount: NSNumber?
    @objc dynamic var category: String?
    @objc dynamic var merchant: String?
    @objc dynamic var notes: String?
}

class CheckBalanceIntent: INIntent {}

class RecentTransactionsIntent: INIntent {
    @objc dynamic var limit: NSNumber?
}

class MonthlySpendingIntent: INIntent {
    @objc dynamic var month: NSNumber?
    @objc dynamic var year: NSNumber?
}

class SearchTransactionsIntent: INIntent {
    @objc dynamic var searchTerm: String?
    @objc dynamic var category: String?
    @objc dynamic var dateRange: String?
}

class FinancialGoalsIntent: INIntent {}

struct SiriShortcutsView: View {
    @StateObject private var siriService = SiriShortcutsService.shared
    @State private var showingSetup = false
    @State private var selectedShortcut: SproutShortcut?
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Available Voice Shortcuts")) {
                    ForEach(siriService.availableShortcuts) { shortcut in
                        SiriShortcutRow(shortcut: shortcut) {
                            selectedShortcut = shortcut
                            showingSetup = true
                        }
                    }
                }
                
                Section(footer: Text("Voice shortcuts let you quickly access Sprout features using Siri. Tap any shortcut above to set up a custom voice command.")) {
                    Button(action: {
                        siriService.donateAllShortcuts()
                    }) {
                        HStack {
                            Image(systemName: "waveform.circle.fill")
                                .foregroundColor(.blue)
                            Text("Set Up All Shortcuts")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Siri Shortcuts")
            .sheet(isPresented: $showingSetup) {
                if let shortcut = selectedShortcut,
                   let viewController = siriService.presentShortcutSetup(for: shortcut) {
                    SiriShortcutSetupView(viewController: viewController)
                }
            }
        }
    }
}

struct SiriShortcutRow: View {
    let shortcut: SproutShortcut
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: shortcut.systemImageName)
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.2, green: 0.8, blue: 0.4),
                                Color(red: 0.1, green: 0.6, blue: 0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(shortcut.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(shortcut.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\"Hey Siri, \(shortcut.suggestedPhrase)\"")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .italic()
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SiriShortcutSetupView: UIViewControllerRepresentable {
    let viewController: INUIAddVoiceShortcutViewController
    
    func makeUIViewController(context: Context) -> INUIAddVoiceShortcutViewController {
        viewController.delegate = context.coordinator
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: INUIAddVoiceShortcutViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, INUIAddVoiceShortcutViewControllerDelegate {
        func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?) {
            controller.dismiss(animated: true)
        }
        
        func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
            controller.dismiss(animated: true)
        }
    }
}