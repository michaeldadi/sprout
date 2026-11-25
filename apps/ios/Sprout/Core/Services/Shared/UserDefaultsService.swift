//
//  UserDefaultsService.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import Foundation

class UserDefaultsService {
    static let shared = UserDefaultsService()
    private let defaults = UserDefaults(suiteName: "group.com.michaeldadi.Sprout")

    private init() {}

    // Store current user ID for intents
    var currentUserId: String? {
        get { defaults?.string(forKey: "currentUserId") }
        set { defaults?.set(newValue, forKey: "currentUserId") }
    }

    // Cache balance for quick access in intents
    var cachedBalance: Double {
        get { defaults?.double(forKey: "cachedBalance") ?? 0 }
        set { defaults?.set(newValue, forKey: "cachedBalance") }
    }
}
