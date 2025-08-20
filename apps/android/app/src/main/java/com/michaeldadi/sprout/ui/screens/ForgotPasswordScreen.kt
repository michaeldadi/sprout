package com.michaeldadi.sprout.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.michaeldadi.sprout.managers.ToastManager
import com.michaeldadi.sprout.services.AuthService
import com.michaeldadi.sprout.ui.components.FloatingCirclesBackground
import com.michaeldadi.sprout.R
import java.util.regex.Pattern

/**
 * Forgot password screen that mirrors the iOS ForgotPasswordView design and functionality
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ForgotPasswordScreen(
    onBackPressed: () -> Unit,
    authService: AuthService = viewModel()
) {
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current

    // State
    var email by remember { mutableStateOf("") }
    var isSubmitted by remember { mutableStateOf(false) }
    var shouldShowSuccessMessage by remember { mutableStateOf(false) }
    var shouldShowResendMessage by remember { mutableStateOf(false) }
    var shouldTriggerForgotPassword by remember { mutableStateOf(false) }
    var shouldTriggerResend by remember { mutableStateOf(false) }

    val failedSendResetEmailMessage = stringResource(R.string.failed_send_reset_email)
    val successSendResetEmailMessage = stringResource(R.string.success_send_reset_email)
    val successResendResetEmailMessage = stringResource(R.string.success_resend_reset_email)

    // Handle forgot password attempts
    LaunchedEffect(shouldTriggerForgotPassword) {
        if (shouldTriggerForgotPassword) {
            try {
                authService.forgotPassword(email)
                // Trigger success message and state change via state
                shouldShowSuccessMessage = true
            } catch (e: Exception) {
                ToastManager.showError(context, e.message ?: failedSendResetEmailMessage)
            } finally {
                shouldTriggerForgotPassword = false
            }
        }
    }

    // Handle resend attempts
    LaunchedEffect(shouldTriggerResend) {
        if (shouldTriggerResend) {
            try {
                authService.forgotPassword(email)
                // Trigger success message via state
                shouldShowResendMessage = true
            } catch (e: Exception) {
                ToastManager.showError(context, e.message ?: failedSendResetEmailMessage)
            } finally {
                shouldTriggerResend = false
            }
        }
    }

    // Handle success messages outside coroutine scope
    LaunchedEffect(shouldShowSuccessMessage) {
        if (shouldShowSuccessMessage) {
            ToastManager.showSuccess(context, successSendResetEmailMessage)
            isSubmitted = true
            shouldShowSuccessMessage = false
        }
    }

    LaunchedEffect(shouldShowResendMessage) {
        if (shouldShowResendMessage) {
            ToastManager.showInfo(context, successResendResetEmailMessage)
            shouldShowResendMessage = false
        }
    }

    // Auth state
    val isLoading by authService.isLoading.collectAsState()

    // Animation
    val infiniteTransition = rememberInfiniteTransition(label = "background")
    val animatedRotation by infiniteTransition.animateFloat(
        initialValue = -5f,
        targetValue = 5f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "rotation"
    )

    val animatedScale by infiniteTransition.animateFloat(
        initialValue = 1.0f,
        targetValue = 1.1f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "scale"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        Color(0xFF99D9A6), // Light green (0.60, 0.85, 0.65)
                        Color(0xFF80CC99), // Medium green (0.50, 0.80, 0.60)
                        Color(0xFFB3E6BF)  // Bright green (0.70, 0.90, 0.75)
                    ),
                    start = androidx.compose.ui.geometry.Offset(0f, 0f),
                    end = androidx.compose.ui.geometry.Offset.Infinite
                )
            )
            .clickable(
                indication = null,
                interactionSource = remember { MutableInteractionSource() }
            ) {
                focusManager.clearFocus()
            }
            .systemBarsPadding()
    ) {
        // Floating circles background
        FloatingCirclesBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp)
        ) {
            // Back Button
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 20.dp),
                horizontalArrangement = Arrangement.Start
            ) {
                TextButton(onClick = onBackPressed) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = "←",
                            color = Color.White,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium,
                            modifier = Modifier.offset(y = (-3).dp)
                        )
                        Text(
                            text = stringResource(R.string.back),
                            color = Color.White,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            if (isSubmitted) {
                // Success State
                SuccessState(
                    email = email,
                    onResendEmail = {
                        shouldTriggerResend = true
                    },
                    animatedScale = animatedScale
                )
            } else {
                val enterEmailText = stringResource(R.string.enter_email_address)
                val enterValidEmailText = stringResource(R.string.enter_valid_email)

                // Input State
                InputState(
                    email = email,
                    onEmailChange = { email = it },
                    onSendResetEmail = {
                        if (email.isBlank()) {
                            ToastManager.showError(context, enterEmailText)
                            return@InputState
                        }
                        if (!isValidEmail(email)) {
                            ToastManager.showError(context, enterValidEmailText)
                            return@InputState
                        }

                        focusManager.clearFocus()
                        shouldTriggerForgotPassword = true
                    },
                    isLoading = isLoading,
                    focusManager = focusManager,
                    animatedRotation = animatedRotation
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            // Back to Login Link
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 50.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = stringResource(R.string.remember_password),
                    color = Color.White.copy(alpha = 0.7f),
                    fontSize = 16.sp
                )

                Spacer(modifier = Modifier.width(4.dp))

                TextButton(onClick = onBackPressed) {
                    Text(
                        text = stringResource(R.string.text_sign_in),
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}

@Composable
private fun InputState(
    email: String,
    onEmailChange: (String) -> Unit,
    onSendResetEmail: () -> Unit,
    isLoading: Boolean,
    focusManager: androidx.compose.ui.focus.FocusManager,
    animatedRotation: Float
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(30.dp)
    ) {
        // Logo and Welcome Text
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // Key Icon
            Box(
                modifier = Modifier.size(100.dp),
                contentAlignment = Alignment.Center
            ) {
                // Background circle
                Box(
                    modifier = Modifier
                        .size(100.dp)
                        .blur(3.dp)
                        .background(
                            Color.White.copy(alpha = 0.15f),
                            CircleShape
                        )
                )

                // Key icon
                Text(
                    text = "🔑",
                    fontSize = 50.sp,
                    modifier = Modifier.graphicsLayer() {
                        rotationZ = animatedRotation
                    }
                )
            }

            Text(
                text = stringResource(R.string.forgot_password_stmt),
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                textAlign = TextAlign.Center
            )

            Text(
                text = stringResource(R.string.password_reset_instructions),
                fontSize = 16.sp,
                color = Color.White.copy(alpha = 0.8f),
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 20.dp)
            )
        }

        // Email Input Form
        Column(
            verticalArrangement = Arrangement.spacedBy(20.dp),
            modifier = Modifier.padding(horizontal = 30.dp)
        ) {
            // Email Field
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = stringResource(R.string.email),
                    color = Color.White.copy(alpha = 0.8f),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium
                )

                OutlinedTextField(
                    value = email,
                    onValueChange = onEmailChange,
                    placeholder = {
                        Text(
                            text = stringResource(R.string.enter_email_address),
                            color = Color.White.copy(alpha = 0.5f)
                        )
                    },
                    leadingIcon = {
                        Text(
                            text = "✉️",
                            fontSize = 16.sp,
                            modifier = Modifier.padding(start = 4.dp)
                        )
                    },
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Email,
                        imeAction = ImeAction.Send
                    ),
                    keyboardActions = KeyboardActions(
                        onSend = { onSendResetEmail() }
                    ),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White,
                        focusedBorderColor = Color.White.copy(alpha = 0.5f),
                        unfocusedBorderColor = Color.Transparent,
                        focusedContainerColor = Color.White.copy(alpha = 0.15f),
                        unfocusedContainerColor = Color.White.copy(alpha = 0.15f),
                        cursorColor = Color.White
                    ),
                    shape = RoundedCornerShape(15.dp),
                    modifier = Modifier.fillMaxWidth()
                )
            }

            // Send Reset Email Button
            Button(
                onClick = onSendResetEmail,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .padding(top = 10.dp),
                enabled = !isLoading,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.White,
                    disabledContainerColor = Color.White.copy(alpha = 0.7f)
                ),
                shape = RoundedCornerShape(15.dp)
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        color = Color(0xFF30A030),
                        strokeWidth = 2.dp
                    )
                } else {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = stringResource(R.string.send_reset_email),
                            color = Color(0xFF30A030),
                            fontSize = 18.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = "📧",
                            fontSize = 16.sp
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SuccessState(
    email: String,
    onResendEmail: () -> Unit,
    animatedScale: Float
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(25.dp)
    ) {
        // Success Icon
        Box(
            modifier = Modifier.size(100.dp),
            contentAlignment = Alignment.Center
        ) {
            // Background circle
            Box(
                modifier = Modifier
                    .size(100.dp)
                    .blur(3.dp)
                    .background(
                        Color.White.copy(alpha = 0.15f),
                        CircleShape
                    )
            )

            // Checkmark icon
            Text(
                text = "✅",
                fontSize = 80.sp,
                modifier = Modifier.graphicsLayer {
                    scaleX = animatedScale
                    scaleY = animatedScale
                }
            )
        }

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(15.dp)
        ) {
            Text(
                text = stringResource(R.string.check_your_email),
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                textAlign = TextAlign.Center
            )

            Text(
                text = stringResource(R.string.password_reset_instructions_sent_to),
                fontSize = 16.sp,
                color = Color.White.copy(alpha = 0.8f),
                textAlign = TextAlign.Center
            )

            Text(
                text = email,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 20.dp)
            )
        }

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(15.dp),
            modifier = Modifier.padding(top = 10.dp)
        ) {
            Text(
                text = stringResource(R.string.text_password_reset_not_received),
                fontSize = 14.sp,
                color = Color.White.copy(alpha = 0.7f),
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 30.dp)
            )

            TextButton(onClick = onResendEmail) {
                Text(
                    text = stringResource(R.string.resend_email),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White,
                    textDecoration = TextDecoration.Underline
                )
            }
        }
    }
}

private fun isValidEmail(email: String): Boolean {
    val emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    return Pattern.compile(emailRegex).matcher(email).matches()
}
