package com.michaeldadi.sprout.services

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

sealed class BiometricAuthError(val message: String) {
    object BiometryNotAvailable : BiometricAuthError("Biometric authentication is not available on this device")
    object BiometryNotEnrolled : BiometricAuthError("No biometric data is enrolled on this device")
    object BiometryLockout : BiometricAuthError("Biometric authentication is locked out. Try again later")
    object AuthenticationFailed : BiometricAuthError("Authentication failed")
    object UserCancel : BiometricAuthError("Authentication was cancelled by user")
    object SystemCancel : BiometricAuthError("Authentication was cancelled by system")
    object PasscodeNotSet : BiometricAuthError("Device credential is not set on this device")
    class Unknown(error: String) : BiometricAuthError("Unknown error: $error")
}

enum class BiometricType(val displayName: String, val iconResource: String?) {
    NONE("None", null),
    FINGERPRINT("Fingerprint", "ic_fingerprint"),
    FACE("Face", "ic_face"),
    IRIS("Iris", "ic_iris");
}

class BiometricAuthService private constructor(private val context: Context) {
    companion object {
        @Volatile
        private var INSTANCE: BiometricAuthService? = null

        fun getInstance(context: Context): BiometricAuthService {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: BiometricAuthService(context.applicationContext).also { INSTANCE = it }
            }
        }
    }

    private val sharedPreferences: SharedPreferences =
        context.getSharedPreferences("biometric_auth_prefs", Context.MODE_PRIVATE)
    private val biometricEnabledKey = "biometric_auth_enabled"

    var isEnabled: Boolean
        get() = sharedPreferences.getBoolean(biometricEnabledKey, false)
        set(value) {
            sharedPreferences.edit().putBoolean(biometricEnabledKey, value).apply()
        }

    val isAvailable: Boolean
      get() = checkBiometricAvailability() == BiometricManager.BIOMETRIC_SUCCESS

    val biometricType: BiometricType
        get() = when (checkBiometricAvailability()) {
            BiometricManager.BIOMETRIC_SUCCESS -> {
                // Android doesn't provide specific biometric type info easily
                // We'll default to fingerprint for available biometrics
                BiometricType.FINGERPRINT
            }
            else -> BiometricType.NONE
        }

    private fun checkBiometricAvailability(): Int {
        val biometricManager = BiometricManager.from(context)
        return biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK)
    }

    suspend fun authenticate(
        activity: FragmentActivity,
        title: String = "Biometric Authentication",
        subtitle: String = "Please authenticate to access your account",
        description: String = "Use your biometric credential to authenticate"
    ): Result<Boolean> = suspendCancellableCoroutine { continuation ->

        if (!isAvailable) {
            continuation.resume(Result.failure(Exception(BiometricAuthError.BiometryNotAvailable.message)))
            return@suspendCancellableCoroutine
        }

        if (!isEnabled) {
            continuation.resume(Result.failure(Exception(BiometricAuthError.BiometryNotAvailable.message)))
            return@suspendCancellableCoroutine
        }

        val executor = ContextCompat.getMainExecutor(context)
        val biometricPrompt = BiometricPrompt(activity, executor, object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                super.onAuthenticationError(errorCode, errString)
                val error = when (errorCode) {
                    BiometricPrompt.ERROR_CANCELED -> BiometricAuthError.SystemCancel
                    BiometricPrompt.ERROR_USER_CANCELED -> BiometricAuthError.UserCancel
                    BiometricPrompt.ERROR_LOCKOUT, BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> BiometricAuthError.BiometryLockout
                    BiometricPrompt.ERROR_NO_BIOMETRICS -> BiometricAuthError.BiometryNotEnrolled
                    BiometricPrompt.ERROR_HW_NOT_PRESENT, BiometricPrompt.ERROR_HW_UNAVAILABLE -> BiometricAuthError.BiometryNotAvailable
                    BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL -> BiometricAuthError.PasscodeNotSet
                    else -> BiometricAuthError.Unknown(errString.toString())
                }
                Log.e("BiometricAuthService", "Authentication error: $errString")
                if (continuation.isActive) {
                    continuation.resume(Result.failure(Exception(error.message)))
                }
            }

            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                super.onAuthenticationSucceeded(result)
                Log.i("BiometricAuthService", "Authentication succeeded")
                if (continuation.isActive) {
                    continuation.resume(Result.success(true))
                }
            }

            override fun onAuthenticationFailed() {
                super.onAuthenticationFailed()
                Log.w("BiometricAuthService", "Authentication failed")
                if (continuation.isActive) {
                    continuation.resume(Result.failure(Exception(BiometricAuthError.AuthenticationFailed.message)))
                }
            }
        })

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setSubtitle(subtitle)
            .setDescription(description)
            .setNegativeButtonText("Cancel")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_WEAK)
            .build()

        activity.lifecycleScope.launch {
          activity.lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            biometricPrompt.authenticate(promptInfo)
          }
        }

        continuation.invokeOnCancellation {
            biometricPrompt.cancelAuthentication()
        }
    }

    suspend fun authenticateWithPasscode(
        activity: FragmentActivity,
        title: String = "Device Authentication",
        subtitle: String = "Please authenticate to access your account",
        description: String = "Use your device PIN, pattern, or password to authenticate"
    ): Result<Boolean> = suspendCancellableCoroutine { continuation ->

        val executor = ContextCompat.getMainExecutor(context)
        val biometricPrompt = BiometricPrompt(activity, executor, object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                super.onAuthenticationError(errorCode, errString)
                val error = when (errorCode) {
                    BiometricPrompt.ERROR_CANCELED -> BiometricAuthError.SystemCancel
                    BiometricPrompt.ERROR_USER_CANCELED -> BiometricAuthError.UserCancel
                    BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL -> BiometricAuthError.PasscodeNotSet
                    else -> BiometricAuthError.Unknown(errString.toString())
                }
                Log.e("BiometricAuthService", "Passcode authentication error: $errString")
                if (continuation.isActive) {
                    continuation.resume(Result.failure(Exception(error.message)))
                }
            }

            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                super.onAuthenticationSucceeded(result)
                Log.i("BiometricAuthService", "Passcode authentication succeeded")
                if (continuation.isActive) {
                    continuation.resume(Result.success(true))
                }
            }

            override fun onAuthenticationFailed() {
                super.onAuthenticationFailed()
                Log.w("BiometricAuthService", "Passcode authentication failed")
                if (continuation.isActive) {
                    continuation.resume(Result.failure(Exception(BiometricAuthError.AuthenticationFailed.message)))
                }
            }
        })

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setSubtitle(subtitle)
            .setDescription(description)
            .setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_WEAK or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
            .build()

        activity.lifecycleScope.launch {
          activity.lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            biometricPrompt.authenticate(promptInfo)
          }
        }

        continuation.invokeOnCancellation {
            biometricPrompt.cancelAuthentication()
        }
    }

    fun enableBiometricAuth() {
        isEnabled = true
        Log.i("BiometricAuthService", "Biometric authentication enabled")
    }

    fun disableBiometricAuth() {
        isEnabled = false
        Log.i("BiometricAuthService", "Biometric authentication disabled")
    }

    fun getBiometricCapabilityString(): String {
        return when (checkBiometricAvailability()) {
            BiometricManager.BIOMETRIC_SUCCESS -> "Biometric authentication available"
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "No biometric hardware available"
            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "Biometric hardware unavailable"
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "No biometric credentials enrolled"
            BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED -> "Security update required"
            BiometricManager.BIOMETRIC_ERROR_UNSUPPORTED -> "Biometric authentication unsupported"
            BiometricManager.BIOMETRIC_STATUS_UNKNOWN -> "Biometric status unknown"
            else -> "Unknown biometric status"
        }
    }
}
