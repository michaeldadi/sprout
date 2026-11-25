package com.michaeldadi.sprout.ui.home

import com.michaeldadi.sprout.data.entities.SyncStatus
import com.michaeldadi.sprout.ui.activity.ActivityFilter
import com.michaeldadi.sprout.ui.activity.ActivityItem
import com.michaeldadi.sprout.ui.activity.ActivityPeriod
import java.util.Date

/** A scoped view of the same saved records shown in Activity. No balance is inferred. */
data class HomeSnapshot(val allCount: Int, val recent: List<ActivityItem>) {
    val latest: ActivityItem? get() = recent.firstOrNull()
    val unsyncedCount: Int get() = recent.count { it.syncStatus != SyncStatus.SYNCED }
    val hasUnsyncedRecords: Boolean get() = unsyncedCount > 0

    companion object {
        fun from(items: List<ActivityItem>, now: Date): HomeSnapshot =
            HomeSnapshot(items.size, ActivityFilter(period = ActivityPeriod.RECENT, now = now).apply(items))
    }
}
