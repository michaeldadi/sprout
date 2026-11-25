package com.michaeldadi.sprout.money

import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.security.MessageDigest
import java.util.zip.ZipFile

class MoneyExportArchiveTest {
    private val image = byteArrayOf(-1, -40, -1, 1, 2, 3, -1, -39)
    private val id = "12345678-1234-1234-1234-123456789abc"
    private val sha = MessageDigest.getInstance("SHA-256").digest(image).joinToString("") { "%02x".format(it) }
    private fun json(bucket: String = "private", checksum: String = sha, status: String = "ready", receiptId: String = id) = """{"schemaVersion":1,"revision":7,"exportedAt":"2026-11-10T10:00:00.000Z","records":{"transactions":[],"receipts":[{"id":"$receiptId","deleted":false,"data":{"status":"$status","fileId":"file","bucketId":"$bucket","sha256":"$checksum","bytes":8}}]}}""".toByteArray()
    @Test fun archiveContainsVerifiedFinancialSnapshotAndRetainedImage() = runBlocking {
        val target = File.createTempFile("sprout-export-test", ".zip")
        try {
            val json = json()
            MoneyExportArchive.write(target, json, "private") { image }
            ZipFile(target).use { zip ->
                assertArrayEquals(json, zip.getInputStream(zip.getEntry("sprout-export.json")).readBytes())
                assertArrayEquals(image, zip.getInputStream(zip.getEntry("receipts/$id.jpg")).readBytes())
                assertEquals(3, zip.size())
            }
        } finally { target.delete() }
    }
    @Test fun failedOrMissingReceiptNeverLeavesAShareablePartialArchive() = runBlocking {
        for (source in listOf(json(), json(checksum = "a".repeat(64)))) {
            val target = File.createTempFile("sprout-export-test", ".zip")
            try { MoneyExportArchive.write(target, source, "private") { if (source.contentEquals(json())) error("missing file") else image }; fail("Expected recovery") } catch (_: Exception) { assertFalse(target.exists()) }
        }
    }
    @Test fun snapshotRejectsCrossBucketAndUnsafeReferencesWhileDescribingPendingCopies() {
        for (source in listOf(json(bucket = "other"), json(receiptId = "../escape"))) {
            try { MoneyExportArchive.receipts(source, "private"); fail("Expected invalid reference") } catch (_: Exception) { }
        }
        assertTrue(MoneyExportArchive.receipts(json(status = "uploading"), "private").isEmpty())
    }
}
