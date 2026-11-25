//
//  CacheManager.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import Foundation
import SwiftUI

@MainActor
class CacheManager: ObservableObject {
    static let shared = CacheManager()

    private let suiteName = "group.com.michaeldadi.Sprout"
    private let cacheQueue = DispatchQueue(label: "com.sprout.cache", qos: .background)

    // Cache keys
    private enum CacheKey: String, CaseIterable {
        case currentBalance = "cache.currentBalance"
        case recentTransactions = "cache.recentTransactions"
        case monthlyBudget = "cache.monthlyBudget"
        case exchangeRates = "cache.exchangeRates"
        case lastSync = "cache.lastSync"
        case userPreferences = "cache.userPreferences"
    }

    private init() {}

    // MARK: - Helper to get UserDefaults
    private func getUserDefaults() -> UserDefaults? {
        return UserDefaults(suiteName: suiteName)
    }

    // MARK: - Balance Cache
    func cacheBalance(_ balance: Double) {
        let defaults = getUserDefaults()

        defaults?.set(balance, forKey: CacheKey.currentBalance.rawValue)
        defaults?.set(Date(), forKey: "\(CacheKey.currentBalance.rawValue).timestamp")
    }

    func getCachedBalance() -> (balance: Double, timestamp: Date)? {
        let defaults = getUserDefaults()

        guard let balance = defaults?.object(forKey: CacheKey.currentBalance.rawValue) as? Double,
              let timestamp = defaults?.object(forKey: "\(CacheKey.currentBalance.rawValue).timestamp") as? Date else {
            return nil
        }
        return (balance, timestamp)
    }

    // MARK: - Transaction Cache
    func cacheTransactions(_ transactions: [TransactionDTO]) {
        // eate local copies for use in async closure
        let key = CacheKey.recentTransactions.rawValue
        _ = "\(key).timestamp"
        let suiteName = self.suiteName

        cacheQueue.async {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(transactions)

                let defaults = UserDefaults(suiteName: suiteName)
                defaults?.set(data, forKey: CacheKey.recentTransactions.rawValue)
                defaults?.set(Date(), forKey: "\(CacheKey.recentTransactions.rawValue).timestamp")
            } catch {
                print("Failed to cache transactions: \(error)")
            }
        }
    }

    func getCachedTransactions() -> [TransactionDTO]? {
        let defaults = getUserDefaults()
        guard let data = defaults?.data(forKey: CacheKey.recentTransactions.rawValue) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode([TransactionDTO].self, from: data)
        } catch {
            print("Failed to decode cached transactions: \(error)")
            return nil
        }
    }

    // MARK: - Exchange Rates Cache (for multi-currency support)
    func cacheExchangeRates(_ rates: [String: Double]) {
        let defaults = getUserDefaults()
        defaults?.set(rates, forKey: CacheKey.exchangeRates.rawValue)
        defaults?.set(Date(), forKey: "\(CacheKey.exchangeRates.rawValue).timestamp")
    }

    func getCachedExchangeRates() -> [String: Double]? {
        let defaults = getUserDefaults()
        guard let rates = defaults?.dictionary(forKey: CacheKey.exchangeRates.rawValue) as? [String: Double],
              let timestamp = defaults?.object(forKey: "\(CacheKey.exchangeRates.rawValue).timestamp") as? Date else {
            return nil
        }

        // Exchange rates are valid for 24 hours
        if Date().timeIntervalSince(timestamp) > 86400 {
            return nil
        }

        return rates
    }

    // MARK: - Cache Validation
    func isCacheValid(for key: String, maxAge: TimeInterval) -> Bool {
        let defaults = getUserDefaults()
        guard let timestamp = defaults?.object(forKey: "\(key).timestamp") as? Date else {
            return false
        }

        return Date().timeIntervalSince(timestamp) < maxAge
    }

    // MARK: - Clear Cache
    func clearCache(olderThan timeInterval: TimeInterval? = nil) {
        let defaults = getUserDefaults()

        if let timeInterval = timeInterval {
            // Clear only old cache
            for key in CacheKey.allCases {
                if let timestamp = defaults?.object(forKey: "\(key.rawValue).timestamp") as? Date,
                   Date().timeIntervalSince(timestamp) > timeInterval {
                    defaults?.removeObject(forKey: key.rawValue)
                    defaults?.removeObject(forKey: "\(key.rawValue).timestamp")
                }
            }
        } else {
            // Clear all cache
            for key in CacheKey.allCases {
                defaults?.removeObject(forKey: key.rawValue)
                defaults?.removeObject(forKey: "\(key.rawValue).timestamp")
            }
        }
    }

    // MARK: - Memory Management
    func handleMemoryWarning() {
        // Clear non-essential cache when memory is low
        clearCache(olderThan: 3600) // Clear cache older than 1 hour
    }

    // MARK: - Sync Status
    func updateLastSyncTime() {
        let defaults = getUserDefaults()
        defaults?.set(Date(), forKey: CacheKey.lastSync.rawValue)
    }

    func getLastSyncTime() -> Date? {
        let defaults = getUserDefaults()
        return defaults?.object(forKey: CacheKey.lastSync.rawValue) as? Date
    }

    // MARK: - Size Management
    func getCacheSize() -> String {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return "Unknown"
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cachesDirectory, includingPropertiesForKeys: [.fileSizeKey])
            let totalSize = contents.reduce(0) { total, url in
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return total + size
            }

            return ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
        } catch {
            return "Unknown"
        }
    }

    // MARK: - Async/Await versions of caching methods
    func cacheTransactionsAsync(_ transactions: [TransactionDTO]) async {
        let key = CacheKey.recentTransactions.rawValue
        let timestampKey = "\(key).timestamp"

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(transactions)

            let defaults = getUserDefaults()
            defaults?.set(data, forKey: key)
            defaults?.set(Date(), forKey: timestampKey)
        } catch {
            print("Failed to cache transactions: \(error)")
        }
    }
}
