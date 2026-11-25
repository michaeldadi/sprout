package com.michaeldadi.sprout.money

import android.content.Context
import android.view.WindowManager
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner

internal fun deviceLockPreferences(context: Context) =
    context.getSharedPreferences("sprout-device-security", Context.MODE_PRIVATE)

internal fun authenticateDevice(context: Context, result: (Boolean) -> Unit) {
    val activity =
        context as? FragmentActivity
            ?: run {
                result(false)
                return
            }
    val authenticators =
        BiometricManager.Authenticators.BIOMETRIC_STRONG or
            BiometricManager.Authenticators.DEVICE_CREDENTIAL
    if (
        BiometricManager.from(context).canAuthenticate(authenticators) !=
            BiometricManager.BIOMETRIC_SUCCESS
    ) {
        result(false)
        return
    }
    val prompt =
        BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(context),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    value: BiometricPrompt.AuthenticationResult
                ) {
                    result(true)
                }

                override fun onAuthenticationError(code: Int, message: CharSequence) {
                    result(false)
                }
            },
        )
    prompt.authenticate(
        BiometricPrompt.PromptInfo.Builder()
            .setTitle("Unlock Sprout")
            .setSubtitle("View your personal finances")
            .setAllowedAuthenticators(authenticators)
            .build()
    )
}

@Composable
internal fun MoneyDeviceGate(review: Boolean, content: @Composable () -> Unit) {
    val context = LocalContext.current
    val prefs = remember { deviceLockPreferences(context) }
    var enabled by remember { mutableStateOf(prefs.getBoolean("enabled", false) && !review) }
    var locked by remember { mutableStateOf(enabled) }
    var prompting by remember { mutableStateOf(false) }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    fun unlock() {
        if (!prompting) {
            prompting = true
            authenticateDevice(context) { success ->
                prompting = false
                if (success) locked = false
            }
        }
    }
    DisposableEffect(prefs, lifecycle, review) {
        val listener =
            android.content.SharedPreferences.OnSharedPreferenceChangeListener { _, _ ->
                enabled = prefs.getBoolean("enabled", false) && !review
                if (enabled) locked = true
            }
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_PAUSE && enabled) locked = true
        }
        prefs.registerOnSharedPreferenceChangeListener(listener)
        lifecycle.addObserver(observer)
        onDispose {
            prefs.unregisterOnSharedPreferenceChangeListener(listener)
            lifecycle.removeObserver(observer)
        }
    }
    DisposableEffect(enabled) {
        val activity = context as? android.app.Activity
        if (enabled) activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        else activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        onDispose { activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE) }
    }
    LaunchedEffect(enabled) { if (enabled && locked) unlock() }
    if (enabled && locked)
        Surface(Modifier.fillMaxSize()) {
            Column(
                Modifier.padding(24.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("Sprout is locked", style = MaterialTheme.typography.headlineMedium)
                Text("Unlock to view your finances.")
                Button(onClick = { unlock() }, enabled = !prompting) { Text("Unlock") }
            }
        }
    else content()
}
