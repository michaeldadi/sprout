package com.michaeldadi.sprout.money

import java.math.BigDecimal
import java.time.LocalDate

/** Suggestions from on-device OCR. No extraction authorizes a save. */
data class MoneyReceiptExtraction(
    val totals: List<Long> = emptyList(),
    val merchant: String? = null,
    val date: String? = null,
) {
    val amount: String get() = totals.singleOrNull()?.let { BigDecimal.valueOf(it, 2).toPlainString() }.orEmpty()

    companion object {
        fun parse(text: String): MoneyReceiptExtraction {
            if (text.length > SproutReceiptRules.maxCharacters) return MoneyReceiptExtraction()
            val lines = text.lineSequence().map { it.trim().replace(Regex("\\s+"), " ") }.filter(String::isNotEmpty).toList()
            val insensitive = RegexOption.IGNORE_CASE
            val foreign = Regex(SproutCaptureRules.unsupportedCurrency, insensitive).containsMatchIn(text)
            val refund = lines.any { Regex(SproutReceiptRules.refund, insensitive).containsMatchIn(it) }
            val totalPattern = Regex(SproutReceiptRules.finalTotal, insensitive)
            val totals = if (foreign || refund) emptyList() else lines.mapNotNull { line ->
                totalPattern.matchEntire(line)?.groupValues?.get(1)?.replace(",", "")?.let(MoneyAmount::parse)
            }.distinct().sorted()
            val noise = Regex(SproutReceiptRules.merchantNoise, insensitive)
            val merchant = lines.take(6).firstOrNull { line -> line.length <= 160 && line.count(Char::isLetter) >= 2 && !noise.containsMatchIn(line) }
            val dates = Regex(SproutReceiptRules.date).findAll(text).mapNotNull { match ->
                val g = match.groupValues
                runCatching {
                    val year = (if(g[1].isNotEmpty()) g[1] else g[6]).toInt()
                    val month = (if(g[1].isNotEmpty()) g[2] else g[4]).toInt()
                    val day = (if(g[1].isNotEmpty()) g[3] else g[5]).toInt()
                    require(year in 1900..2100)
                    LocalDate.of(year, month, day).toString()
                }.getOrNull()
            }.distinct().toList()
            return MoneyReceiptExtraction(totals, merchant, dates.singleOrNull())
        }
    }
}
