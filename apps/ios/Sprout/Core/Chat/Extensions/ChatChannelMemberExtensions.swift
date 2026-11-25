//
//  ChatChannelMemberExtensions.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import StreamChat
import StreamChatSwiftUI

extension ChatChannelMember {
    /// Returns true if the member has admin privileges (owner, admin, or moderator)
    var isAdmin: Bool {
        MemberRole.adminRoles.contains(memberRole)
    }

    var isSupportAgent: Bool {
        // Check if this member is part of support team
      return isAdmin || memberRole.rawValue.contains("support-")
    }

    var isCustomer: Bool {
        return !isSupportAgent
    }
}

extension MemberRole {
    static let adminRoles: [Self] = [
        .moderator,
        .admin,
        .owner
    ]
}
