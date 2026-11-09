package com.michaeldadi.sprout.ui.home

import com.michaeldadi.sprout.data.entities.SyncStatus
import com.michaeldadi.sprout.data.entities.TransactionType
import com.michaeldadi.sprout.ui.activity.ActivityItem
import java.math.BigDecimal
import java.util.Date
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HomeSnapshotTest {
    private val now = Date(1_783_600_000_000L)

    @Test fun latestAndCountComeFromRecentSavedRecords() {
        val latest = item("latest", 1, SyncStatus.PENDING)
        val older = item("older", 60, SyncStatus.SYNCED)
        val snapshot = HomeSnapshot.from(listOf(older, latest), now)
        assertEquals(2, snapshot.allCount)
        assertEquals(listOf("latest"), snapshot.recent.map { it.id })
        assertEquals(BigDecimal("84.27"), snapshot.latest?.amount)
        assertTrue(snapshot.hasUnsyncedRecords)
        assertFalse(HomeSnapshot.from(listOf(older), now).hasUnsyncedRecords)
        assertTrue(HomeSnapshot.from(listOf(older), now).recent.isEmpty())
    }

    private fun item(id: String, daysAgo: Long, sync: SyncStatus) = ActivityItem(
        id, "North Market", "Groceries", BigDecimal("84.27"), "USD",
        Date(now.time - daysAgo * 86_400_000), TransactionType.EXPENSE, sync, null, null, null
    )
}
