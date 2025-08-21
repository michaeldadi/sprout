import Foundation
import Intents
import SwiftData

class SiriIntentHandler: NSObject {
    static let shared = SiriIntentHandler()
    
    private override init() {
        super.init()
    }
    
    func handle(intent: INIntent, completion: @escaping (INIntentResponse) -> Void) {
        switch intent {
        case let addExpenseIntent as AddExpenseIntent:
            handleAddExpense(intent: addExpenseIntent, completion: completion)
        case is CheckBalanceIntent:
            handleCheckBalance(completion: completion)
        case let recentTransactionsIntent as RecentTransactionsIntent:
            handleRecentTransactions(intent: recentTransactionsIntent, completion: completion)
        case let monthlySpendingIntent as MonthlySpendingIntent:
            handleMonthlySpending(intent: monthlySpendingIntent, completion: completion)
        case let searchIntent as SearchTransactionsIntent:
            handleSearchTransactions(intent: searchIntent, completion: completion)
        case is FinancialGoalsIntent:
            handleFinancialGoals(completion: completion)
        default:
            let response = INIntentResponse()
            response.userActivity = createUserActivity(for: intent)
            completion(response)
        }
    }
    
    private func handleAddExpense(intent: AddExpenseIntent, completion: @escaping (INIntentResponse) -> Void) {
        let response = AddExpenseIntentResponse(code: .continueInApp, userActivity: nil)
        
        let userActivity = NSUserActivity(activityType: "com.michaeldadi.sprout.add-expense")
        userActivity.title = "Add Expense"
        userActivity.isEligibleForSearch = true
        userActivity.isEligibleForPrediction = true
        
        var userInfo: [String: Any] = [:]
        if let amount = intent.amount {
            userInfo["amount"] = amount.doubleValue
        }
        if let category = intent.category {
            userInfo["category"] = category
        }
        if let merchant = intent.merchant {
            userInfo["merchant"] = merchant
        }
        if let notes = intent.notes {
            userInfo["notes"] = notes
        }
        userActivity.userInfo = userInfo
        
        response.userActivity = userActivity
        completion(response)
    }
    
    private func handleCheckBalance(completion: @escaping (INIntentResponse) -> Void) {
        let response = CheckBalanceIntentResponse(code: .continueInApp, userActivity: nil)
        
        let userActivity = NSUserActivity(activityType: "com.michaeldadi.sprout.check-balance")
        userActivity.title = "Check Balance"
        userActivity.isEligibleForSearch = true
        userActivity.isEligibleForPrediction = true
        
        response.userActivity = userActivity
        completion(response)
    }
    
    private func handleRecentTransactions(intent: RecentTransactionsIntent, completion: @escaping (INIntentResponse) -> Void) {
        let response = RecentTransactionsIntentResponse(code: .continueInApp, userActivity: nil)
        
        let userActivity = NSUserActivity(activityType: "com.michaeldadi.sprout.recent-transactions")
        userActivity.title = "Recent Transactions"
        userActivity.isEligibleForSearch = true
        userActivity.isEligibleForPrediction = true
        
        if let limit = intent.limit {
            userActivity.userInfo = ["limit": limit.intValue]
        }
        
        response.userActivity = userActivity
        completion(response)
    }
    
    private func handleMonthlySpending(intent: MonthlySpendingIntent, completion: @escaping (INIntentResponse) -> Void) {
        let response = MonthlySpendingIntentResponse(code: .continueInApp, userActivity: nil)
        
        let userActivity = NSUserActivity(activityType: "com.michaeldadi.sprout.monthly-spending")
        userActivity.title = "Monthly Spending"
        userActivity.isEligibleForSearch = true
        userActivity.isEligibleForPrediction = true
        
        var userInfo: [String: Any] = [:]
        if let month = intent.month {
            userInfo["month"] = month.intValue
        }
        if let year = intent.year {
            userInfo["year"] = year.intValue
        }
        userActivity.userInfo = userInfo
        
        response.userActivity = userActivity
        completion(response)
    }
    
