package com.michaeldadi.sprout.money

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.michaeldadi.sprout.BuildConfig
import com.michaeldadi.sprout.config.AppConfig

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun MoneySupportSheet(dismiss: () -> Unit) {
    val context = LocalContext.current
    var unavailable by remember { mutableStateOf(false) }
    ModalBottomSheet(onDismissRequest = dismiss) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text("Help & support", style = MaterialTheme.typography.headlineMedium)
            Text("Contact Sprout", style = MaterialTheme.typography.titleLarge)
            Text("Write to the support team using your email app.")
            Button(onClick = { unavailable = runCatching { context.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:${AppConfig.supportEmail}")).putExtra(Intent.EXTRA_SUBJECT, "Sprout support")) }.isFailure }) { Text("Email support") }
            SelectionContainer { Text(AppConfig.supportEmail) }
            if (unavailable) Text("No email app is available. Copy the address into your preferred mail service.")
            Text("In-app chat", style = MaterialTheme.typography.titleMedium)
            Text("Chat is awaiting account-identity setup. Email is the contact option for this build.")
            Text("Your data", style = MaterialTheme.typography.titleMedium)
            Text("Import, export, account deletion and saved-change reviews are available in Profile. Your export includes ready retained receipt copies.")
            Text("Sprout ${BuildConfig.VERSION_NAME}", style = MaterialTheme.typography.bodySmall)
            TextButton(onClick = dismiss) { Text("Close") }
        }
    }
}
