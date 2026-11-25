package com.michaeldadi.sprout.money

import android.content.Intent
import android.net.Uri
import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.michaeldadi.sprout.services.*
import kotlinx.coroutines.launch

@Composable
fun MoneyWelcome() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var email by rememberSaveable { mutableStateOf("") }
    var name by rememberSaveable { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var create by rememberSaveable { mutableStateOf(true) }
    var form by rememberSaveable { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    Surface(color = MaterialTheme.colorScheme.background, modifier = Modifier.fillMaxSize()) {
        Column(
            Modifier.safeDrawingPadding()
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(Icons.Default.Spa, null, tint = MaterialTheme.colorScheme.primary)
                Text("sprout", style = MaterialTheme.typography.headlineLarge)
            }
            if (!form) {
                Surface(
                    shape = RoundedCornerShape(44.dp),
                    color = MaterialTheme.colorScheme.surfaceContainer,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Column(
                        Modifier.padding(32.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(24.dp),
                    ) {
                        Icon(
                            Icons.Default.Spa,
                            "Sprout helps you see your financial picture and take action",
                            Modifier.size(100.dp),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                        Text(
                            "A little clarity.\nA little more room to grow.",
                            style = MaterialTheme.typography.titleLarge,
                        )
                        Surface(
                            shape = RoundedCornerShape(24.dp),
                            color = MaterialTheme.colorScheme.surface,
                        ) {
                            Row(
                                Modifier.padding(24.dp),
                                horizontalArrangement = Arrangement.spacedBy(24.dp),
                            ) {
                                Icon(Icons.Default.ShowChart, null)
                                Text("Your money")
                                Icon(
                                    Icons.Default.CheckCircle,
                                    null,
                                    tint = MaterialTheme.colorScheme.primary,
                                )
                            }
                        }
                    }
                }
                Text("Make room for\nwhat matters.", style = MaterialTheme.typography.displaySmall)
                Text(
                    "Sprout watches your money, shows you what's coming, and helps you take care of it.",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Button(
                    onClick = {
                        create = true
                        form = true
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Get started")
                }
                TextButton(
                    onClick = {
                        create = false
                        form = true
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("I already have an account")
                }
                OutlinedButton(
                    onClick = {
                        scope.launch {
                            val activity = context as? ComponentActivity
                            if (activity == null) {
                                error = "Sign-in is unavailable."
                                return@launch
                            }
                            when (val result = GoogleSignInService(context, activity).signIn()) {
                                is GoogleSignInResult.Success ->
                                    try {
                                        AppwriteNativeSession.signInWithGoogle(
                                            result.idToken,
                                            result.displayName,
                                        )
                                    } catch (_: Exception) {
                                        error =
                                            "Google sign-in didn't complete. Try again or use email."
                                    }
                                is GoogleSignInResult.Error ->
                                    error = "Google sign-in isn't available in this build."
                                else -> Unit
                            }
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Continue with Google")
                }
            } else {
                Text(
                    if (create) "Start growing" else "Welcome back",
                    style = MaterialTheme.typography.headlineLarge,
                )
                if (create)
                    OutlinedTextField(
                        name,
                        { name = it },
                        Modifier.fillMaxWidth(),
                        label = { Text("Name") },
                    )
                OutlinedTextField(
                    email,
                    { email = it },
                    Modifier.fillMaxWidth(),
                    label = { Text("Email") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                    singleLine = true,
                )
                OutlinedTextField(
                    password,
                    { password = it },
                    Modifier.fillMaxWidth(),
                    label = { Text("Password") },
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    singleLine = true,
                )
                Button(
                    onClick = {
                        scope.launch {
                            busy = true
                            try {
                                AppwriteNativeSession.signIn(email.trim(), password, create, name)
                                password = ""
                            } catch (_: Exception) {
                                error =
                                    "Couldn't sign in. Check your details and connection, then try again."
                            }
                            busy = false
                        }
                    },
                    enabled = !busy && email.isNotBlank() && password.isNotBlank(),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(if (create) "Create account" else "Sign in")
                }
                TextButton(
                    onClick = {
                        form = false
                        password = ""
                    }
                ) {
                    Text("Back")
                }
                if (busy) LinearProgressIndicator(Modifier.fillMaxWidth())
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                TextButton(
                    onClick = {
                        context.startActivity(
                            Intent(
                                Intent.ACTION_VIEW,
                                Uri.parse("https://getsprout.appwrite.network/terms"),
                            )
                        )
                    }
                ) {
                    Text("Terms")
                }
                TextButton(
                    onClick = {
                        context.startActivity(
                            Intent(
                                Intent.ACTION_VIEW,
                                Uri.parse("https://getsprout.appwrite.network/privacy"),
                            )
                        )
                    }
                ) {
                    Text("Privacy")
                }
            }
        }
    }
}
