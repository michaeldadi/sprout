//
//  AnalyticsManager.swift
//  Sprout
//
//  Created by Michael Dadi on 8/23/25.
//

import Foundation
import Mixpanel

// MARK: - Analytics Event Protocol
protocol AnalyticsEvent {
    var name: String { get }
    var parameters: [String: Any]? { get }
}

// MARK: - Standard Events
enum StandardEvent: AnalyticsEvent {
    // Onboarding
    case signUpStarted
    case signUpCompleted(method: String)
    case loginCompleted(method: String)
    case onboardingCompleted
    case onboardingSkipped
    case referralOpened(source: String)
    case referralAccepted(source: String, code: String? = nil)

    // Budget & Finance
    case budgetCreated(amount: Double, category: String)
    case budgetUpdated(amount: Double, category: String)
    case transactionAdded(amount: Double, category: String, type: String)
    case transactionDeleted
    case accountLinked(institution: String)

    // User Actions
    case screenViewed(screenName: String)
    case buttonTapped(buttonName: String, screenName: String)
    case settingsChanged(setting: String, value: Any)
    case notificationPermissionGranted
    case notificationPermissionDenied
    case deepLinkOpened(url: String, path: String)

    // Monetization
    case subscriptionStarted(plan: String, price: Double)
    case subscriptionCancelled
    case purchaseCompleted(itemId: String, price: Double)

    var name: String {
        switch self {
        case .signUpStarted: return "sign_up_started"
        case .signUpCompleted: return "sign_up_completed"
        case .loginCompleted: return "login_completed"
        case .onboardingCompleted: return "onboarding_completed"
        case .onboardingSkipped: return "onboarding_skipped"
        case .referralOpened: return "referral_opened"
        case .referralAccepted: return "referral_accepted"
        case .budgetCreated: return "budget_created"
        case .budgetUpdated: return "budget_updated"
        case .transactionAdded: return "transaction_added"
        case .transactionDeleted: return "transaction_deleted"
        case .accountLinked: return "account_linked"
        case .deepLinkOpened: return "deep_link_opened"
        case .screenViewed: return "screen_view"
        case .buttonTapped: return "button_tapped"
        case .settingsChanged: return "settings_changed"
        case .notificationPermissionGranted: return "notification_permission_granted"
        case .notificationPermissionDenied: return "notification_permission_denied"
        case .subscriptionStarted: return "subscription_started"
        case .subscriptionCancelled: return "subscription_cancelled"
        case .purchaseCompleted: return "purchase_completed"
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .signUpCompleted(let method),
             .loginCompleted(let method):
            return ["method": method]

        case .referralOpened(let source):
            return ["source": source]
        case .referralAccepted(let source, let code):
            return ["source": source, "code": code ?? NSNull()]

        case .budgetCreated(let amount, let category),
             .budgetUpdated(let amount, let category):
            return ["amount": amount, "category": category]

        case .transactionAdded(let amount, let category, let type):
            return ["amount": amount, "category": category, "type": type]

        case .accountLinked(let institution):
            return ["institution": institution]

        case .deepLinkOpened(let url, let path):
            return ["url": url, "path": path]

        case .screenViewed(let screenName):
            return ["screen_name": screenName]

        case .buttonTapped(let buttonName, let screenName):
            return ["button_name": buttonName, "screen_name": screenName]

        case .settingsChanged(let setting, let value):
            return ["setting_name": setting, "value": value]

        case .subscriptionStarted(let plan, let price):
            return ["plan": plan, "price": price]

        case .purchaseCompleted(let itemId, let price):
            return ["item_id": itemId, "price": price]

        default:
            return nil
        }
    }
}

// MARK: - Custom Event
struct CustomEvent: AnalyticsEvent {
    let name: String
    let parameters: [String: Any]?

    init(name: String, parameters: [String: Any]? = nil) {
        self.name = name
        self.parameters = parameters
    }
}

/// A single analytics destination. Every caller, including legacy call sites,
/// passes the same generated event/value allowlist before SDK persistence.
final class AnalyticsManager {
    static let shared = AnalyticsManager()
    private var instance: MixpanelInstance?
    private init() {}

    func configure(debugMode: Bool = false) {
        guard instance == nil, AppConfig.shared.isProduction else { return }
        #if !DEBUG
        let token = AppConfig.shared.mixpanelProjectToken
        guard !token.isEmpty else { return }
        let client = Mixpanel.initialize(token: token, trackAutomaticEvents: false, instanceName: "sprout-allowlist-v1")
        client.loggingEnabled = false
        client.trackAutomaticEventsEnabled = false
        client.useIPAddressForGeoLocation = false
        instance = client
        #endif
    }

    func track(_ event: AnalyticsEvent) {
        guard let properties = SproutAnalyticsPolicy.sanitize(name: event.name, parameters: event.parameters) else { return }
        instance?.track(event: event.name, properties: properties)
    }
    func track(_ event: StandardEvent) { track(event as AnalyticsEvent) }
    func trackCustom(name: String, parameters: [String: Any]? = nil) { track(CustomEvent(name: name, parameters: parameters)) }
    func trackScreen(_ screenName: String, additionalParameters: [String: Any]? = nil) {
        trackCustom(name: "screen_view", parameters: ["screen_name": screenName])
    }
    func trackButtonTap(_ buttonName: String, on screen: String) { track(.buttonTapped(buttonName: buttonName, screenName: screen)) }
    func startSession() { trackCustom(name: "session_start") }
    func endSession(duration: TimeInterval) { trackCustom(name: "session_end") }

    // Account identifiers, profile properties, revenue amounts, error messages
    // and arbitrary timings are deliberately outside the analytics contract.
    func setUserId(_ userId: String?) { if userId == nil { instance?.reset() } }
    func setUserProperty(key: String, value: String?) {}
    func setUserProperties(_ properties: [String: String]) {}
    func logRevenue(amount: Double, currency: String = "USD") {}
    func trackError(_ error: Error, context: String? = nil) {}
    func trackTiming(name: String, duration: TimeInterval, category: String? = nil) {}
}
