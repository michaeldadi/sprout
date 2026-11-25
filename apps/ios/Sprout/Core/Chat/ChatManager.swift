//
//  ChatManager.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import Foundation
import StreamChat
import StreamChatSwiftUI

class SupportChatManager: ObservableObject {
    static let shared = SupportChatManager()

    @Injected(\.chatClient) var chatClient

    @Published var supportChannelController: ChatChannelController?
    @Published var unreadCount: Int = 0

    private var channelId: ChannelId?
    private var hasShownWelcomeMessage = false

    private init() {}

    func initializeSupportChannel() {
        guard let currentUserId = chatClient.currentUserId else {
            print("No current user connected")
            return
        }

        // Create channel ID
        let channelId = ChannelId(
            type: .messaging,
            id: "support-\(currentUserId)"
        )

        self.channelId = channelId

        // Create channel controller with initial configuration
        let channelController = chatClient.channelController(
            for: channelId,
            messageOrdering: .topToBottom
        )

        // Set delegate to monitor changes
        channelController.delegate = self

        // Synchronize to get latest state
        channelController.synchronize { [weak self] error in
            if error != nil {
                // Channel doesn't exist, create it
                self?.createSupportChannel(controller: channelController, userId: currentUserId)
            } else {
                // Channel exists
                self?.supportChannelController = channelController
                self?.updateUnreadCount()
                self?.checkAndSendWelcomeMessage(channelController)
            }
        }
    }

    private func createSupportChannel(controller: ChatChannelController, userId: String) {
        // Update channel with name and add members
        controller.updateChannel(
            name: "Customer Support",
            imageURL: nil,
            team: nil,
            extraData: [:] // Stream handles extra data separately if needed
        ) { [weak self] error in
            if error == nil {
                // Add members to the channel
                controller.addMembers(userIds: [userId, AppConfig.Support.teamId]) { error in
                    if error == nil {
                        self?.supportChannelController = controller
                        self?.updateUnreadCount()
                        self?.checkAndSendWelcomeMessage(controller)
                        print("Support channel created successfully")
                    } else {
                        print("Error adding members: \(error?.localizedDescription ?? "")")
                    }
                }
            } else {
                // If update fails, the channel might not exist yet
                // Try to synchronize with create flag
                self?.createChannelAlternativeWay(userId: userId)
            }
        }
    }

    // Alternative way to create channel using ChannelController
    private func createChannelAlternativeWay(userId: String) {
        guard let channelId = channelId else { return }

        do {
            // Create a new channel controller with members specified
            let controller = try chatClient.channelController(
                createChannelWithId: channelId,
                name: "Customer Support",
                imageURL: nil,
                members: Set([userId, AppConfig.Support.teamId]),
                isCurrentUserMember: true,
                messageOrdering: .topToBottom,
                extraData: [:]
            )

            controller.synchronize { [weak self] error in
                if error == nil {
                    self?.supportChannelController = controller
                    self?.updateUnreadCount()
                    self?.checkAndSendWelcomeMessage(controller)
                    print("Support channel created using alternative method")
                } else {
                    print("Error creating channel: \(error?.localizedDescription ?? "")")
                }
            }
        } catch {
            print("Error creating channel controller: \(error)")
            // Fallback to simple channel creation
            createSimpleChannel(userId: userId)
        }
    }

    private func createSimpleChannel(userId: String) {
        guard let channelId = channelId else { return }

        // Get channel controller and let Stream handle creation
        let controller = chatClient.channelController(
            for: channelId,
            messageOrdering: .topToBottom
        )

        self.supportChannelController = controller
        controller.delegate = self

        controller.synchronize { [weak self] error in
            if error == nil {
                self?.updateUnreadCount()
                print("Support channel ready (simple method)")
            } else {
                print("Error: \(error?.localizedDescription ?? "")")
            }
        }
    }

    private func checkAndSendWelcomeMessage(_ controller: ChatChannelController) {
        // Check if channel is new (no messages)
        if let channel = controller.channel,
           channel.lastMessageAt == nil,
           !hasShownWelcomeMessage {
            sendWelcomeMessage()
            hasShownWelcomeMessage = true
        }
    }

    private func sendWelcomeMessage() {
        guard let channelController = supportChannelController else { return }

        let welcomeText = """
        👋 Welcome to customer support!

        We're here to help with any questions about your finances or the app.

        🕐 Support Hours: \(AppConfig.Support.businessHours)
        ⏱ Response Time: \(AppConfig.Support.responseTime)

        How can we help you today?
        """

        // Create new message
        channelController.createNewMessage(text: welcomeText) { result in
            switch result {
            case .success(let messageId):
                print("Welcome message sent successfully with ID: \(messageId)")
            case .failure(let error):
                print("Error sending welcome message: \(error)")
            }
        }
    }

    private func updateUnreadCount() {
        unreadCount = supportChannelController?.channel?.unreadCount.messages ?? 0
    }

    func markAllAsRead() {
        supportChannelController?.markRead { error in
            if error == nil {
                print("Messages marked as read")
            } else {
                print("Error marking messages as read: \(error?.localizedDescription ?? "")")
            }
        }
    }

    func cleanup() {
        supportChannelController = nil
        channelId = nil
        unreadCount = 0
        hasShownWelcomeMessage = false
    }
}

// MARK: - ChatChannelControllerDelegate
extension SupportChatManager: ChatChannelControllerDelegate {
    func channelController(
        _ channelController: ChatChannelController,
        didUpdateChannel channel: EntityChange<ChatChannel>
    ) {
        updateUnreadCount()
    }

    func channelController(
        _ channelController: ChatChannelController,
        didUpdateMessages changes: [ListChange<ChatMessage>]
    ) {
        updateUnreadCount()
    }
}
