package com.michaeldadi.sprout.money

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import java.time.LocalDate
import java.util.UUID
import kotlinx.coroutines.launch

@Composable
fun MoneyGoals(repo: MoneyRepository, state: MoneyState) {
    var selected by remember { mutableStateOf<MoneyRecord<MoneyGoal>?>(null) }
    var editor by remember { mutableStateOf(false) }
    var showArchived by rememberSaveable { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    Surface(shape = MaterialTheme.shapes.extraLarge, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text("Goals", style = MaterialTheme.typography.titleLarge)
            Text(
                "Virtual allocations record your plan. They do not move money or change your remaining budget.",
                style = MaterialTheme.typography.bodySmall,
            )
            val goals = repo.goals()
            val visible = goals.filter { showArchived || !it.data.archived }
            if (visible.isEmpty()) Text("Give a future priority a name and a target.")
            visible.forEach { record ->
                val goal = record.data
                Text(goal.name, style = MaterialTheme.typography.titleMedium)
                Text("${goal.allocated.formatted()} allocated of ${goal.target.formatted()}")
                LinearProgressIndicator(
                    progress = {
                        (goal.allocated.minor.toDouble() / goal.target.minor.toDouble()).toFloat()
                    },
                    modifier = Modifier.fillMaxWidth(),
                )
                goal.targetDate?.let {
                    Text("Target date: $it", style = MaterialTheme.typography.bodySmall)
                }
                if (goal.archived) Text("Archived")
                if (repo.pendingGoal(goal.id))
                    Text("Pending sync", style = MaterialTheme.typography.bodySmall)
                TextButton(
                    onClick = {
                        selected = record
                        editor = true
                    },
                    enabled = !repo.pendingGoal(goal.id),
                ) {
                    Text("Edit ${goal.name}")
                }
            }
            if (goals.any { it.data.archived })
                Row {
                    Checkbox(showArchived, { showArchived = it })
                    Text("Show archived goals")
                }
            state.mutations
                .filter { it.conflict && it.entity.startsWith("goal:") }
                .forEach { mutation ->
                    Text(
                        "Goal changed on another device",
                        style = MaterialTheme.typography.titleMedium,
                    )
                    Text(repo.goalConflictDescription(mutation))
                    Text("The goal above shows the server version. Review both before choosing.")
                    MoneyEditConflictButton(repo, state, mutation)
                    TextButton(onClick = { scope.launch { repo.useServer(mutation) } }) {
                        Text("Use server goal")
                    }
                }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            OutlinedButton(
                onClick = {
                    selected = null
                    editor = true
                }
            ) {
                Text("Add goal")
            }
        }
    }
    if (editor) MoneyGoalEditor(repo, selected) { editor = false }
}

@Composable
private fun MoneyGoalEditor(
    repo: MoneyRepository,
    record: MoneyRecord<MoneyGoal>?,
    close: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    val id = rememberSaveable { record?.id ?: UUID.randomUUID().toString() }
    var name by rememberSaveable { mutableStateOf(record?.data?.name ?: "") }
    var target by rememberSaveable {
        mutableStateOf(
            record?.data?.target?.minor?.let { java.math.BigDecimal.valueOf(it, 2).toPlainString() }
                ?: ""
        )
    }
    var allocation by rememberSaveable {
        mutableStateOf(
            record?.data?.allocated?.minor?.let {
                java.math.BigDecimal.valueOf(it, 2).toPlainString()
            } ?: "0"
        )
    }
    var date by rememberSaveable { mutableStateOf(record?.data?.targetDate ?: "") }
    var archived by rememberSaveable { mutableStateOf(record?.data?.archived ?: false) }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = { if (!busy) close() },
        title = { Text(if (record == null) "Add goal" else "Edit goal") },
        text = {
            Column(
                Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                OutlinedTextField(name, { name = it }, label = { Text("Goal name") })
                OutlinedTextField(
                    target,
                    { target = it },
                    label = { Text("Goal target in USD") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                )
                OutlinedTextField(
                    allocation,
                    { allocation = it },
                    label = { Text("Virtual allocation in USD") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                )
                OutlinedTextField(
                    date,
                    { date = it },
                    label = { Text("Target date (YYYY-MM-DD, optional)") },
                )
                Row {
                    Checkbox(archived, { archived = it })
                    Text("Archive goal")
                }
                Text("This is a virtual plan. Saving does not transfer funds.")
                error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            }
        },
        confirmButton = {
            TextButton(
                enabled = !busy,
                onClick = {
                    scope.launch {
                        try {
                            val clean = name.trim()
                            val targetMinor = MoneyAmount.parse(target)
                            val allocated =
                                if (allocation.trim() in listOf("0", "0.0", "0.00")) 0L
                                else MoneyAmount.parse(allocation)
                            require(
                                clean.isNotEmpty() &&
                                    clean.length <= 80 &&
                                    targetMinor != null &&
                                    allocated != null &&
                                    allocated <= targetMinor &&
                                    (date.isEmpty() ||
                                        runCatching { LocalDate.parse(date).toString() == date }
                                            .getOrDefault(false))
                            ) {
                                "Review the name, target, allocation and optional calendar date. Allocation must be between zero and the target."
                            }
                            busy = true
                            repo.enqueue(
                                mapOf(
                                    "type" to "goal.upsert",
                                    "expectedVersion" to (record?.version ?: 0),
                                    "goal" to
                                        MoneyGoal(
                                            id,
                                            clean,
                                            MoneyAmount(targetMinor!!),
                                            MoneyAmount(allocated!!),
                                            date.ifEmpty { null },
                                            archived,
                                        ),
                                ),
                                "goal:$id",
                            )
                            close()
                            repo.refresh()
                        } catch (e: Exception) {
                            error = e.message
                        } finally {
                            busy = false
                        }
                    }
                },
            ) {
                Text("Save goal")
            }
        },
        dismissButton = { TextButton(enabled = !busy, onClick = close) { Text("Cancel") } },
    )
}
