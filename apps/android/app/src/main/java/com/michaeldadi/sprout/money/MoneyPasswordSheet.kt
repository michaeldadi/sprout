package com.michaeldadi.sprout.money

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.michaeldadi.sprout.services.AppwriteAccountSecurity
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun MoneyPasswordSheet(owner: String, dismiss: () -> Unit) {
    val scope = rememberCoroutineScope()
    var account by remember { mutableStateOf<AppwriteAccountSecurity?>(null) }
    var current by remember { mutableStateOf("") }; var new by remember { mutableStateOf("") }; var confirmation by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }; var error by remember { mutableStateOf<String?>(null) }; var succeeded by remember { mutableStateOf(false) }
    suspend fun verify() { error = null; account = null; try { account = AppwriteAccountSecurity.verified(owner) } catch (_: Exception) { error = "Connect to Sprout and sign in again if necessary to verify this account's password credential." } }
    LaunchedEffect(owner) { verify() }
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true, confirmValueChange = { !busy || it != SheetValue.Hidden })
    ModalBottomSheet(sheetState = sheet, onDismissRequest = { if (!busy) dismiss() }) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).imePadding().padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text("Change password", style = MaterialTheme.typography.headlineSmall)
            Text("Change the password for this Sprout account. Your device lock is managed separately.")
            if (account == null && error == null) CircularProgressIndicator()
            error?.let { Text(it, color = MaterialTheme.colorScheme.error); TextButton(enabled = !busy, onClick = { scope.launch { verify() } }) { Text("Check again") } }
            if (account != null && !succeeded) {
                OutlinedTextField(current, { current = it }, label = { Text("Current password") }, visualTransformation = PasswordVisualTransformation(), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password), singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(new, { new = it }, label = { Text("New password") }, visualTransformation = PasswordVisualTransformation(), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password), singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(confirmation, { confirmation = it }, label = { Text("Confirm new password") }, visualTransformation = PasswordVisualTransformation(), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password), singleLine = true, modifier = Modifier.fillMaxWidth())
                Text("Use 8–256 characters. Your account's password-strength rules also apply.", style = MaterialTheme.typography.bodySmall)
                Button(enabled = !busy && current.isNotEmpty() && new.length in 8..256 && new == confirmation, onClick = { scope.launch {
                    busy = true; error = null
                    try { account!!.changePassword(current, new); current = ""; new = ""; confirmation = ""; succeeded = true }
                    catch (failure: Exception) { error = failure.message ?: "The password update could not be confirmed. Try signing in with your new password." }
                    finally { busy = false }
                } }) { Text("Update password") }
            }
            if (busy) CircularProgressIndicator()
            if (succeeded) { Text("Password updated", style = MaterialTheme.typography.titleLarge); Text("Use your new password the next time you sign in."); Button(onClick = dismiss) { Text("Done") } }
            else TextButton(enabled = !busy, onClick = dismiss) { Text("Close") }
        }
    }
}
