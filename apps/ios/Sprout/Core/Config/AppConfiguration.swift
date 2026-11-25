//
//  AppConfiguration.swift
//  Sprout
//
//  Created by Michael Dadi on 8/19/25.
//

import Foundation

struct AppConfig {
    static let shared = AppConfig()

    // Environment variables
    let apiBaseURL: String
    let environmentName: String
    let apiKey: String
    let mixpanelProjectToken: String
    let appsFlyerDevKey: String
    let appsFlyerAppId: String = "644203646" // Default App Store ID
    let awsRegion: String = "us-east-1" // Default AWS region
    let cognitoUserPoolId: String = "us-east-1_acu33uaoz" // Default User Pool ID
    let cognitoClientId: String = "52atb5sd5p1gcn5ohlvtt9dkfp" // Default
    let onesignalAppId: String
    let streamApiKey: String

    // Stream Chat Support Configuration
    struct Support {
        static let channelType = "messaging"
        static let teamId = "support-team"
        static let responseTime = "2-4 hours"
        static let businessHours = "Monday-Friday, 9 AM - 6 PM EST"
        static let welcomeMessageEnabled = true
    }

    // Computed properties
    var isProduction: Bool {
        return environmentName == "Production"
    }

    var isDevelopment: Bool {
        return environmentName == "Development"
    }

    var isStaging: Bool {
        return environmentName == "Staging"
    }

    // Stream Chat specific computed properties
    var streamChatLogLevel: String {
        return isProduction ? "error" : "info"
    }

    var streamLocalStorageEnabled: Bool {
        return true // Enable for all environments for support chat
    }

    var streamStaysConnectedInBackground: Bool {
        return isProduction || isStaging // Only in non-dev environments
    }

    private init() {
        // Always load environment name from Info.plist (set by xcconfig)
        self.environmentName = Bundle.main.object(forInfoDictionaryKey: "ENVIRONMENT_NAME") as? String ?? "Development"

        // Try to load from Secrets first (generated from .env.local)
        if !Secrets.apiBaseURL.isEmpty {
            // Use values from .env.local (highest priority)
            self.apiKey = Secrets.apiKey
            self.apiBaseURL = Secrets.apiBaseURL
            self.mixpanelProjectToken = Secrets.mixpanelProjectToken
            self.appsFlyerDevKey = Secrets.appsFlyerDevKey
            self.onesignalAppId = Secrets.onesignalAppId
            self.streamApiKey = Secrets.streamApiKey

            #if DEBUG
            print("✅ Using configuration from .env.local")
            #endif

        } else if let plistAPIBaseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
                  !plistAPIBaseURL.isEmpty {
            // Fallback to Info.plist values (from xcconfig)
            self.apiKey = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String ?? ""
            self.apiBaseURL = plistAPIBaseURL
            self.mixpanelProjectToken = Bundle.main.object(forInfoDictionaryKey: "MIXPANEL_PROJECT_TOKEN") as? String ?? ""
            self.appsFlyerDevKey = Bundle.main.object(forInfoDictionaryKey: "APPSFLYER_DEV_KEY") as? String ?? ""
            self.onesignalAppId = Bundle.main.object(forInfoDictionaryKey: "ONESIGNAL_APP_ID") as? String ?? ""
            self.streamApiKey = Bundle.main.object(forInfoDictionaryKey: "STREAM_API_KEY") as? String ?? ""

            #if DEBUG
            print("✅ Using configuration from xcconfig/Info.plist")
            #endif

        } else {
            // An Appwrite-only build can launch without the legacy API. Requests
            // stay unavailable until an explicit, valid legacy endpoint is set.
            self.apiKey = ""
            self.apiBaseURL = ""
            self.mixpanelProjectToken = ""
            self.appsFlyerDevKey = ""
            self.onesignalAppId = ""
            self.streamApiKey = ""
        }

        // Debug logging (remove in production)
        #if DEBUG
        print("🚀 App Configuration Loaded:")
//        print("📍 Environment: \(environment)")
//        print("🔗 API URL: \(baseURL)")
        #endif
    }

    var hasLegacyAPI: Bool {
        guard let url = URLComponents(string: apiBaseURL) else { return false }
        return url.scheme == "https" && url.host != nil &&
            url.user == nil && url.password == nil &&
            !apiBaseURL.contains("$(") && !apiBaseURL.contains("yourapp.com")
    }
}
