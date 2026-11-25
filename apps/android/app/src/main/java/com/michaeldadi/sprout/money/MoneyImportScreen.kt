package com.michaeldadi.sprout.money

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun MoneyImportScreen(repo: MoneyRepository, state: MoneyState) {
    val context = LocalContext.current; val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()
    var batch by remember { mutableStateOf<MoneyCSVImport?>(null) }; var error by remember { mutableStateOf<String?>(null) }
    var reviewed by remember { mutableStateOf(false) }; var queued by remember { mutableStateOf(false) }; var loading by remember { mutableStateOf(false) }
    var paste by remember { mutableStateOf(false) }; var csv by remember { mutableStateOf("") }
    val template = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri ->
        if (uri != null) scope.launch { runCatching { withContext(Dispatchers.IO) { context.contentResolver.openOutputStream(uri)?.use { it.write(MoneyCSVImport.template.toByteArray()) } ?: throw java.io.IOException("File unavailable") } }.onFailure { error = "Couldn't save the template. Try another destination." } }
    }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) scope.launch {
            loading = true
            try { batch = withContext(Dispatchers.IO) { context.contentResolver.openInputStream(uri)?.use { input -> val output = java.io.ByteArrayOutputStream(); val buffer = ByteArray(8192); while (output.size() <= 500_000) { val count = input.read(buffer, 0, minOf(buffer.size, 500_001 - output.size())); if (count < 0) break; output.write(buffer, 0, count) }; MoneyCSVImport.parse(output.toByteArray(), state.workspace?.transactions.orEmpty()) } ?: throw MoneyApiException("INVALID_IMPORT", "This file could not be read.") }; reviewed = false; queued = false; error = null }
            catch (e: Exception) { error = e.message ?: "The file could not be read." }
            finally { loading = false; listState.scrollToItem(0) }
        }
    }
    LazyColumn(Modifier.fillMaxSize().imePadding().testTag("money.import.list"), state = listState, contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { Text("Import transactions", style = MaterialTheme.typography.headlineLarge) }
        item { Text("Review a CSV of individual USD transactions. Negative amounts are expenses; positive amounts are income or refunds. Transfers do not count as spending. Imported records use your manual cash account.") }
        item { TextButton(onClick = { template.launch("sprout-transactions.csv") }) { Text("Save CSV template") } }
        item { OutlinedButton(onClick = { picker.launch(arrayOf("text/csv", "text/comma-separated-values", "text/plain", "application/csv")) }, enabled = !loading) { Text(if (loading) "Reading file…" else "Choose CSV file") } }
        item { TextButton(onClick = { paste = !paste }) { Text("Paste CSV text") } }
        if (paste) item { Column {
            OutlinedTextField(csv, onValueChange = { if (it.toByteArray(Charsets.UTF_8).size <= 500_000) csv = it }, label = { Text("CSV text") }, minLines = 4, modifier = Modifier.fillMaxWidth())
            TextButton(onClick = { try { batch = MoneyCSVImport.parse(csv.toByteArray(Charsets.UTF_8), state.workspace?.transactions.orEmpty()); reviewed = false; queued = false; error = null; paste = false; scope.launch { listState.scrollToItem(0) } } catch (e: Exception) { error = e.message } }) { Text("Review pasted CSV") }
        } }
        batch?.let { current ->
            item { Text("${current.rows.count { it.selected }} selected · ${current.rows.size} rows", style = MaterialTheme.typography.titleMedium) }
            item { Text("Check possible duplicates, dates and amount signs. Invalid rows are excluded until corrected. Repeating this file preserves existing records, including edits and deletions.") }
            itemsIndexed(current.rows, key = { _, row -> row.sourceIndex }) { index, row ->
                var expanded by remember { mutableStateOf(false) }
                ElevatedCard {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row { Checkbox(row.selected, onCheckedChange = { selected -> batch = current.copy(rows = current.rows.toMutableList().also { it[index] = row.copy(selected = selected) }); reviewed = false }, enabled = !queued && row.transaction(current.batchId) != null); Text("Row ${row.sourceIndex + 2}: ${row.fields["merchant"].orEmpty()}", Modifier.weight(1f)) }
                        row.warning?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
                        if (row.transaction(current.batchId) == null) Text("Correct date, merchant, USD currency, type and amount sign before selecting.", color = MaterialTheme.colorScheme.error)
                        TextButton(onClick = { expanded = !expanded }) { Text(if (expanded) "Hide fields" else "Review fields") }
                        if (expanded) listOf("date", "merchant", "amount", "type", "currency", "category", "notes").forEach { key ->
                            OutlinedTextField(row.fields[key].orEmpty(), onValueChange = { value -> batch = current.copy(rows = current.rows.toMutableList().also { it[index] = row.copy(fields = row.fields + (key to value), selected = false) }); reviewed = false }, label = { Text(key.replaceFirstChar { it.uppercase() }) }, enabled = !queued, modifier = Modifier.fillMaxWidth())
                        }
                    }
                }
            }
            item { Row { Checkbox(reviewed, onCheckedChange = { reviewed = it }, enabled = !queued); Text("I reviewed the selected records") } }
            item { Button(onClick = { scope.launch { try { repo.enqueue(current.command(), "import:${current.batchId}"); queued = true; repo.refresh() } catch (e: Exception) { error = e.message } } }, enabled = reviewed && !queued && current.rows.any { it.selected }) { Text(if (queued) "Saved for import" else "Import selected records") } }
            if (queued) item { Text("Saved on this device. Import starts when connected; progress appears below.") }
        }
        state.workspace?.jobs.orEmpty().filter { it.type == "transaction.import" }.sortedWith(compareByDescending<MoneyJob> { it.batchId == batch?.batchId }.thenByDescending { it.updatedAt.orEmpty() }).forEach { job ->
            item(key = job.id) {
                ElevatedCard { Column(Modifier.padding(16.dp)) {
                    if (job.batchId == batch?.batchId) Text("Current file", style = MaterialTheme.typography.labelMedium)
                    Text("CSV import · ${job.status.replace('_', ' ')}", style = MaterialTheme.typography.titleMedium)
                    job.updatedAt?.let { value -> runCatching { java.time.Instant.parse(value).atZone(java.time.ZoneId.systemDefault()).format(java.time.format.DateTimeFormatter.ofLocalizedDateTime(java.time.format.FormatStyle.MEDIUM)) }.getOrNull()?.let { Text("Updated $it", style = MaterialTheme.typography.bodySmall) } }
                    job.progress?.let { Text("${it.processed} of ${it.total} processed · ${it.imported} added · ${it.preserved} existing records preserved", Modifier.testTag("money.import.progress.${job.batchId}")) }
                    if (job.status == "needs_attention") TextButton(onClick = { scope.launch { try { repo.enqueue(mapOf("type" to "transaction.import.resume", "id" to job.id), "import-resume:${job.id}"); repo.refresh() } catch (e: Exception) { error = e.message } } }) { Text("Resume import") }
                } }
            }
        }
        item { TextButton(onClick = { scope.launch { repo.refresh() } }) { Text("Refresh import progress") } }
        error?.let { item { Text(it, color = MaterialTheme.colorScheme.error) } }
    }
}
