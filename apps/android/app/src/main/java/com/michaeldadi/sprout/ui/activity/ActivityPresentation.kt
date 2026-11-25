package com.michaeldadi.sprout.ui.activity

import com.michaeldadi.sprout.data.entities.SyncStatus
import com.michaeldadi.sprout.data.entities.TransactionEntity
import com.michaeldadi.sprout.data.entities.TransactionType
import java.math.BigDecimal
import java.util.Calendar
import java.util.Date

enum class ActivityKind(val label: String) { ALL("All"), INCOME("Income"), EXPENSE("Expenses"), TRANSFER("Transfers") }
enum class ActivityPeriod(val label: String) { RECENT("Last 30 days"), ALL("All time") }

data class ActivityItem(
    val id: String,
    val title: String,
    val category: String,
    val amount: BigDecimal,
    val currencyCode: String,
    val date: Date,
    val type: TransactionType,
    val syncStatus: SyncStatus,
    val lastSyncedAt: Date?,
    val paymentMethod: String?,
    val notes: String?
) {
    val typeLabel: String get() = when (type) {
        TransactionType.INCOME -> "Income"
        TransactionType.EXPENSE -> "Expense"
        TransactionType.TRANSFER -> "Transfer"
    }
    val syncLabel: String? get() = when (syncStatus) {
        SyncStatus.SYNCED -> null
        SyncStatus.PENDING -> "Pending sync"
        SyncStatus.SYNCING -> "Syncing"
        SyncStatus.FAILED -> "Sync failed"
        SyncStatus.CONFLICT -> "Sync conflict"
    }
}

fun TransactionEntity.toActivityItem(): ActivityItem = ActivityItem(
    id = id,
    title = listOfNotNull(merchant, description, category).firstOrNull { it.isNotBlank() } ?: "Transaction",
    category = category,
    amount = BigDecimal.valueOf(amount),
    currencyCode = currency,
    date = date,
    type = type,
    syncStatus = syncStatus,
    lastSyncedAt = lastSyncedAt,
    paymentMethod = paymentMethod,
    notes = notes
)

sealed interface ActivityLoadState {
    data object Loading : ActivityLoadState
    data class Ready(val items: List<ActivityItem>) : ActivityLoadState
    data class Failed(val message: String) : ActivityLoadState
}

data class ActivityFilter(
    val query: String = "",
    val kind: ActivityKind = ActivityKind.ALL,
    val period: ActivityPeriod = ActivityPeriod.RECENT,
    val now: Date = Date()
) {
    fun apply(items: List<ActivityItem>): List<ActivityItem> {
        val start = Calendar.getInstance().apply {
            time = now
            add(Calendar.DAY_OF_YEAR, -30)
        }.time.time
        return items.filter { item ->
            (kind == ActivityKind.ALL || item.type.name == kind.name) &&
                (period == ActivityPeriod.ALL || item.date.time in start..now.time) &&
                (query.isBlank() || item.title.contains(query, ignoreCase = true) ||
                    item.category.contains(query, ignoreCase = true))
        }.sortedByDescending { it.date.time }
    }
}
