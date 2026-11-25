package com.michaeldadi.sprout.money

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import com.google.gson.Gson
import com.google.gson.JsonObject
import kotlinx.coroutines.launch

/** The exact local/server pair presented for a user's conflict decision. */
data class MoneyBudgetConflictReview(
    val mutation: MoneyMutation,
    val local: MoneyBudget,
    val server: MoneyRecord<MoneyBudget>?,
) {
    fun command(): Map<String, Any?> {
        val target = server ?: throw MoneyApiException("REVIEW_REQUIRED", "The server budget is unavailable. Refresh and review your plan.")
        return mapOf("type" to "budget.upsert", "budget" to local.copy(id = target.id), "expectedVersion" to target.version)
    }

    companion object {
        fun capture(mutation: MoneyMutation, budgets: List<MoneyRecord<MoneyBudget>>): MoneyBudgetConflictReview? = runCatching {
            require(mutation.conflict)
            val gson = Gson()
            val command = gson.fromJson(mutation.payload, JsonObject::class.java).getAsJsonObject("command")
            require(command["type"].asString == "budget.upsert")
            val local = gson.fromJson(command["budget"], MoneyBudget::class.java)
            require(local.category.isNotBlank() && local.month.matches(Regex("\\d{4}-(0[1-9]|1[0-2])")) && local.limit.currency == "USD" && local.limit.minor > 0)
            val available = budgets.filterNot { it.deleted }
            val server = available.firstOrNull { it.id == local.id } ?: available.firstOrNull { it.data.month == local.month && MoneyBudget.categoryKey(it.data.category) == MoneyBudget.categoryKey(local.category) }
            MoneyBudgetConflictReview(mutation, local, server)
        }.getOrNull()
    }
}

fun moneyPendingSyncCopy(mutations: List<MoneyMutation>): String = when {
    mutations.all { it.conflict } -> "A saved change needs review in Profile before it can sync."
    mutations.any { it.conflict } -> "Some changes need review in Profile. Other saved changes retry when Sprout connects."
    else -> "Saved on this device. Pending changes retry when Sprout can connect."
}

@Composable
fun MoneyBudgetConflicts(repo: MoneyRepository, state: MoneyState) {
    val conflicts = state.mutations.filter { it.conflict && it.entity.startsWith("budget:") }
    if (conflicts.isEmpty()) return
    var selected by remember { mutableStateOf<MoneyBudgetConflictReview?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var saving by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    Surface(shape = MaterialTheme.shapes.extraLarge, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Budget changes need review", style = MaterialTheme.typography.titleMedium)
            conflicts.forEach { mutation ->
                val review = MoneyBudgetConflictReview.capture(mutation, state.workspace?.budgets.orEmpty())
                if (review == null) Text("A saved budget edit could not be opened. It remains on this device; you can discard it in Profile.")
                else {
                    Text("${review.local.category} · ${review.local.month}")
                    TextButton(enabled = !state.refreshing, onClick = { error = null; selected = review }, modifier = Modifier.semantics { contentDescription = "Review ${review.local.category} budget for ${review.local.month}" }) { Text("Review budget change") }
                }
            }
        }
    }
    selected?.let { review ->
        AlertDialog(
            onDismissRequest = { if (!saving) selected = null },
            title = { Text("Review budget change") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("Your saved edit", style = MaterialTheme.typography.titleSmall)
                    Text("${review.local.category} · ${review.local.month} · ${review.local.limit.formatted()}")
                    Text("Latest synced budget", style = MaterialTheme.typography.titleSmall)
                    review.server?.data?.let { Text("${it.category} · ${it.month} · ${it.limit.formatted()}") } ?: Text("This budget is no longer available. Refresh and review your plan before adding a new limit.")
                    Text("Review both before choosing. Closing this sheet keeps your edit on this device.", style = MaterialTheme.typography.bodySmall)
                    error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                }
            },
            confirmButton = { TextButton(enabled = !saving && review.server != null, onClick = {
                saving = true
                scope.launch { try { repo.keepBudgetEdit(review); selected = null } catch (e: Exception) { error = e.message } finally { saving = false } }
            }) { Text("Keep my budget edit") } },
            dismissButton = { TextButton(enabled = !saving, onClick = {
                saving = true
                scope.launch { try { repo.useServer(review.mutation); selected = null } catch (e: Exception) { error = e.message } finally { saving = false } }
            }) { Text(if (review.server == null) "Discard this edit" else "Use synced budget") } },
        )
    }
}
