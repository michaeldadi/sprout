//
//  AppBootstrap.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import SwiftUI
import SwiftData
import Sentry
import FirebaseCore
import Mixpanel
import StreamChat
import StreamChatSwiftUI
import Combine

@MainActor
class AppBootstrap: ObservableObject {
    // MARK: - Published Properties
    @Published var dataContainer: DataContainer
    @Published var syncService: SyncService
    @Published var authService = AuthService.shared
    @Published var toastManager = ToastManager.shared
    @Published var locationManager = LocationManager.shared
    @Published var chatManager = ChatClientManager.shared
    @Published var deepLinkManager = DeepLinkManager.shared

    // MARK: - Private Properties
    private var hasInitialized = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        do {
            // Initialize data container
            let container = try DataContainer()
            self.dataContainer = container
            self.syncService = SyncService(
                dataContainer: container,
                networkManager: NetworkManager.shared
            )

            // Configure third-party services that don't need AppDelegate
            configureSentry()
            configureFirebase()
            AnalyticsManager.shared.configure()

        } catch {
            fatalError("Failed to initialize data container: \(error)")
        }
    }

    // MARK: - App Initialization
    func initializeApp() async {
        guard !hasInitialized else { return }
        hasInitialized = true

        // Report which legacy integration is configured; Appwrite-only builds
        // can still present native authentication without an AWS endpoint.
        #if DEBUG
        print("📍 Environment: \(AppConfig.shared.environmentName)")
        print("🔗 Legacy API configured: \(AppConfig.shared.hasLegacyAPI)")
        #endif

        // Initialize Stream Chat client
        ChatClientManager.shared.initialize()

        // Connect user if authenticated
        if authService.isAuthenticated {
            await connectAuthenticatedUser()
        }

        // Observe auth changes
        observeAuthChanges()

        // The Appwrite onboarding asks for notification permission only after
        // a user chooses an available reminder. Legacy finance shortcuts stay
        // undiscoverable until their authenticated data path is migrated.
    }

    // MARK: - User Connection
    private func connectAuthenticatedUser() async {
        guard let user = authService.currentUser else {
            print("No authenticated user found")
            return
        }

        // Connect to Stream Chat
        await ChatClientManager.shared.connectUser(
            userId: user.id,
            userName: user.displayName,
            userEmail: user.email,
            imageURL: nil
        )

        // Note: SupportChatManager.initializeSupportChannel() is called
        // automatically after successful connection in ChatClientManager

        // Sync user data
        do {
            try await syncService.syncData()
            print("✅ User data synced successfully")
        } catch {
            print("❌ Failed to sync data: \(error)")
            // Show error toast to user
            await MainActor.run {
              toastManager.showError("Failed to sync data. Pull to refresh to try again.")
            }
        }

        // Update location if permission granted
        if locationManager.authorizationStatus == .authorizedWhenInUse ||
           locationManager.authorizationStatus == .authorizedAlways {
            locationManager.requestSingleLocation()
        }
    }

    // MARK: - Auth Observation
    private func observeAuthChanges() {
        authService.$isAuthenticated
            .dropFirst() // Skip initial value
            .removeDuplicates()
            .sink { [weak self] isAuthenticated in
                Task { @MainActor in
                    if isAuthenticated {
                        print("🔐 User authenticated, connecting services...")
                        await self?.connectAuthenticatedUser()
                    } else {
                        print("🔓 User logged out, disconnecting services...")
                        await self?.disconnectServices()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Service Disconnection
    private func disconnectServices() async {
        // Disconnect from Stream Chat
        await ChatClientManager.shared.disconnect()

        // Clear local data if needed
        await dataContainer.clearUserData()

        // Clear any cached data
        syncService.clearCache()

        print("✅ Services disconnected and data cleared")
    }

    // MARK: - Notification Permissions
    private func requestNotificationPermissionsIfNeeded() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            // First time, ask for permission
            NotificationManager.shared.requestPermission()
        } else if settings.authorizationStatus == .authorized {
            // Already authorized, register for remote notifications
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - Configuration Methods

    private func configureSentry() {
        SentrySDK.start { options in
            options.dsn = "https://cc367d1e16674e8b7a63694900d28bc9@o4509872073342976.ingest.us.sentry.io/4509874072715264"
            options.debug = false
            options.environment = AppConfig.shared.environmentName.lowercased()
            options.sendDefaultPii = false
            options.tracesSampleRate = AppConfig.shared.isProduction ? 0.1 : 0.5
            options.attachViewHierarchy = false
            options.enableAutoSessionTracking = true
            options.sessionTrackingIntervalMillis = 30000

            // Only enable profiling in non-production
            if !AppConfig.shared.isProduction {
              options.configureProfiling = {
                $0.sessionSampleRate = 0.2
              }
              options.enableAppHangTracking = true
            }

            options.beforeSend = { event in
                // Add custom context
                event.context?["app"] = [
                    "version": Bundle.main.appVersion,
                    "build": Bundle.main.buildNumber,
                    "environment": AppConfig.shared.environmentName
                ]
                return event
            }
        }

        print("📊 Sentry configured for \(AppConfig.shared.environmentName)")
    }

    private func configureFirebase() {
        FirebaseApp.configure()
        print("🔥 Firebase configured")
    }

    // MARK: - Deep Linking

    func handleUniversalLink(_ userActivity: NSUserActivity) {
      deepLinkManager.handleUniversalLink(userActivity)
    }

    func handleDeepLink(_ url: URL) {
      deepLinkManager.handleDeepLink(url)
    }

    private func handleReferralCode(_ code: String) {
        // Store referral code for later use
        UserDefaults.standard.set(code, forKey: "referral_code")

        // Track referral
        AnalyticsManager.shared.track(.referralAccepted(source: "link", code: code))

        // Show toast or navigate to appropriate screen
        toastManager.showSuccess("Referral code applied!")
    }

    // MARK: - Cleanup

    deinit {
        cancellables.forEach { $0.cancel() }
    }
}
