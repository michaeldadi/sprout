package com.michaeldadi.sprout.money

import android.content.Context
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.michaeldadi.sprout.config.AppConfig
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.UUID

/** Durable CE-protected app files, partitioned exactly like the financial outbox. */
object MoneyReceiptArchive {
    private fun directory(context: Context, owner: String): File {
        val scope = sha("${AppConfig.appwriteEndpoint}/${AppConfig.appwriteProjectId}/$owner".toByteArray(Charsets.UTF_8))
        return File(context.filesDir, "sprout-receipts/$scope")
    }
    private fun file(context: Context, owner: String, id: String): File {
        if (runCatching { UUID.fromString(id).toString() == id }.getOrDefault(false).not()) throw MoneyApiException("INVALID_RECEIPT", "This local receipt reference needs review.")
        return File(directory(context, owner), "$id.jpg")
    }
    fun sha(data: ByteArray): String = MessageDigest.getInstance("SHA-256").digest(data).joinToString("") { "%02x".format(it.toInt() and 255) }
    fun save(context: Context, owner: String, id: String, jpeg: ByteArray) {
        if (jpeg.size > 650_000) throw MoneyApiException("INVALID_RECEIPT", "Choose a smaller receipt copy.")
        val target = file(context, owner, id); check(target.parentFile!!.isDirectory || target.parentFile!!.mkdirs())
        val temporary = File(target.parentFile, ".pending-${UUID.randomUUID()}")
        try { FileOutputStream(temporary).use { it.write(jpeg); it.fd.sync() }; check(temporary.renameTo(target)) }
        finally { temporary.delete() }
    }
    fun read(context: Context, owner: String, id: String): ByteArray {
        val file = file(context, owner, id)
        if (!file.isFile) throw MoneyApiException("RECEIPT_LOCAL_MISSING", "This device no longer has the pending receipt copy. Choose its photo again, or discard the pending copy in Profile.")
        if (file.length() > 650_000) throw MoneyApiException("INVALID_RECEIPT", "The pending receipt copy needs review.")
        return file.readBytes()
    }
    fun wire(context: Context, owner: String, payload: String): String {
        val value = JsonParser.parseString(payload).asJsonObject; val command = value.getAsJsonObject("command"); val id = reference(payload)
            ?: throw MoneyApiException("INVALID_RECEIPT", "This local receipt reference needs review.")
        val jpeg = read(context, owner, id)
        if (sha(jpeg) != command["sha256"]?.asString) throw MoneyApiException("RECEIPT_LOCAL_CHANGED", "The pending receipt image changed. Choose its photo again before uploading.")
        command.addProperty("jpegBase64", android.util.Base64.encodeToString(jpeg, android.util.Base64.NO_WRAP)); value.remove("attachmentFile")
        return value.toString()
    }
    fun reference(payload: String): String? = runCatching {
        val value = JsonParser.parseString(payload).asJsonObject; val command = value.getAsJsonObject("command"); val id = command["id"].asString
        if (command["type"].asString == "receipt.attach" && value["attachmentFile"]?.asString == "$id.jpg") id else null
    }.getOrNull()
    fun remove(context: Context, owner: String, id: String) { val file = file(context, owner, id); check(!file.exists() || file.delete()) }
    fun erase(context: Context, owner: String) { val directory = directory(context, owner); check(!directory.exists() || directory.deleteRecursively()) }
    fun prune(context: Context, owner: String, keeping: Set<String>) {
        directory(context, owner).listFiles()?.filter { it.extension == "jpg" && runCatching { UUID.fromString(it.nameWithoutExtension) }.isSuccess && it.nameWithoutExtension !in keeping }?.forEach { check(it.delete()) }
    }
}
