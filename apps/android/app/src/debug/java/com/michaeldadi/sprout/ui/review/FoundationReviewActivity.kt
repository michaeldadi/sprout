package com.michaeldadi.sprout.ui.review

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import com.michaeldadi.sprout.ui.components.SocialLoginButton
import com.michaeldadi.sprout.ui.components.SproutActionButton
import com.michaeldadi.sprout.ui.components.SproutActionRole
import com.michaeldadi.sprout.ui.components.SproutAmountText
import com.michaeldadi.sprout.ui.components.SproutFeedbackKind
import com.michaeldadi.sprout.ui.components.SproutInputField
import com.michaeldadi.sprout.ui.components.SproutStatePanel
import com.michaeldadi.sprout.ui.components.SproutStatusBanner
import com.michaeldadi.sprout.ui.components.SproutTransactionRow
import com.michaeldadi.sprout.ui.theme.SproutSpacing
import com.michaeldadi.sprout.ui.theme.SproutTheme
import com.michaeldadi.sprout.ui.theme.SproutTokens
import java.math.BigDecimal

/** Debug-only review route. No auth, bank connection, or network actions are mounted here. */
class FoundationReviewActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { FoundationReview() }
    }
}

@Composable
private fun FoundationReview() {
    var dark by remember { mutableStateOf<Boolean?>(null) }
    var selected by remember { mutableStateOf(false) }
    var input by remember { mutableStateOf("") }
    var showError by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    val isDark = dark ?: isSystemInDarkTheme()
    val activity = LocalContext.current as FoundationReviewActivity
    SideEffect {
        activity.window.statusBarColor = android.graphics.Color.parseColor(if (isDark) "#101B16" else "#F6F8F4")
        activity.window.navigationBarColor = android.graphics.Color.parseColor(if (isDark) "#101B16" else "#F6F8F4")
        WindowCompat.getInsetsController(activity.window, activity.window.decorView).apply {
            isAppearanceLightStatusBars = !isDark
            isAppearanceLightNavigationBars = !isDark
        }
    }
    SproutTheme(darkTheme = isDark) {
        Column(
            modifier = Modifier.fillMaxSize().background(SproutTokens.colors.canvas)
                .windowInsetsPadding(WindowInsets.safeDrawing).verticalScroll(rememberScrollState())
                .padding(horizontal = SproutSpacing.screen, vertical = SproutSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(SproutSpacing.md)
        ) {
            Text("Sprout foundations", style = MaterialTheme.typography.headlineMedium,
                color = SproutTokens.colors.textPrimary)
            Text("DEMO DATA • 8 Nov 2026 • USD • no account connected",
                style = MaterialTheme.typography.labelMedium, color = SproutTokens.colors.textSecondary)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(SproutSpacing.sm)) {
                Text("Dark theme", color = SproutTokens.colors.textPrimary)
                Switch(checked = dark ?: isSystemInDarkTheme(), onCheckedChange = { dark = it })
            }
            HorizontalDivider()
            Text("Existing shared auth control", style = MaterialTheme.typography.titleLarge,
                color = SproutTokens.colors.textPrimary)
            SocialLoginButton("Continue with Apple", Color.White, Color.Black, "apple", onClick = {})
            Text("Semantic actions", style = MaterialTheme.typography.titleLarge,
                color = SproutTokens.colors.textPrimary)
            SproutActionButton("Review activity", onClick = { selected = !selected })
            SproutActionButton("Selected: ${if (selected) "yes" else "no"}", onClick = { selected = !selected }, role = SproutActionRole.SECONDARY)
            SproutActionButton("Unavailable action", onClick = {}, enabled = false)
            SproutActionButton("Loading action", onClick = {}, busy = true)
            SproutActionButton("Destructive example", onClick = {}, role = SproutActionRole.DESTRUCTIVE)
            Text("Amounts and long rows", style = MaterialTheme.typography.titleLarge,
                color = SproutTokens.colors.textPrimary)
            SproutAmountText(BigDecimal("1245600.25"), "USD", large = true)
            SproutTransactionRow(
                title = "A fictional merchant with a very long descriptive name",
                detail = "8 Nov • Possible recurring payment",
                amount = BigDecimal("-12456.78"), currencyCode = "USD", onClick = { selected = !selected },
                selected = selected, status = "Sync pending"
            )
            SproutTransactionRow("Unknown amount", "No verified balance", null, "USD", onClick = {}, enabled = false)
            Text("Input and feedback", style = MaterialTheme.typography.titleLarge,
                color = SproutTokens.colors.textPrimary)
            SproutInputField("Search activity", input, { input = it }, helper = "Try a fictional merchant",
                error = if (showError) "Enter a search term" else null)
            SproutActionButton("Toggle validation", onClick = { showError = !showError }, role = SproutActionRole.QUIET)
            SproutStatusBanner("Some data needs review", "A fictional account has not synced yet.", SproutFeedbackKind.WARNING)
            SproutStatusBanner("Could not refresh", "Try again when a connection is available.", SproutFeedbackKind.ERROR)
            SproutStatePanel("No activity yet", "A connected account would show verified transactions here.")
            SproutStatePanel("Loading activity", "Waiting for a response.", loading = true)
            SproutActionButton(if (busy) "Stop loading demo" else "Start loading demo", onClick = { busy = !busy }, role = SproutActionRole.SECONDARY)
        }
    }
}
