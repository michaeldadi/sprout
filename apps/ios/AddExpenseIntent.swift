//
//  AddExpenseIntent.swift
//  Sprout
//
//  Created by Michael Dadi on 8/21/25.
//

import Foundation
import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct AddExpenseIntent: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    static let intentClassName = "AddExpenseIntentIntent"

    static var title: LocalizedStringResource = "Add Expense Intent"
    static var description = IntentDescription("Add a new expense to your budget")

    @Parameter(title: "Amount")
    var amount: IntentCurrencyAmount?

    @Parameter(title: "Category", default: .other)
    var category: ExpenseCategoryAppEnum?

    @Parameter(title: "Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Add a Sprout Expense") {
            \.$amount
            \.$category
            \.$note
        }
    }

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$amount, \.$category, \.$note)) { amount, category, note in
            DisplayRepresentation(
                title: "Add a Sprout Expense",
                subtitle: "Keep your budget up to date."
            )
        }
        IntentPrediction(parameters: (\.$amount, \.$category)) { amount, category in
            DisplayRepresentation(
                title: "Add an expense to Sprout",
                subtitle: "Keep your budget up to date."
            )
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<ExpenseCategoryAppEnum> {
        // TODO: Place your refactored intent handler code here.
        return .result(value: ExpenseCategoryAppEnum(/* fill in result initializer here */))
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
fileprivate extension IntentDialog {
    static var amountParameterPrompt: Self {
        "How much did you spend?"
    }
    static func categoryParameterDisambiguationIntro(count: Int, category: ExpenseCategoryAppEnum) -> Self {
        "There are \(count) options matching ‘\(category)’."
    }
    static var categoryParameterDisambiguationMore: Self {
        "What category is this expense?"
    }
    static func categoryParameterConfirmation(category: ExpenseCategoryAppEnum) -> Self {
        "Just to confirm, you said ‘\(category)’?"
    }
    static var categoryParameterInvalidCategory: Self {
        "Please choose a valid category"
    }
    static var responseSuccess: Self {
        "I've added your expense to Sprout."
    }
    static var responseFailure: Self {
        "Hmm, something went wrong."
    }
}
