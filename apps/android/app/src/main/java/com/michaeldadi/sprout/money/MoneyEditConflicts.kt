package com.michaeldadi.sprout.money

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.google.gson.Gson
import com.google.gson.JsonObject
import kotlinx.coroutines.launch

/** Immutable local/server pair used for a single explicit conflict decision. */
data class MoneyEditConflictReview(val mutation: MoneyMutation, val entityId: String, val kind: String, val localSummary: String, val serverSummary: String?, val serverVersion: Int?) {
    fun command(): Map<String, Any?> {
        val version = serverVersion?.takeIf { it > 0 } ?: throw MoneyApiException("REVIEW_REQUIRED", "The synced record is unavailable. Refresh before making a new edit.")
        val command = Gson().fromJson(mutation.payload, JsonObject::class.java).getAsJsonObject("command")
        val key = if (kind == "expense") "transaction" else "goal"
        return mapOf("type" to command["type"].asString, key to command[key], "expectedVersion" to version)
    }
    fun currentVersion(workspace: MoneyWorkspace?): Int? = if (kind == "expense") workspace?.transactions?.firstOrNull { it.id == entityId && it.source != "plaid" && it.providerId == null }?.version else workspace?.goals?.firstOrNull { it.id == entityId && !it.deleted }?.version
    companion object {
        fun capture(mutation: MoneyMutation, workspace: MoneyWorkspace?): MoneyEditConflictReview? = runCatching {
            require(mutation.conflict)
            val gson = Gson(); val command = gson.fromJson(mutation.payload, JsonObject::class.java).getAsJsonObject("command")
            when (command["type"].asString) {
                "transaction.upsert" -> {
                    val local = decodePendingTransaction(command, gson)
                    val server = workspace?.transactions?.firstOrNull { it.id == local.id && it.source != "plaid" && it.providerId == null }
                    MoneyEditConflictReview(mutation, local.id, "expense", summary(local), server?.let(::summary), server?.version)
                }
                "goal.upsert" -> {
                    val local = gson.fromJson(command["goal"], MoneyGoal::class.java)
                    val server = workspace?.goals?.firstOrNull { it.id == local.id && !it.deleted }
                    MoneyEditConflictReview(mutation, local.id, "goal", summary(local), server?.data?.let(::summary), server?.version)
                }
                else -> error("Unsupported conflict")
            }
        }.getOrNull()
        private fun summary(item: MoneyTransaction) = "${item.merchant}\n${item.amount.formatted()} · ${item.type}\n${item.date} · ${item.category}\n${if(item.excluded) "Excluded from totals" else "Included in totals"}\n${item.description}"
        private fun summary(item: MoneyGoal) = "${item.name}\n${item.allocated.formatted()} allocated of ${item.target.formatted()}\nTarget date: ${item.targetDate ?: "none"}\n${if(item.archived) "Archived" else "Active"}"
    }
}

@Composable
fun MoneyEditConflictButton(repo: MoneyRepository, state: MoneyState, mutation: MoneyMutation) {
    var selected by remember { mutableStateOf<MoneyEditConflictReview?>(null) }; var error by remember { mutableStateOf<String?>(null) }; var saving by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    TextButton(modifier = Modifier.testTag("money.conflict.${mutation.entity}"), enabled = !state.refreshing, onClick = { selected = MoneyEditConflictReview.capture(mutation, state.workspace); error = null }) { Text("Review saved edit") }
    selected?.let { review ->
        AlertDialog(onDismissRequest = { if (!saving) selected = null }, title = { Text("Review ${review.kind} change") }, text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Your saved edit", style = MaterialTheme.typography.titleSmall); Text(review.localSummary)
                Text("Latest synced ${review.kind}", style = MaterialTheme.typography.titleSmall); Text(review.serverSummary ?: "This record is no longer available. Your edit remains on this device; it cannot replace a missing record.")
                Text("Compare both versions before choosing. Closing this review preserves your saved edit.")
                error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            }
        }, confirmButton = { TextButton(enabled = !saving && !state.refreshing && review.serverVersion != null, onClick = { saving = true; scope.launch { try { repo.keepReviewedEdit(review); selected = null; repo.refresh() } catch (e: Exception) { error = e.message } finally { saving = false } } }) { Text("Keep my ${review.kind} edit") } },
            dismissButton = { TextButton(enabled = !saving, onClick = { saving = true; scope.launch { try { repo.discardReviewedEdit(review); selected = null } catch (e: Exception) { error = e.message } finally { saving = false } } }) { Text(if (review.serverVersion == null) "Discard this edit" else "Use synced ${review.kind}") } })
    }
}
