package com.michaeldadi.sprout.money

import com.google.gson.JsonParser
import java.io.File
import java.security.MessageDigest
import java.time.Instant
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

internal object MoneyExportArchive {
    data class Receipt(val id: String, val fileId: String, val bucketId: String, val sha256: String, val bytes: Int)
    fun receipts(json: ByteArray, bucket: String): List<Receipt> {
        require(json.size <= 9_000_000)
        val root = JsonParser.parseString(json.toString(Charsets.UTF_8)).asJsonObject
        require(root["schemaVersion"].asInt == 1 && root["revision"].asLong >= 0)
        Instant.parse(root["exportedAt"].asString)
        val receipts = root.getAsJsonObject("records").getAsJsonArray("receipts") ?: return emptyList()
        val ready = receipts.mapNotNull { row ->
            val record = row.asJsonObject
            val data = record.getAsJsonObject("data")
            if (record["deleted"].asBoolean || data["status"].asString != "ready") null
            else Receipt(record["id"].asString, data["fileId"].asString, data["bucketId"].asString, data["sha256"].asString, data["bytes"].asInt)
        }
        require(ready.size <= 100 && ready.map { it.id }.toSet().size == ready.size)
        require(ready.all { UUID.fromString(it.id).toString() == it.id && it.bucketId == bucket && it.bytes in 1..650_000 && it.sha256.matches(Regex("[a-f0-9]{64}")) })
        require(ready.sumOf { it.bytes.toLong() } <= 50_000_000)
        return ready
    }
    fun verify(bytes: ByteArray, receipt: Receipt) {
        require(bytes.size == receipt.bytes && MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) } == receipt.sha256)
    }
    suspend fun write(target: File, json: ByteArray, bucket: String, load: suspend (Receipt) -> ByteArray) {
        val receipts = receipts(json, bucket)
        try {
            ZipOutputStream(target.outputStream()).use { zip ->
                fun entry(name: String, bytes: ByteArray) { zip.putNextEntry(ZipEntry(name)); zip.write(bytes); zip.closeEntry() }
                entry("sprout-export.json", json)
                entry("README.txt", "Sprout private export\nFinancial records and receipt metadata are in sprout-export.json. Ready retained copies are in receipts/<receipt-id>.jpg. Pending uploads and removing copies remain described by their metadata and are not represented as available files. Export reflects the JSON snapshot timestamp. Store this archive securely.\n".toByteArray())
                for (receipt in receipts) { val bytes = load(receipt); verify(bytes, receipt); entry("receipts/${receipt.id}.jpg", bytes) }
            }
        } catch (error: Throwable) { target.delete(); throw error }
    }
}
