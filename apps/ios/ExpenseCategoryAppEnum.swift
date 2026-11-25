//
//  ExpenseCategoryAppEnum.swift
//  Sprout
//
//  Created by Michael Dadi on 8/21/25.
//

import Foundation
import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum ExpenseCategoryAppEnum: String, AppEnum {
    case shopping
    case entertainment
    case bills
    case transportation
    case food

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Expense Category")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .shopping: "Shopping",
        .entertainment: "Entertainment",
        .bills: "Bills",
        .transportation: "Transportation",
        .food: "Food"
    ]
}
