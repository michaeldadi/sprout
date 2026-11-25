package com.michaeldadi.sprout.ui.activity

import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.FilterChip
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.michaeldadi.sprout.data.entities.SyncStatus
import com.michaeldadi.sprout.data.entities.TransactionType
import com.michaeldadi.sprout.ui.components.SproutActionButton
import com.michaeldadi.sprout.ui.components.SproutAmountText
import com.michaeldadi.sprout.ui.components.SproutFeedbackKind
import com.michaeldadi.sprout.ui.components.SproutStatePanel
import com.michaeldadi.sprout.ui.components.SproutStatusBanner
import com.michaeldadi.sprout.ui.components.SproutStatusLine
import com.michaeldadi.sprout.ui.components.SproutSearchField
import com.michaeldadi.sprout.ui.theme.SproutSpacing
import com.michaeldadi.sprout.ui.theme.SproutTokens
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

@Composable
fun ActivityListScreen(
    state: ActivityLoadState,
    now: Date,
    offline: Boolean,
    query: String,
    onQueryChange: (String) -> Unit,
    kind: ActivityKind,
    onKindChange: (ActivityKind) -> Unit,
    period: ActivityPeriod,
    onPeriodChange: (ActivityPeriod) -> Unit,
    onOpen: (String) -> Unit,
    onRetry: () -> Unit
) {
    val readyItems = (state as? ActivityLoadState.Ready)?.items
    val filtered = readyItems?.let { ActivityFilter(query, kind, period, now).apply(it) }.orEmpty()
    Scaffold(containerColor = SproutTokens.colors.canvas, contentWindowInsets = WindowInsets(0, 0, 0, 0)) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(horizontal = SproutSpacing.screen, vertical = SproutSpacing.md)
        ) {
            item {
                Column(
                    modifier = Modifier.padding(bottom = if (filtered.isNotEmpty()) SproutSpacing.md else 0.dp),
                    verticalArrangement = Arrangement.spacedBy(SproutSpacing.sm)
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(SproutSpacing.xs)) {
                        Text("Activity", style = MaterialTheme.typography.headlineLarge, color = SproutTokens.colors.textPrimary)
                        Text("Your Sprout account", style = MaterialTheme.typography.bodyMedium,
                            color = SproutTokens.colors.textSecondary)
                        Text("Full sync time unavailable", style = MaterialTheme.typography.labelMedium,
                            color = SproutTokens.colors.textSecondary)
                    }
                    if (offline) SproutStatusBanner("Offline", "Showing records saved on this device. Changes may not be current.", SproutFeedbackKind.WARNING)
                    when (state) {
                        ActivityLoadState.Loading -> SproutStatePanel("Loading activity", "Reading saved transactions on this device.", loading = true)
                        is ActivityLoadState.Failed -> {
                            SproutStatePanel("Activity unavailable", state.message)
                            SproutActionButton("Try again", onRetry)
                        }
                        is ActivityLoadState.Ready -> {
                            if (state.items.isEmpty()) {
                                SproutStatePanel("No saved transactions", "Your saved transactions will appear here when available.")
                            } else {
                                SproutSearchField("Search activity", query, onQueryChange)
                                Row(horizontalArrangement = Arrangement.spacedBy(SproutSpacing.xs)) {
                                    ActivityPeriod.entries.forEach { option ->
                                        FilterChip(selected = period == option, onClick = { onPeriodChange(option) },
                                            label = { Text(option.label) }, modifier = Modifier.semantics { selected = period == option })
                                    }
                                }
                                Row(modifier = Modifier.horizontalScroll(rememberScrollState()),
                                    horizontalArrangement = Arrangement.spacedBy(SproutSpacing.xs)) {
                                    ActivityKind.entries.forEach { option ->
                                        FilterChip(selected = kind == option, onClick = { onKindChange(option) },
                                            label = { Text(option.label) }, modifier = Modifier.semantics { selected = kind == option })
                                    }
                                }
                                Text("${filtered.size} of ${state.items.size} saved transactions",
                                    style = MaterialTheme.typography.bodyMedium, color = SproutTokens.colors.textSecondary)
                                val unsyncedCount = state.items.count { it.syncStatus != SyncStatus.SYNCED }
                                if (unsyncedCount > 0) {
                                    SproutStatusLine(
                                        "$unsyncedCount Sprout ${if (unsyncedCount == 1) "record needs" else "records need"} sync · See row details",
                                        SproutFeedbackKind.WARNING
                                    )
                                }
                                val lastRecordSync = state.items.mapNotNull { it.lastSyncedAt }.maxOrNull()
                                if (lastRecordSync != null && now.time - lastRecordSync.time > 86_400_000) {
                                    SproutStatusBanner("Latest record sync may be old",
                                        "Last saved record sync ${shortDate(lastRecordSync)}. Full account sync time is unavailable.", SproutFeedbackKind.WARNING)
                                }
                                if (filtered.isEmpty()) SproutStatePanel("No matches", "Try a different search, type, or period.")
                            }
                        }
                    }
                }
            }
            if (filtered.isNotEmpty()) {
                itemsIndexed(filtered, key = { _, item -> item.id }) { index, item ->
                    val corner = SproutSpacing.md
                    val square = 0.dp
                    Surface(
                        color = SproutTokens.colors.surface,
                        shape = RoundedCornerShape(
                            topStart = if (index == 0) corner else square,
                            topEnd = if (index == 0) corner else square,
                            bottomStart = if (index == filtered.lastIndex) corner else square,
                            bottomEnd = if (index == filtered.lastIndex) corner else square
                        )
                    ) {
                        Column {
                            ActivityRow(item, onClick = { onOpen(item.id) })
                            if (index != filtered.lastIndex) HorizontalDivider(color = SproutTokens.colors.separator)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ActivityRow(item: ActivityItem, onClick: () -> Unit) {
    val largeText = LocalDensity.current.fontScale >= 1.4f
    Column(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick).heightIn(min = 64.dp)
            .padding(horizontal = SproutSpacing.md, vertical = SproutSpacing.sm),
        verticalArrangement = Arrangement.spacedBy(SproutSpacing.xs)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(SproutSpacing.sm)) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(SproutSpacing.xxs)) {
                Text(item.title, style = MaterialTheme.typography.titleMedium, color = SproutTokens.colors.textPrimary)
                Text(rowMetadata(item),
                    style = MaterialTheme.typography.bodyMedium, color = SproutTokens.colors.textSecondary)
                item.syncLabel?.let { label ->
                    Text(label, style = MaterialTheme.typography.labelMedium,
                        color = if (item.syncStatus == SyncStatus.FAILED || item.syncStatus == SyncStatus.CONFLICT)
                            SproutTokens.colors.error else SproutTokens.colors.warning)
                }
            }
            if (!largeText) ActivityRowAmount(item)
        }
        if (largeText) ActivityRowAmount(item, Modifier.align(Alignment.End))
    }
}

