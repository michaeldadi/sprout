//
//  NotificationService.swift
//  OneSignalNotificationServiceExtension
//
//  Created by Michael Dadi on 8/21/25.
//

import UserNotifications
import OneSignalExtension
import StreamChat

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var receivedRequest: UNNotificationRequest!
    var bestAttemptContent: UNMutableNotificationContent?

    // Note this extension only runs when `mutable_content` is set
    // Setting an attachment or action buttons automatically sets the property to true
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.receivedRequest = request
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        if let bestAttemptContent = bestAttemptContent {
          // DEBUGGING: Uncomment the 2 lines below to check this extension is executing
//            print("Running NotificationServiceExtension")
//            bestAttemptContent.body = "[Modified] " + bestAttemptContent.body

          // Check if this is a Stream Chat notification
          if isStreamChatNotification(userInfo: bestAttemptContent.userInfo) {
              handleStreamChatNotification(content: bestAttemptContent, contentHandler: contentHandler)
          } else {
            OneSignalExtension.didReceiveNotificationExtensionRequest(self.receivedRequest, with: bestAttemptContent, withContentHandler: self.contentHandler)
          }
        }
    }

    private func isStreamChatNotification(userInfo: [AnyHashable: Any]) -> Bool {
      // Stream Chat notifications contain these specific keys
      return userInfo["stream"] != nil ||
             userInfo["channel_id"] != nil ||
             userInfo["channel_type"] != nil ||
             userInfo["type"] as? String == "message.new" // Stream Chat message type
    }

    private func handleStreamChatNotification(content: UNMutableNotificationContent, contentHandler: @escaping (UNNotificationContent) -> Void) {
            // Configure Stream Chat client
            var config = ChatClientConfig(apiKey: .init(AppConfig.shared.streamApiKey))
            config.isLocalStorageEnabled = true
            config.applicationGroupIdentifier = "group.com.michaeldadi.Sprout"

            let client = ChatClient(config: config)

            // Retrieve user token from Keychain (shared app group)
            guard let token = KeychainService.shared.getStreamToken() else {
                // Fallback to basic notification if no token
                content.title = "New Message"
                content.body = "You have a new message"
                contentHandler(content)
                return
            }

            client.setToken(token: Token(stringLiteral: token))

            let chatHandler = ChatRemoteNotificationHandler(client: client, content: content)
            _ = chatHandler.handleNotification { chatContent in
                switch chatContent {
                case let .message(message):
                    // Check if it's a support channel from userInfo
                    let channelId = content.userInfo["channel_id"] as? String ?? ""
                    _ = content.userInfo["channel_type"] as? String ?? ""
                    _ = content.userInfo["channel_name"] as? String

                    // Customize notification for support messages
                    if channelId.contains("support") {
                        content.title = "Customer Support"
                        content.subtitle = message.message.author.name ?? "Support Agent"
                        content.body = message.message.text
                        content.sound = .default

                        // Add custom action for support
                        if #available(iOS 15.0, *) {
                            content.interruptionLevel = .timeSensitive
                        }
                    } else {
                      content.title = message.message.author.name ?? "New Message"
                      content.body = message.message.text
                    }

                case .unknown:
                    // Fallback for unknown notification types
                    // Try to extract what we can from userInfo
                    if let messageText = content.userInfo["message_text"] as? String {
                        content.body = messageText
                    }

                    if let authorName = content.userInfo["message_author_name"] as? String {
                        content.title = authorName
                    } else {
                        content.title = "New Message"
                    }

                    content.body = content.body.isEmpty ? "You have new activity in chat" : content.body
                }

                contentHandler(content)
            }
        }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            // Check if it's Stream Chat to provide appropriate fallback
            if isStreamChatNotification(userInfo: bestAttemptContent.userInfo) {
                bestAttemptContent.title = "New Message"
                bestAttemptContent.body = "You have a new message"
            } else {
                OneSignalExtension.serviceExtensionTimeWillExpireRequest(
                    self.receivedRequest,
                    with: self.bestAttemptContent
                )
            }
            contentHandler(bestAttemptContent)
        }
    }
}
