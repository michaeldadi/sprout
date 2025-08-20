package com.michaeldadi.sprout.ui.screens

import androidx.compose.ui.res.stringResource
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.material3.HorizontalDivider
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.michaeldadi.sprout.R
import com.michaeldadi.sprout.managers.ToastManager
import com.michaeldadi.sprout.managers.rememberToastState
import com.michaeldadi.sprout.services.AuthService
import com.michaeldadi.sprout.services.GoogleSignInService
import com.michaeldadi.sprout.services.GoogleSignInResult
import com.michaeldadi.sprout.services.AppleSignInService
import com.michaeldadi.sprout.services.AppleSignInResult
import com.michaeldadi.sprout.ui.components.FloatingCirclesBackground
import com.michaeldadi.sprout.ui.components.SocialLoginButton
import androidx.activity.ComponentActivity

/**
 * Login screen that mirrors the iOS LoginView design and functionality
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreen(
    onNavigateToSignUp: () -> Unit,
    onNavigateToForgotPassword: () -> Unit,
    authService: AuthService = viewModel()
) {
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current
    val toastState = rememberToastState()

    // State
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isPasswordVisible by remember { mutableStateOf(false) }
    var shouldTriggerLogin by remember { mutableStateOf(false) }
    var shouldTriggerGoogleLogin by remember { mutableStateOf(false) }
    var shouldTriggerAppleLogin by remember { mutableStateOf(false) }

    val textLoginFailure = stringResource(R.string.login_failed)

    // Handle login attempts via LaunchedEffect
    LaunchedEffect(shouldTriggerLogin) {
        if (shouldTriggerLogin) {
            try {
                authService.signIn(email, password)
                // Success is handled by isAuthenticated state change
            } catch (e: Exception) {
                ToastManager.showError(context, e.message ?: textLoginFailure)
            } finally {
                shouldTriggerLogin = false
            }
        }
    }

    val textGoogleSignInFailure = stringResource(R.string.login_failed_google)

    // Handle Google login attempts
    LaunchedEffect(shouldTriggerGoogleLogin) {
        if (shouldTriggerGoogleLogin) {
            try {
                val activity = context as? ComponentActivity
                if (activity != null) {
                    val googleSignInService = GoogleSignInService(context, activity)
                    when (val result = googleSignInService.signIn()) {
                        is GoogleSignInResult.Success -> {
                            authService.signInWithGoogle(
                                idToken = result.idToken,
                                email = result.email,
                                fullName = result.displayName
                            )
                            // Success message is handled by LaunchedEffect
                        }
                        is GoogleSignInResult.Cancelled -> {
                            ToastManager.showInfo(context, "Sign in cancelled")
                        }
                        is GoogleSignInResult.Error -> {
                            ToastManager.showError(context, result.message)
                        }
                    }
                } else {
                    ToastManager.showError(context, "Unable to get activity context")
                }
            } catch (e: Exception) {
                ToastManager.showError(context, e.message ?: textGoogleSignInFailure)
            } finally {
                shouldTriggerGoogleLogin = false
            }
        }
    }

    val textAppleSignInFailure = stringResource(R.string.login_failed_apple)

    // Handle Apple login attempts
    LaunchedEffect(shouldTriggerAppleLogin) {
        if (shouldTriggerAppleLogin) {
            try {
                val activity = context as? ComponentActivity
                if (activity != null) {
                    val appleSignInService = AppleSignInService(context, activity)
                    when (val result = appleSignInService.signIn()) {
                        is AppleSignInResult.Success -> {
                            authService.signInWithApple(
                                idToken = result.idToken,
                                email = result.email,
                                fullName = result.fullName
                            )
                            // Success message is handled by LaunchedEffect
                        }
                        is AppleSignInResult.Cancelled -> {
                            ToastManager.showInfo(context, "Sign in cancelled")
                        }
                        is AppleSignInResult.Error -> {
                            ToastManager.showError(context, result.message)
                        }
                    }
                } else {
                    ToastManager.showError(context, "Unable to get activity context")
                }
            } catch (e: Exception) {
                ToastManager.showError(context, e.message ?: textAppleSignInFailure)
            } finally {
                shouldTriggerAppleLogin = false
            }
        }
    }

    // Auth state
    val isLoading by authService.isLoading.collectAsState()
    val isAuthenticated by authService.isAuthenticated.collectAsState()

    val textLoginSuccess = stringResource(R.string.login_success)

    // Handle navigation based on auth state changes - outside of coroutine scope
    LaunchedEffect(isAuthenticated) {
        if (isAuthenticated) {
            // Show success message and clear focus when authenticated
            ToastManager.showSuccess(context, textLoginSuccess)
            focusManager.clearFocus()
            // Navigation is handled by parent component observing auth state
        }
    }

    // Animation
    val infiniteTransition = rememberInfiniteTransition(label = "background")
    val animatedOffset by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(20000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "offset"
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
    ) {
        // Floating circles background
        FloatingCirclesBackground(animatedOffset = animatedOffset)

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 30.dp)
                .systemBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(40.dp))

            // Logo Section
            LogoSection()

            Spacer(modifier = Modifier.height(30.dp))

            // Login Form
            LoginForm(
                email = email,
                onEmailChange = { email = it },
                password = password,
                onPasswordChange = { password = it },
                isPasswordVisible = isPasswordVisible,
                onPasswordVisibilityToggle = { isPasswordVisible = !isPasswordVisible },
                onForgotPassword = onNavigateToForgotPassword,
                onLogin = {
                    shouldTriggerLogin = true
                },
                isLoading = isLoading,
                focusManager = focusManager,
                onTriggerGoogleLogin = { shouldTriggerGoogleLogin = true },
                onTriggerAppleLogin = { shouldTriggerAppleLogin = true }
            )

            Spacer(modifier = Modifier.weight(1f))

            // Sign Up Link
            SignUpLink(onNavigateToSignUp = onNavigateToSignUp)

            Spacer(modifier = Modifier.height(30.dp))
        }
    }
}

@Composable
private fun LogoSection() {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // App Logo
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

            // Leaf icon (using a simple circle with text for now)
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .background(Color.White.copy(alpha = 0.9f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "🌱",
                    fontSize = 40.sp
                )
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Welcome Text
        Text(
            text = stringResource(R.string.welcome_back),
            fontSize = 32.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = stringResource(R.string.login_continue_journey),
            fontSize = 16.sp,
            color = Color.White.copy(alpha = 0.8f)
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LoginForm(
    email: String,
    onEmailChange: (String) -> Unit,
    password: String,
    onPasswordChange: (String) -> Unit,
    isPasswordVisible: Boolean,
    onPasswordVisibilityToggle: () -> Unit,
    onForgotPassword: () -> Unit,
    onLogin: () -> Unit,
    isLoading: Boolean,
    focusManager: androidx.compose.ui.focus.FocusManager,
    onTriggerGoogleLogin: () -> Unit,
    onTriggerAppleLogin: () -> Unit
) {
    val context = LocalContext.current

    Column(
        verticalArrangement = Arrangement.spacedBy(15.dp)
    ) {
        // Email Field
        CustomTextField(
            title = stringResource(R.string.email),
            value = email,
            onValueChange = onEmailChange,
            placeholder = stringResource(R.string.enter_your_email),
            keyboardType = KeyboardType.Email,
            imeAction = ImeAction.Next,
            onImeAction = { focusManager.moveFocus(FocusDirection.Down) },
            leadingIcon = "✉️"
        )

        // Password Field
        CustomTextField(
            title = "Password",
            value = password,
            onValueChange = onPasswordChange,
            placeholder = stringResource(R.string.enter_your_password),
            keyboardType = KeyboardType.Password,
            imeAction = ImeAction.Done,
            onImeAction = { onLogin() },
            leadingIcon = "🔒",
            isPassword = true,
            isPasswordVisible = isPasswordVisible,
            onPasswordVisibilityToggle = onPasswordVisibilityToggle
        )

        // Forgot Password
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End
        ) {
            TextButton(onClick = onForgotPassword) {
                Text(
                    text = stringResource(R.string.forgot_password),
                    color = Color.White.copy(alpha = 0.8f),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }

        val textEnterEmail = stringResource(R.string.enter_your_email)
        val textEnterPassword = stringResource(R.string.enter_your_password)

        // Sign In Button
        Button(
            onClick = {
                if (email.isBlank()) {
                    ToastManager.showError(context, textEnterEmail)
                    return@Button
                }
                if (password.isBlank()) {
                    ToastManager.showError(context, textEnterPassword)
                    return@Button
                }
                onLogin()
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
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
                        text = stringResource(R.string.text_sign_in),
                        color = Color(0xFF30A030),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = "→",
                        color = Color(0xFF30A030),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.offset(y = (-4).dp)
                    )
                }
            }
        }

        // Divider
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 15.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
          HorizontalDivider(
            modifier = Modifier.weight(1f),
            thickness = 1.dp,
            color = Color.White.copy(alpha = 0.3f)
          )
          Text(
                text = stringResource(R.string.or_auth_divider_label),
                modifier = Modifier.padding(horizontal = 10.dp),
                color = Color.White.copy(alpha = 0.6f),
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium
            )
            HorizontalDivider(
              modifier = Modifier.weight(1f),
              thickness = 1.dp,
              color = Color.White.copy(alpha = 0.3f)
            )
        }

        // Social Login Buttons
        Column(
            verticalArrangement = Arrangement.spacedBy(15.dp)
        ) {
            SocialLoginButton(
              text = stringResource(R.string.continue_with_google),
              backgroundColor = Color.White,
              textColor = Color.Black,
              icon = "google",
              onClick = onTriggerGoogleLogin
            )

            SocialLoginButton(
                text = stringResource(R.string.continue_with_apple),
                backgroundColor = Color.Black,
                textColor = Color.White,
                icon = "apple",
                onClick = onTriggerAppleLogin
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CustomTextField(
    title: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    keyboardType: KeyboardType = KeyboardType.Text,
    imeAction: ImeAction = ImeAction.Next,
    onImeAction: () -> Unit = {},
    leadingIcon: String? = null,
    isPassword: Boolean = false,
    isPasswordVisible: Boolean = false,
    onPasswordVisibilityToggle: () -> Unit = {}
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            text = title,
            color = Color.White.copy(alpha = 0.8f),
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium
        )

        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = {
                Text(
                    text = placeholder,
                    color = Color.White.copy(alpha = 0.5f)
                )
            },
            leadingIcon = leadingIcon?.let { icon ->
                {
                    Text(
                        text = icon,
                        fontSize = 16.sp,
                        modifier = Modifier.padding(start = 4.dp)
                    )
                }
            },
            trailingIcon = if (isPassword) {
                {
                    IconButton(onClick = onPasswordVisibilityToggle) {
                        Text(
                            text = if (isPasswordVisible) "👁️" else "🙈",
                            fontSize = 16.sp
                        )
                    }
                }
            } else null,
            visualTransformation = if (isPassword && !isPasswordVisible) {
                PasswordVisualTransformation()
            } else {
                VisualTransformation.None
            },
            keyboardOptions = KeyboardOptions(
                keyboardType = keyboardType,
                imeAction = imeAction
            ),
            keyboardActions = KeyboardActions(
                onDone = { onImeAction() },
                onNext = { onImeAction() }
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
}

@Composable
private fun SignUpLink(onNavigateToSignUp: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = stringResource(R.string.not_have_an_account),
            color = Color.White.copy(alpha = 0.7f),
            fontSize = 16.sp
        )

        TextButton(onClick = onNavigateToSignUp) {
            Text(
                text = stringResource(R.string.text_sign_up),
                color = Color.White,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}
