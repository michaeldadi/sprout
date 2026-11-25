//
//  Currency.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//


import Foundation
#if canImport(AppIntents)
import AppIntents
#endif

public enum Currency: String, CaseIterable, Codable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case cad = "CAD"
    case aud = "AUD"
    case jpy = "JPY"
    case cny = "CNY"
    case inr = "INR"

    // Display properties
    public var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .cad: return "C$"
        case .aud: return "A$"
        case .jpy: return "¥"
        case .cny: return "¥"
        case .inr: return "₹"
        }
    }

    public var displayName: String {
        switch self {
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .cad: return "Canadian Dollar"
        case .aud: return "Australian Dollar"
        case .jpy: return "Japanese Yen"
        case .cny: return "Chinese Yuan"
        case .inr: return "Indian Rupee"
        }
    }

    public var locale: Locale {
        switch self {
        case .usd: return Locale(identifier: "en_US")
        case .eur: return Locale(identifier: "fr_FR")
        case .gbp: return Locale(identifier: "en_GB")
        case .cad: return Locale(identifier: "en_CA")
        case .aud: return Locale(identifier: "en_AU")
        case .jpy: return Locale(identifier: "ja_JP")
        case .cny: return Locale(identifier: "zh_CN")
        case .inr: return Locale(identifier: "hi_IN")
        }
    }

    // Format amount in this currency
    public func format(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = self.rawValue
        formatter.locale = self.locale
        return formatter.string(from: NSNumber(value: amount)) ?? "\(symbol)\(amount)"
    }
}

// MARK: - App Intents Support
#if canImport(AppIntents)
@available(iOS 16.0, *)
extension Currency: AppEnum {
    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Currency")

    public static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .usd: DisplayRepresentation(title: "US Dollar", subtitle: "USD"),
        .eur: DisplayRepresentation(title: "Euro", subtitle: "EUR"),
        .gbp: DisplayRepresentation(title: "British Pound", subtitle: "GBP"),
        .cad: DisplayRepresentation(title: "Canadian Dollar", subtitle: "CAD"),
        .aud: DisplayRepresentation(title: "Australian Dollar", subtitle: "AUD"),
        .jpy: DisplayRepresentation(title: "Japanese Yen", subtitle: "JPY"),
        .cny: DisplayRepresentation(title: "Chinese Yuan", subtitle: "CNY"),
        .inr: DisplayRepresentation(title: "Indian Rupee", subtitle: "INR")
    ]
}
#endif
