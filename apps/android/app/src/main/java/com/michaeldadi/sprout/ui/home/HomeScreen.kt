package com.michaeldadi.sprout.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.michaeldadi.sprout.ui.activity.ActivityLoadState
import com.michaeldadi.sprout.data.entities.SyncStatus
import com.michaeldadi.sprout.ui.components.SproutActionButton
import com.michaeldadi.sprout.ui.components.SproutAmountText
import com.michaeldadi.sprout.ui.components.SproutFeedbackKind
import com.michaeldadi.sprout.ui.components.SproutStatePanel
import com.michaeldadi.sprout.ui.components.SproutStatusBanner
import com.michaeldadi.sprout.ui.components.SproutStatusLine
import com.michaeldadi.sprout.ui.theme.SproutSpacing
import com.michaeldadi.sprout.ui.theme.SproutTokens
import java.text.DateFormat
import java.util.Date

@Composable
fun HomeScreen(
    state: ActivityLoadState,
    now: Date,
    offline: Boolean,
    onViewActivity: () -> Unit,
    onRetry: () -> Unit
) {
    Scaffold(containerColor = SproutTokens.colors.canvas, contentWindowInsets = WindowInsets(0, 0, 0, 0)) { inset ->
        Column(
            modifier = Modifier.fillMaxSize().padding(inset).verticalScroll(rememberScrollState())
                .padding(horizontal = SproutSpacing.screen, vertical = SproutSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(SproutSpacing.lg)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(SproutSpacing.xs)) {
                Text("Home", style = MaterialTheme.typography.headlineLarge, color = SproutTokens.colors.textPrimary)
                Text("Your Sprout account", style = MaterialTheme.typography.bodyMedium,
                    color = SproutTokens.colors.textSecondary)
                Text("Full sync time unavailable", style = MaterialTheme.typography.labelMedium,
                    color = SproutTokens.colors.textSecondary)
            }
            if (offline) SproutStatusBanner("Offline", "Showing records saved on this device. Changes may not be current.", SproutFeedbackKind.WARNING)
            when (state) {
                ActivityLoadState.Loading -> SproutStatePanel("Loading home", "Reading saved transactions on this device.", loading = true)
                is ActivityLoadState.Failed -> {
                    SproutStatePanel("Home unavailable", state.message)
                    SproutActionButton("Try again", onRetry)
                }
                is ActivityLoadState.Ready -> {
                    val snapshot = HomeSnapshot.from(state.items, now)
                    val latest = snapshot.latest
                    if (latest == null) {
                        SproutStatePanel(
                            if (snapshot.allCount == 0) "No saved transactions" else "No recent saved transactions",
                            if (snapshot.allCount == 0)
                                "Your saved transactions will appear here when available."
                            else "View older transactions in Activity. Choose All time."
                        )
                        SproutActionButton("View activity", onViewActivity)
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(SproutSpacing.sm)) {
                            Text("Latest saved transaction", style = MaterialTheme.typography.titleLarge, color = SproutTokens.colors.textPrimary)
                            Text("${snapshot.recent.size} saved ${if (snapshot.recent.size == 1) "transaction" else "transactions"} · Last 30 days",
                                style = MaterialTheme.typography.bodyMedium, color = SproutTokens.colors.textSecondary)
                            Column(verticalArrangement = Arrangement.spacedBy(SproutSpacing.xs)) {
                                Text(latest.title, style = MaterialTheme.typography.titleMedium, color = SproutTokens.colors.textPrimary)
                                SproutAmountText(latest.amount, latest.currencyCode, large = true)
                                Text("${latest.typeLabel} · ${DateFormat.getDateInstance(DateFormat.MEDIUM).format(latest.date)} · ${latest.currencyCode}",
                                    style = MaterialTheme.typography.bodyMedium, color = SproutTokens.colors.textSecondary)
                            }
                        }
                        SproutActionButton("View activity", onViewActivity)
                        if (latest.syncStatus == SyncStatus.SYNCED && latest.lastSyncedAt != null &&
                            now.time - latest.lastSyncedAt.time > 86_400_000L) {
                            SproutStatusBanner(
                                "Latest record sync may be old",
                                "This record last synced ${DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(latest.lastSyncedAt)}. Full account sync time is unavailable.",
                                SproutFeedbackKind.WARNING
                            )
                        }
                        if (snapshot.unsyncedCount > 0) {
                            SproutStatusLine(
                                "${snapshot.unsyncedCount} recent Sprout ${if (snapshot.unsyncedCount == 1) "record needs" else "records need"} sync · Details in Activity",
                                SproutFeedbackKind.WARNING
                            )
                        }
                    }
                }
            }
        }
    }
}
