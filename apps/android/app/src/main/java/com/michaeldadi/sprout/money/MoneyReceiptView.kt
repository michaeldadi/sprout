package com.michaeldadi.sprout.money

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.google.gson.JsonParser
import com.michaeldadi.sprout.services.AppwriteConnection
import com.michaeldadi.sprout.services.AppwriteNativeSession
import io.appwrite.services.Storage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun MoneyReceiptSection(repo: MoneyRepository, state: MoneyState, transactionId: String) {
    val pending = state.mutations.filter { m -> MoneyReceiptArchive.reference(m.payload) != null && runCatching { JsonParser.parseString(m.payload).asJsonObject.getAsJsonObject("command")["transactionId"].asString == transactionId }.getOrDefault(false) }
    val localIds = pending.mapNotNull { MoneyReceiptArchive.reference(it.payload) }.toSet()
    pending.forEach { m ->
        Surface(shape = MaterialTheme.shapes.extraLarge, modifier = Modifier.fillMaxWidth()) { Column(Modifier.padding(20.dp)) {
            Text(if (m.conflict) "Receipt upload needs review" else "Receipt saved on this device", style = MaterialTheme.typography.titleMedium)
            Text(if (m.conflict) "Review or discard the pending copy in Profile. Your transaction remains saved." else "The private copy uploads after its transaction has synced.")
            MoneyPendingReceiptButton(repo, m)
        } }
    }
    state.workspace?.receipts.orEmpty().filter { it.transactionId == transactionId && it.id !in localIds }.forEach { MoneyReceiptRow(repo, state, it) }
}

@Composable
fun MoneyPendingReceiptButton(repo: MoneyRepository, mutation: MoneyMutation) {
    val context = LocalContext.current; val scope = rememberCoroutineScope()
    var jpeg by remember { mutableStateOf<ByteArray?>(null) }; var error by remember { mutableStateOf<String?>(null) }
    TextButton(onClick = { scope.launch { try { val id = MoneyReceiptArchive.reference(mutation.payload) ?: return@launch; jpeg = withContext(Dispatchers.IO) { MoneyReceiptArchive.read(context, repo.identity.id, id) } } catch (e: Exception) { error = e.message } } }) { Text("View on-device receipt copy") }
    error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
    jpeg?.let { MoneyReceiptImage(it, repo.identity.id) { jpeg = null } }
}

