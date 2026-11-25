//
//  IntentExtensions.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//


import Foundation
import Intents
import AppIntents

// MARK: - Intent Type Definitions
enum SproutIntentType: String, CaseIterable {
    case addExpense = "add_expense"
    case checkBalance = "check_balance"
    case recentTransactions = "recent_transactions"
    case monthlySpending = "monthly_spending"
    case searchTransactions = "search_transactions"
    case financialGoals = "financial_goals"

    var displayName: String {
        switch self {
        case .addExpense:
            return "Add Expense"
        case .checkBalance:
            return "Check Balance"
        case .recentTransactions:
            return "Recent Transactions"
        case .monthlySpending:
            return "Monthly Spending"
        case .searchTransactions:
            return "Search Transactions"
        case .financialGoals:
            return "Financial Goals"
        }
    }

    var description: String {
        switch self {
        case .addExpense:
            return "Quickly add a new expense"
        case .checkBalance:
            return "Check your current balance"
        case .recentTransactions:
            return "View your recent transactions"
        case .monthlySpending:
            return "See your spending for this month"
        case .searchTransactions:
            return "Search through your transactions"
        case .financialGoals:
            return "Check progress on your financial goals"
        }
    }

    var suggestedInvocationPhrase: String {
        switch self {
        case .addExpense:
            return "Add expense"
        case .checkBalance:
            return "What's my balance"
        case .recentTransactions:
            return "Show recent transactions"
        case .monthlySpending:
            return "Monthly spending"
        case .searchTransactions:
            return "Search transactions"
        case .financialGoals:
            return "Check my goals"
        }
    }

    var systemImageName: String {
        switch self {
        case .addExpense:
            return "plus.circle"
        case .checkBalance:
            return "creditcard"
        case .recentTransactions:
            return "clock"
        case .monthlySpending:
            return "chart.pie"
        case .searchTransactions:
            return "magnifyingglass"
        case .financialGoals:
            return "target"
        }
    }
}

// MARK: - Intent Validation Helpers
struct IntentValidation {
    /// Validates that a required string parameter is not empty
    static func validateRequired(_ string: String?, parameterName: String) -> INStringResolutionResult {
        guard let string = string, !string.isEmpty else {
            return INStringResolutionResult.needsValue()
        }
        return INStringResolutionResult.success(with: string)
    }

    /// Validates a currency amount
    static func validateAmount(_ amount: NSNumber?) -> INCurrencyAmountResolutionResult {
        guard let amount = amount else {
            return INCurrencyAmountResolutionResult.needsValue()
        }

        if amount.doubleValue <= 0 {
            // Just return needs value for negative amounts
            return INCurrencyAmountResolutionResult.needsValue()
        }

        let currencyAmount = INCurrencyAmount(
            amount: NSDecimalNumber(decimal: amount.decimalValue),
            currencyCode: "USD"
        )
        return INCurrencyAmountResolutionResult.success(with: currencyAmount)
    }

    /// Validates a date parameter
    static func validateDate(_ dateComponents: DateComponents?) -> INDateComponentsRangeResolutionResult {
        guard let dateComponents = dateComponents else {
            return INDateComponentsRangeResolutionResult.needsValue()
        }

        let dateRange = INDateComponentsRange(
            start: dateComponents,
            end: dateComponents
        )
        return INDateComponentsRangeResolutionResult.success(with: dateRange)
    }

    /// Validates a category selection
    static func validateCategory(_ category: String?) -> INStringResolutionResult {
        guard let category = category, !category.isEmpty else {
            return INStringResolutionResult.needsValue()
        }

        // Check if it's a valid category
        let validCategories = ["Food", "Transportation", "Shopping", "Bills", "Entertainment", "Other"]
        if validCategories.contains(category) {
            return INStringResolutionResult.success(with: category)
        } else {
            // Provide alternatives for disambiguation
            return INStringResolutionResult.disambiguation(with: validCategories)
        }
    }
}

