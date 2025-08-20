package com.michaeldadi.sprout.ui.screens

import android.content.Context
import android.content.Intent
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
import com.michaeldadi.sprout.R
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withLink
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.michaeldadi.sprout.config.AppConfig
import com.michaeldadi.sprout.managers.ToastManager
import com.michaeldadi.sprout.services.AuthService
import com.michaeldadi.sprout.services.GoogleSignInService
import com.michaeldadi.sprout.services.GoogleSignInResult
import com.michaeldadi.sprout.services.AppleSignInService
import com.michaeldadi.sprout.services.AppleSignInResult
import com.michaeldadi.sprout.ui.components.FloatingCirclesBackground
import com.michaeldadi.sprout.ui.components.SocialLoginButton
import kotlinx.coroutines.launch
import java.util.regex.Pattern
import androidx.activity.ComponentActivity
import androidx.core.net.toUri

/**
 * Sign up screen that mirrors the iOS SignUpView design and functionality
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SignUpScreen(
    onNavigateToLogin: () -> Unit,
    onNavigateToVerification: (String) -> Unit,
    authService: AuthService = viewModel()
) {
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current
    val coroutineScope = rememberCoroutineScope()

    // State
    var firstName by remember { mutableStateOf("") }
    var lastName by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var isPasswordVisible by remember { mutableStateOf(false) }
    var isConfirmPasswordVisible by remember { mutableStateOf(false) }

    // Auth state
    val isLoading by authService.isLoading.collectAsState()

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
        FloatingCirclesBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .systemBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(40.dp))

            // Logo Section
            SignUpLogoSection()

            Spacer(modifier = Modifier.height(25.dp))

            // Sign Up Form
            SignUpForm(
                firstName = firstName,
                onFirstNameChange = { firstName = it },
                lastName = lastName,
                onLastNameChange = { lastName = it },
                email = email,
                onEmailChange = { email = it },
                password = password,
                onPasswordChange = { password = it },
                confirmPassword = confirmPassword,
                onConfirmPasswordChange = { confirmPassword = it },
                isPasswordVisible = isPasswordVisible,
                onPasswordVisibilityToggle = { isPasswordVisible = !isPasswordVisible },
                isConfirmPasswordVisible = isConfirmPasswordVisible,
                onConfirmPasswordVisibilityToggle = { isConfirmPasswordVisible = !isConfirmPasswordVisible },
                onSignUp = {
                    coroutineScope.launch {
                        try {
                            authService.signUp(email, password)
                            ToastManager.showSuccess(context, "Account created! Please check your email for verification code.")
                            onNavigateToVerification(email)
                        } catch (e: Exception) {
                            ToastManager.showError(context, e.message ?: "Sign up failed")
                        }
                    }
                },
                isLoading = isLoading,
                focusManager = focusManager,
                context = context,
                coroutineScope = coroutineScope,
                authService = authService,
                onNavigateToVerification = onNavigateToVerification
            )

            Spacer(modifier = Modifier.height(20.dp))

            // Login Link
            LoginLink(onNavigateToLogin = onNavigateToLogin)

            Spacer(modifier = Modifier.height(30.dp))
        }
    }
}

@Composable
private fun SignUpLogoSection() {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // App Logo
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

            // Leaf icon
            Box(
                modifier = Modifier
                    .size(60.dp)
                    .background(Color.White.copy(alpha = 0.9f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "🌱",
                    fontSize = 30.sp
                )
            }
        }

        Spacer(modifier = Modifier.height(15.dp))

        // Welcome Text
        Text(
            text = "Create your Account",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Join Sprout and start growing",
            fontSize = 14.sp,
            color = Color.White.copy(alpha = 0.8f)
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SignUpForm(
    firstName: String,
    onFirstNameChange: (String) -> Unit,
    lastName: String,
    onLastNameChange: (String) -> Unit,
    email: String,
    onEmailChange: (String) -> Unit,
    password: String,
    onPasswordChange: (String) -> Unit,
    confirmPassword: String,
    onConfirmPasswordChange: (String) -> Unit,
    isPasswordVisible: Boolean,
    onPasswordVisibilityToggle: () -> Unit,
    isConfirmPasswordVisible: Boolean,
    onConfirmPasswordVisibilityToggle: () -> Unit,
    onSignUp: () -> Unit,
    isLoading: Boolean,
    focusManager: androidx.compose.ui.focus.FocusManager,
    context: Context,
    coroutineScope: kotlinx.coroutines.CoroutineScope,
    authService: AuthService,
    onNavigateToVerification: (String) -> Unit
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Name Fields Row
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // First Name Field
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = "First Name",
                    color = Color.White.copy(alpha = 0.8f),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium
                )

                OutlinedTextField(
                    value = firstName,
                    onValueChange = onFirstNameChange,
                    placeholder = {
                        Text(
                            text = "First",
                            color = Color.White.copy(alpha = 0.5f)
                        )
                    },
                    leadingIcon = {
                        Text(
                            text = "👤",
                            fontSize = 16.sp,
                            modifier = Modifier.padding(start = 4.dp)
                        )
                    },
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Text,
                        imeAction = ImeAction.Next
                    ),
                    keyboardActions = KeyboardActions(
                        onNext = { focusManager.moveFocus(FocusDirection.Right) }
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
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                )
            }

            // Last Name Field
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = "Last Name",
                    color = Color.White.copy(alpha = 0.8f),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium
                )

                OutlinedTextField(
                    value = lastName,
                    onValueChange = onLastNameChange,
                    placeholder = {
                        Text(
                            text = "Last",
                            color = Color.White.copy(alpha = 0.5f)
                        )
                    },
                    leadingIcon = {
                        Text(
                            text = "👤",
                            fontSize = 16.sp,
                            modifier = Modifier.padding(start = 4.dp)
                        )
                    },
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Text,
                        imeAction = ImeAction.Next
                    ),
                    keyboardActions = KeyboardActions(
                        onNext = { focusManager.moveFocus(FocusDirection.Down) }
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
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }

        // Email Field
        SignUpTextField(
            title = "Email",
            value = email,
            onValueChange = onEmailChange,
            placeholder = "Enter your email",
            keyboardType = KeyboardType.Email,
            imeAction = ImeAction.Next,
            onImeAction = { focusManager.moveFocus(FocusDirection.Down) },
            leadingIcon = "✉️"
        )

        // Password Field
        SignUpTextField(
            title = "Password",
            value = password,
            onValueChange = onPasswordChange,
            placeholder = "Create password",
            keyboardType = KeyboardType.Password,
            imeAction = ImeAction.Next,
            onImeAction = { focusManager.moveFocus(FocusDirection.Down) },
            leadingIcon = "🔒",
            isPassword = true,
            isPasswordVisible = isPasswordVisible,
            onPasswordVisibilityToggle = onPasswordVisibilityToggle
        )

        // Confirm Password Field
        SignUpTextField(
            title = "Confirm Password",
            value = confirmPassword,
            onValueChange = onConfirmPasswordChange,
            placeholder = "Confirm password",
            keyboardType = KeyboardType.Password,
            imeAction = ImeAction.Done,
            onImeAction = { onSignUp() },
            leadingIcon = "🔒",
            isPassword = true,
            isPasswordVisible = isConfirmPasswordVisible,
            onPasswordVisibilityToggle = onConfirmPasswordVisibilityToggle
        )

        // Terms and Conditions
        TermsAndConditions(context = context)

        // Sign Up Button
        Button(
            onClick = {
                if (firstName.isBlank()) {
                    ToastManager.showError(context, "Please enter your first name")
                    return@Button
                }
                if (lastName.isBlank()) {
                    ToastManager.showError(context, "Please enter your last name")
                    return@Button
                }
                if (email.isBlank()) {
                    ToastManager.showError(context, "Please enter your email")
                    return@Button
                }
                if (!isValidEmail(email)) {
                    ToastManager.showError(context, "Please enter a valid email address")
                    return@Button
                }
                if (password.isBlank()) {
                    ToastManager.showError(context, "Please create a password")
                    return@Button
                }
                if (password.length < 8) {
                    ToastManager.showError(context, "Password must be at least 8 characters")
                    return@Button
                }
                if (password != confirmPassword) {
                    ToastManager.showError(context, "Passwords do not match")
                    return@Button
                }

                focusManager.clearFocus()
                onSignUp()
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            enabled = !isLoading,
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.White,
                disabledContainerColor = Color.White.copy(alpha = 0.7f)
            ),
            shape = RoundedCornerShape(12.dp)
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
                        text = "Create Account",
                        color = Color(0xFF30A030),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = "→",
                        color = Color(0xFF30A030),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.offset(y = (-3).dp)
                    )
                }
            }
        }

        // Divider
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
          HorizontalDivider(
            modifier = Modifier.weight(1f),
            thickness = 1.dp,
            color = Color.White.copy(alpha = 0.3f)
          )
          Text(
                text = "OR",
                modifier = Modifier.padding(horizontal = 8.dp),
                color = Color.White.copy(alpha = 0.6f),
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium
            )
            HorizontalDivider(
              modifier = Modifier.weight(1f),
              thickness = 1.dp,
              color = Color.White.copy(alpha = 0.3f)
            )
        }

        // Social Sign Up Buttons
        Column(
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            SocialLoginButton(
              text = stringResource(R.string.continue_with_google),
              backgroundColor = Color.White,
              textColor = Color.Black,
              icon = "google",
              onClick = {
                coroutineScope.launch {
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
                          ToastManager.showSuccess(context, "Signed up successfully! Please check your email for verification.")
                          onNavigateToVerification(result.email)
                        }
                        is GoogleSignInResult.Cancelled -> {
                          ToastManager.showInfo(context, "Sign up cancelled")
                        }
                        is GoogleSignInResult.Error -> {
                          ToastManager.showError(context, result.message)
                        }
                      }
                    } else {
                      ToastManager.showError(context, "Unable to get activity context")
                    }
                  } catch (e: Exception) {
                    ToastManager.showError(context, e.message ?: "Google Sign Up failed")
                  }
                }
              }
            )

            SocialLoginButton(
                text = stringResource(R.string.continue_with_apple),
                backgroundColor = Color.Black,
                textColor = Color.White,
                icon = "apple",
                onClick = {
                    coroutineScope.launch {
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
                                        ToastManager.showSuccess(context, "Signed up successfully! Please check your email for verification.")
                                        result.email?.let { onNavigateToVerification(it) }
                                    }
                                    is AppleSignInResult.Cancelled -> {
                                        ToastManager.showInfo(context, "Sign up cancelled")
                                    }
                                    is AppleSignInResult.Error -> {
                                        ToastManager.showError(context, result.message)
                                    }
                                }
                            } else {
                                ToastManager.showError(context, "Unable to get activity context")
                            }
                        } catch (e: Exception) {
                            ToastManager.showError(context, e.message ?: "Apple Sign Up failed")
                        }
                    }
                }
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SignUpTextField(
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
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text(
            text = title,
            color = Color.White.copy(alpha = 0.8f),
            fontSize = 12.sp,
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
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
private fun TermsAndConditions(context: Context) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "By continuing, you agree to our",
            fontSize = 12.sp,
            color = Color.White.copy(alpha = 0.8f),
            textAlign = TextAlign.Center
        )

        Row(
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val annotatedString = buildAnnotatedString {
                val termsLink = LinkAnnotation.Url(AppConfig.termsUrl)
                withLink(termsLink) {
                    withStyle(style = SpanStyle(
                        color = Color.White,
                        fontWeight = FontWeight.Medium,
                        textDecoration = TextDecoration.Underline
                    )) {
                        append("Terms of Service")
                    }
                }

                withStyle(style = SpanStyle(color = Color.White.copy(alpha = 0.8f))) {
                    append(" and ")
                }

                val privacyLink = LinkAnnotation.Url(AppConfig.privacyUrl)
                withLink(privacyLink) {
                    withStyle(style = SpanStyle(
                        color = Color.White,
                        fontWeight = FontWeight.Medium,
                        textDecoration = TextDecoration.Underline
                    )) {
                        append("Privacy Policy")
                    }
                }
            }

            Text(
                text = annotatedString,
                fontSize = 12.sp
            )
        }
    }
}

@Composable
private fun LoginLink(onNavigateToLogin: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "Already have an account?",
            color = Color.White.copy(alpha = 0.7f),
            fontSize = 14.sp
        )

        TextButton(onClick = onNavigateToLogin) {
            Text(
                text = "Sign In",
                color = Color.White,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

private fun isValidEmail(email: String): Boolean {
    val emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    return Pattern.compile(emailRegex).matcher(email).matches()
}

private fun openUrl(context: Context, url: String) {
    val intent = Intent(Intent.ACTION_VIEW, url.toUri())
    context.startActivity(intent)
}
