//
//  SproutApp.swift
//  Sprout
//
//  Created by Michael Dadi on 8/16/25.
//

import SwiftUI
import Sentry

import SwiftData
import FirebaseCore
import Mixpanel

import ZendeskCoreSDK
import SupportSDK

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        SentrySDK.start { options in
            options.dsn = "https://cc367d1e16674e8b7a63694900d28bc9@o4509872073342976.ingest.us.sentry.io/4509874072715264"
            options.debug = false

            // Adds IP for users.
            // For more information, visit: https://docs.sentry.io/platforms/apple/data-management/data-collected/
            options.sendDefaultPii = true

          options.tracesSampleRate = 0.25

            options.configureProfiling = {
              $0.sessionSampleRate = 0.2
                $0.lifecycle = .trace
            }

            // options.attachScreenshot = true // This adds a screenshot to the error events
            options.attachViewHierarchy = true
            
            // Enable experimental logging features
            options.experimental.enableLogs = true
        }
        // Remove the next line after confirming that your Sentry integration is working.
        SentrySDK.capture(message: "This app uses Sentry! :)")
    
    // Initialize Zendesk SDK
    Zendesk.initialize(appId: Secrets.zendeskAppId, clientId: Secrets.zendeskClientId, zendeskUrl: "zendesk.sprout.io")
    Support.initialize(withZendesk: Zendesk.instance)

    
    // Validate configuration early in DEBUG builds
    #if DEBUG
    // Check all critical configuration values
    assert(!AppConfig.shared.mixpanelProjectToken.isEmpty, "Mixpanel token not configured!")
    assert(!AppConfig.shared.apiBaseURL.isEmpty, "API Base URL not configured!")
    // Add more assertions for other critical config values
    
    // Optional: Full validation
    AppConfig.shared.validate()
    
    print("✅ Configuration validated successfully")
    print("📍 Environment: \(AppConfig.shared.environmentName)")
    print("🔗 API URL: \(AppConfig.shared.apiBaseURL)")
    #endif
    
    // Configure Firebase
    FirebaseApp.configure()
    
    // Initialize Mixpanel
    Mixpanel.initialize(token: AppConfig.shared.mixpanelProjectToken,
            trackAutomaticEvents: false
            )

    return true
  }
}

@main
struct SproutApp: App {
    // Register the AppDelegate for
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var dataContainer: DataContainer
    @StateObject private var syncService: SyncService
    @StateObject private var authService = AuthService.shared
    @StateObject private var toastManager = ToastManager()
    
    init() {
        do {
            // Initialize Safari WebKit engine on app launch
            SafariInitializer.shared.ensureInitialized()

            let container = try DataContainer()
            _dataContainer = StateObject(wrappedValue: container)
            _syncService = StateObject(wrappedValue: SyncService(
                dataContainer: container,
                networkManager: NetworkManager.shared
            ))
        } catch {
            fatalError("Failed to initialize data container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataContainer)
                .environmentObject(syncService)
                .environmentObject(authService)
                .environmentObject(toastManager)
                .task {
                    // Start sync when app launches if user is authenticated
                    if authService.isAuthenticated {
                        try? await syncService.syncData()
                    }
                }
        }
    }
}