    private func handleSearchTransactions(intent: SearchTransactionsIntent, completion: @escaping (INIntentResponse) -> Void) {
        let response = SearchTransactionsIntentResponse(code: .continueInApp, userActivity: nil)
        
        let userActivity = NSUserActivity(activityType: "com.michaeldadi.sprout.search-transactions")
        userActivity.title = "Search Transactions"
        userActivity.isEligibleForSearch = true
        userActivity.isEligibleForPrediction = true
        
        var userInfo: [String: Any] = [:]
        if let searchTerm = intent.searchTerm {
            userInfo["searchTerm"] = searchTerm
        }
        if let category = intent.category {
            userInfo["category"] = category
        }
        if let dateRange = intent.dateRange {
            userInfo["dateRange"] = dateRange
        }
        userActivity.userInfo = userInfo
        
        response.userActivity = userActivity
        completion(response)
    }
    
    private func handleFinancialGoals(completion: @escaping (INIntentResponse) -> Void) {
        let response = FinancialGoalsIntentResponse(code: .continueInApp, userActivity: nil)
        
        let userActivity = NSUserActivity(activityType: "com.michaeldadi.sprout.financial-goals")
        userActivity.title = "Financial Goals"
        userActivity.isEligibleForSearch = true
        userActivity.isEligibleForPrediction = true
        
        response.userActivity = userActivity
        completion(response)
    }
    
    private func createUserActivity(for intent: INIntent) -> NSUserActivity {
        let activity = NSUserActivity(activityType: "com.michaeldadi.sprout.siri-shortcut")
        activity.title = "Sprout Action"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        return activity
    }
}

class AddExpenseIntentResponse: INIntentResponse {
    convenience init(code: Code, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }
    
    @objc public enum Code: Int {
        case unspecified = 0
        case ready = 1
        case continueInApp = 2
        case inProgress = 3
        case success = 4
        case failure = 5
        case failureRequiringAppLaunch = 6
    }
    
    @objc public var code: Code = .unspecified
}

class CheckBalanceIntentResponse: INIntentResponse {
    convenience init(code: Code, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }
    
    @objc public enum Code: Int {
        case unspecified = 0
        case ready = 1
        case continueInApp = 2
        case inProgress = 3
        case success = 4
        case failure = 5
        case failureRequiringAppLaunch = 6
    }
    
    @objc public var code: Code = .unspecified
}

class RecentTransactionsIntentResponse: INIntentResponse {
    convenience init(code: Code, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }
    
    @objc public enum Code: Int {
        case unspecified = 0
        case ready = 1
        case continueInApp = 2
        case inProgress = 3
        case success = 4
        case failure = 5
        case failureRequiringAppLaunch = 6
    }
    
    @objc public var code: Code = .unspecified
}

class MonthlySpendingIntentResponse: INIntentResponse {
    convenience init(code: Code, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }
    
    @objc public enum Code: Int {
        case unspecified = 0
        case ready = 1
        case continueInApp = 2
        case inProgress = 3
        case success = 4
        case failure = 5
        case failureRequiringAppLaunch = 6
    }
    
    @objc public var code: Code = .unspecified
}

class SearchTransactionsIntentResponse: INIntentResponse {
    convenience init(code: Code, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }
    
    @objc public enum Code: Int {
        case unspecified = 0
        case ready = 1
        case continueInApp = 2
        case inProgress = 3
        case success = 4
        case failure = 5
        case failureRequiringAppLaunch = 6
    }
    
    @objc public var code: Code = .unspecified
}

class FinancialGoalsIntentResponse: INIntentResponse {
    convenience init(code: Code, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }
    
    @objc public enum Code: Int {
        case unspecified = 0
        case ready = 1
        case continueInApp = 2
        case inProgress = 3
        case success = 4
        case failure = 5
        case failureRequiringAppLaunch = 6
    }
    
    @objc public var code: Code = .unspecified
}