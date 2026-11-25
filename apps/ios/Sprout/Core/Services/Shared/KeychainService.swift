//
//  KeychainService.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()

    private let streamTokenKey = "com.michaeldadi.Sprout.streamToken"
    private let streamTokenService = "com.michaeldadi.Sprout.chat"

    private init() {}

    func saveStreamToken(_ token: String) -> Bool {
        let data = token.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: streamTokenService,
            kSecAttrAccount as String: streamTokenKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func getStreamToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: streamTokenService,
            kSecAttrAccount as String: streamTokenKey,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    func deleteStreamToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: streamTokenService,
            kSecAttrAccount as String: streamTokenKey,
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}
