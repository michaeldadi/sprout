package com.michaeldadi.sprout.money

import com.google.gson.Gson
import org.junit.Assert.*
import org.junit.Test

class MoneyImportTest {
    private data class Case(val name: String, val csv: String, val rowCount: Int?, val selectedCount: Int?, val amounts: List<Long?>?, val batchId: String)
    @Test fun sharedCsvReviewAndStableIdentity() {
        val cases = Gson().fromJson(javaClass.classLoader!!.getResource("transaction-import.json")!!.readText(), Array<Case>::class.java)
        for (item in cases) {
            if (item.rowCount == null) { assertTrue(item.name, runCatching { MoneyCSVImport.parse(item.csv.toByteArray()) }.isFailure); continue }
            val batch = MoneyCSVImport.parse(item.csv.toByteArray())
            assertEquals(item.name, item.rowCount, batch.rows.size); assertEquals(item.name, item.selectedCount, batch.rows.count { it.selected })
            assertEquals(item.name, item.batchId, batch.batchId); assertEquals(item.name, item.amounts, batch.rows.map { it.transaction(batch.batchId)?.amount?.minor })
            assertEquals(item.name, item.selectedCount != 0, runCatching { batch.command() }.isSuccess)
        }
    }
    @Test fun boundedUtf8AndExistingDuplicatesRequireReview() {
        assertTrue(runCatching { MoneyCSVImport.parse(byteArrayOf(0xff.toByte(),0xfe.toByte())) }.isFailure)
        assertTrue(runCatching { MoneyCSVImport.parse(ByteArray(500001)) }.isFailure)
        val batch = MoneyCSVImport.parse(MoneyCSVImport.template.toByteArray()); val existing = batch.rows[0].transaction(batch.batchId)!!
        assertFalse(MoneyCSVImport.parse(MoneyCSVImport.template.toByteArray(), listOf(existing)).rows[0].selected)
    }
}
