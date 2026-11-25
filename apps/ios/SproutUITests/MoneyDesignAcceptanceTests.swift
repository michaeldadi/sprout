import XCTest

final class MoneyDesignAcceptanceTests: XCTestCase {
    @MainActor func testExpenseEditReview() {
        let app = XCUIApplication(); app.launchArguments = ["-money-design-review"]
        app.launchEnvironment["SPROUT_MONEY_REVIEW_FRAME"] = "activity"; app.launch()
        let transaction = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Juniper Coffee")).firstMatch
        XCTAssertTrue(transaction.waitForExistence(timeout: 10)); transaction.tap()
        let edit = app.buttons["Edit expense"]; XCTAssertTrue(edit.waitForExistence(timeout: 5)); edit.tap()
        let amount = app.textFields["Expense amount in US dollars"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5)); XCTAssertEqual(amount.value as? String, "6.75")
        XCTAssertTrue(app.textFields["Merchant"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Manual-expense-edit-review"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["Cancel"].tap(); XCTAssertTrue(edit.waitForExistence(timeout: 5)); app.terminate()
    }

    @MainActor func testSelectedScreenReview() throws {
        for frame in ["welcome", "connect-bank", "subscriptions-found", "your-plan", "home", "budget", "activity", "subscriptions", "subscription-detail", "insights", "add-expense", "profile"] {
            let app = XCUIApplication(); app.launchArguments = ["-money-design-review"]
            app.launchEnvironment["SPROUT_MONEY_REVIEW_FRAME"] = frame; app.launch()
            XCTAssertTrue(app.staticTexts["FICTIONAL DESIGN REVIEW"].waitForExistence(timeout: 10), frame)
            let marker = try XCTUnwrap([
                "welcome": "Make room for\nwhat matters.",
                "connect-bank": "A clearer picture starts here.",
                "subscriptions-found": "Estimated monthly cost of your selected subscriptions",
                "your-plan": "Your monthly spending target",
                "home": "Remaining budget",
                "budget": "Remaining monthly target",
                "activity": "This month",
                "subscriptions": "Monthly equivalent · confirmed subscriptions",
                "subscription-detail": "Charge history",
                "insights": "Feed",
                "add-expense": "Save to Activity",
                "profile": "Membership",
            ][frame])
            XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", marker)).firstMatch.waitForExistence(timeout: 10), "Missing content for \(frame)")
            if frame == "subscriptions-found" {
                XCTAssertTrue(app.buttons["Track 1 and continue"].exists)
                let candidate = app.switches.firstMatch
                if candidate.exists {
                    candidate.tap(); XCTAssertTrue(app.buttons["Track 0 and continue"].exists)
                    candidate.tap(); XCTAssertTrue(app.buttons["Track 1 and continue"].exists)
                }
            }
            if ["home", "budget", "activity", "insights", "profile"].contains(frame) {
                let tree = XCTAttachment(string: app.debugDescription); tree.name = "navigation-\(frame)"; tree.lifetime = .keepAlways; add(tree)
                for label in ["Home", "Budget", "Activity", "Insights", "Profile"] {
                    XCTAssertTrue(app.buttons[label].exists, "\(frame): \(label)")
                }
            }
            let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "B-\(frame)"; attachment.lifetime = .keepAlways; add(attachment); app.terminate()
        }
    }

    @MainActor func testDarkKeyboardAndLargeText() {
        for frame in ["home", "insights", "add-expense"] {
            let app = XCUIApplication(); app.launchArguments = ["-money-design-review", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launchEnvironment = ["SPROUT_MONEY_REVIEW_FRAME": frame, "SPROUT_MONEY_REVIEW_DARK": "true"]; app.launch()
            XCTAssertTrue(app.staticTexts["FICTIONAL DESIGN REVIEW"].waitForExistence(timeout: 10))
            if frame == "add-expense" {
                let amount = app.textFields["Expense amount in US dollars"]; XCTAssertTrue(amount.waitForExistence(timeout: 5)); if amount.exists {
                    amount.tap(); amount.typeText("12.50"); XCTAssertTrue(app.keyboards.firstMatch.exists)
                }
            }
            if frame == "insights" {
                let chat = app.buttons["Chat"]; XCTAssertTrue(chat.waitForExistence(timeout: 5)); chat.tap()
                let composer = app.descendants(matching: .any).matching(identifier: "money.chat.composer").firstMatch
                XCTAssertTrue(composer.waitForExistence(timeout: 5))
                if composer.exists {
                    composer.tap(); composer.typeText("Review my budget"); XCTAssertTrue(app.keyboards.firstMatch.exists)
                }
            }
            let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "C-dark-large-\(frame)"; attachment.lifetime = .keepAlways; add(attachment); app.terminate()
        }
    }
}
