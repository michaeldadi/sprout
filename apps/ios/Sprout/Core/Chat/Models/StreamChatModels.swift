//
//  StreamChatModels.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import Foundation

// MARK: - Stream Chat Token Models

struct StreamTokenRequest: Encodable {
    let userId: String
    let provider: String = "stream"
}

struct StreamTokenResponse: Decodable {
    let token: String
    let userId: String
    let expiresAt: Date?
}

// MARK: - Stream Chat Error Response

struct StreamErrorResponse: Decodable {
    let message: String
    let code: String?
    let statusCode: Int?
}

// MARK: - Stream Chat User Models (if needed)

struct StreamUserRequest: Encodable {
    let userId: String
    let name: String
    let email: String
    let role: String?
}

// MARK: - Stream Chat Channel Models (if needed)

struct StreamChannelRequest: Encodable {
    let type: String
    let id: String
    let members: [String]
    let extraData: [String: String]?
}