// MARK: - User Activity Extensions
extension NSUserActivity {
    /// Creates a user activity for a Sprout intent
    static func sproutActivity(for intentType: SproutIntentType) -> NSUserActivity {
        let activity = NSUserActivity(activityType: "com.michaeldadi.sprout.intent.\(intentType.rawValue)")
        activity.title = intentType.displayName
        activity.suggestedInvocationPhrase = intentType.suggestedInvocationPhrase
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true

        if #available(iOS 12.0, *) {
            activity.persistentIdentifier = NSUserActivityPersistentIdentifier(intentType.rawValue)
            activity.isEligibleForHandoff = false
        }

        return activity
    }

    /// Adds transaction data to the user activity
    func addTransactionInfo(amount: Double, category: String) {
        addUserInfoEntries(from: [
            "amount": amount,
            "category": category,
            "timestamp": Date()
        ])
    }
}

// MARK: - Intent Handling Result
enum IntentHandlingResult<T> {
    case success(T)
    case failure(String)
    case requiresAuth
    case requiresUnlock

    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .failure(let message) = self {
            return message
        }
        return nil
    }
}

// MARK: - Shared Intent Data Provider
protocol IntentDataProvider {
    func getCurrentBalance() async -> IntentHandlingResult<Double>
    func getRecentTransactions(limit: Int) async -> IntentHandlingResult<[Transaction]>
    func addExpense(amount: Double, category: String, note: String?) async -> IntentHandlingResult<Transaction>
    func getMonthlySpending(for date: Date) async -> IntentHandlingResult<Double>
    func searchTransactions(query: String) async -> IntentHandlingResult<[Transaction]>
    func getFinancialGoals() async -> IntentHandlingResult<[FinancialGoal]>
}

// MARK: - Currency Formatter
extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()

    static let shortCurrency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

// MARK: - Intent Response Messages
struct IntentResponseMessages {
    static func balanceMessage(_ balance: Double) -> String {
        let formatted = NumberFormatter.currency.string(from: NSNumber(value: balance)) ?? "$0"
        return "Your current balance is \(formatted)"
    }

    static func expenseAddedMessage(amount: Double, category: String) -> String {
        let formatted = NumberFormatter.currency.string(from: NSNumber(value: amount)) ?? "$0"
        return "Added \(formatted) expense to \(category)"
    }

    static func monthlySpendingMessage(_ amount: Double, month: String) -> String {
        let formatted = NumberFormatter.currency.string(from: NSNumber(value: amount)) ?? "$0"
        return "You've spent \(formatted) in \(month)"
    }

    static func errorMessage(_ error: String) -> String {
        return "Sorry, something went wrong: \(error)"
    }

    static let authRequiredMessage = "Please open Sprout to sign in first"
    static let noTransactionsMessage = "No transactions found"
}

// MARK: - Mock Data for Testing
#if DEBUG
struct MockIntentDataProvider: IntentDataProvider {
    func getCurrentBalance() async -> IntentHandlingResult<Double> {
        return .success(2547.83)
    }

    func getRecentTransactions(limit: Int) async -> IntentHandlingResult<[Transaction]> {
        return .success([])
    }

    func addExpense(amount: Double, category: String, note: String?) async -> IntentHandlingResult<Transaction> {
        let transaction = Transaction(
            id: UUID().uuidString,
            userId: "test",
            amount: amount,
            category: category,
            transactionDescription: note,
            date: Date(),
            type: .expense,
            syncStatus: .pending,
            lastSyncedAt: nil,
            remoteVersion: 0
        )
        return .success(transaction)
    }

    func getMonthlySpending(for date: Date) async -> IntentHandlingResult<Double> {
        return .success(1234.56)
    }

    func searchTransactions(query: String) async -> IntentHandlingResult<[Transaction]> {
        return .success([])
    }

    func getFinancialGoals() async -> IntentHandlingResult<[FinancialGoal]> {
        return .success([])
    }
}
#endif

// MARK: - Financial Goal Model (if not defined elsewhere)
struct FinancialGoal: Codable {
    let id: String
    let name: String
    let targetAmount: Double
    let currentAmount: Double
    let deadline: Date?

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(currentAmount / targetAmount, 1.0)
    }

    var progressPercentage: Int {
        return Int(progress * 100)
    }

    var remainingAmount: Double {
        return max(targetAmount - currentAmount, 0)
    }
}
