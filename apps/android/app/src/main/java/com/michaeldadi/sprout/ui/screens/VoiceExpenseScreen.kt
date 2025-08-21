package com.michaeldadi.sprout.ui.screens

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.michaeldadi.sprout.services.AndroidSpeechService
import com.michaeldadi.sprout.services.ExpenseData

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VoiceExpenseScreen(
    onDismiss: () -> Unit = {},
    onSaveExpense: (ExpenseData) -> Unit = {}
) {
    val context = LocalContext.current
    val speechService = remember { AndroidSpeechService(context) }

    var isListening by remember { mutableStateOf(false) }
    var transcript by remember { mutableStateOf("") }
    var expenseData by remember { mutableStateOf(ExpenseData("", "", "", "")) }
    var showError by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf("") }

    // Permission launcher
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            speechService.updateAvailability()
        } else {
            errorMessage = "Microphone permission is required for voice input"
            showError = true
        }
    }

    // Set up speech service callbacks
    LaunchedEffect(speechService) {
        speechService.onTranscriptChanged = { newTranscript ->
            transcript = newTranscript
            expenseData = speechService.parseExpenseFromText(newTranscript)
        }

        speechService.onListeningStateChanged = { listening ->
            isListening = listening
        }

        speechService.onError = { error ->
            errorMessage = error
            showError = true
            isListening = false
        }

        speechService.updateAvailability()
    }

    // Cleanup
    DisposableEffect(speechService) {
        onDispose {
            speechService.destroy()
        }
    }

    Column(
        modifier = Modifier
          .fillMaxSize()
          .padding(16.dp)
          .verticalScroll(rememberScrollState())
    ) {
        // Header
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer
            )
        ) {
            Column(
                modifier = Modifier
                  .fillMaxWidth()
                  .padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Icon(
                    imageVector = if (isListening) Icons.Outlined.Close else Icons.Default.Check,
                    contentDescription = "Voice Input",
                    modifier = Modifier.size(48.dp),
                    tint = if (isListening) Color.Red else MaterialTheme.colorScheme.primary
                )

                Spacer(modifier = Modifier.height(8.dp))

                Text(
                    text = "Voice Expense Entry",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )

                Text(
                    text = "Say something like: \"I spent 12.50 at Starbucks for coffee\"",
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Voice Input Section
        Card(
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(16.dp)
            ) {
                Text(
                    text = "Recognized Speech",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Medium
                )

                Spacer(modifier = Modifier.height(8.dp))

                // Transcript display
                Surface(
                    modifier = Modifier
                      .fillMaxWidth()
                      .heightIn(min = 100.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    shape = MaterialTheme.shapes.medium
                ) {
                    Text(
                        text = if (transcript.isEmpty()) "Tap the microphone and start speaking..." else transcript,
                        modifier = Modifier.padding(12.dp),
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (transcript.isEmpty())
                            MaterialTheme.colorScheme.onSurfaceVariant
                        else
                            MaterialTheme.colorScheme.onSurface
                    )
                }

                Spacer(modifier = Modifier.height(16.dp))

                // Microphone button
                Button(
                    onClick = {
                        if (!speechService.isAvailable) {
                            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                            return@Button
                        }

                        if (isListening) {
                            speechService.stopListening()
                        } else {
                            speechService.startListening()
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isListening) Color.Red else MaterialTheme.colorScheme.primary
                    )
                ) {
                    Icon(
                        imageVector = if (isListening) Icons.Default.Delete else Icons.Default.CheckCircle,
                        contentDescription = if (isListening) "Stop" else "Start"
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(if (isListening) {
                      "Stop Listening"
                    } else {
                      "Start Voice Entry"
                    })
                }
            }
        }

        // Extracted Information
        if (expenseData.amount.isNotEmpty() || expenseData.merchant.isNotEmpty() || expenseData.category.isNotEmpty()) {
            Spacer(modifier = Modifier.height(16.dp))

            Card(
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(16.dp)
                ) {
                    Text(
                        text = "Extracted Information",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Medium
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    if (expenseData.amount.isNotEmpty()) {
                        InfoRow(label = "Amount", value = "$${expenseData.amount}")
                    }

                    if (expenseData.merchant.isNotEmpty()) {
                        InfoRow(label = "Merchant", value = expenseData.merchant)
                    }

                    if (expenseData.category.isNotEmpty()) {
                        InfoRow(label = "Category", value = expenseData.category)
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Action Buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            OutlinedButton(
                onClick = onDismiss,
                modifier = Modifier.weight(1f)
            ) {
                Text("Cancel")
            }

            Button(
                onClick = { onSaveExpense(expenseData) },
                modifier = Modifier.weight(1f),
                enabled = expenseData.amount.isNotEmpty()
            ) {
                Icon(
                    imageVector = Icons.Default.Lock,
                    contentDescription = "Save"
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text("Save")
            }
        }

        Spacer(modifier = Modifier.height(16.dp))
    }

    // Error dialog
    if (showError) {
        AlertDialog(
            onDismissRequest = { showError = false },
            title = { Text("Error") },
            text = { Text(errorMessage) },
            confirmButton = {
                TextButton(onClick = { showError = false }) {
                    Text("OK")
                }
            }
        )
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(
        modifier = Modifier
          .fillMaxWidth()
          .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = "$label:",
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
