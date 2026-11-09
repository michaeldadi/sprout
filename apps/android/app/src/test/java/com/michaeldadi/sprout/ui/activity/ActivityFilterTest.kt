package com.michaeldadi.sprout.ui.activity

import com.michaeldadi.sprout.data.entities.SyncStatus
import com.michaeldadi.sprout.data.entities.TransactionType
import java.math.BigDecimal
import java.util.Date
import java.time.Instant
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Test

class ActivityFilterTest {
    private val now = Date(1_783_600_000_000L)
    private val items = listOf(
        item("pay", "Payroll deposit", TransactionType.INCOME, 1),
        item("transfer", "Transfer to savings", TransactionType.TRANSFER, 2),
        item("market", "North Market", TransactionType.EXPENSE, 3),
        item("old", "Cinema", TransactionType.EXPENSE, 60)
    )

    @Test fun preservesTypeAndDateScope() {
        assertEquals(listOf("market"), ActivityFilter(kind = ActivityKind.EXPENSE, now = now)
            .apply(items).map { it.id })
        assertEquals(listOf("transfer"), ActivityFilter(kind = ActivityKind.TRANSFER, now = now)
            .apply(items).map { it.id })
        assertEquals(4, ActivityFilter(period = ActivityPeriod.ALL, now = now).apply(items).size)
    }

    @Test fun searchDoesNotChangeSourceRecords() {
        val result = ActivityFilter(query = "north", now = now).apply(items)
        assertEquals(listOf("market"), result.map { it.id })
        assertEquals(BigDecimal("84.27"), result.single().amount)
        assertEquals(4, items.size)
    }

    @Test fun recentPeriodUsesLocalCalendarDaysAcrossDaylightSaving() {
        val originalZone = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("America/New_York"))
            val afterClockChange = Date.from(Instant.parse("2026-11-08T14:41:00Z"))
            val insideCalendarWindow = item("boundary", "Boundary", TransactionType.EXPENSE, 1)
                .copy(date = Date.from(Instant.parse("2026-10-09T13:50:00Z")))
            assertEquals(listOf("boundary"), ActivityFilter(now = afterClockChange)
                .apply(listOf(insideCalendarWindow)).map { it.id })
        } finally {
            TimeZone.setDefault(originalZone)
        }
    }

    private fun item(id: String, title: String, type: TransactionType, daysAgo: Long) = ActivityItem(
        id, title, "Test", BigDecimal("84.27"), "USD", Date(now.time - daysAgo * 86_400_000),
        type, SyncStatus.SYNCED, null, null, null
    )
}
