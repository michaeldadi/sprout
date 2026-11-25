//
//  NotificationManager.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import Foundation
import UserNotifications
import OneSignalFramework

class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private override init() {
        super.init()
    }

    func configure(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        // Configure OneSignal
        OneSignal.Debug.setLogLevel(.LL_ERROR)
        OneSignal.initialize(AppConfig.shared.onesignalAppId, withLaunchOptions: launchOptions)

        // Set up observers
        OneSignal.Notifications.addPermissionObserver(self)
        OneSignal.Notifications.addClickListener(self)
        OneSignal.Notifications.addForegroundLifecycleListener(self)
        OneSignal.InAppMessages.addLifecycleListener(self)
    }

    func requestPermission() {
        OneSignal.Notifications.requestPermission({ accepted in
            print("User accepted notifications: \(accepted)")

            // Also request permission for regular UN notifications for Stream Chat
            if accepted {
                UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound, .badge]
                ) { granted, _ in
                    if granted {
                        DispatchQueue.main.async {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    }
                }
            }
        }, fallbackToSettings: false)
    }

    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo

        // Check if it's a Stream Chat notification
        if userInfo["stream"] != nil ||
           userInfo["channel_id"] != nil ||
           userInfo["channel_type"] != nil {
            // Handle Stream Chat notification
            handleStreamChatNotification(userInfo: userInfo)
        }
        // OneSignal notifications are handled by OneSignal SDK automatically
    }

    private func handleStreamChatNotification(userInfo: [AnyHashable: Any]) {
        // Extract channel info and navigate to chat
        if let channelId = userInfo["channel_id"] as? String,
           let channelType = userInfo["channel_type"] as? String {

            let cid = "\(channelType):\(channelId)"

            // Post notification to open specific chat
            NotificationCenter.default.post(
                name: .openSupportChat,
                object: cid
            )
        } else {
            // Generic support chat opening
            NotificationCenter.default.post(
                name: .openSupportChat,
                object: nil
            )
        }
    }

    deinit {
        OneSignal.Notifications.removePermissionObserver(self)
        OneSignal.Notifications.removeClickListener(self)
        OneSignal.Notifications.removeForegroundLifecycleListener(self)
        OneSignal.InAppMessages.removeLifecycleListener(self)
    }
}

// MARK: - OneSignal Observers
extension NotificationManager: OSNotificationPermissionObserver,
                               OSNotificationClickListener,
                               OSNotificationLifecycleListener,
                               OSInAppMessageLifecycleListener {

    func onNotificationPermissionDidChange(_ granted: Bool) {
        print("Notification permission changed: \(granted)")

      if granted {
        AnalyticsManager.shared.track(.notificationPermissionGranted)
      } else {
        AnalyticsManager.shared.track(.notificationPermissionDenied)
      }
    }

    func onClick(event: OSNotificationClickEvent) {
        print("OneSignal notification clicked: \(event.notification.title ?? "")")

        // Handle OneSignal notification clicks
        if let additionalData = event.notification.additionalData {
            handleOneSignalNotificationClick(additionalData: additionalData)
        }
    }

    func onWillDisplay(event: OSNotificationWillDisplayEvent) {
        print("Will display notification: \(event.notification.title ?? "")")
        // You can modify or prevent the notification here if needed
    }

    // In-App Message handlers
    func onWillDisplay(message: OSInAppMessageWillDisplayEvent) {
        print("Will display in-app message")
    }

    func onDidDisplay(message: OSInAppMessageDidDisplayEvent) {
        print("Did display in-app message")
    }

    func onWillDismiss(message: OSInAppMessageWillDismissEvent) {
        print("Will dismiss in-app message")
    }

    func onDidDismiss(message: OSInAppMessageDidDismissEvent) {
        print("Did dismiss in-app message")
    }

    // MARK: - Helpers

    private func handleOneSignalNotificationClick(additionalData: [AnyHashable: Any]) {
        // Handle different types of OneSignal notifications
        if let actionType = additionalData["action_type"] as? String {
            switch actionType {
            case "open_support":
                NotificationCenter.default.post(name: .openSupportChat, object: nil)
            case "open_transaction":
                if let transactionId = additionalData["transaction_id"] as? String {
                    NotificationCenter.default.post(
                        name: .openTransaction,
                        object: transactionId
                    )
                }
            default:
                break
            }
        }
    }
}
