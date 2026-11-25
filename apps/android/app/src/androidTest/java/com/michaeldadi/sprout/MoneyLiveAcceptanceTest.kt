package com.michaeldadi.sprout

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Opt-in staging credentials are supplied as instrumentation arguments. */
@RunWith(AndroidJUnit4::class)
class MoneyLiveAcceptanceTest {
    @Test fun livePasswordChangeAndAccountIsolation() {
        val args=InstrumentationRegistry.getArguments();val email=args.getString("sproutEmail")!!;val password=args.getString("sproutPassword")!!;val replacement=args.getString("sproutNextPassword")!!;val returnEmail=args.getString("sproutReturnEmail")!!;val returnPassword=args.getString("sproutReturnPassword")!!
        fun signOut() {compose.waitUntil(30000){compose.onAllNodesWithContentDescription("Profile").fetchSemanticsNodes().isNotEmpty()};compose.onNodeWithContentDescription("Profile").performClick();waitText("Sign out");compose.onNodeWithText("Sign out").performScrollTo().performClick();waitText("I already have an account")}
        fun signIn(email:String,password:String) {waitText("I already have an account");compose.onNodeWithText("I already have an account").performScrollTo().performClick();compose.onNodeWithText("Email").performTextReplacement(email);compose.onNodeWithText("Password").performTextReplacement(password);compose.onNodeWithText("Sign in",useUnmergedTree=true).performScrollTo().performClick();compose.waitUntil(35000){compose.onAllNodesWithContentDescription("Activity").fetchSemanticsNodes().isNotEmpty()}}
        fun search(text:String) {openActivity();compose.onNodeWithText("All").performClick();compose.onNodeWithText("Search your activity").performTextReplacement(text)}
        compose.waitUntil(30000){compose.onAllNodesWithContentDescription("Profile").fetchSemanticsNodes().isNotEmpty() || compose.onAllNodesWithText("I already have an account").fetchSemanticsNodes().isNotEmpty()}
        if(compose.onAllNodesWithContentDescription("Profile").fetchSemanticsNodes().isNotEmpty()) signOut()
        signIn(email,password);search("Sprout QA security account only");waitText("Sprout QA security account only");compose.onNode(hasText("Sprout QA security account only") and !hasSetTextAction()).assertExists();search("Sprout QA prior-week review");compose.onNode(hasText("Sprout QA prior-week review") and !hasSetTextAction()).assertDoesNotExist()
        compose.onNodeWithContentDescription("Profile").performClick();waitText("Change password");compose.onNodeWithText("Change password").performScrollTo().performClick();waitText("Current password")
        compose.onNodeWithText("Current password").performScrollTo().performTextReplacement("Incorrect-QA-password-only");compose.onNodeWithText("New password").performScrollTo().performTextReplacement(replacement);compose.onNodeWithText("Confirm new password").performScrollTo().performTextReplacement(replacement);compose.onNodeWithText("Update password").performScrollTo().performClick();waitText("The change was not confirmed. Check your current password and your account's password requirements, then retry.")
        compose.onNodeWithText("Current password").performScrollTo().performTextReplacement(password);compose.onNodeWithText("Update password").performScrollTo().performClick();waitText("Password updated");capture("live-appwrite-password-updated.png");compose.onNodeWithText("Done").performScrollTo().performClick()
        signOut();signIn(email,replacement);search("Sprout QA security account only");compose.onNode(hasText("Sprout QA security account only") and !hasSetTextAction()).assertExists()
        signOut();signIn(returnEmail,returnPassword);search("Sprout QA prior-week review");compose.waitUntil(30000){compose.onAllNodes(hasText("Sprout QA prior-week review") and !hasSetTextAction()).fetchSemanticsNodes().isNotEmpty()};search("Sprout QA security account only");compose.onNode(hasText("Sprout QA security account only") and !hasSetTextAction()).assertDoesNotExist()
    }
    @Test fun liveWeeklyReviewWithoutNotificationOptIn() {
        val args=InstrumentationRegistry.getArguments();val week=args.getString("sproutWeek")!!;val spending=args.getString("sproutWeekSpending")!!;val income=args.getString("sproutWeekIncome")!!
        compose.waitUntil(30000){compose.onAllNodesWithContentDescription("Insights").fetchSemanticsNodes().isNotEmpty()};compose.onNodeWithContentDescription("Insights").performClick();compose.onNodeWithText("Feed").performClick()
        waitText("Review last week");compose.onNodeWithText("Review last week").performScrollTo().performClick()
        compose.waitUntil(60000){compose.onAllNodesWithText("Your week of $week").fetchSemanticsNodes().isNotEmpty()};compose.onNodeWithText("Your week of $week").performScrollTo().assertExists()
        compose.onNode(hasText("$spending net spending",substring=true) and hasText("$income income",substring=true)).assertExists();capture("live-appwrite-weekly-review.png")
        scenario.recreate();waitText("Insights");compose.onNodeWithText("Feed").performClick();waitText("Your week of $week");compose.onNodeWithText("Your week of $week").performScrollTo().assertExists()
    }
    @Test fun liveReviewedEditConflict() {
        val args = InstrumentationRegistry.getArguments(); val kind = args.getString("sproutEditKind")!!; val name = args.getString("sproutEditName")!!; val id = args.getString("sproutEditId")!!
        val expense = kind == "expense"
        compose.waitUntil(30000) { compose.onAllNodesWithContentDescription(if (expense) "Activity" else "Budget").fetchSemanticsNodes().isNotEmpty() }
        if (expense) {
            openActivity(); compose.onNodeWithText("Search your activity").performTextReplacement(name)
            compose.onNode(hasText(name) and !hasSetTextAction()).performClick(); compose.onNodeWithText("Edit expense").performScrollTo().performClick()
        } else {
            compose.onNodeWithContentDescription("Budget").performClick(); waitText("Edit $name"); compose.onNodeWithText("Edit $name").performScrollTo().performClick()
        }
        compose.onNodeWithText(if (expense) "Amount in USD" else "Virtual allocation in USD").performScrollTo().performTextReplacement("22.22")
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val directory = context.getExternalFilesDir(null)!!; val done = java.io.File(directory, "sprout-edit-remote-done")
        done.delete(); java.io.File(directory, "sprout-edit-ready").writeText(name)
        compose.waitUntil(60000) { done.isFile && done.readText() == name }
        if (expense) compose.onNodeWithText("Save to Activity").performScrollTo().performClick() else compose.onNodeWithText("Save goal").performClick()
        scenario.recreate()
        if (expense) { waitText("Transaction"); compose.onNodeWithContentDescription("Back").performClick() }
        compose.waitUntil(30000) { compose.onAllNodesWithContentDescription(if (expense) "Profile" else "Budget").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithContentDescription(if (expense) "Profile" else "Budget").performClick()
        val tag = "money.conflict.${if (expense) "transaction" else "goal"}:$id"
        compose.waitUntil(40000) { compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag(tag).performScrollTo().performClick()
        compose.onNode(hasText("22.22", substring = true) and hasAnyAncestor(isDialog())).assertExists(); compose.onNode(hasText("33.33", substring = true) and hasAnyAncestor(isDialog())).assertExists()
        capture("live-appwrite-$kind-conflict-pair.png")
        compose.onNodeWithText("Keep my $kind edit").performClick()
        compose.waitUntil(30000) { compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isEmpty() }
    }
    @Test fun liveNotificationPreferencesCrossPlatform() {
        compose.waitUntil(30000) { compose.onAllNodesWithContentDescription("Profile").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithContentDescription("Profile").performClick()
        compose.onNodeWithText("Quiet hours off · America/Los_Angeles").performScrollTo().assertExists()
        compose.onNodeWithText("Notification preferences").performScrollTo().performClick()
        waitText("Timezone: America/Los_Angeles")
        compose.onNodeWithContentDescription("Quiet hours").performScrollTo().assertIsOff().performClick().assertIsOn()
        fun setTime(tag: String,hour:String,minute:String) {
            compose.onNodeWithTag(tag).performScrollTo().performClick()
            compose.onAllNodes(hasSetTextAction()).assertCountEquals(2)
            compose.onAllNodes(hasSetTextAction())[0].performTextReplacement(hour)
            compose.onAllNodes(hasSetTextAction())[1].performTextReplacement(minute)
            compose.onNodeWithText("Use time").performClick()
        }
        setTime("money.notification.start","20","30");setTime("money.notification.end","07","30")
        compose.onNodeWithText("Quiet hours start: 20:30").assertExists();compose.onNodeWithText("Quiet hours end: 07:30").assertExists()
        compose.onNodeWithText("Save notification preferences").performScrollTo().performClick()
        compose.waitUntil(30000) { compose.onAllNodesWithText("Save notification preferences").fetchSemanticsNodes().isEmpty() }
        compose.onNodeWithText("Quiet hours on · America/Los_Angeles").performScrollTo().assertExists()
        scenario.recreate();waitText("Profile & security");compose.onNodeWithText("Notification preferences").performScrollTo().performClick()
        waitText("Quiet hours start: 20:30");compose.onNodeWithText("Quiet hours end: 07:30").assertExists();compose.onNodeWithText("Timezone: America/Los_Angeles").assertExists()
        capture("live-appwrite-notification-preferences.png")
    }
    @Test fun liveReceiptPhotoOptInPreviewAndRemoval() {
        val args = InstrumentationRegistry.getArguments(); val merchant = args.getString("sproutMerchant")!!
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val bitmap = android.graphics.Bitmap.createBitmap(1200, 700, android.graphics.Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap); canvas.drawColor(android.graphics.Color.WHITE)
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.BLACK; textSize = 48f }
        listOf("SPROUT SYNTHETIC CAFE", "11/10/2026", "TOTAL USD 5.40").forEachIndexed { index, line -> canvas.drawText(line, 60f, 100f + index * 120, paint) }
        val values = android.content.ContentValues().apply { put(android.provider.MediaStore.Images.Media.DISPLAY_NAME, "sprout-synthetic-receipt-${System.currentTimeMillis()}.jpg"); put(android.provider.MediaStore.Images.Media.MIME_TYPE, "image/jpeg"); put(android.provider.MediaStore.Images.Media.RELATIVE_PATH, "Pictures/SproutAcceptance") }
        val uri = context.contentResolver.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)!!
        try {
            context.contentResolver.openOutputStream(uri)!!.use { bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 80, it) }
            compose.waitUntil(30000) { compose.onAllNodesWithContentDescription("Activity").fetchSemanticsNodes().isNotEmpty() }
            openActivity(); compose.onNodeWithText("Search your activity").performTextReplacement(""); compose.onNodeWithContentDescription("Add expense").performClick()
            compose.onNodeWithText("Scan receipt from photo").performScrollTo().performClick()
            val device = androidx.test.uiautomator.UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
            val photo = device.wait(androidx.test.uiautomator.Until.findObject(androidx.test.uiautomator.By.descContains("Photo taken")), 15000)
                ?: device.wait(androidx.test.uiautomator.Until.findObject(androidx.test.uiautomator.By.res("com.google.android.providers.media.module", "icon_thumbnail")), 10000)
            org.junit.Assert.assertNotNull("The system photo picker must expose the synthetic image", photo); photo!!.click()
            device.wait(androidx.test.uiautomator.Until.findObject(androidx.test.uiautomator.By.text("Done")),5000)?.click()
            waitText("Keep compressed receipt with this expense")
            org.junit.Assert.assertTrue("The selected photo must produce the synthetic receipt text",compose.onAllNodesWithText("SPROUT SYNTHETIC CAFE",substring=true).fetchSemanticsNodes().isNotEmpty())
            val keep = compose.onNode(hasAnySibling(hasText("Keep compressed receipt with this expense")) and isToggleable())
            keep.performScrollTo().assertIsOff().performClick().assertIsOn()
            compose.onNodeWithText("Amount in USD").performScrollTo().performTextReplacement("5.40")
            compose.onNodeWithText("Merchant").performScrollTo().performTextReplacement(merchant)
            compose.onNodeWithText("Save to Activity").performScrollTo().performClick()
            compose.onNodeWithText("Search your activity").performTextReplacement(merchant)
            val saved = hasText(merchant) and !hasSetTextAction()
            compose.waitUntil(20000) { compose.onAllNodes(saved).fetchSemanticsNodes().isNotEmpty() }; compose.onNode(saved).performClick()
            compose.waitUntil(60000) { compose.onAllNodesWithText("View private receipt").fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithText("View private receipt").performScrollTo().performClick()
            compose.waitUntil(20000) { compose.onAllNodesWithContentDescription("Receipt image. Reviewed transaction details are on the previous screen.").fetchSemanticsNodes().isNotEmpty() }
            capture("live-appwrite-private-receipt-preview.png"); compose.onNodeWithText("Close").performScrollTo().performClick()
            compose.onNodeWithText("Remove Sprout receipt copy").performScrollTo().performClick(); compose.onNodeWithText("Remove receipt copy").performClick()
            compose.waitUntil(60000) { compose.onAllNodesWithText("Private receipt copy").fetchSemanticsNodes().isEmpty() }
            scenario.recreate(); compose.waitUntil(25000) { compose.onAllNodesWithText(merchant).fetchSemanticsNodes().isNotEmpty() }
            compose.onAllNodesWithText("View private receipt").assertCountEquals(0)
        } finally { bitmap.recycle(); context.contentResolver.delete(uri, null, null) }
    }
    @Test fun liveCsvReviewImportAndRestoration() {
        val args = InstrumentationRegistry.getArguments(); val merchant = args.getString("sproutMerchant")!!
        compose.waitUntil(30000) { compose.onAllNodesWithContentDescription("Profile").fetchSemanticsNodes().isNotEmpty() || compose.onAllNodesWithText("I already have an account").fetchSemanticsNodes().isNotEmpty() }
        if (compose.onAllNodesWithText("I already have an account").fetchSemanticsNodes().isNotEmpty()) {
            compose.onNodeWithText("I already have an account").performScrollTo().performClick(); waitText("Email")
            compose.onNodeWithText("Email").performTextInput(args.getString("sproutEmail")!!); compose.onNodeWithText("Password").performTextInput(args.getString("sproutPassword")!!); compose.onNodeWithText("Sign in").performClick()
        }
        compose.waitUntil(30000) { compose.onAllNodesWithContentDescription("Profile").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithContentDescription("Profile").performClick(); compose.onNodeWithText("Import transactions").performScrollTo().performClick()
        waitText("Paste CSV text"); compose.onNodeWithText("Paste CSV text").performClick()
        val csv = "date,merchant,amount,type,currency,category,notes\n2026-11-10,$merchant,-4.20,expense,USD,Other,Reviewed CSV\n2026-11-10,$merchant,-4.20,expense,USD,Other,Possible duplicate\n2026-11-10,$merchant Invalid,4.20,expense,USD,Other,Wrong sign\n"
        val progressTag = "money.import.progress." + com.michaeldadi.sprout.money.MoneyCSVImport.parse(csv.toByteArray()).batchId
        compose.onNodeWithText("CSV text").performScrollTo().performTextInput(csv)
        compose.onNodeWithText("Review pasted CSV").performScrollTo().performClick(); waitText("1 selected · 3 rows")
        val list = compose.onNodeWithTag("money.import.list")
        list.performScrollToNode(hasText("I reviewed the selected records"))
        compose.onNode(hasAnySibling(hasText("I reviewed the selected records")) and isToggleable()).performClick()
        list.performScrollToNode(hasText("Import selected records")); compose.onNodeWithText("Import selected records").performClick()
        compose.waitUntil(60000) { compose.onAllNodesWithText("Saved for import").fetchSemanticsNodes().isNotEmpty() }
        for (attempt in 0 until 15) {
            list.performScrollToNode(hasText("Refresh import progress")); compose.onNodeWithText("Refresh import progress").performClick(); Thread.sleep(2000)
            if (compose.onAllNodes(hasTestTag(progressTag) and hasText("1 of 1 processed · 1 added · 0 existing records preserved")).fetchSemanticsNodes().isNotEmpty()) break
        }
        compose.onNodeWithTag(progressTag).assertTextContains("1 of 1 processed · 1 added · 0 existing records preserved"); capture("live-appwrite-csv-import.png")
        scenario.recreate(); waitText("Import transactions"); androidx.test.espresso.Espresso.pressBack(); openActivity(); compose.onNodeWithText("Search your activity").performTextInput(merchant)
        compose.waitUntil(15000) { compose.onAllNodesWithText(merchant, substring=true).fetchSemanticsNodes().isNotEmpty() }
    }
    @get:Rule val compose = createEmptyComposeRule()
    private lateinit var scenario: ActivityScenario<MainActivity>

    @Before
    fun launchRequestedEntry() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val intent =
            android.content
                .Intent(context, MainActivity::class.java)
                .addFlags(
                    android.content.Intent.FLAG_ACTIVITY_NEW_TASK or
                        android.content.Intent.FLAG_ACTIVITY_CLEAR_TASK
                )
        val args = InstrumentationRegistry.getArguments()
        if (args.getString("class").orEmpty().contains("#liveShortcutOpensReviewAndSaves")) {
            intent.action = android.content.Intent.ACTION_VIEW
            intent.data =
                android.net.Uri.Builder()
                    .scheme("sprout")
                    .authority("expense")
                    .appendQueryParameter("amount", "2.35")
                    .appendQueryParameter("currency", "USD")
                    .appendQueryParameter("merchant", args.getString("sproutMerchant"))
                    .appendQueryParameter("category", "Food")
                    .appendQueryParameter("date", "2026-11-09")
                    .appendQueryParameter("notes", "Reviewed shortcut")
                    .build()
        }
        if (args.getString("class").orEmpty().contains("#liveColdSubscriptionBackStackAndRestoration")) {
            intent.action = android.content.Intent.ACTION_VIEW
            intent.data = android.net.Uri.parse("sprout://subscriptions")
        }
        scenario = ActivityScenario.launch(intent)
    }

    private fun waitText(text: String) =
        compose.waitUntil(30000) {
            compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty()
        }

    private fun openActivity() {
        compose.waitUntil(15000) {
            compose.onAllNodesWithContentDescription("Activity").fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithContentDescription("Activity").performClick()
    }

    private fun capture(name: String) {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        instrumentation.waitForIdleSync()
        android.os.SystemClock.sleep(500) // Let the native dialog-window transition finish.
        val device = androidx.test.uiautomator.UiDevice.getInstance(instrumentation)
        org.junit.Assert.assertFalse("System UI must be responsive for visual acceptance", device.hasObject(androidx.test.uiautomator.By.text("System UI isn't responding")))
        val screenshot = instrumentation.uiAutomation.takeScreenshot()
        java.io
            .File(instrumentation.targetContext.getExternalFilesDir(null), name)
            .outputStream()
            .use { screenshot.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
    }

    @After
    fun captureFinalState() {
        runCatching { capture("live-last-state.png") }
        if (::scenario.isInitialized) scenario.close()
    }

    @Test
    fun onDeviceReceiptOcrReadsPixelsBeforeReview() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val bitmap = android.graphics.Bitmap.createBitmap(1200, 700, android.graphics.Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap); canvas.drawColor(android.graphics.Color.WHITE)
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.BLACK; textSize = 48f }
        listOf("SPROUT CAFE", "11/09/2026", "SUBTOTAL $5.00", "TAX $0.40", "TOTAL USD 5.40").forEachIndexed { index, line -> canvas.drawText(line, 60f, 100f + index * 100, paint) }
        val file = java.io.File.createTempFile("sprout-ocr-test-", ".png", context.cacheDir)
        try {
            file.outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
            val text = kotlinx.coroutines.runBlocking { com.michaeldadi.sprout.money.MoneyReceiptOcr.recognize(context, android.net.Uri.fromFile(file)) }
            val result = com.michaeldadi.sprout.money.MoneyReceiptExtraction.parse(text)
            org.junit.Assert.assertEquals("Synthetic OCR output: ${text.take(500)}", listOf(540L), result.totals)
            org.junit.Assert.assertEquals("SPROUT CAFE", result.merchant)
            org.junit.Assert.assertEquals("2026-11-09", result.date)
        } finally { bitmap.recycle(); file.delete() }
    }

    @Test
    fun liveColdSubscriptionBackStackAndRestoration() {
        val args = InstrumentationRegistry.getArguments()
        compose.waitUntil(30000) {
            compose.onAllNodesWithText("Subscriptions").fetchSemanticsNodes().isNotEmpty() ||
                compose.onAllNodesWithText("I already have an account").fetchSemanticsNodes().isNotEmpty()
        }
        if (compose.onAllNodesWithText("I already have an account").fetchSemanticsNodes().isNotEmpty()) {
            compose.onNodeWithText("I already have an account").performScrollTo().performClick()
            waitText("Email")
            compose.onNodeWithText("Email").performTextInput(args.getString("sproutEmail")!!)
            compose.onNodeWithText("Password").performTextInput(args.getString("sproutPassword")!!)
            compose.onNodeWithText("Sign in").performClick()
        }
        waitText("Subscriptions")
        scenario.recreate(); waitText("Subscriptions")
        androidx.test.espresso.Espresso.pressBack()
        waitText("Insights")
        compose.onNodeWithText("Subscriptions", substring = false).assertDoesNotExist()
        repeat(2) {
            scenario.onActivity { activity -> activity.startActivity(android.content.Intent(activity, MainActivity::class.java).setAction(android.content.Intent.ACTION_VIEW).setData(android.net.Uri.parse("sprout://subscriptions")).addFlags(android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP)) }
            waitText("Subscriptions")
            androidx.test.espresso.Espresso.pressBack(); waitText("Insights")
        }
        capture("live-appwrite-cold-link-insights.png")
        androidx.test.espresso.Espresso.pressBackUnconditionally()
        // Android 12+ backgrounds a root task on Back rather than destroying it.
        compose.waitUntil(5000) { scenario.state != androidx.lifecycle.Lifecycle.State.RESUMED }
        org.junit.Assert.assertNotEquals("Cold links must not fabricate Home below the Insights stack", androidx.lifecycle.Lifecycle.State.RESUMED, scenario.state)
    }

    @Test
    fun liveCompetingBudgetRequiresExplicitReview() {
        val args = InstrumentationRegistry.getArguments()
        val category = args.getString("sproutBudgetConflictCategory")!!
        val month = args.getString("sproutBudgetConflictMonth")!!
        compose.waitUntil(30000) { compose.onAllNodesWithContentDescription("Budget").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithContentDescription("Budget").performClick()
        waitText("Edit your plan"); compose.onNodeWithText("Edit your plan").performScrollTo().performClick()
        compose.onNodeWithText("Category budgets").performClick()
        compose.onNodeWithText("Category").performTextReplacement(category)
        compose.onNodeWithText("Limit in USD").performTextReplacement("22.22")
        val directory = InstrumentationRegistry.getInstrumentation().targetContext.getExternalFilesDir(null)
        val done = java.io.File(directory, "sprout-budget-remote-done"); done.delete()
        java.io.File(directory, "sprout-budget-ready").writeText(category)
        compose.waitUntil(60000) { done.exists() && done.readText() == category }
        compose.onNodeWithText("Save").performClick()
        val review = "Review $category budget for $month"
        compose.waitUntil(35000) { compose.onAllNodes(hasContentDescription(review) and isEnabled()).fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithContentDescription(review).performScrollTo().performClick()
        compose.onNodeWithText("$category · $month · $22.22").assertIsDisplayed(); compose.onNodeWithText("$category · $month · $33.33").assertIsDisplayed()
        compose.onNodeWithText("Keep my budget edit").performClick()
        val acknowledged = hasText(category) and hasText("$0.00 / $22.22")
        compose.waitUntil(35000) { compose.onAllNodes(acknowledged).fetchSemanticsNodes().isNotEmpty() }
        compose.onNode(acknowledged).performScrollTo().assertIsDisplayed()
        capture("live-appwrite-budget-conflict.png")
    }

    @Test
    fun liveCurrentAndHistoricalBudgetEdits() {
        val args = InstrumentationRegistry.getArguments()
        val category = args.getString("sproutBudgetCategory")!!
        val prior = args.getString("sproutBudgetPriorMonth")!!
        compose.waitUntil(30000) { compose.onAllNodesWithContentDescription("Budget").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithContentDescription("Budget").performClick()
        waitText("Edit your plan")
        compose.onNodeWithText("Edit your plan").performScrollTo().performClick()
        compose.onNodeWithText("Category budgets").performClick()
        compose.onNodeWithText("Category").performTextReplacement(category)
        compose.onNodeWithText("Limit in USD").performTextReplacement("22.22")
        compose.onNodeWithText("Save").performClick()
        waitText(category)
        compose.onNodeWithText("Period:", substring = true).performScrollTo().performClick()
        compose.onNodeWithText(prior).performClick()
        compose.onNodeWithText("Edit category budgets").performScrollTo().performClick()
        compose.onNodeWithText("Choose a saved category").performClick()
        compose.onNode(hasText(category + " Prior") and hasClickAction()).performClick()
        compose.onNodeWithText("11.11").assertExists()
        compose.onNodeWithText("Limit in USD").performTextReplacement("33.33")
        compose.onNodeWithText("Save").performClick()
        waitText("$0.00 / $33.33")
        waitText(category + " Prior")
        capture("live-appwrite-historical-budget.png")
    }

    @Test
    fun liveRemoteChangeAppearsWithoutRefresh() {
        val args = InstrumentationRegistry.getArguments()
        compose.waitUntil(30000) {
            compose.onAllNodesWithContentDescription("Activity").fetchSemanticsNodes().isNotEmpty() ||
                compose.onAllNodesWithText("I already have an account").fetchSemanticsNodes().isNotEmpty()
        }
        if (compose.onAllNodesWithText("I already have an account").fetchSemanticsNodes().isNotEmpty()) {
            compose.onNodeWithText("I already have an account").performScrollTo().performClick()
            waitText("Email")
            compose.onNodeWithText("Email").performTextInput(args.getString("sproutEmail")!!)
            compose.onNodeWithText("Password").performTextInput(args.getString("sproutPassword")!!)
            compose.onNodeWithText("Sign in").performClick()
        }
        openActivity()
        val merchant = args.getString("sproutMerchant")!!
        compose.onNodeWithText("Search your activity").performTextReplacement(merchant)
        androidx.test.espresso.Espresso.closeSoftKeyboard()
        val remoteRow = hasText(merchant) and !hasSetTextAction()
        compose.onNode(remoteRow).assertDoesNotExist()
        compose.waitUntil(30000) { compose.onAllNodes(SemanticsMatcher.keyIsDefined(androidx.compose.ui.semantics.SemanticsProperties.ProgressBarRangeInfo)).fetchSemanticsNodes().isEmpty() }
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        java.io.File(context.getExternalFilesDir(null), "sprout-realtime-ready").writeText(merchant)
        // The host waits for this test-owned marker. No app gesture follows.
        compose.waitUntil(100000) { compose.onAllNodes(remoteRow).fetchSemanticsNodes().isNotEmpty() }
        compose.onNode(remoteRow).assertIsDisplayed()
        capture("live-appwrite-realtime.png")
    }

    @Test
    fun liveShortcutOpensReviewAndSaves() {
        val merchant = InstrumentationRegistry.getArguments().getString("sproutMerchant")!!
        waitText("Amount in USD")
        compose.onNodeWithText("2.35").assertIsDisplayed()
        compose.onNodeWithText(merchant).assertIsDisplayed()
        compose.onNodeWithText("Save to Activity").performScrollTo().performClick()
        openActivity()
        waitText(merchant)
        compose.onNodeWithText(merchant).performClick()
        compose.waitUntil(30000) {
            compose
                .onAllNodes(hasText("Edit expense") and isEnabled())
                .fetchSemanticsNodes()
                .isNotEmpty()
        }
        capture("live-appwrite-shortcut.png")
    }

    @Test
    fun liveDeletionLostResponseRestoresSavedReceipt() {
        val args = InstrumentationRegistry.getArguments()
        compose.waitUntil(20000) {
            compose.onAllNodesWithContentDescription("Profile").fetchSemanticsNodes().isNotEmpty() ||
                compose.onAllNodesWithText("I already have an account").fetchSemanticsNodes().isNotEmpty()
        }
        if (compose.onAllNodesWithContentDescription("Profile").fetchSemanticsNodes().isNotEmpty()) {
            compose.onNodeWithContentDescription("Profile").performClick()
            compose.onNodeWithText("Sign out").performScrollTo().performClick()
        }
        waitText("I already have an account")
        compose.onNodeWithText("I already have an account").performScrollTo().performClick()
        waitText("Email")
        compose.onNodeWithText("Email").performTextInput(args.getString("sproutEmail")!!)
        compose.onNodeWithText("Password").performTextInput(args.getString("sproutPassword")!!)
        compose.onNodeWithText("Sign in").performClick()
        openActivity(); waitText(args.getString("sproutMerchant")!!)
        // Stop the UI before sending: deliberately lose the acceptance response without
        // a production test hook, then restore the actual encrypted device receipt.
        scenario.close()
        val receipt = com.michaeldadi.sprout.money.MoneyDeletionState.prepare(args.getString("sproutPrivacyOwner")!!)
        kotlinx.coroutines.runBlocking {
            val result = io.appwrite.services.Functions(com.michaeldadi.sprout.services.AppwriteConnection.client()).createExecution(
                functionId = "sprout-api", async = false, path = "/v1/privacy", method = io.appwrite.enums.ExecutionMethod.POST,
                headers = mapOf("x-sprout-account" to receipt.owner),
                body = com.google.gson.Gson().toJson(mapOf("type" to "delete", "requestId" to receipt.requestId, "receipt" to receipt.receipt, "_account" to receipt.owner)),
            )
            org.junit.Assert.assertTrue("The synthetic request must be accepted before its response is discarded", result.responseStatusCode in 200..299)
        }
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        com.michaeldadi.sprout.money.MoneyDeletionState.initialize(context)
        org.junit.Assert.assertEquals(false, com.michaeldadi.sprout.money.MoneyDeletionState.active.value?.accepted)
        org.junit.Assert.assertEquals(receipt.requestId, com.michaeldadi.sprout.money.MoneyDeletionState.active.value?.requestId)
        scenario = ActivityScenario.launch(android.content.Intent(context, MainActivity::class.java).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TASK))
        waitText("Account deletion")
        compose.onNodeWithContentDescription("Activity").assertDoesNotExist()
        compose.waitUntil(150000) { compose.onAllNodesWithText("Active financial data removed").fetchSemanticsNodes().isNotEmpty() }
        capture("live-appwrite-deletion-lost-response.png")
        compose.onNodeWithText("Return to welcome").performScrollTo().performClick()
        waitText("I already have an account")
    }

    @Test
    fun liveDeletionRevokesAccessAndRestoresProgress() {
        val args = InstrumentationRegistry.getArguments()
        val email = args.getString("sproutEmail")!!
        val password = args.getString("sproutPassword")!!
        val merchant = args.getString("sproutMerchant")!!
        compose.waitUntil(20000) {
            compose
                .onAllNodesWithContentDescription("Profile")
                .fetchSemanticsNodes()
                .isNotEmpty() ||
                compose
                    .onAllNodesWithText("I already have an account")
                    .fetchSemanticsNodes()
                    .isNotEmpty()
        }
        if (
            compose.onAllNodesWithContentDescription("Profile").fetchSemanticsNodes().isNotEmpty()
        ) {
            compose.onNodeWithContentDescription("Profile").performClick()
            compose.onNodeWithText("Sign out").performScrollTo().performClick()
        }
        waitText("I already have an account")
        compose.onNodeWithText("I already have an account").performScrollTo().performClick()
        waitText("Email")
        compose.onNodeWithText("Email").performTextInput(email)
        compose.onNodeWithText("Password").performTextInput(password)
        compose.onNodeWithText("Sign in").performClick()
        openActivity()
        waitText(merchant)
        compose.onNodeWithText("Android Live Lunch", substring = true).assertDoesNotExist()
        compose.onNodeWithContentDescription("Profile").performClick()
        compose.onNodeWithText("Delete my account").performScrollTo().performClick()
        compose.onNodeWithText("Request account deletion").performScrollTo().performClick()
        compose.onNodeWithText("Confirm").performClick()
        compose.waitUntil(150000) {
            compose
                .onAllNodesWithText("Active financial data removed")
                .fetchSemanticsNodes()
                .isNotEmpty()
        }
        capture("live-appwrite-active-data-erasure.png")
        scenario.recreate()
        waitText("Active financial data removed")
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val hash =
            java.security.MessageDigest.getInstance("SHA-256")
                .digest(
                    "${com.michaeldadi.sprout.config.AppConfig.appwriteEndpoint}/${com.michaeldadi.sprout.config.AppConfig.appwriteProjectId}/${args.getString("sproutPrivacyOwner")}"
                        .toByteArray()
                )
                .joinToString("") { "%02x".format(it) }
        org.junit.Assert.assertFalse(context.getDatabasePath("sprout-money-v1-$hash").exists())
        compose.onNodeWithText("Return to welcome").performScrollTo().performClick()
        waitText("I already have an account")
    }

    @Test
    fun liveGoalCrossPlatformEditAndCreate() {
        val args = InstrumentationRegistry.getArguments()
        val iosName = args.getString("sproutIosGoal")!!
        val androidName = args.getString("sproutAndroidGoal")!!
        compose.waitUntil(15000) {
            compose.onAllNodesWithContentDescription("Budget").fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithContentDescription("Budget").performClick()
        waitText("Edit $iosName")
        compose.onNodeWithText("Edit $iosName").performScrollTo().performClick()
        compose.onNodeWithText("Virtual allocation in USD").performTextReplacement("150")
        compose.onNodeWithText("Save goal").performClick()
        compose.waitUntil(30000) {
            compose
                .onAllNodes(hasText("Edit $iosName") and isEnabled())
                .fetchSemanticsNodes()
                .isNotEmpty()
        }
        compose.onNodeWithText("Add goal").performScrollTo().performClick()
        compose.onNodeWithText("Goal name").performTextInput(androidName)
        compose.onNodeWithText("Goal target in USD").performTextInput("750")
        compose.onNodeWithText("Virtual allocation in USD").performTextReplacement("50")
        compose.onNodeWithText("Save goal").performClick()
        compose.waitUntil(30000) {
            compose
                .onAllNodes(hasText("Edit $androidName") and isEnabled())
                .fetchSemanticsNodes()
                .isNotEmpty()
        }
        compose.onNodeWithText("Edit $androidName").performScrollTo()
        capture("live-appwrite-goals.png")
    }

    @Test
    fun liveExportDownloadsPrivateJson() {
        compose.waitUntil(15000) {
            compose.onAllNodesWithContentDescription("Profile").fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithContentDescription("Profile").performClick()
        waitText("Export my data")
        compose.onNodeWithText("Export my data").performScrollTo().performClick()
        compose.waitUntil(15000) {
            compose.onAllNodesWithText("Request export").fetchSemanticsNodes().isNotEmpty()
        }
        if (compose.onAllNodesWithText("Download private export").fetchSemanticsNodes().isEmpty()) {
            compose.onNodeWithText("Request export").performScrollTo().performClick()
            compose.onNodeWithText("Confirm").performClick()
        }
        compose.waitUntil(60000) {
            compose.onAllNodesWithText("Download private export").fetchSemanticsNodes().isNotEmpty()
        }
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val directory = java.io.File(context.cacheDir, "sprout-exports")
        val before = directory.walkTopDown().filter { it.isFile }.map { it.absolutePath }.toSet()
        compose.onNodeWithText("Download private export").performScrollTo().performClick()
        var downloaded: java.io.File? = null
        compose.waitUntil(30000) {
            downloaded =
                directory
                    .walkTopDown()
                    .filter { it.isFile && it.absolutePath !in before }
                    .firstOrNull { file ->
                        runCatching {
                                val value = java.util.zip.ZipFile(file).use { zip ->
                                    com.google.gson.JsonParser.parseString(zip.getInputStream(zip.getEntry("sprout-export.json")).bufferedReader().readText()).asJsonObject
                                }
                                value["schemaVersion"].asInt == 1 &&
                                    value
                                        .getAsJsonObject("records")
                                        .getAsJsonArray("transactions")
                                        .size() > 0
                            }
                            .getOrDefault(false)
                    }
            downloaded != null
        }
        org.junit.Assert.assertNotNull(downloaded)
        java.io.File(context.filesDir, "sprout-export-accepted").writeText(downloaded!!.relativeTo(context.dataDir).path)
        InstrumentationRegistry.getInstrumentation()
            .uiAutomation
            .performGlobalAction(
                android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_BACK
            )
        capture("live-appwrite-private-export.png")
    }

    @Test
    fun liveCrossPlatformEditAndDeletionReadback() {
        val merchant = InstrumentationRegistry.getArguments().getString("sproutMerchant")!!
        openActivity()
        waitText(merchant)
        compose.onNodeWithText("iOS Live Coffee").assertDoesNotExist()
        compose.onNodeWithText(merchant).performClick()
        compose.waitUntil(30000) {
            compose.onAllNodesWithText("5.67", substring = true).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithText("Edit expense").assertIsEnabled()
        capture("live-appwrite-roundtrip.png")
    }

    @Test
    fun liveOfflineDraftSurvivesRecreation() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val connectivity =
            context.getSystemService(android.content.Context.CONNECTIVITY_SERVICE)
                as android.net.ConnectivityManager
        org.junit.Assert.assertFalse(
            "The emulator must actually be offline",
            connectivity
                .getNetworkCapabilities(connectivity.activeNetwork)
                ?.hasCapability(android.net.NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true,
        )
        val merchant = InstrumentationRegistry.getArguments().getString("sproutMerchant")!!
        openActivity()
        compose.onNodeWithContentDescription("Add expense").performClick()
        compose.onNodeWithText("Amount in USD").performTextInput("7.89")
        compose.onNodeWithText("Merchant").performTextInput(merchant)
        compose.onNodeWithText("Save to Activity").performScrollTo().performClick()
        waitText(merchant)
        scenario.recreate()
        openActivity()
        waitText(merchant)
        compose.onNodeWithText(merchant).performClick()
        waitText("Edit expense")
        compose.onNodeWithText("Edit expense").assertIsNotEnabled()
        capture("live-appwrite-offline.png")
    }

    @Test
    fun liveOfflineDraftAcknowledgesAfterReconnect() {
        val merchant = InstrumentationRegistry.getArguments().getString("sproutMerchant")!!
        openActivity()
        waitText(merchant)
        compose.onNodeWithText(merchant).performClick()
        compose.waitUntil(30000) {
            compose
                .onAllNodes(hasText("Edit expense") and isEnabled())
                .fetchSemanticsNodes()
                .isNotEmpty()
        }
        compose.onNodeWithText("7.89", substring = true).assertIsDisplayed()
        capture("live-appwrite-reconnected.png")
    }

    @Test
    fun liveAuthenticationCrossPlatformReadAndExpenseSave() {
        val args = InstrumentationRegistry.getArguments()
        val email = args.getString("sproutEmail")
        val password = args.getString("sproutPassword")
        assumeTrue(
            "Live staging credentials were not supplied",
            !email.isNullOrBlank() && !password.isNullOrBlank(),
        )
        fun waitText(text: String) =
            compose.waitUntil(30000) {
                compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty()
            }
        compose.waitUntil(30000) {
            compose
                .onAllNodesWithText("I already have an account")
                .fetchSemanticsNodes()
                .isNotEmpty() ||
                compose
                    .onAllNodesWithContentDescription("Activity")
                    .fetchSemanticsNodes()
                    .isNotEmpty()
        }
        if (
            compose
                .onAllNodesWithText("I already have an account")
                .fetchSemanticsNodes()
                .isNotEmpty()
        ) {
            compose.onNodeWithText("I already have an account").performScrollTo().performClick()
            compose.onNodeWithText("Email").performTextInput(email!!)
            compose.onNodeWithText("Password").performTextInput(password!!)
            compose
                .onNodeWithText("Sign in", useUnmergedTree = true)
                .performScrollTo()
                .performClick()
        }
        compose.waitUntil(30000) {
            compose.onAllNodesWithContentDescription("Activity").fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithContentDescription("Activity").performClick()
        waitText("iOS Live Coffee")
        compose.onNodeWithText("iOS Live Coffee").assertIsDisplayed()
        compose.onNodeWithContentDescription("Add expense").performClick()
        compose.onNodeWithText("Amount in USD").performTextInput("4.56")
        val merchant =
            args.getString("sproutMerchant") ?: "Android Live Lunch ${System.currentTimeMillis()}"
        compose.onNodeWithText("Merchant").performTextInput(merchant)
        compose.onNodeWithText("Save to Activity").performScrollTo().performClick()
        waitText(merchant)
        compose.onNodeWithText(merchant).performClick()
        waitText("Edit expense")
        compose.waitUntil(30000) {
            compose
                .onAllNodes(hasText("Edit expense") and isEnabled())
                .fetchSemanticsNodes()
                .isNotEmpty()
        }
        compose.onNodeWithText("Edit expense").assertIsEnabled()
        val screenshot = InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        val file =
            java.io.File(
                InstrumentationRegistry.getInstrumentation()
                    .targetContext
                    .getExternalFilesDir(null),
                "live-appwrite-android.png",
            )
        file.outputStream().use {
            screenshot.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it)
        }
    }
}
