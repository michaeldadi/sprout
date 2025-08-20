//
//  AppConfig.swift
//  Sprout
//
//  Created by Michael Dadi on 8/19/25.
//


// AppConfig.swift
import Foundation

struct AppConfig {
    static let shared = AppConfig()
    
    // Environment variables
    let apiBaseURL: String
    let environmentName: String
    let apiKey: String
    let mixpanelProjectToken: String
    let awsRegion: String = "us-east-1" // Default AWS region
    let cognitoUserPoolId: String = "us-east-1_acu33uaoz" // Default User Pool ID
    let cognitoClientId: String = "52atb5sd5p1gcn5ohlvtt9dkfp" // Default
    
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
    
    private init() {
        // Always load environment name from Info.plist (set by xcconfig)
        self.environmentName = Bundle.main.object(forInfoDictionaryKey: "ENVIRONMENT_NAME") as? String ?? "Development"

        // Try to load from Secrets first (generated from .env.local)
        if !Secrets.apiKey.isEmpty && !Secrets.apiBaseURL.isEmpty {
            // Use values from .env.local (highest priority)
            self.apiKey = Secrets.apiKey
            self.apiBaseURL = Secrets.apiBaseURL
            self.mixpanelProjectToken = Secrets.mixpanelProjectToken
            
            #if DEBUG
            print("✅ Using configuration from .env.local")
            #endif
            
        } else if let plistAPIKey = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String,
                  let plistAPIBaseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
                  let plistMixpanelToken = Bundle.main.object(forInfoDictionaryKey: "MIXPANEL_PROJECT_TOKEN") as? String {
            // Fallback to Info.plist values (from xcconfig)
            self.apiKey = plistAPIKey
            self.apiBaseURL = plistAPIBaseURL
            self.mixpanelProjectToken = plistMixpanelToken
            
            #if DEBUG
            print("✅ Using configuration from xcconfig/Info.plist")
            #endif
            
        } else {
            // Last resort: defaults for development
            #if DEBUG
            print("⚠️ No configuration found, using defaults")
            self.apiKey = "debug_api_key"
            self.apiBaseURL = "https://gt9xp1956l.execute-api.us-east-1.amazonaws.com"
            self.mixpanelProjectToken = "debug_mixpanel_token"
            #else
            // In production, this should never happen
            fatalError("❌ No API configuration found! Check .env.local and xcconfig files")
            #endif
        }
        
        // Debug logging (remove in production)
        #if DEBUG
        print("🚀 App Configuration Loaded:")
//        print("📍 Environment: \(environment)")
//        print("🔗 API URL: \(baseURL)")
        #endif
    }
    
    // Helper method to validate configuration
    func validate() {
        assert(!apiBaseURL.isEmpty, "API Base URL is empty")
        assert(apiBaseURL.hasPrefix("https://"), "API URL should use HTTPS")
    }
}
