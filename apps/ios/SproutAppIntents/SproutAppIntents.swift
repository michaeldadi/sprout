//
//  SproutAppIntents.swift
//  SproutAppIntents
//
//  Created by Michael Dadi on 8/22/25.
//

import AppIntents

struct SproutAppIntents: AppIntent {
    static var title: LocalizedStringResource { "SproutAppIntents" }
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "This shortcut is not available in this build.")
    }
}
