//
//  AppDelegate.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import OneSignalFramework
import StreamChatSwiftUI

extension NSNotification.Name {
    static let siriShortcutReceived = NSNotification.Name("siriShortcutReceived")
}

class AppDelegate: NSObject, UIApplicationDelegate {
    @Injected(\.chatClient) var chatClient

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AnalyticsManager.shared.configure()
        // Configure services that require AppDelegate
        NotificationManager.shared.configure(launchOptions: launchOptions)

        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Register device token with Stream Chat
//        chatClient.registerDeviceToken(deviceToken)

        // Register with OneSignal (handled internally by OneSignal SDK)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        // Handle Siri shortcuts
        if userActivity.activityType.contains("com.michaeldadi.sprout") {
            NotificationCenter.default.post(
                name: .siriShortcutReceived,
                object: userActivity
            )
            return true
        }
        return false
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notifications even when app is in foreground
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        NotificationManager.shared.handleNotificationResponse(response)
        completionHandler()
    }
}
