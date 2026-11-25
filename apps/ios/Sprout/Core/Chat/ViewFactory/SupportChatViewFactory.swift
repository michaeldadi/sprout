//
//  CustomViewFactory.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import SwiftUI
import StreamChat
import StreamChatSwiftUI

class SupportChatViewFactory: ViewFactory {
    @Injected(\.chatClient) var chatClient

    // Override the correct method signature
    func makeMessageContextMenuActions(
        for message: ChatMessage,
        isRightAligned: Bool,
        channel: ChatChannel?,
        onFinish: @escaping (MessageActionInfo) -> Void,
        onError: @escaping (MessageActionInfo) -> Void
    ) -> [MessageAction] {
        // Get default actions from the base ViewFactory
        var actions: [MessageAction] = []

        // Add default actions based on message state
        if !message.isDeleted {
            // Copy action
            actions.append(
                MessageAction(
                    title: "Copy",
                    iconName: "doc.on.doc",
                    action: {
                        UIPasteboard.general.string = message.text
                        onFinish(.init(message: message, identifier: "copy"))
                    },
                    confirmationPopup: nil,
                    isDestructive: false,
                )
            )

            // Reply action
            actions.append(
                MessageAction(
                    title: "Reply",
                    iconName: "arrowshape.turn.up.left",
                    action: {
                        onFinish(.init(message: message, identifier: "reply"))
                    },
                    confirmationPopup: nil,
                    isDestructive: false,
                )
            )
        }

        // Support agents can delete any message
        if let membership = channel?.membership,
           membership.isAdmin,
           !message.isDeleted,
           !message.isSentByCurrentUser {

            actions.append(
                MessageAction(
                    title: "Delete Message (Admin)",
                    iconName: "trash.fill",
                    action: {
                        self.deleteMessage(message, onFinish: onFinish, onError: onError)
                    },
                    confirmationPopup: ConfirmationPopup(
                        title: "Delete Message",
                        message: "Remove this message from the conversation?",
                        buttonTitle: "Delete"
                    ),
                    isDestructive: true
                )
            )
        }

        // Add "Report Issue" action for customers
        if !message.isDeleted {
            actions.append(
                MessageAction(
                    title: "Report Issue",
                    iconName: "exclamationmark.triangle",
                    action: {
                        self.reportTechnicalIssue(from: message)
                        onFinish(.init(message: message, identifier: "report"))
                    },
                    confirmationPopup: nil,
                    isDestructive: false,
                )
            )
        }

        return actions
    }

    // Helper to delete a message
    private func deleteMessage(
        _ message: ChatMessage,
        onFinish: @escaping (MessageActionInfo) -> Void,
        onError: @escaping (MessageActionInfo) -> Void
    ) {
        guard let cid = message.cid else { return }

        let messageController = chatClient.messageController(
            cid: cid,
            messageId: message.id
        )

        messageController.deleteMessage { error in
            if let error = error {
                print("Error deleting message: \(error)")
                onError(.init(message: message, identifier: "delete"))
            } else {
                print("Message deleted successfully")
                onFinish(.init(message: message, identifier: "delete"))
            }
        }
    }

    // Helper to report technical issues
    private func reportTechnicalIssue(from message: ChatMessage) {
        // Log the issue or send to your analytics
        print("User reported issue with message: \(message.text)")
        // You could trigger an alert or send this to your backend
    }
}
