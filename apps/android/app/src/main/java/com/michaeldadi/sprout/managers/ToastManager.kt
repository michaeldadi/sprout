package com.michaeldadi.sprout.managers

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

/**
 * Toast manager for showing toast notifications
 * Mirrors the iOS ToastManager functionality
 */
object ToastManager {
    
    fun showSuccess(context: Context, message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        // Success haptic feedback
        triggerHapticFeedback(context, HapticType.SUCCESS)
    }
    
    fun showError(context: Context, message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        // Error haptic feedback
        triggerHapticFeedback(context, HapticType.ERROR)
    }
    
    fun showInfo(context: Context, message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        // Light haptic feedback
        triggerHapticFeedback(context, HapticType.LIGHT)
    }
    
    private fun triggerHapticFeedback(context: Context, type: HapticType) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = when (type) {
                HapticType.SUCCESS -> VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE)
                HapticType.ERROR -> VibrationEffect.createWaveform(longArrayOf(0, 50, 50, 50), -1)
                HapticType.LIGHT -> VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE)
            }
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            when (type) {
                HapticType.SUCCESS -> vibrator.vibrate(100)
                HapticType.ERROR -> vibrator.vibrate(longArrayOf(0, 50, 50, 50), -1)
                HapticType.LIGHT -> vibrator.vibrate(50)
            }
        }
    }
    
    private enum class HapticType {
        SUCCESS, ERROR, LIGHT
    }
}

/**
 * Custom toast composable for more control over appearance
 * Mirrors the iOS toast UI styling
 */
@Composable
fun CustomToast(
    message: String,
    isVisible: Boolean,
    isError: Boolean = false,
    onDismiss: () -> Unit
) {
    LaunchedEffect(isVisible) {
        if (isVisible) {
            delay(3000) // Show for 3 seconds
            onDismiss()
        }
    }
    
    if (isVisible) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            contentAlignment = Alignment.BottomCenter
        ) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(
                    containerColor = if (isError) 
                        Color(0xFFFF3B30) 
                    else 
                        Color(0xFF34C759)
                ),
                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
            ) {
                Text(
                    text = message,
                    modifier = Modifier
                        .padding(16.dp)
                        .fillMaxWidth(),
                    color = Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
}

/**
 * Toast state management
 */
class ToastState {
    private val _isVisible = mutableStateOf(false)
    val isVisible: State<Boolean> = _isVisible
    
    private val _message = mutableStateOf("")
    val message: State<String> = _message
    
    private val _isError = mutableStateOf(false)
    val isError: State<Boolean> = _isError
    
    fun showSuccess(message: String) {
        _message.value = message
        _isError.value = false
        _isVisible.value = true
    }
    
    fun showError(message: String) {
        _message.value = message
        _isError.value = true
        _isVisible.value = true
    }
    
    fun dismiss() {
        _isVisible.value = false
    }
}

/**
 * Remember toast state for use in composables
 */
@Composable
fun rememberToastState() = remember { ToastState() }