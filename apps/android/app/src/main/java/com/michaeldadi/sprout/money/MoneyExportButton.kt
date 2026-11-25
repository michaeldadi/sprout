package com.michaeldadi.sprout.money

import android.content.ClipData
import android.content.Intent
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.FileProvider
import com.michaeldadi.sprout.BuildConfig
import com.michaeldadi.sprout.config.AppConfig
import com.michaeldadi.sprout.services.AppwriteConnection
import com.michaeldadi.sprout.services.AppwriteNativeSession
import io.appwrite.services.Storage
import java.io.File
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
internal fun MoneyExportButton(fileId: String, bucketId: String, owner: String) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var progress by remember { mutableStateOf("Preparing export…") }
    TextButton(
        enabled = !busy,
        onClick = {
            scope.launch {
                busy = true
                try {
                    check(AppwriteNativeSession.identity.value?.id == owner)
                    val file =
                        withContext(Dispatchers.IO) {
                            val data =
                                Storage(AppwriteConnection.client())
                                    .getFileDownload(bucketId = bucketId, fileId = fileId)
                            check(AppwriteNativeSession.identity.value?.id == owner)
                            val accountScope =
                                java.security.MessageDigest.getInstance("SHA-256")
                                    .digest(
                                        "${AppConfig.appwriteEndpoint}/${AppConfig.appwriteProjectId}/$owner"
                                            .toByteArray()
                                    )
                                    .joinToString("") { "%02x".format(it) }
                            val directory = File(context.cacheDir, "sprout-exports/$accountScope")
                            check(directory.exists() || directory.mkdirs())
                            val target = File(directory, "sprout-${UUID.randomUUID()}.zip")
                            var index = 0
                            MoneyExportArchive.write(target, data, bucketId) { receipt ->
                                check(AppwriteNativeSession.identity.value?.id == owner)
                                withContext(Dispatchers.Main) { progress = "Preparing receipt ${++index}…" }
                                Storage(AppwriteConnection.client()).getFileDownload(bucketId = receipt.bucketId, fileId = receipt.fileId).also { check(AppwriteNativeSession.identity.value?.id == owner) }
                            }
                            check(AppwriteNativeSession.identity.value?.id == owner)
                            target
                        }
                    check(AppwriteNativeSession.identity.value?.id == owner)
                    val uri =
                        FileProvider.getUriForFile(
                            context,
                            "${BuildConfig.APPLICATION_ID}.exports",
                            file,
                        )
                    val intent =
                        Intent(Intent.ACTION_SEND)
                            .setType("application/zip")
                            .putExtra(Intent.EXTRA_STREAM, uri)
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    intent.clipData = ClipData.newRawUri("Sprout export", uri)
                    context.startActivity(Intent.createChooser(intent, "Save or share export"))
                } catch (_: Exception) {
                    error =
                        "Your export could not be prepared. Sign in to the same account and retry, or request a fresh export if a retained receipt was removed."
                }
                busy = false
            }
        },
    ) {
        Text(if (busy) progress else "Download private export")
    }
    error?.let { Text(it) }
}
