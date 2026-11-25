package com.michaeldadi.sprout.money

import android.content.Context
import android.graphics.ImageDecoder
import android.net.Uri
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class MoneyCaptureFileProvider : androidx.core.content.FileProvider()

/** Bundled on-device recognition. ImageDecoder applies orientation and bounds memory. */
object MoneyReceiptOcr {
    data class Scan(val text: String, val jpeg: ByteArray?)
    fun captureDirectory(context: Context, owner: String): java.io.File {
        val scope = java.security.MessageDigest.getInstance("SHA-256").digest("${com.michaeldadi.sprout.config.AppConfig.appwriteEndpoint}/${com.michaeldadi.sprout.config.AppConfig.appwriteProjectId}/$owner".toByteArray()).joinToString("") { "%02x".format(it) }
        return java.io.File(context.cacheDir, "sprout-capture/$scope")
    }
    fun pruneAbandoned(context: Context) {
        val cutoff = System.currentTimeMillis() - 3600000
        java.io.File(context.cacheDir, "sprout-capture").walkTopDown().filter { it.isFile && it.lastModified() < cutoff }.forEach { it.delete() }
    }
    suspend fun recognize(context: Context, uri: Uri): String = scan(context, uri).text
    suspend fun scan(context: Context, uri: Uri): Scan = withContext(Dispatchers.IO) {
        val bitmap = ImageDecoder.decodeBitmap(ImageDecoder.createSource(context.contentResolver, uri)) { decoder, info, _ ->
            val largest = maxOf(info.size.width, info.size.height)
            require(largest > 0)
            if (largest > 2400) {
                val scale = 2400.0 / largest
                decoder.setTargetSize(maxOf(1, (info.size.width * scale).toInt()), maxOf(1, (info.size.height * scale).toInt()))
            }
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
        }
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        try {
            val text = Tasks.await(recognizer.process(InputImage.fromBitmap(bitmap, 0))).text
            var jpeg: ByteArray? = null
            for (quality in listOf(85, 70, 55, 40)) {
                val output = java.io.ByteArrayOutputStream()
                if (bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, quality, output) && output.size() <= 650_000) { jpeg = output.toByteArray(); break }
            }
            Scan(text, jpeg)
        }
        finally { recognizer.close(); bitmap.recycle() }
    }
}
