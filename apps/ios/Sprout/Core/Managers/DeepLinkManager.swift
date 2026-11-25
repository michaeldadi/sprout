//
//  DeepLinkManager.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import SwiftUI
import Mixpanel

@MainActor
class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    @Published var pendingDeepLink: URL?
    @Published var selectedTab: Int = 0
    @Published var showingSupportChat = false
    @Published var activeTransactionId: String?

    private init() {}

    func handleUniversalLink(_ userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = userActivity.webpageURL else { return }

        handleDeepLink(incomingURL)
    }

    func handleDeepLink(_ url: URL) {
        pendingDeepLink = url
    }

    private func handleReferralCode(_ code: String) {
        UserDefaults.standard.set(code, forKey: "referral_code")

        AnalyticsManager.shared.track(.referralOpened(source: "link"))

        ToastManager.shared.showSuccess("Referral code applied!")
    }

    func processPendingDeepLinkIfNeeded() {
        guard let pendingURL = pendingDeepLink else { return }

        // Check if we're ready to process
        guard AuthService.shared.isAuthenticated else {
            print("⏳ Still not authenticated, keeping deep link pending")
            return
        }

        processDeepLink(pendingURL)
        pendingDeepLink = nil
    }

    private func processDeepLink(_ url: URL) {
        // Your actual deep link logic
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }


        // Track in analytics
        AnalyticsManager.shared.track(.deepLinkOpened(url: "", path: components.path))

        switch components.path {
        case "/support", "/help":
            showingSupportChat = true
            selectedTab = 3 // Profile tab

        case "/transaction":
            if let transactionId = components.queryItems?.first(where: { $0.name == "id" })?.value {
                activeTransactionId = transactionId
            }
            selectedTab = 2 // Activity tab

        case "/budget":
            selectedTab = 1 // Budget tab

        case "/invite":
            if let referralCode = components.queryItems?.first(where: { $0.name == "code" })?.value {
                handleReferralCode(referralCode)
            }

        default:
            print("Unhandled deep link path: \(components.path)")
            break
        }
    }
}
