package com.michaeldadi.sprout.money

import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.security.MessageDigest
import java.time.LocalDate

data class MoneyImportRow(val sourceIndex: Int, val fields: Map<String, String>, val selected: Boolean = false, val warning: String? = null) {
    fun transaction(batchId: String): MoneyTransaction? {
        val date = fields["date"].orEmpty(); val merchant = fields["merchant"].orEmpty().trim()
        val raw = fields["amount"].orEmpty(); val type = fields["type"].orEmpty(); val category = fields["category"].orEmpty().trim()
        if (fields["currency"] != "USD" || type !in listOf("expense", "income", "refund", "transfer") || !Regex("^-?\\d+(\\.\\d{1,2})?$").matches(raw)) return null
        val absolute = MoneyAmount.parse(raw.removePrefix("-")) ?: return null
        if (merchant.isEmpty() || merchant.length > 160 || category.isEmpty() || category.length > 80 || fields["notes"].orEmpty().length > 1000 || !Regex("^\\d{4}-\\d{2}-\\d{2}$").matches(date) || runCatching { LocalDate.parse(date).toString() == date }.getOrDefault(false).not()) return null
        val minor = if (raw.startsWith("-")) -absolute else absolute
        if (type != "transfer" && if (type == "expense") minor >= 0 else minor <= 0) return null
        return MoneyTransaction(MoneyCSVImport.transactionId(batchId, sourceIndex), MoneyAmount(minor), date, merchant, category, type, "import", description = fields["notes"].orEmpty())
    }
}

data class MoneyCSVImport(val batchId: String, val rows: List<MoneyImportRow>) {
    fun command(): Map<String, Any> {
        val selected = rows.filter { it.selected }
        if (selected.isEmpty()) invalid("Select at least one reviewed row.")
        val values = selected.map { row -> mapOf("sourceIndex" to row.sourceIndex, "transaction" to (row.transaction(batchId) ?: invalid("Correct the selected rows before importing.")).commandValue()) }
        val command = mapOf("type" to "transaction.import", "batchId" to batchId, "rows" to values)
        if (com.google.gson.Gson().toJson(command).toByteArray(Charsets.UTF_8).size >= 950_000) invalid("Select fewer records for this import.")
        return command
    }
    companion object {
        const val template = "date,merchant,amount,type,currency,category,notes\n2026-11-10,Example cafe,-5.40,expense,USD,Food,\n"
        private fun hash(data: ByteArray): String = MessageDigest.getInstance("SHA-256").digest(data).joinToString("") { "%02x".format(it.toInt() and 255) }
        fun transactionId(batchId: String, index: Int): String = "import-" + hash("$batchId:$index".toByteArray(Charsets.UTF_8))
        fun parse(data: ByteArray, existing: List<MoneyTransaction> = emptyList()): MoneyCSVImport {
            if (data.size > 500_000) invalid("Choose a UTF-8 CSV file under 500 KB.")
            val text = runCatching { Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(data)).toString() }.getOrElse { invalid("Choose a UTF-8 CSV file under 500 KB.") }.removePrefix("\uFEFF").replace("\r\n", "\n").replace("\r", "\n")
            if (text.contains('\u0000')) invalid("Choose a UTF-8 CSV file under 500 KB.")
            val table = cells(text); val headers = table.firstOrNull()?.map { it.trim().lowercase(java.util.Locale.ROOT) } ?: invalid("This file is empty.")
            val required = setOf("date", "merchant", "amount", "type", "currency")
            if (headers.toSet().size != headers.size || !headers.containsAll(required) || !required.plus(setOf("category", "notes")).containsAll(headers)) invalid("Use the Sprout CSV headers: date, merchant, amount, type, currency, category, notes.")
            val batchId = hash(text.toByteArray(Charsets.UTF_8)); val rows = mutableListOf<MoneyImportRow>(); val seen = mutableSetOf<String>()
            table.drop(1).forEachIndexed { index, values ->
                if (values.all { it.isEmpty() }) return@forEachIndexed
                if (index >= 10_000 || values.size != headers.size || rows.size >= 1000) invalid("Check column counts and import at most 1,000 records at a time.")
                val fields = headers.zip(values).toMap().toMutableMap(); fields["category"] = fields["category"].takeUnless { it.isNullOrEmpty() } ?: "Other"
                var row = MoneyImportRow(index, fields); val item = row.transaction(batchId)
                if (item != null) {
                    val key = "${item.date}|${item.amount.minor}|${item.merchant.lowercase(java.util.Locale.ROOT)}"
                    val duplicate = !seen.add(key) || existing.any { it.id == item.id || it.date == item.date && it.amount == item.amount && it.merchant.lowercase(java.util.Locale.ROOT) == item.merchant.lowercase(java.util.Locale.ROOT) }
                    row = row.copy(selected = !duplicate, warning = if (duplicate) "Possible duplicate. Excluded until you select it." else null)
                }
                rows += row
            }
            if (rows.isEmpty()) invalid("This file has no transaction rows.")
            return MoneyCSVImport(batchId, rows)
        }
        private fun invalid(message: String): Nothing = throw MoneyApiException("INVALID_IMPORT", message)
        private fun cells(text: String): List<List<String>> {
            val rows = mutableListOf<List<String>>(); var row = mutableListOf<String>(); val field = StringBuilder(); var quoted = false; var closed = false; var index = 0
            while (index < text.length) {
                val c = text[index]
                if (quoted) {
                    if (c == '"') {
                        if (index + 1 < text.length && text[index + 1] == '"') { field.append('"'); index++ } else { quoted = false; closed = true }
                    } else field.append(c)
                } else if (c == ',' || c == '\n') {
                    row += field.toString(); field.setLength(0); closed = false
                    if (c == '\n') { rows += row; row = mutableListOf() }
                } else if (c == '"' && field.isEmpty() && !closed) quoted = true
                else { if (closed || c == '"') invalid("Check the quoted CSV fields."); field.append(c) }
                if (rows.size > 10_001 || field.length > 4000) invalid("This file has too many rows or an oversized field.")
                index++
            }
            if (quoted) invalid("A quoted CSV field was not closed.")
            if (field.isNotEmpty() || row.isNotEmpty() || closed) { row += field.toString(); rows += row }
            return rows
        }
    }
}
