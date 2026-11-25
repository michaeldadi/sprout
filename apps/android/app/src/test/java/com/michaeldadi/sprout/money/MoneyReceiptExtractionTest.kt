package com.michaeldadi.sprout.money

import com.google.gson.Gson
import org.junit.Assert.*
import org.junit.Test

class MoneyReceiptExtractionTest {
    private data class Case(val name: String, val text: String, val amountMinor: Long?, val merchant: String?, val date: String?)
    @Test fun sharedReceiptSuggestionsNeverConfuseTaxAndFinalTotal() {
        val rows = Gson().fromJson(javaClass.classLoader!!.getResource("receipt-text.json")!!.readText(), Array<Case>::class.java)
        for (row in rows) {
            val extraction = MoneyReceiptExtraction.parse(row.text)
            assertEquals(row.name, row.amountMinor, extraction.totals.singleOrNull())
            assertEquals(row.name, row.merchant, extraction.merchant)
            assertEquals(row.name, row.date, extraction.date)
        }
    }
    @Test fun excessiveOcrCannotBecomeAnExpenseSuggestion() {
        val result = MoneyReceiptExtraction.parse("x".repeat(12001) + "\nTOTAL $12.34")
        assertTrue(result.totals.isEmpty()); assertNull(result.merchant); assertNull(result.date)
    }
}
