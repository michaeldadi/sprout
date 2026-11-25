import XCTest
import CryptoKit

/// Opt-in staging tests. Credentials are injected into the test runner from a
/// private xctestrun file, never compiled into the application or repository.
final class MoneyLiveAcceptanceTests: XCTestCase {
    @MainActor func testLivePasswordChangeAndAccountIsolation() throws {
        let env=ProcessInfo.processInfo.environment
        guard env["SPROUT_LIVE_TEST_PHASE"]=="password",let email=env["SPROUT_LIVE_TEST_EMAIL"],let password=env["SPROUT_LIVE_TEST_PASSWORD"],let replacement=env["SPROUT_LIVE_SECURITY_NEXT_PASSWORD"],let returnEmail=env["SPROUT_LIVE_RETURN_EMAIL"],let returnPassword=env["SPROUT_LIVE_RETURN_PASSWORD"] else {throw XCTSkip("The account security phase was not requested")}
        continueAfterFailure=false;let app=XCUIApplication();app.launch()
        func set(_ field:XCUIElement,_ text:String) {XCTAssertTrue(field.waitForExistence(timeout:15));field.tap();let old=field.value as? String ?? "";if old != field.placeholderValue && !old.isEmpty {field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:old.count))};field.typeText(text)}
        func signOut() {let tab=app.tabBars.buttons["Profile"];XCTAssertTrue(tab.waitForExistence(timeout:25));tab.tap();let button=app.buttons["Sign out"];XCTAssertTrue(button.waitForExistence(timeout:15));for _ in 0..<60 where !button.isHittable {app.swipeUp()};button.tap();XCTAssertTrue(app.buttons["I already have an account"].waitForExistence(timeout:25))}
        func signIn(_ email:String,_ password:String) {let entry=app.buttons["I already have an account"];XCTAssertTrue(entry.waitForExistence(timeout:15));for _ in 0..<8 where !entry.isHittable {app.swipeUp()};entry.tap();set(app.textFields["Email"],email);set(app.secureTextFields["Password"],password);app.buttons["Sign in"].tap();XCTAssertTrue(app.tabBars.buttons["Activity"].waitForExistence(timeout:35))}
        func search(_ text:String) {app.tabBars.buttons["Activity"].tap();set(app.searchFields["Search your activity"],text);app.typeText("\n")}
        if app.tabBars.buttons["Profile"].waitForExistence(timeout:15) {signOut()}
        signIn(email,password);search("Sprout QA security account only");XCTAssertTrue(app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Sprout QA security account only")).firstMatch.waitForExistence(timeout:25));search("Sprout QA prior-week review");XCTAssertFalse(app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Sprout QA prior-week review")).firstMatch.exists)
        app.tabBars.buttons["Profile"].tap();let edit=app.buttons["money.security.password"];XCTAssertTrue(edit.waitForExistence(timeout:25));for _ in 0..<25 where !edit.isHittable {app.swipeUp()};edit.tap()
        set(app.secureTextFields["Current password"],"Incorrect-QA-password-only");set(app.secureTextFields["New password"],replacement);set(app.secureTextFields["Confirm new password"],replacement)
        let update=app.buttons["Update password"];for _ in 0..<10 where !update.isHittable {app.swipeUp()};update.tap();XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","The change was not confirmed")).firstMatch.waitForExistence(timeout:25))
        let current=app.secureTextFields["Current password"];for _ in 0..<10 where !current.isHittable {app.swipeDown()};set(current,password);for _ in 0..<10 where !update.isHittable {app.swipeUp()};update.tap()
        let success=app.alerts["Password updated"];XCTAssertTrue(success.waitForExistence(timeout:25));let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name="Live-Appwrite-iOS-password-updated";attachment.lifetime = .keepAlways;add(attachment);success.buttons["Done"].tap()
        signOut();signIn(email,replacement);search("Sprout QA security account only");XCTAssertTrue(app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Sprout QA security account only")).firstMatch.waitForExistence(timeout:25))
        signOut();signIn(returnEmail,returnPassword);search("Sprout QA prior-week review");XCTAssertTrue(app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Sprout QA prior-week review")).firstMatch.waitForExistence(timeout:25));search("Sprout QA security account only");XCTAssertFalse(app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Sprout QA security account only")).firstMatch.exists)
    }
    @MainActor func testLiveWeeklyReviewWithoutNotificationOptIn() throws {
        let env=ProcessInfo.processInfo.environment
        guard env["SPROUT_LIVE_TEST_PHASE"] == "weekly", let week=env["SPROUT_LIVE_WEEK"], let spending=env["SPROUT_LIVE_WEEK_SPENDING"], let income=env["SPROUT_LIVE_WEEK_INCOME"] else {throw XCTSkip("The weekly review phase was not requested")}
        continueAfterFailure=false;let app=XCUIApplication();app.launch();let tab=app.tabBars.buttons["Insights"];XCTAssertTrue(tab.waitForExistence(timeout:25));tab.tap();app.buttons["Feed"].tap()
        let request=app.buttons["Review last week"];XCTAssertTrue(request.waitForExistence(timeout:10));request.tap()
        let title=app.staticTexts["Your week of \(week)"];XCTAssertTrue(title.waitForExistence(timeout:60));for _ in 0..<30 where !title.isHittable {app.swipeUp()}
        let detail=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@ AND label CONTAINS %@", "\(spending) net spending", "\(income) income")).firstMatch;XCTAssertTrue(detail.exists)
        let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name="Live-Appwrite-iOS-weekly-review";attachment.lifetime = .keepAlways;add(attachment)
        app.terminate();app.launch();XCTAssertTrue(app.tabBars.buttons["Insights"].waitForExistence(timeout:25));app.tabBars.buttons["Insights"].tap();app.buttons["Feed"].tap();XCTAssertTrue(app.staticTexts["Your week of \(week)"].waitForExistence(timeout:25))
    }
    @MainActor func testLiveReviewedEditConflict() throws {
        let env = ProcessInfo.processInfo.environment, phase = ProcessInfo.processInfo.environment["SPROUT_LIVE_TEST_PHASE"] ?? ""
        guard ["expenseconflict", "goalconflict"].contains(phase), let name = env["SPROUT_LIVE_EDIT_NAME"], let id = env["SPROUT_LIVE_EDIT_ID"] else { throw XCTSkip("The reviewed edit phase was not requested") }
        continueAfterFailure = false
        let expense = phase == "expenseconflict", app = XCUIApplication(); app.launch()
        let destination = app.tabBars.buttons[expense ? "Activity" : "Budget"]; XCTAssertTrue(destination.waitForExistence(timeout: 25)); destination.tap()
        if expense {
            let search = app.searchFields["Search your activity"]; XCTAssertTrue(search.waitForExistence(timeout: 15)); search.tap(); let old = search.value as? String ?? ""; if old != search.placeholderValue { search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count)) }; search.typeText(name); app.typeText("\n")
            let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch; XCTAssertTrue(row.waitForExistence(timeout: 20)); row.tap(); app.buttons["Edit expense"].tap()
        } else {
            let edit = app.buttons["Edit \(name)"]; XCTAssertTrue(edit.waitForExistence(timeout: 20)); for _ in 0..<25 where !edit.isHittable { app.swipeUp() }; edit.tap()
        }
        let amount = app.textFields[expense ? "Expense amount in US dollars" : "Virtual allocation in USD"]; XCTAssertTrue(amount.waitForExistence(timeout: 10)); amount.tap()
        let previous = amount.value as? String ?? ""; amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + "22.22")
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0], done = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("sprout-edit-remote-done")
        try? FileManager.default.removeItem(at: done); try name.write(to: directory.appendingPathComponent("sprout-edit-ready"), atomically: true, encoding: .utf8)
        expectation(for: NSPredicate { _, _ in (try? String(contentsOf: done, encoding: .utf8)) == name }, evaluatedWith: nil); waitForExpectations(timeout: 60)
        app.buttons[expense ? "Save to Activity" : "Save goal"].tap()
        app.terminate(); app.launch()
        let tab = app.tabBars.buttons[expense ? "Profile" : "Budget"]; XCTAssertTrue(tab.waitForExistence(timeout: 25)); tab.tap()
        let review = app.buttons["money.conflict.\(expense ? "transaction" : "goal"):\(id)"]; XCTAssertTrue(review.waitForExistence(timeout: 40)); for _ in 0..<30 where !review.isHittable { app.swipeUp() }; review.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "22.22")).firstMatch.waitForExistence(timeout: 10)); XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "33.33")).firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Live-Appwrite-iOS-\(expense ? "expense" : "goal")-conflict-pair"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons[expense ? "Keep my expense edit" : "Keep my goal edit"].tap()
        expectation(for: NSPredicate { _, _ in !review.exists }, evaluatedWith: nil); waitForExpectations(timeout: 30)
    }
    @MainActor private func notificationPreferences(_ app: XCUIApplication, summary: String) {
        let profile=app.tabBars.buttons["Profile"];XCTAssertTrue(profile.waitForExistence(timeout:25));profile.tap()
        let entry=app.buttons["money.notification.preferences"];for _ in 0..<12 where !entry.isHittable {app.swipeUp()};XCTAssertTrue(entry.waitForExistence(timeout:10))
        expectation(for:NSPredicate { _,_ in entry.value as? String == summary },evaluatedWith:nil);waitForExpectations(timeout:35);entry.tap()
        XCTAssertTrue(app.navigationBars["Notification preferences"].waitForExistence(timeout:10))
    }
    @MainActor func testLiveNotificationPreferences() throws {
        guard ProcessInfo.processInfo.environment["SPROUT_LIVE_TEST_PHASE"] == "preferences" else {throw XCTSkip("The preferences phase was not requested")}
        continueAfterFailure=false;let app=XCUIApplication();app.launch();notificationPreferences(app,summary:"Quiet hours on · America/Anchorage")
        let quiet=app.switches["money.notification.quiet"];for _ in 0..<12 where !quiet.isHittable {app.swipeUp()};XCTAssertEqual(quiet.value as? String,"1");quiet.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:0.5)).tap();XCTAssertEqual(quiet.value as? String,"0")
        let zone=app.buttons["money.notification.timezone"];for _ in 0..<12 where !zone.isHittable {app.swipeUp()};XCTAssertTrue(zone.waitForExistence(timeout:10));zone.tap()
        let choice=app.buttons["America/Los_Angeles"];XCTAssertTrue(choice.waitForExistence(timeout:10));choice.tap();let back=app.navigationBars.buttons["Notification preferences"];if back.exists {back.tap()}
        let save=app.buttons["Save notification preferences"];for _ in 0..<12 where !save.isHittable {app.swipeUp()};save.tap()
        let entry=app.buttons["money.notification.preferences"];XCTAssertTrue(entry.waitForExistence(timeout:15));expectation(for:NSPredicate { _,_ in entry.value as? String == "Quiet hours off · America/Los_Angeles" },evaluatedWith:nil);waitForExpectations(timeout:40)
        app.terminate();app.launch();notificationPreferences(app,summary:"Quiet hours off · America/Los_Angeles");XCTAssertEqual(app.switches["money.notification.quiet"].value as? String,"0")
        let capture=XCTAttachment(screenshot:app.screenshot());capture.name="Live-Appwrite-iOS-notification-preferences";capture.lifetime = .keepAlways;add(capture)
    }
    @MainActor func testLiveNotificationPreferencesRoundtrip() throws {
        guard ProcessInfo.processInfo.environment["SPROUT_LIVE_TEST_PHASE"] == "preferences-roundtrip" else {throw XCTSkip("The preferences roundtrip was not requested")}
        continueAfterFailure=false;let app=XCUIApplication();app.launch();notificationPreferences(app,summary:"Quiet hours on · America/Los_Angeles")
        let quiet=app.switches["money.notification.quiet"];for _ in 0..<12 where !quiet.isHittable {app.swipeUp()};XCTAssertEqual(quiet.value as? String,"1")
        let capture=XCTAttachment(screenshot:app.screenshot());capture.name="Live-Appwrite-iOS-notification-roundtrip";capture.lifetime = .keepAlways;add(capture)
    }
    @MainActor func testLiveReceiptPhotoOptInPreviewAndRemoval() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["SPROUT_LIVE_TEST_PHASE"] == "receipt-retention", let merchant = env["SPROUT_LIVE_RECEIPT_MERCHANT"] else { throw XCTSkip("The receipt retention phase was not requested") }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let activity = app.tabBars.buttons["Activity"]; XCTAssertTrue(activity.waitForExistence(timeout: 25)); activity.tap()
        let search = app.searchFields["Search your activity"]
        func replace(_ field: XCUIElement, _ value: String) { XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap(); let old = field.value as? String ?? ""; if old != field.placeholderValue && !old.isEmpty { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count)) }; field.typeText(value) }
        replace(search, ""); app.typeText("\n"); app.buttons["Add expense"].tap()
        let scan = app.buttons["Scan receipt from photo"]; for _ in 0..<12 where !scan.isHittable { app.swipeUp() }; XCTAssertTrue(scan.waitForExistence(timeout: 10)); scan.tap()
        let photos = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Photo, "))
        let photoDate = Date(timeIntervalSince1970: try XCTUnwrap(Double(env["SPROUT_LIVE_RECEIPT_PHOTO_CREATED_AT"] ?? "")))
        let created = DateFormatter(); created.locale = Locale(identifier: "en_US"); created.dateFormat = "MMMM d"
        let minute = DateFormatter(); minute.locale = Locale(identifier: "en_US"); minute.dateFormat = "h:mm"
        let photo = photos.matching(NSPredicate(format:"label CONTAINS[c] %@ AND label CONTAINS[c] %@",created.string(from: photoDate),minute.string(from:photoDate))).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 15), "The imported synthetic receipt must be selectable: \(photos.allElementsBoundByIndex.map(\.label))")
        // This iOS 18.5 QA runtime exposes the virtualized picker grid as one
        // AX group. Tap its observed first thumbnail on the small simulator;
        // the OCR assertion below verifies the exact fixture was selected.
        XCTAssertEqual(app.frame.width,375); XCTAssertEqual(app.frame.height,667)
        app.coordinate(withNormalizedOffset:CGVector(dx:1.0/6.0,dy:0.56)).tap()
        let keep = app.switches["Keep compressed receipt with this expense"]
        for _ in 0..<12 where !keep.isHittable { app.swipeUp() }; XCTAssertTrue(keep.waitForExistence(timeout: 25)); XCTAssertEqual(keep.value as? String, "0")

        // SwiftUI exposes the whole labeled form row as the switch frame.
        // Hit the trailing control and prove the opted-in value before saving.
        keep.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        expectation(for:NSPredicate { _,_ in keep.value as? String == "1" },evaluatedWith:nil);waitForExpectations(timeout:5)
        let amount = app.textFields["Expense amount in US dollars"]; for _ in 0..<12 where !amount.isHittable { app.swipeDown() }; XCTAssertEqual(NSDecimalNumber(string: amount.value as? String ?? ""), NSDecimalNumber(string: "5.40"), "Receipt pixels must populate the correct total before review"); replace(amount, "5.40"); replace(app.textFields["Merchant"], merchant); app.buttons["Save to Activity"].tap()
        replace(search, merchant); app.typeText("\n")
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", merchant)).firstMatch; XCTAssertTrue(row.waitForExistence(timeout: 15)); row.tap()
        let view = app.buttons["View private receipt"]; for _ in 0..<12 where !view.isHittable { app.swipeUp() }; XCTAssertTrue(view.waitForExistence(timeout: 60)); for _ in 0..<12 where !view.isHittable { app.swipeUp() }; view.tap()
        XCTAssertTrue(app.images["Receipt image. Reviewed transaction details are on the previous screen."].waitForExistence(timeout: 20))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Live-Appwrite-iOS-private-receipt-preview"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Close"].tap(); app.buttons["Remove Sprout receipt copy"].tap(); app.buttons["Remove receipt copy"].tap()
        expectation(for: NSPredicate { _,_ in !app.staticTexts["Private receipt copy"].exists }, evaluatedWith: nil); waitForExpectations(timeout: 60)
        app.terminate(); app.launch(); XCTAssertTrue(activity.waitForExistence(timeout: 25)); activity.tap(); replace(search, merchant); app.typeText("\n"); XCTAssertTrue(row.waitForExistence(timeout: 15)); row.tap(); XCTAssertFalse(app.buttons["View private receipt"].exists)
    }
    @MainActor func testLiveOfflineSaveColdRestoreAndReconnect() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["SPROUT_LIVE_TEST_PHASE"] == "offline", let merchant = env["SPROUT_LIVE_OFFLINE_MERCHANT"] else { throw XCTSkip("The offline phase was not requested") }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-sprout-test-offline"]; app.launch()
        let activity = app.tabBars.buttons["Activity"]; XCTAssertTrue(activity.waitForExistence(timeout: 20)); activity.tap()
        let search = app.searchFields["Search your activity"]
        if search.exists { search.tap(); let value = search.value as? String ?? ""; if !value.isEmpty && value != search.placeholderValue { search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,count:value.count)) }; app.typeText("\n") }
        app.buttons["Add expense"].tap()
        let amount=app.textFields["Expense amount in US dollars"]; XCTAssertTrue(amount.waitForExistence(timeout: 8)); amount.tap(); amount.typeText("1.47")
        app.textFields["Merchant"].tap(); app.textFields["Merchant"].typeText(merchant); app.buttons["Save to Activity"].tap()
        let row=app.buttons.matching(NSPredicate(format:"label CONTAINS %@",merchant)).firstMatch
        func findSaved() { XCTAssertTrue(search.waitForExistence(timeout: 8)); search.tap(); let value=search.value as? String ?? ""; if !value.isEmpty && value != search.placeholderValue { search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,count:value.count)) }; search.typeText(merchant); app.typeText("\n"); XCTAssertTrue(row.waitForExistence(timeout: 15)) }
        findSaved(); app.terminate(); app.launch(); XCTAssertTrue(activity.waitForExistence(timeout: 20)); activity.tap(); findSaved()
        row.tap(); let edit=app.buttons["Edit expense"]; XCTAssertTrue(edit.waitForExistence(timeout: 10)); XCTAssertFalse(edit.isEnabled)
        let offline=XCTAttachment(screenshot:app.screenshot());offline.name="Live-Appwrite-iOS-offline-cold-restore";offline.lifetime = .keepAlways;add(offline)
        app.terminate();app.launchArguments=[];app.launch();XCTAssertTrue(activity.waitForExistence(timeout: 25));activity.tap();findSaved();row.tap();XCTAssertTrue(edit.waitForExistence(timeout: 10))
        expectation(for:NSPredicate { _,_ in edit.isEnabled },evaluatedWith:nil);waitForExpectations(timeout:45)
        let online=XCTAttachment(screenshot:app.screenshot());online.name="Live-Appwrite-iOS-offline-reconnected";online.lifetime = .keepAlways;add(online)
    }
    @MainActor func testLiveCSVReviewImportAndRestoration() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["SPROUT_LIVE_TEST_PHASE"] == "import", let merchant = env["SPROUT_LIVE_IMPORT_MERCHANT"] else { throw XCTSkip("The import phase was not requested") }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let profile = app.tabBars.buttons["Profile"]; XCTAssertTrue(profile.waitForExistence(timeout: 25)); profile.tap()
        let entry = app.buttons["Import transactions"]; for _ in 0 ..< 15 where !entry.isHittable { app.swipeUp() }; XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        app.buttons["Paste CSV text"].tap()
        let field = app.textViews["CSV text"]; XCTAssertTrue(field.waitForExistence(timeout: 8)); field.tap()
        let csv = "date,merchant,amount,type,currency,category,notes\n2026-11-10,\(merchant),-4.20,expense,USD,Other,Reviewed CSV\n2026-11-10,\(merchant),-4.20,expense,USD,Other,Possible duplicate\n2026-11-10,\(merchant) Invalid,4.20,expense,USD,Other,Wrong sign\n"
        let batchId = SHA256.hash(data: Data(csv.utf8)).map { String(format: "%02x", $0) }.joined()
        field.typeText(csv)
        let review = app.buttons["Review pasted CSV"]; for _ in 0 ..< 8 where !review.isHittable { app.swipeUp() }; review.tap()
        XCTAssertTrue(app.staticTexts["1 selected · 3 rows"].waitForExistence(timeout: 10))
        let consent = app.switches["I reviewed the selected records"]; for _ in 0 ..< 15 where !consent.isHittable { app.swipeUp() }; consent.tap()
        app.buttons["Import selected records"].tap()
        let completed = app.staticTexts["money.import.progress.\(batchId)"]
        XCTAssertTrue(completed.waitForExistence(timeout: 50)); expectation(for: NSPredicate { _, _ in completed.label == "1 of 1 processed · 1 added · 0 existing records preserved" }, evaluatedWith: nil); waitForExpectations(timeout: 50); for _ in 0 ..< 10 where !completed.isHittable { app.swipeUp() }
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Live-Appwrite-iOS-CSV-import"; capture.lifetime = .keepAlways; add(capture)
        app.terminate(); app.launch(); let activity = app.tabBars.buttons["Activity"]; XCTAssertTrue(activity.waitForExistence(timeout: 25)); activity.tap()
        let search = app.searchFields["Search your activity"]; XCTAssertTrue(search.waitForExistence(timeout: 8)); search.tap(); search.typeText(merchant); app.typeText("\n")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", merchant)).firstMatch.waitForExistence(timeout: 20))
    }
    @MainActor func testLiveReleaseReviewedExpense() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["SPROUT_LIVE_TEST_PHASE"] == "release-smoke", let email = env["SPROUT_LIVE_TEST_EMAIL"], let password = env["SPROUT_LIVE_TEST_PASSWORD"], let merchant = env["SPROUT_LIVE_RELEASE_MERCHANT"] else { throw XCTSkip("The release phase was not requested") }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let welcome = app.buttons["I already have an account"]
        if welcome.waitForExistence(timeout: 8) {
            for _ in 0 ..< 8 where !welcome.isHittable { app.swipeUp() }; welcome.tap()
            let emailField = app.textFields["Email"]; XCTAssertTrue(emailField.waitForExistence(timeout: 8)); emailField.tap(); emailField.typeText(email)
            app.secureTextFields["Password"].tap(); app.typeText(password); app.buttons["Sign in"].tap()
        }
        let activity = app.tabBars.buttons["Activity"]; XCTAssertTrue(activity.waitForExistence(timeout: 30)); activity.tap()
        let search = app.searchFields["Search your activity"]
        func findSavedExpense() {
            XCTAssertTrue(search.waitForExistence(timeout: 10)); search.tap()
            let value = search.value as? String ?? ""
            if !value.isEmpty && value != search.placeholderValue { search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)) }
            search.typeText(merchant); app.typeText("\n")
        }
        if search.exists { search.tap(); let value = search.value as? String ?? ""; if !value.isEmpty && value != search.placeholderValue { search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)) }; app.typeText("\n") }
        let add = app.buttons["Add expense"]; XCTAssertTrue(add.waitForExistence(timeout: 10)); add.tap()
        let amount = app.textFields["Expense amount in US dollars"]; XCTAssertTrue(amount.waitForExistence(timeout: 8)); amount.tap(); amount.typeText("2.75")
        app.textFields["Merchant"].tap(); app.textFields["Merchant"].typeText(merchant); app.buttons["Save to Activity"].tap()
        // Day-grouped history has no provider time-of-day and can be larger
        // than the viewport. Use the normal search path, not random ID order.
        findSavedExpense()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", merchant)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20)); row.tap()
        let edit = app.buttons["Edit expense"]; XCTAssertTrue(edit.waitForExistence(timeout: 10)); expectation(for: NSPredicate { _, _ in edit.isEnabled }, evaluatedWith: nil); waitForExpectations(timeout: 35)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Live-Appwrite-iOS-release-expense"; capture.lifetime = .keepAlways; self.add(capture)
        app.terminate(); app.launch(); XCTAssertTrue(activity.waitForExistence(timeout: 20)); activity.tap(); findSavedExpense(); XCTAssertTrue(row.waitForExistence(timeout: 20))
    }
    @MainActor func testLiveCompetingBudgetRequiresExplicitReview() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["SPROUT_LIVE_TEST_PHASE"] == "budgetconflict", let category = env["SPROUT_LIVE_BUDGET_CONFLICT_CATEGORY"], let month = env["SPROUT_LIVE_BUDGET_CONFLICT_MONTH"] else { throw XCTSkip("The conflict phase was not requested") }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let budget = app.tabBars.buttons["Budget"]; XCTAssertTrue(budget.waitForExistence(timeout: 25)); budget.tap()
        let edit = app.buttons["Edit your plan"]; for _ in 0 ..< 15 where !edit.isHittable { app.swipeUp() }; edit.tap(); app.buttons["Category budgets"].tap()
        func set(_ field: XCUIElement, _ value: String) {
            XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap()
            let previous = field.value as? String ?? ""
            if previous != field.placeholderValue && !previous.isEmpty { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count)) }
            field.typeText(value)
        }
        set(app.textFields["Category"], category); set(app.textFields["Limit in USD"], "22.22")
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let done = directory.appendingPathComponent("sprout-budget-remote-done"); try? FileManager.default.removeItem(at: done)
        try category.write(to: directory.appendingPathComponent("sprout-budget-ready"), atomically: true, encoding: .utf8)
        expectation(for: NSPredicate { _, _ in (try? String(contentsOf: done, encoding: .utf8)) == category }, evaluatedWith: nil)
        waitForExpectations(timeout: 60)
        app.buttons["Save"].tap()
        let review = app.buttons["Review \(category) budget for \(month)"]
        XCTAssertTrue(review.waitForExistence(timeout: 35)); for _ in 0 ..< 15 where !review.isHittable { app.swipeUp() }; review.tap()
        XCTAssertTrue(app.staticTexts["$22.22"].waitForExistence(timeout: 10)); XCTAssertTrue(app.staticTexts["$33.33"].exists)
        app.buttons["Keep my budget edit"].tap()
        let acknowledged = app.progressIndicators.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", category, "22.22")).firstMatch
        XCTAssertTrue(acknowledged.waitForExistence(timeout: 35)); for _ in 0 ..< 15 where !acknowledged.isHittable { app.swipeDown() }
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Live-Appwrite-iOS-budget-conflict"; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor func testLiveCurrentAndHistoricalBudgetEdits() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["SPROUT_LIVE_TEST_PHASE"] == "budgets", let category = env["SPROUT_LIVE_BUDGET_CATEGORY"], let prior = env["SPROUT_LIVE_BUDGET_PRIOR_MONTH"] else { throw XCTSkip("The budgets phase was not requested") }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let budget = app.tabBars.buttons["Budget"]; XCTAssertTrue(budget.waitForExistence(timeout: 25)); budget.tap()
        func set(_ field: XCUIElement, _ value: String) {
            XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap()
            let existing = field.value as? String ?? ""
            if existing != field.placeholderValue && !existing.isEmpty { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count)) }
            field.typeText(value)
        }
        let edit = app.buttons["Edit your plan"]
        for _ in 0 ..< 8 where !edit.isHittable { app.swipeUp() }; edit.tap()
        app.buttons["Category budgets"].tap()
        set(app.textFields["Category"], category); set(app.textFields["Limit in USD"], "22.22")
        app.buttons["Save"].tap()
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", category)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        for _ in 0 ..< 8 where !app.buttons["money.budget.period"].isHittable { app.swipeDown() }
        app.buttons["money.budget.period"].tap(); XCTAssertTrue(app.buttons[prior].waitForExistence(timeout: 10)); app.buttons[prior].tap()
        let history = app.buttons["Edit category budgets"]; for _ in 0 ..< 8 where !history.isHittable { app.swipeUp() }; history.tap()
        app.buttons["Choose a saved category"].tap()
        let savedCategory = app.buttons[category + " Prior"]
        XCTAssertTrue(savedCategory.waitForExistence(timeout: 10)); savedCategory.tap()
        XCTAssertEqual(app.textFields["Category"].value as? String, category + " Prior")
        XCTAssertEqual(app.textFields["Limit in USD"].value as? String, "11.11")
        set(app.textFields["Limit in USD"], "33.33"); app.buttons["Save"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "33.33")).firstMatch.waitForExistence(timeout: 30))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Live-Appwrite-iOS-historical-budget"; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor func testLiveDeletionRevokesAccessAndRestoresProgress() throws {
        guard ProcessInfo.processInfo.environment["SPROUT_LIVE_TEST_PHASE"] == "deletion", let email = ProcessInfo.processInfo.environment["SPROUT_LIVE_TEST_EMAIL"], let password = ProcessInfo.processInfo.environment["SPROUT_LIVE_TEST_PASSWORD"], let merchant = ProcessInfo.processInfo.environment["SPROUT_LIVE_PRIVACY_MERCHANT"] else { throw XCTSkip("The dedicated erasure phase was not requested") }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let profile = app.tabBars.buttons["Profile"]
        if profile.waitForExistence(timeout: 10) { profile.tap(); let signOut = app.buttons["Sign out"]; for _ in 0 ..< 8 where !signOut.isHittable { app.swipeUp() }; signOut.tap() }
        let welcome = app.buttons["I already have an account"]; XCTAssertTrue(welcome.waitForExistence(timeout: 15)); for _ in 0 ..< 8 where !welcome.isHittable { app.swipeUp() }; welcome.tap()
        let field = app.textFields["Email"]; XCTAssertTrue(field.waitForExistence(timeout: 8)); field.tap(); let existing = field.value as? String ?? ""; if existing != "Email" && !existing.isEmpty { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count)) }; field.typeText(email); XCTAssertTrue(field.value as? String == email, "Email input must match the supplied test identity."); let secret = app.secureTextFields["Password"]; secret.tap(); app.typeText(password); let enteredSecret = secret.value as? String ?? ""; XCTAssertFalse(enteredSecret.isEmpty || enteredSecret == "Password", "The secure field must contain input."); app.buttons["Sign in"].tap()
        let activity = app.tabBars.buttons["Activity"]; XCTAssertTrue(activity.waitForExistence(timeout: 25)); activity.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", merchant)).firstMatch.waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Android Live Lunch")).firstMatch.exists)
        profile.tap(); let deletion = app.buttons["Delete my account"]; for _ in 0 ..< 8 where !deletion.isHittable { app.swipeUp() }; deletion.tap()
        app.buttons["Request account deletion"].tap(); app.buttons["Confirm"].tap()
        XCTAssertTrue(app.staticTexts["Active financial data removed"].waitForExistence(timeout: 150))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Live-Appwrite-iOS-active-data-erasure"; attachment.lifetime = .keepAlways; add(attachment)
        app.terminate(); app.launch(); XCTAssertTrue(app.staticTexts["Active financial data removed"].waitForExistence(timeout: 30))
        let finish = app.buttons["Return to welcome"]; for _ in 0 ..< 8 where !finish.isHittable { app.swipeUp() }; finish.tap(); XCTAssertTrue(app.buttons["I already have an account"].waitForExistence(timeout: 15))
    }
    @MainActor func testLiveRemoteChangeAppearsWithoutRefresh() throws {
        guard ProcessInfo.processInfo.environment["SPROUT_LIVE_TEST_PHASE"] == "realtime", let merchant = ProcessInfo.processInfo.environment["SPROUT_LIVE_REALTIME_MERCHANT"], let email = ProcessInfo.processInfo.environment["SPROUT_LIVE_TEST_EMAIL"], let password = ProcessInfo.processInfo.environment["SPROUT_LIVE_TEST_PASSWORD"] else { throw XCTSkip("The realtime phase was not requested") }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let welcome = app.buttons["I already have an account"]
        if welcome.waitForExistence(timeout: 8) {
            for _ in 0 ..< 8 where !welcome.isHittable { app.swipeUp() }; welcome.tap()
            let emailField = app.textFields["Email"]; XCTAssertTrue(emailField.waitForExistence(timeout: 8)); emailField.tap(); emailField.typeText(email)
            let passwordField = app.secureTextFields["Password"]; passwordField.tap(); app.typeText(password); app.buttons["Sign in"].tap()
        }
        let activity = app.tabBars.buttons["Activity"]; XCTAssertTrue(activity.waitForExistence(timeout: 25)); activity.tap()
        let search = app.searchFields["Search your activity"]
        XCTAssertTrue(search.waitForExistence(timeout: 10)); search.tap(); search.typeText(merchant)
        let submit = app.keyboards.buttons["Search"]
        if submit.exists { submit.tap() } else { app.typeText("\n") }
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", merchant)).firstMatch
        XCTAssertFalse(row.exists)
        let syncing = app.progressIndicators["Syncing"]
        if syncing.exists { expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: syncing); waitForExpectations(timeout: 30) }
        let ready = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("sprout-realtime-ready")
        try merchant.write(to: ready, atomically: true, encoding: .utf8)
        // The host waits for this test-owned marker. No app gesture follows.
        XCTAssertTrue(row.waitForExistence(timeout: 100))
        XCTAssertTrue(row.isHittable)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Live-Appwrite-iOS-realtime"; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor func testLiveGoalAllocationAndAcknowledgment() throws {
        guard ProcessInfo.processInfo.environment["SPROUT_LIVE_TEST_PHASE"] == "goals", let name = ProcessInfo.processInfo.environment["SPROUT_LIVE_GOAL_NAME"] else { throw XCTSkip("The goals phase was not requested") }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let budget = app.tabBars.buttons["Budget"]; XCTAssertTrue(budget.waitForExistence(timeout: 20)); budget.tap()
        let addGoal = app.buttons["Add goal"]; XCTAssertTrue(addGoal.waitForExistence(timeout: 10)); for _ in 0 ..< 8 where !addGoal.isHittable { app.swipeUp() }; addGoal.tap()
        let field = app.textFields["Goal name"]; XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap(); field.typeText(name)
        let target = app.textFields["Goal target in USD"]; target.tap(); target.typeText("500")
        let allocation = app.textFields["Virtual allocation in USD"]; allocation.tap(); allocation.typeText(XCUIKeyboardKey.delete.rawValue + "100")
        app.buttons["Save goal"].tap()
        let edit = app.buttons["Edit \(name)"]; XCTAssertTrue(edit.waitForExistence(timeout: 15))
        expectation(for: NSPredicate { _, _ in edit.isEnabled }, evaluatedWith: nil); waitForExpectations(timeout: 30)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Live-Appwrite-iOS-goal-allocation"; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testLiveGoalEditedOnAndroid() throws {
        guard ProcessInfo.processInfo.environment["SPROUT_LIVE_TEST_PHASE"] == "goalroundtrip", let name = ProcessInfo.processInfo.environment["SPROUT_LIVE_GOAL_NAME"] else { throw XCTSkip("The goal roundtrip phase was not requested") }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let budget = app.tabBars.buttons["Budget"]; XCTAssertTrue(budget.waitForExistence(timeout: 20)); budget.tap()
        let edit = app.buttons["Edit \(name)"]; XCTAssertTrue(edit.waitForExistence(timeout: 25)); for _ in 0 ..< 8 where !edit.isHittable {app.swipeUp()}; edit.tap()
        XCTAssertTrue(app.textFields["Virtual allocation in USD"].waitForExistence(timeout: 8)); XCTAssertEqual(app.textFields["Virtual allocation in USD"].value as? String, "150")
        app.buttons["Cancel"].tap()
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Live-Appwrite-iOS-goal-cross-platform"; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testLiveExportAutomaticallyBecomesDownloadable() throws {
        guard ProcessInfo.processInfo.environment["SPROUT_LIVE_TEST_PHASE"] == "export" else { throw XCTSkip("The export phase was not requested") }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let profile = app.tabBars.buttons["Profile"]; XCTAssertTrue(profile.waitForExistence(timeout: 20)); profile.tap()
        let link = app.buttons["Export my data"]; XCTAssertTrue(link.waitForExistence(timeout: 10))
        for _ in 0 ..< 5 where !link.isHittable { app.swipeUp() }; link.tap()
        let download = app.buttons["Download private export"]
        if !download.waitForExistence(timeout: 3) {
            let request = app.buttons["Request export"]; XCTAssertTrue(request.waitForExistence(timeout: 10)); request.tap(); app.buttons["Confirm"].tap()
        }
        XCTAssertTrue(download.waitForExistence(timeout: 60)); download.tap()
        XCTAssertTrue(app.buttons["Save or share export"].waitForExistence(timeout: 30))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Live-Appwrite-iOS-private-export"; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testLiveShortcutOpensReviewAndSaves() throws {
        guard ProcessInfo.processInfo.environment["SPROUT_LIVE_TEST_PHASE"] == "shortcut", let merchant = ProcessInfo.processInfo.environment["SPROUT_LIVE_SHORTCUT_MERCHANT"] else { throw XCTSkip("The shortcut phase was not requested") }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Activity"].waitForExistence(timeout: 20))
        var url = URLComponents(); url.scheme = "sprout"; url.host = "expense"
        url.queryItems = [URLQueryItem(name: "amount", value: "2.34"), URLQueryItem(name: "currency", value: "USD"), URLQueryItem(name: "merchant", value: merchant), URLQueryItem(name: "category", value: "Food"), URLQueryItem(name: "date", value: "2026-11-09"), URLQueryItem(name: "notes", value: "Reviewed shortcut")]
        app.open(try XCTUnwrap(url.url))
        let amount = app.textFields["Expense amount in US dollars"]; XCTAssertTrue(amount.waitForExistence(timeout: 20)); XCTAssertEqual(amount.value as? String, "2.34")
        XCTAssertEqual(app.textFields["Merchant"].value as? String, merchant)
        app.buttons["Save to Activity"].tap()
        app.tabBars.buttons["Activity"].tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", merchant)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15)); row.tap()
        let edit = app.buttons["Edit expense"]; XCTAssertTrue(edit.waitForExistence(timeout: 8))
        expectation(for: NSPredicate { _, _ in edit.isEnabled }, evaluatedWith: nil); waitForExpectations(timeout: 30)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Live-Appwrite-iOS-shortcut-reviewed"; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testLiveCrossPlatformEditAndDelete() throws {
        guard ProcessInfo.processInfo.environment["SPROUT_LIVE_TEST_PHASE"] == "roundtrip", let merchant = ProcessInfo.processInfo.environment["SPROUT_LIVE_ANDROID_MERCHANT"], !merchant.isEmpty else { throw XCTSkip("The cross-platform phase was not requested") }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let activity = app.tabBars.buttons["Activity"]; XCTAssertTrue(activity.waitForExistence(timeout: 20)); activity.tap()
        let transaction = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", merchant)).firstMatch
        XCTAssertTrue(transaction.waitForExistence(timeout: 25)); transaction.tap()
        let edit = app.buttons["Edit expense"]; XCTAssertTrue(edit.waitForExistence(timeout: 8)); edit.tap()
        let amount = app.textFields["Expense amount in US dollars"]; XCTAssertTrue(amount.waitForExistence(timeout: 8)); amount.tap()
        let old = amount.value as? String ?? ""; amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + "5.67")
        app.buttons["Save to Activity"].tap()
        expectation(for: NSPredicate { _, _ in edit.exists && edit.isEnabled }, evaluatedWith: nil); waitForExpectations(timeout: 30)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let own = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "iOS Live Coffee")).firstMatch
        XCTAssertTrue(own.waitForExistence(timeout: 10)); own.tap()
        let delete = app.buttons["Delete transaction"]; XCTAssertTrue(delete.waitForExistence(timeout: 8)); delete.tap()
        app.buttons["Delete"].tap()
        expectation(for: NSPredicate { _, _ in !own.exists }, evaluatedWith: nil); waitForExpectations(timeout: 30)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Live-Appwrite-cross-platform-edit-delete"; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testLiveOnboardingExpenseAndRestoration() throws {
        continueAfterFailure = false
        guard let email = ProcessInfo.processInfo.environment["SPROUT_LIVE_TEST_EMAIL"], let password = ProcessInfo.processInfo.environment["SPROUT_LIVE_TEST_PASSWORD"] else { throw XCTSkip("Live staging credentials were not supplied") }
        let app = XCUIApplication(); app.launch()
        let welcome = app.buttons["I already have an account"]
        if welcome.waitForExistence(timeout: 8) {
            while !welcome.isHittable { app.swipeUp() }
            welcome.tap()
            let emailField = app.textFields["Email"]; XCTAssertTrue(emailField.waitForExistence(timeout: 5)); emailField.tap(); emailField.typeText(email)
            let passwordField = app.secureTextFields["Password"]; passwordField.tap(); passwordField.typeText(password)
            app.buttons["Sign in"].tap()
        }
        let skip = app.buttons["Skip for now"]
        if skip.waitForExistence(timeout: 15) {
            skip.tap()
        }
        let track = app.buttons["Track 0 and continue"]
        if track.waitForExistence(timeout: 8) { track.tap() }
        let target = app.textFields["Enter your target in USD"]
        if target.waitForExistence(timeout: 8) {
            target.tap(); target.typeText("1500")
            app.swipeUp(); app.buttons["Save my plan"].tap()
        }
        let activity = app.tabBars.buttons["Activity"]
        XCTAssertTrue(activity.waitForExistence(timeout: 30)); activity.tap()
        let addExpense = app.buttons["Add expense"]; XCTAssertTrue(addExpense.waitForExistence(timeout: 8)); addExpense.tap()
        let amount = app.textFields["Expense amount in US dollars"]; XCTAssertTrue(amount.waitForExistence(timeout: 8)); amount.tap(); amount.typeText("12.34")
        let merchant = app.textFields["Merchant"]; merchant.tap(); merchant.typeText("iOS Live Coffee")
        app.buttons["Save to Activity"].tap()
        let transaction = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "iOS Live Coffee")).firstMatch
        XCTAssertTrue(transaction.waitForExistence(timeout: 15)); transaction.tap()
        let edit = app.buttons["Edit expense"]; XCTAssertTrue(edit.waitForExistence(timeout: 8))
        let acknowledged = NSPredicate { _, _ in edit.isEnabled }
        expectation(for: acknowledged, evaluatedWith: nil); waitForExpectations(timeout: 30)
        XCTAssertFalse(app.staticTexts["Pending sync"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Live-Appwrite-iOS-acknowledged-expense"; attachment.lifetime = .keepAlways; add(attachment)
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Activity"].waitForExistence(timeout: 15)); app.tabBars.buttons["Activity"].tap()
        XCTAssertTrue(transaction.waitForExistence(timeout: 15))
    }
}