@Composable
private fun ActivityRowAmount(item: ActivityItem, modifier: Modifier = Modifier) {
    Column(modifier = modifier, horizontalAlignment = Alignment.End) {
        SproutAmountText(item.amount, item.currencyCode)
        Text(item.currencyCode, style = MaterialTheme.typography.labelSmall,
            color = SproutTokens.colors.textSecondary)
    }
}

private fun rowMetadata(item: ActivityItem): String =
    listOfNotNull(item.typeLabel, item.category.takeUnless { it.equals(item.typeLabel, ignoreCase = true) },
        shortDate(item.date)).joinToString(" · ")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ActivityDetailScreen(item: ActivityItem?, onBack: () -> Unit) {
    Scaffold(
        containerColor = SproutTokens.colors.canvas,
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = { TopAppBar(title = { Text("Transaction") }, navigationIcon = {
            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back to activity") }
        }) }
    ) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState())
                .padding(SproutSpacing.screen),
            verticalArrangement = Arrangement.spacedBy(SproutSpacing.lg)
        ) {
            if (item == null) {
                SproutStatePanel("Transaction unavailable", "This record is no longer available in your saved activity.")
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(SproutSpacing.sm)) {
                    Text(item.title, style = MaterialTheme.typography.headlineLarge, color = SproutTokens.colors.textPrimary)
                    Text(item.typeLabel, style = MaterialTheme.typography.bodyMedium, color = SproutTokens.colors.textSecondary)
                    SproutAmountText(item.amount, item.currencyCode, large = true)
                    Text("${item.currencyCode} · Source amount", style = MaterialTheme.typography.labelMedium,
                        color = SproutTokens.colors.textSecondary)
                }
                item.syncLabel?.let { label ->
                    SproutStatusLine("Sprout ${label.lowercase(Locale.getDefault())} · Bank status not shown",
                        if (item.syncStatus == SyncStatus.FAILED || item.syncStatus == SyncStatus.CONFLICT)
                            SproutFeedbackKind.ERROR else SproutFeedbackKind.WARNING)
                }
                val details = buildList {
                    add("Date · device time zone" to fullDate(item.date))
                    add("Category" to item.category)
                    item.paymentMethod?.takeIf { it.isNotBlank() }?.let { add("Payment method" to it) }
                    add("Last Sprout record sync" to (item.lastSyncedAt?.let(::fullDate) ?: "Unavailable"))
                    item.notes?.takeIf { it.isNotBlank() }?.let { add("Notes" to it) }
                }
                Column {
                    details.forEachIndexed { index, (label, value) ->
                        detailLine(label, value)
                        if (index < details.lastIndex) HorizontalDivider(color = SproutTokens.colors.separator)
                    }
                }
            }
        }
    }
}

@Composable
private fun detailLine(label: String, value: String) {
    Column(modifier = Modifier.padding(vertical = SproutSpacing.sm),
        verticalArrangement = Arrangement.spacedBy(SproutSpacing.xxs)) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = SproutTokens.colors.textSecondary)
        Text(value, style = MaterialTheme.typography.bodyLarge, color = SproutTokens.colors.textPrimary)
    }
}

private fun shortDate(date: Date): String = DateFormat.getDateInstance(DateFormat.MEDIUM).format(date)
private fun fullDate(date: Date): String = SimpleDateFormat("EEEE, MMMM d, yyyy · h:mm a z", Locale.getDefault())
    .apply { timeZone = TimeZone.getDefault() }.format(date)