@Composable
private fun MoneyReceiptRow(repo: MoneyRepository, state: MoneyState, receipt: MoneyReceipt) {
    val scope = rememberCoroutineScope(); var busy by remember { mutableStateOf(false) }; var error by remember { mutableStateOf<String?>(null) }
    var jpeg by remember { mutableStateOf<ByteArray?>(null) }; var removal by remember { mutableStateOf<Int?>(null) }
    val removing = receipt.status == "removing" || state.mutations.any { it.entity == "receipt-remove:${receipt.id}" || it.entity == "receipt-cancel:${receipt.id}" }
    LaunchedEffect(removing) { if (removing) jpeg = null }
    Surface(shape = MaterialTheme.shapes.extraLarge, modifier = Modifier.fillMaxWidth()) { Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Private receipt copy", style = MaterialTheme.typography.titleMedium)
        Text(android.text.format.Formatter.formatShortFileSize(LocalContext.current, receipt.bytes.toLong()), style = MaterialTheme.typography.bodySmall)
        if (removing) Text("Removal is saved and will finish when connected. Previously started uploads are reconciled first.")
        else if (receipt.status == "ready") TextButton(enabled = !busy, onClick = {
            scope.launch {
                busy = true
                try {
                    check(AppwriteNativeSession.identity.value?.id == repo.identity.id)
                    val data = withContext(Dispatchers.IO) { Storage(AppwriteConnection.client()).getFileDownload(bucketId = receipt.bucketId!!, fileId = receipt.fileId!!) }
                    check(AppwriteNativeSession.identity.value?.id == repo.identity.id && data.size == receipt.bytes && data.size <= 650_000 && MoneyReceiptArchive.sha(data) == receipt.sha256)
                    jpeg = data; error = null
                } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
                catch (_: Exception) { error = "The private receipt could not be opened. Connect to Sprout and try again." }
                finally { busy = false }
            }
        }) { Text(if (busy) "Opening receipt…" else "View private receipt") }
        else Text(if (receipt.status == "awaiting_upload") "Waiting for this device's saved copy to upload." else "Private upload is being recovered.")
        TextButton(enabled = !removing, onClick = { removal = receipt.version }) { Text("Remove Sprout receipt copy", color = MaterialTheme.colorScheme.error) }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
    } }
    removal?.let { version -> AlertDialog(onDismissRequest = { removal = null }, title = { Text("Remove this private Sprout copy?") }, confirmButton = { TextButton(onClick = { removal = null; scope.launch { try { repo.enqueue(mapOf("type" to "receipt.remove", "id" to receipt.id, "expectedVersion" to version), "receipt-remove:${receipt.id}"); jpeg = null; repo.refresh() } catch (e: Exception) { error = e.message } } }) { Text("Remove receipt copy") } }, dismissButton = { TextButton(onClick = { removal = null }) { Text("Keep") } }) }
    jpeg?.let { MoneyReceiptImage(it, repo.identity.id) { jpeg = null } }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MoneyReceiptImage(data: ByteArray, owner: String, close: () -> Unit) {
    val context = LocalContext.current; val scope = rememberCoroutineScope()
    var bitmap by remember { mutableStateOf<android.graphics.Bitmap?>(null) }; var error by remember { mutableStateOf<String?>(null) }; var temporary by remember { mutableStateOf<java.io.File?>(null) }
    LaunchedEffect(data) {
        try {
            check(AppwriteNativeSession.identity.value?.id == owner && data.size <= 650_000)
            bitmap = withContext(Dispatchers.IO) {
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }; BitmapFactory.decodeByteArray(data, 0, data.size, bounds); check(bounds.outWidth > 0 && bounds.outHeight > 0)
                var sample = 1; while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 2400) sample *= 2
                BitmapFactory.decodeByteArray(data, 0, data.size, BitmapFactory.Options().apply { inSampleSize = sample }) ?: throw IllegalStateException("Image unavailable")
            }
            check(AppwriteNativeSession.identity.value?.id == owner)
        } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled } catch (_: Exception) { error = "This receipt image could not be opened." }
    }
    DisposableEffect(Unit) { onDispose { temporary?.delete() } }
    ModalBottomSheet(onDismissRequest = close, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Private receipt", style = MaterialTheme.typography.headlineSmall)
            bitmap?.let { Image(it.asImageBitmap(), "Receipt image. Reviewed transaction details are on the previous screen.", Modifier.fillMaxWidth().aspectRatio(it.width.toFloat() / it.height)) }
            if (bitmap != null) TextButton(onClick = { scope.launch { try {
                check(AppwriteNativeSession.identity.value?.id == owner)
                val file = withContext(Dispatchers.IO) { val account = MoneyReceiptArchive.sha("${com.michaeldadi.sprout.config.AppConfig.appwriteEndpoint}/${com.michaeldadi.sprout.config.AppConfig.appwriteProjectId}/$owner".toByteArray()); val directory = java.io.File(context.cacheDir, "sprout-exports/$account"); check(directory.isDirectory || directory.mkdirs()); java.io.File(directory, "receipt-${java.util.UUID.randomUUID()}.jpg").apply { writeBytes(data) } }
                temporary?.delete(); temporary = file; check(AppwriteNativeSession.identity.value?.id == owner)
                val uri = androidx.core.content.FileProvider.getUriForFile(context, "${context.packageName}.exports", file)
                val intent = android.content.Intent(android.content.Intent.ACTION_SEND).setType("image/jpeg").putExtra(android.content.Intent.EXTRA_STREAM, uri).addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION).apply { clipData = android.content.ClipData.newRawUri("Sprout receipt", uri) }
                context.startActivity(android.content.Intent.createChooser(intent, "Save or share a copy"))
            } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled } catch (_: Exception) { error = "This copy could not be prepared for sharing." } } }) { Text("Save or share a copy") }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            TextButton(onClick = close) { Text("Close") }; Spacer(Modifier.height(24.dp))
        }
    }
}
