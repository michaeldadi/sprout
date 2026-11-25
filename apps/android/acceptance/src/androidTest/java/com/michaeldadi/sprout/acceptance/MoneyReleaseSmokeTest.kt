package com.michaeldadi.sprout.acceptance

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.os.SystemClock
import android.view.accessibility.AccessibilityNodeInfo
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** Platform accessibility drives the minified app without linking its private classes. */
@RunWith(AndroidJUnit4::class)
class MoneyReleaseSmokeTest {
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    private val device get() = androidx.test.uiautomator.UiDevice.getInstance(instrumentation)
    private fun find(label: String, visible: Boolean = true): androidx.test.uiautomator.UiObject2? =
        device.findObject(androidx.test.uiautomator.By.text(label)) ?: device.findObject(androidx.test.uiautomator.By.desc(label))
    private fun waitFor(label: String, seconds: Int = 30): androidx.test.uiautomator.UiObject2 {
        val until = SystemClock.uptimeMillis() + seconds * 1000
        while (SystemClock.uptimeMillis() < until) { find(label)?.let { return it }; SystemClock.sleep(200) }
        fail("Expected native control: $label"); error("unreachable")
    }
    private fun click(label: String) { waitFor(label).click(); device.waitForIdle(2000) }
    private fun enter(label: String, text: String) {
        var node: androidx.test.uiautomator.UiObject2? = waitFor(label)
        repeat(5) {
            if (node?.className == "android.widget.EditText") { node!!.text = text; device.waitForIdle(2000); return }
            node = node?.parent
        }
        fail("Native input field is unavailable: $label")
    }
    private fun scrollTo(label: String) {
        repeat(18) {
            if (find(label) != null) return
            device.findObject(androidx.test.uiautomator.By.scrollable(true))?.scroll(androidx.test.uiautomator.Direction.DOWN, 0.6f)
        }
        waitFor(label)
    }
    private fun expenseRow(merchant: String): Boolean {
        val matches = device.findObjects(androidx.test.uiautomator.By.clickable(true))
        fun labels(node: androidx.test.uiautomator.UiObject2): String = (node.text.orEmpty() + " " + node.contentDescription.orEmpty() + " " + node.children.joinToString(" ") { labels(it) }).take(4000)
        return matches.any { node -> !node.isFocused && labels(node).let { it.contains(merchant) && it.contains("2.75") } }
    }
    @org.junit.After fun captureNativeState() {
        val directory = instrumentation.targetContext.getExternalFilesDir(null)!!
        runCatching { device.takeScreenshot(java.io.File(directory,"live-release-last-state.png")) }
        runCatching { device.dumpWindowHierarchy(java.io.File(directory,"live-release-window.xml")) }
    }

    @Test fun minifiedReleaseRestoresAndSavesReviewedExpense() {
        val args = InstrumentationRegistry.getArguments()
        val context = instrumentation.targetContext
        val app = context.packageManager.getApplicationInfo("com.michaeldadi.sprout", 0)
        assertEquals("This acceptance journey must drive a non-debuggable shipping app", 0, app.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE)
        instrumentation.uiAutomation.executeShellCommand("am start -W -f 268468224 -n com.michaeldadi.sprout/com.michaeldadi.sprout.MainActivity").use { android.os.ParcelFileDescriptor.AutoCloseInputStream(it).readBytes() }
        val end = SystemClock.uptimeMillis() + 40000
        while (find("Activity") == null && find("I already have an account", false) == null && SystemClock.uptimeMillis() < end) SystemClock.sleep(250)
        if (find("Activity") == null) {
            scrollTo("I already have an account"); click("I already have an account")
            enter("Email", args.getString("sproutEmail")!!); enter("Password", args.getString("sproutPassword")!!); click("Sign in")
        }
        waitFor("Activity", 40)
        click("Add expense")
        enter("Amount in USD", "2.75"); enter("Merchant", args.getString("sproutMerchant")!!)
        scrollTo("Save to Activity"); click("Save to Activity")
        click("Activity"); enter("Search your activity", args.getString("sproutMerchant")!!)
        val merchant = args.getString("sproutMerchant")!!
        val until = SystemClock.uptimeMillis() + 30000
        while (SystemClock.uptimeMillis() < until) {
            if (expenseRow(merchant)) {
                val image = instrumentation.uiAutomation.takeScreenshot()
                java.io.File(context.getExternalFilesDir(null), "live-release-activity.png").outputStream().use { image.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
                image.recycle(); return
            }
            SystemClock.sleep(250)
        }
        fail("The reviewed expense must appear in the minified Activity screen")
    }
}
