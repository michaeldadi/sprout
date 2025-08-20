package com.michaeldadi.sprout.ui.screens

import androidx.compose.foundation.*
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
import com.michaeldadi.sprout.R
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.michaeldadi.sprout.managers.ToastManager
import com.michaeldadi.sprout.services.AuthService
import com.michaeldadi.sprout.ui.components.FloatingCirclesBackground
import kotlinx.coroutines.launch

/**
 * Verification screen that mirrors the iOS VerificationView design and functionality
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VerificationScreen(
    email: String,
    onBackPressed: () -> Unit,
    onVerificationComplete: () -> Unit,
    authService: AuthService = viewModel()
) {
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current
    val coroutineScope = rememberCoroutineScope()

    // State
    var verificationCode by remember { mutableStateOf("") }

    // Auth state
    val isLoading by authService.isLoading.collectAsState()

    // Auto-submit when 6 digits entered
    LaunchedEffect(verificationCode) {
        if (verificationCode.length == 6) {
            handleVerification(
                authService = authService,
                email = email,
                verificationCode = verificationCode,
                context = context,
                focusManager = focusManager,
                onSuccess = onVerificationComplete,
                coroutineScope = coroutineScope
            )
        }
    }

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
            .systemBarsPadding()
    ) {
        // Floating circles background
        FloatingCirclesBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Back Button
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 20.dp),
                horizontalArrangement = Arrangement.Start
            ) {
                TextButton(
                    onClick = onBackPressed
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(5.dp)
                    ) {
                        Text(
                            text = "←",
                            color = Color.White,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = "Back",
                            color = Color.White,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            // Email Icon
            Box(
                modifier = Modifier.size(80.dp),
                contentAlignment = Alignment.Center
            ) {
                // Background circle
                Box(
                    modifier = Modifier
                        .size(80.dp)
                        .blur(3.dp)
                        .background(
                            Color.White.copy(alpha = 0.15f),
                            CircleShape
                        )
                )

                // Email icon
                Text(
                    text = "📧",
                    fontSize = 40.sp
                )
            }

            Spacer(modifier = Modifier.height(30.dp))

            // Title and Description
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = "Verify Your Email",
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    textAlign = TextAlign.Center
                )

                Text(
                    text = "We've sent a verification code to",
                    fontSize = 16.sp,
                    color = Color.White.copy(alpha = 0.8f),
                    textAlign = TextAlign.Center
                )

                Text(
                    text = email,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White,
                    textAlign = TextAlign.Center
                )
            }

            Spacer(modifier = Modifier.height(40.dp))

            // Verification Code Field
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = "Verification Code",
                    color = Color.White.copy(alpha = 0.8f),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium
                )

                OutlinedTextField(
                    value = verificationCode,
                    onValueChange = { newValue ->
                        // Limit to 6 digits
                        if (newValue.length <= 6 && newValue.all { it.isDigit() }) {
                            verificationCode = newValue
                        }
                    },
                    placeholder = {
                        Text(
                            text = "Enter 6-digit code",
                            color = Color.White.copy(alpha = 0.5f)
                        )
                    },
                    leadingIcon = {
                        Text(
                            text = "#️⃣",
                            fontSize = 16.sp,
                            modifier = Modifier.padding(start = 4.dp)
                        )
                    },
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Number,
                        imeAction = ImeAction.Done
                    ),
                    keyboardActions = KeyboardActions(
                        onDone = {
                            if (verificationCode.length == 6) {
                                handleVerification(
                                    authService = authService,
                                    email = email,
                                    verificationCode = verificationCode,
                                    context = context,
                                    focusManager = focusManager,
                                    onSuccess = onVerificationComplete,
                                    coroutineScope = coroutineScope
                                )
                            }
                        }
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

            Spacer(modifier = Modifier.height(30.dp))

            // Verify Button
            Button(
                onClick = {
                    handleVerification(
                        authService = authService,
                        email = email,
                        verificationCode = verificationCode,
                        context = context,
                        focusManager = focusManager,
                        onSuccess = onVerificationComplete,
                        coroutineScope = coroutineScope
                    )
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                enabled = !isLoading && verificationCode.length == 6,
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
                            text = "Verify Email",
                            color = Color(0xFF30A030),
                            fontSize = 18.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = "✓",
                            color = Color(0xFF30A030),
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Resend Code
            TextButton(
                onClick = {
                    // TODO: Implement resend functionality
                    ToastManager.showInfo(context, "Verification code resent to $email")
                }
            ) {
                Text(
                    text = stringResource(R.string.not_receive_code),
                    color = Color.White.copy(alpha = 0.8f),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium
                )
            }

            Spacer(modifier = Modifier.weight(1f))
        }
    }
}

private fun handleVerification(
    authService: AuthService,
    email: String,
    verificationCode: String,
    context: android.content.Context,
    focusManager: androidx.compose.ui.focus.FocusManager,
    onSuccess: () -> Unit,
    coroutineScope: kotlinx.coroutines.CoroutineScope
) {
    if (verificationCode.length != 6) {
        ToastManager.showError(context, "Please enter a 6-digit verification code")
        return
    }

    focusManager.clearFocus()

    coroutineScope.launch {
        try {
            authService.confirmSignUp(email, verificationCode)
            ToastManager.showSuccess(context, "Email verified! You can now sign in.")
            onSuccess()
        } catch (e: Exception) {
            ToastManager.showError(context, e.message ?: "Verification failed")
        }
    }
}
