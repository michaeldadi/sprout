//
//  SproutApp.swift
//  Sprout
//
//  Created by Michael Dadi on 8/16/25.
//

import SwiftUI
import Sentry
import Intents
import UserNotifications

import SwiftData
import FirebaseCore
import Mixpanel

import BrazeKit
import BrazeUI
import BrazeLocation
import AppTrackingTransparency

import ZendeskCoreSDK
import SupportSDK
import WebKit

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  static private(set) var shared: AppDelegate!

  static var braze: Braze? = nil
  public var showMessage: Bool = false

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    AppDelegate.shared = self

    SentrySDK.start { options in
        options.dsn = "https://cc367d1e16674e8b7a63694900d28bc9@o4509872073342976.ingest.us.sentry.io/4509874072715264"
        options.debug = false

        options.sendDefaultPii = true

      options.tracesSampleRate = 0.2

        options.configureProfiling = {
          $0.sessionSampleRate = 0.2
            $0.lifecycle = .trace
        }

        // options.attachScreenshot = true // This adds a screenshot to the error events
        options.attachViewHierarchy = true
        
        // Enable experimental logging features
        options.experimental.enableLogs = true
    }
    
    let configuration = Braze.Configuration(
        apiKey: Secrets.brazeApiKey,
        endpoint: Secrets.brazeEndpoint
    )
    configuration.logger.level = .info
    configuration.forwardUniversalLinks = true

    // Create the script message handler using the initialized Braze instance
    let scriptMessageHandler = Braze.WebViewBridge.ScriptMessageHandler(braze: AppDelegate.braze)

    // Create a web view config and set up the script message handler
    let webViewConfiguration = WKWebViewConfiguration()
    webViewConfiguration.userContentController.addUserScript(
      Braze.WebViewBridge.ScriptMessageHandler.script
    )
    webViewConfiguration.userContentController.add(
      scriptMessageHandler,
      name: Braze.WebViewBridge.ScriptMessageHandler.name
    )

    // Create the webview using the configuration
    _ = WKWebView(frame: .zero, configuration: webViewConfiguration)

    webViewConfiguration.allowsInlineMediaPlayback = true
    webViewConfiguration.allowsPictureInPictureMediaPlayback = true
    webViewConfiguration.allowsAirPlayForMediaPlayback = true
    webViewConfiguration.defaultWebpagePreferences.allowsContentJavaScript = true

    configuration.location.brazeLocationProvider = BrazeLocationProvider()
    configuration.location.automaticLocationCollection = true
    configuration.location.geofencesEnabled = true
    configuration.location.allowBackgroundGeofenceUpdates = false
    configuration.location.distanceFilter = 6000
    configuration.location.automaticGeofenceRequests = true

    configuration.push.automation = true
    // Manually enable or disable individual settings by overriding properties of `automation`.
    configuration.push.automation.requestAuthorizationAtLaunch = false

    // Declare which types of data you wish to collect for user tracking.
    configuration.api.trackingPropertyAllowList = [.everything]
    configuration.api.sdkAuthentication = true

    configuration.optInWhenPushAuthorized = true
    configuration.push.automation.requestAuthorizationAtLaunch = true
    configuration.push.automation.automaticSetup = true
    configuration.push.automation.registerDeviceToken = true
    
    configuration.push.automation.setNotificationCategories = false

    let braze = Braze(configuration: configuration)
    // Set the Braze instance in the AppDelegate for global access
    AppDelegate.braze = braze

    // Request updated Braze banners
    braze.banners.requestBannersRefresh(placementIds: ["home-screen-top"])

    let inAppMessageUI = BrazeInAppMessageUI()
    inAppMessageUI.delegate = self
    braze.inAppMessagePresenter = inAppMessageUI

    braze.enabled = true

    // Initialize Zendesk SDK
    Zendesk.initialize(appId: Secrets.zendeskAppId, clientId: Secrets.zendeskClientId, zendeskUrl: "zendesk.getsprout.io")
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

    // Set up Siri shortcuts
    SiriShortcutsService.shared.donateAllShortcuts()

    GIFViewProvider.shared = .sdWebImage

    return true
  }

  func braze(_ braze: Braze, sdkAuthenticationFailedWithError error: Braze.SDKAuthenticationError) {
    // TODO: Check if the `user_id` within the `error` matches the currently logged-in user
    print("Invalid SDK Authentication Token.", error.localizedDescription)
    // Get new token
    let newSignature = "your_new_signature_here"
    AppDelegate.braze?.set(sdkAuthenticationSignature: newSignature)
  }
  
  func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    // Handle Siri shortcuts
    if userActivity.activityType.contains("com.michaeldadi.sprout") {
      handleSiriShortcut(userActivity)
      return true
    }
    return false
  }
  
  func applicationDidBecomeActive(_ application: UIApplication) {
    // Request and check your user's tracking authorization status.
    ATTrackingManager.requestTrackingAuthorization { status in
      // Let Braze know whether user data is allowed to be collected for tracking.
      let enableAdTracking = status == .authorized
      AppDelegate.braze?.set(adTrackingEnabled: enableAdTracking)
      
      if enableAdTracking {
        AppDelegate.braze?.set(identifierForAdvertiser: UIDevice.current.identifierForVendor?.uuidString)
      }
      
      // Add the `.firstName` and `.lastName` properties, while removing the `.everything` configuration.
      AppDelegate.braze?.updateTrackingAllowList(
        adding: [.firstName, .lastName],
        removing: [.everything]
      )
    }
  }
  
  func application(_ application: UIApplication,
     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    if (!Braze.Notifications.isInternalNotification(userInfo)) {
      if AppDelegate.braze!.notifications.handleBackgroundNotification(
        userInfo: userInfo,
        fetchCompletionHandler: completionHandler
      ) {
       // Braze handled the notification, nothing more to do.
       return
   }
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Forward foreground notification to Braze.
    AppDelegate.braze!.notifications.handleForegroundNotification(notification: notification)


   // Braze will never call the completion handler of
   // `userNotificationCenter(_:willPresent:withCompletionHandler:)`, so make sure to call
   // it in your own implementation.
    if #available(iOS 14.0, *) {
      completionHandler([.list, .banner])
    } else {
      completionHandler([.alert])
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    // Forward user notification to Braze.
    if AppDelegate.braze!.notifications.handleUserNotification(
      response: response,
      withCompletionHandler: completionHandler
    ) {
      // Braze handled the notification, nothing more to do.
      return
    }


    // Braze did not handle this user notification, manually
    // call the completion handler to let the system know
    // that the user notification is processed.
    completionHandler()
  }

  let cancellable = AppDelegate.braze?.subscribeToSessionUpdates { event in
    switch event {
    case .started(let id):
      print("Session \(id) has started")
    case .ended(let id):
      print("Session \(id) has ended")
    @unknown default:
      print("Unknown session event")
    }
  }

  func subscribeToUpdates(
      payloadTypes: Braze.Notifications.Payload.PayloadTypeFilter = [.opened, .received],
      _ update: @escaping (Braze.Notifications.Payload) -> Void
  ) -> Braze.Cancellable {
    return AppDelegate.braze?.notifications.subscribeToUpdates(
      payloadTypes: payloadTypes,
      update
    ) ?? Braze.Cancellable.empty
  }

  private func handleSiriShortcut(_ userActivity: NSUserActivity) {
    NotificationCenter.default.post(
      name: .siriShortcutReceived,
      object: userActivity
    )
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
    @StateObject private var locationManager = LocationManager.shared
    
    init() {
        do {
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
            VStack(spacing: 0) {
                BannerViewController()
                ContentView()
                    .environmentObject(dataContainer)
                    .environmentObject(syncService)
                    .environmentObject(authService)
                    .environmentObject(toastManager)
                    .environmentObject(locationManager)
            }
                .task {
                    // Start sync when app launches if user is authenticated
                    if authService.isAuthenticated {
                        try? await syncService.syncData()
                    }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb, perform: handleUserActivity)
        }
    }
  
    func handleUserActivity(_ userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = userActivity.webpageURL,
              let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true),
              let path = components.path,
              let params = components.queryItems else { return }

        print("path = \(path)")

        if let albumName = params.first(where: { $0.name == "albumname" })?.value,
           let photoIndex = params.first(where: { $0.name == "index" })?.value {
            print("album = \(albumName)")
            print("photoIndex = \(photoIndex)")
        } else {
            print("Either album name or photo index missing")
        }
    }
}
