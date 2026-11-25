//
//  ExpenseCategoryAppEnum.swift
//  Sprout
//
//  Created by Michael Dadi on 8/21/25.
//


import Foundation
#if canImport(AppIntents)
import AppIntents
#endif

public enum ExpenseCategory: String, CaseIterable, Codable {
    case shopping
    case entertainment
    case bills
    case transportation
    case food
    case other

    // Display name for UI
    public var displayName: String {
        switch self {
        case .shopping: return "Shopping"
        case .entertainment: return "Entertainment"
        case .bills: return "Bills"
        case .transportation: return "Transportation"
        case .food: return "Food"
        case .other: return "Other"
        }
    }

    // Icon for UI
    public var iconName: String {
        switch self {
        case .shopping: return "cart"
        case .entertainment: return "tv"
        case .bills: return "doc.text"
        case .transportation: return "car"
        case .food: return "fork.knife"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - App Intents Support
#if canImport(AppIntents)
@available(iOS 16.0, *)
extension ExpenseCategory: AppEnum {
    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Expense Category")

    public static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .shopping: "Shopping",
        .entertainment: "Entertainment",
        .bills: "Bills",
        .transportation: "Transportation",
        .food: "Food",
        .other: "Other"
    ]
}
#endif
