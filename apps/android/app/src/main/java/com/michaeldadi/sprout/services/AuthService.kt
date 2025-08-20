package com.michaeldadi.sprout.services

import android.app.Application
import android.content.Context
import android.content.SharedPreferences
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.michaeldadi.sprout.config.CognitoConfig
import com.michaeldadi.sprout.models.AuthError
import com.michaeldadi.sprout.models.CognitoUser
import com.michaeldadi.sprout.models.StoredTokens
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import aws.sdk.kotlin.services.cognitoidentityprovider.CognitoIdentityProviderClient
import aws.sdk.kotlin.services.cognitoidentityprovider.model.*
import java.util.*
import androidx.core.content.edit

/**
 * Authentication service for handling Cognito authentication
 * Mirrors the iOS AuthService.swift structure and functionality
 */
class AuthService(application: Application) : AndroidViewModel(application) {

    companion object {
        private const val PREFS_NAME = "sprout_auth_prefs"
        private const val KEY_TOKENS = "cognito_tokens"
    }

    private val cognitoClient = CognitoIdentityProviderClient {
        region = CognitoConfig.region
    }

    private val prefs: SharedPreferences = application.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // State management
    private val _isAuthenticated = MutableStateFlow(false)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated.asStateFlow()

    private val _currentUser = MutableStateFlow<CognitoUser?>(null)
    val currentUser: StateFlow<CognitoUser?> = _currentUser.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    // MARK: - Sign Up
    suspend fun signUp(email: String, passwordText: String) {
        _isLoading.value = true
        try {
            val signUpRequest = SignUpRequest {
                clientId = CognitoConfig.clientId
                username = email
                password = passwordText
                userAttributes = listOf(
                    AttributeType {
                        name = "email"
                        value = email
                    }
                )
            }

            val response = cognitoClient.signUp(signUpRequest)
            println("Sign up successful: $response")
        } catch (e: Exception) {
            println("Sign up error: ${e.message}")
            throw AuthError.SignUpFailed(e.message ?: "Unknown error")
        } finally {
            _isLoading.value = false
        }
    }

    // MARK: - Confirm Sign Up
    suspend fun confirmSignUp(email: String, confirmationCodeText: String) {
        _isLoading.value = true
        try {
            val confirmRequest = ConfirmSignUpRequest {
                clientId = CognitoConfig.clientId
                username = email
                confirmationCode = confirmationCodeText
            }

            val response = cognitoClient.confirmSignUp(confirmRequest)
            println("Confirmation successful: $response")
        } catch (e: Exception) {
            println("Confirmation error: ${e.message}")
            throw AuthError.ConfirmationFailed(e.message ?: "Unknown error")
        } finally {
            _isLoading.value = false
        }
    }

    // MARK: - Sign In
    suspend fun signIn(email: String, password: String) {
        _isLoading.value = true
        try {
            val authRequest = InitiateAuthRequest {
                authFlow = AuthFlowType.UserPasswordAuth
                clientId = CognitoConfig.clientId
                authParameters = mapOf(
                    "USERNAME" to email,
                    "PASSWORD" to password
                )
            }

            val response = cognitoClient.initiateAuth(authRequest)

            response.authenticationResult?.let { authResult ->
                val accessToken = authResult.accessToken
                val idToken = authResult.idToken
                val refreshToken = authResult.refreshToken

                if (accessToken != null && idToken != null && refreshToken != null) {
                    // Store tokens securely
                    storeTokens(accessToken, idToken, refreshToken)

                    // Create user object
                    val user = CognitoUser(
                        email = email,
                        accessToken = accessToken,
                        idToken = idToken,
                        refreshToken = refreshToken
                    )

                    _currentUser.value = user
                    _isAuthenticated.value = true
                }
            } ?: run {
                response.challengeName?.let { challengeName ->
                    throw AuthError.ChallengeRequired(challengeName.toString())
                }
            }

        } catch (e: AuthError) {
            throw e
        } catch (e: Exception) {
            println("Sign in error: ${e.message}")
            throw AuthError.SignInFailed(e.message ?: "Unknown error")
        } finally {
            _isLoading.value = false
        }
    }

    // MARK: - Sign Out
    suspend fun signOut() {
        _isLoading.value = true
        try {
            _currentUser.value?.accessToken?.let { accessTokenVal ->
                val signOutRequest = GlobalSignOutRequest {
                    accessToken = accessTokenVal
                }

                cognitoClient.globalSignOut(signOutRequest)
            }
        } catch (e: Exception) {
            println("Sign out error: ${e.message}")
        } finally {
            // Clear local state regardless of API call result
            clearStoredTokens()
            _currentUser.value = null
            _isAuthenticated.value = false
            _isLoading.value = false
        }
    }

    // MARK: - Forgot Password
    suspend fun forgotPassword(email: String) {
        _isLoading.value = true
        try {
            val forgotPasswordRequest = ForgotPasswordRequest {
                clientId = CognitoConfig.clientId
                username = email
            }

            val response = cognitoClient.forgotPassword(forgotPasswordRequest)
            println("Forgot password initiated: $response")
        } catch (e: Exception) {
            println("Forgot password error: ${e.message}")
            throw AuthError.ForgotPasswordFailed(e.message ?: "Unknown error")
        } finally {
            _isLoading.value = false
        }
    }

    // MARK: - Confirm Forgot Password
    suspend fun confirmForgotPassword(email: String, confirmationCodeText: String, newPassword: String) {
        _isLoading.value = true
        try {
            val confirmRequest = ConfirmForgotPasswordRequest {
                clientId = CognitoConfig.clientId
                username = email
                confirmationCode = confirmationCodeText
                password = newPassword
            }

            val response = cognitoClient.confirmForgotPassword(confirmRequest)
            println("Password reset successful: $response")
        } catch (e: Exception) {
            println("Password reset error: ${e.message}")
            throw AuthError.PasswordResetFailed(e.message ?: "Unknown error")
        } finally {
            _isLoading.value = false
        }
    }

    // MARK: - Apple Sign In
    suspend fun signInWithApple(idToken: String, authorizationCode: String, email: String?, fullName: String?) {
        _isLoading.value = true
        try {
            // First, check if we need to exchange the authorization code for tokens
            // This would typically be done on your backend server
            println("Apple Sign In - Authorization Code: $authorizationCode")
            println("Apple Sign In - ID Token: $idToken")

            // For Cognito federated sign in, you have two options:
            // 1. Use a custom authentication flow (requires Lambda triggers)
            // 2. Use AdminInitiateAuth with ADMIN_USER_PASSWORD_AUTH (requires backend)

            // Option 1: Try custom auth flow
            try {
                val authRequest = InitiateAuthRequest {
                    authFlow = AuthFlowType.CustomAuth
                    clientId = CognitoConfig.clientId
                    authParameters = mapOf(
                        "USERNAME" to (email ?: "apple_user"),
                        "CHALLENGE_NAME" to "APPLE_SIGNIN",
                        "ID_TOKEN" to idToken
                    )
                }

                val response = cognitoClient.initiateAuth(authRequest)

                response.authenticationResult?.let { authResult ->
                    handleAuthenticationResult(authResult, email ?: "apple_user@example.com")
                } ?: response.challengeName?.let { challenge ->
                    // Handle custom auth challenge if needed
                    println("Apple Sign In Challenge: $challenge")
                    throw AuthError.ChallengeRequired(challenge.toString())
                }
            } catch (customAuthError: Exception) {
                // If custom auth fails, try creating/linking user
                println("Custom auth failed, trying user creation: ${customAuthError.message}")

                // Extract email from ID token if not provided
                val userEmail = email ?: extractEmailFromAppleIdToken(idToken) ?: "apple_user_${UUID.randomUUID()}@example.com"

                // Create or get existing user
                signUpOrLinkAppleUser(userEmail, idToken, fullName)
            }

        } catch (e: Exception) {
            println("Apple Sign In error: ${e.message}")
            throw AuthError.SignInFailed("Apple Sign In failed: ${e.message}")
        } finally {
            _isLoading.value = false
        }
    }

    private suspend fun signUpOrLinkAppleUser(email: String, idToken: String, fullName: String?) {
        // First, try to see if user exists
        try {
            // Check if user already exists by trying to sign in
            val testAuthRequest = InitiateAuthRequest {
                authFlow = AuthFlowType.UserPasswordAuth
                clientId = CognitoConfig.clientId
                authParameters = mapOf(
                    "USERNAME" to email,
                    "PASSWORD" to "DummyPassword123!" // This will fail but tells us if user exists
                )
            }
            cognitoClient.initiateAuth(testAuthRequest)
        } catch (e: Exception) {
            if (e.message?.contains("NotAuthorizedException") == true) {
                // User exists but password is wrong - this means they signed up with Apple before
                // In production, you'd link the Apple ID to the existing user
                println("User exists, would link Apple ID: $email")
                throw AuthError.SignInFailed("Please sign in with your original method")
            } else if (e.message?.contains("UserNotFoundException") == true) {
                // User doesn't exist, create new user
                signUpWithApple(email, idToken, fullName)
            }
        }
    }

    private suspend fun signUpWithApple(email: String, idToken: String, fullName: String?) {
        val names = fullName?.split(" ") ?: listOf()
        val givenName = names.firstOrNull() ?: ""
        val familyName = if (names.size > 1) names.drop(1).joinToString(" ") else ""

        val signUpRequest = SignUpRequest {
            clientId = CognitoConfig.clientId
            username = email
            password = UUID.randomUUID().toString() // Generate random password for Apple users
            userAttributes = listOf(
                AttributeType {
                    name = "email"
                    value = email
                },
                AttributeType {
                    name = "email_verified"
                    value = "true"
                },
                AttributeType {
                    name = "given_name"
                    value = givenName
                },
                AttributeType {
                    name = "family_name"
                    value = familyName
                }
            )
        }

        val response = cognitoClient.signUp(signUpRequest)
        println("Apple user sign up successful: $response")

        // Note: AdminConfirmSignUp requires admin privileges
        // In production, you'd handle this server-side
        println("Would auto-confirm Apple user: $email")
    }

    private fun extractEmailFromAppleIdToken(idToken: String): String? {
        try {
            // Split the JWT token
            val parts = idToken.split(".")
            if (parts.size >= 2) {
                // Decode the payload (second part)
                val payload = String(Base64.getUrlDecoder().decode(parts[1]))

                // Simple JSON parsing - extract email
                val emailPattern = """"email":\s*"([^"]+)"""".toRegex()
                val emailMatch = emailPattern.find(payload)
                return emailMatch?.groupValues?.get(1)
            }
        } catch (e: Exception) {
            println("Error extracting email from Apple ID token: ${e.message}")
        }
        return null
    }

    private fun handleAuthenticationResult(authResult: AuthenticationResultType, email: String) {
        val accessToken = authResult.accessToken
        val idToken = authResult.idToken
        val refreshToken = authResult.refreshToken

        if (accessToken != null && idToken != null && refreshToken != null) {
            // Store tokens securely
            storeTokens(accessToken, idToken, refreshToken)

            // Create user object
            val user = CognitoUser(
                email = email,
                accessToken = accessToken,
                idToken = idToken,
                refreshToken = refreshToken
            )

            _currentUser.value = user
            _isAuthenticated.value = true
        }
    }

    // MARK: - Google Sign In
    suspend fun signInWithGoogle(idToken: String, email: String, fullName: String?) {
        _isLoading.value = true
        try {
            // Use federated sign in with Google ID token
            val authRequest = InitiateAuthRequest {
                authFlow = AuthFlowType.CustomAuth
                clientId = CognitoConfig.clientId
                authParameters = mapOf(
                    "PROVIDER_NAME" to "Google",
                    "ID_TOKEN" to idToken
                )
            }

            val response = cognitoClient.initiateAuth(authRequest)

            response.authenticationResult?.let { authResult ->
                handleAuthenticationResult(authResult, email)
            } ?: run {
                // If custom auth is not set up, fall back to creating a regular user
                signUpWithGoogle(email, idToken, fullName)
            }

        } catch (e: Exception) {
            println("Google Sign In error: ${e.message}")
            throw AuthError.SignInFailed("Google Sign In failed: ${e.message}")
        } finally {
            _isLoading.value = false
        }
    }

    private suspend fun signUpWithGoogle(email: String, idToken: String, fullName: String?) {
        val names = fullName?.split(" ") ?: listOf()
        val givenName = names.firstOrNull() ?: ""
        val familyName = if (names.size > 1) names.drop(1).joinToString(" ") else ""

        val signUpRequest = SignUpRequest {
            clientId = CognitoConfig.clientId
            username = email
            password = UUID.randomUUID().toString() // Generate random password for Google users
            userAttributes = listOf(
                AttributeType {
                    name = "email"
                    value = email
                },
                AttributeType {
                    name = "email_verified"
                    value = "true"
                },
                AttributeType {
                    name = "given_name"
                    value = givenName
                },
                AttributeType {
                    name = "family_name"
                    value = familyName
                }
            )
        }

        val response = cognitoClient.signUp(signUpRequest)
        println("Google user sign up successful: $response")

        // Auto-confirm the user since Google has already verified the email
        println("Would auto-confirm Google user: $email")
    }

    // MARK: - Check Existing Session
    suspend fun checkExistingSession() {
        getStoredTokens()?.let { storedTokens ->
            // Validate tokens by making a test request
            try {
                val getUserRequest = GetUserRequest {
                    accessToken = storedTokens.accessToken
                }

                val response = cognitoClient.getUser(getUserRequest)

                // Create user from stored data
                response.userAttributes.find { it.name == "email" }?.value?.let { email ->
                    val user = CognitoUser(
                        email = email,
                        accessToken = storedTokens.accessToken,
                        idToken = storedTokens.idToken,
                        refreshToken = storedTokens.refreshToken
                    )
                    _currentUser.value = user
                    _isAuthenticated.value = true
                }
            } catch (e: Exception) {
                // Tokens are invalid, try to refresh
                try {
                    refreshSession(storedTokens)
                } catch (refreshError: Exception) {
                    // Refresh failed, clear everything
                    clearStoredTokens()
                }
            }
        }
    }

    // MARK: - Refresh Token
    private suspend fun refreshSession(storedTokens: StoredTokens) {
        _isLoading.value = true
        try {
            val refreshRequest = InitiateAuthRequest {
                authFlow = AuthFlowType.RefreshTokenAuth
                clientId = CognitoConfig.clientId
                authParameters = mapOf("REFRESH_TOKEN" to storedTokens.refreshToken)
            }

            val response = cognitoClient.initiateAuth(refreshRequest)

            response.authenticationResult?.let { authResult ->
                val accessToken = authResult.accessToken
                val idToken = authResult.idToken

                if (accessToken != null && idToken != null) {
                    // Update tokens
                    storeTokens(accessToken, idToken, storedTokens.refreshToken)

                    _currentUser.value?.let { currentUser ->
                        val updatedUser = currentUser.copy(
                            accessToken = accessToken,
                            idToken = idToken
                        )
                        _currentUser.value = updatedUser
                    }
                }
            }

        } catch (e: Exception) {
            println("Token refresh error: ${e.message}")
            // If refresh fails, sign out the user
            signOut()
            throw AuthError.TokenRefreshFailed(e.message ?: "Unknown error")
        } finally {
            _isLoading.value = false
        }
    }

    // MARK: - Token Storage
    private fun storeTokens(accessToken: String, idToken: String, refreshToken: String) {
        val tokens = StoredTokens(
            accessToken = accessToken,
            idToken = idToken,
            refreshToken = refreshToken
        )

        // Convert to JSON string for storage
        // In a real app, you'd use a more secure storage solution like EncryptedSharedPreferences
        val tokensJson = """
            {
                "accessToken": "${tokens.accessToken}",
                "idToken": "${tokens.idToken}",
                "refreshToken": "${tokens.refreshToken}"
            }
        """.trimIndent()

        prefs.edit().putString(KEY_TOKENS, tokensJson).apply()
    }

    private fun getStoredTokens(): StoredTokens? {
        val tokensJson = prefs.getString(KEY_TOKENS, null) ?: return null

        // In a real app, you'd use a proper JSON parsing library like Gson or Moshi
        // This is a simplified parsing for demonstration
        return try {
            // Simple JSON parsing - replace with proper library in production
            val accessToken = tokensJson.substringAfter("\"accessToken\": \"").substringBefore("\",")
            val idToken = tokensJson.substringAfter("\"idToken\": \"").substringBefore("\",")
            val refreshToken = tokensJson.substringAfter("\"refreshToken\": \"").substringBefore("\"")

            StoredTokens(accessToken, idToken, refreshToken)
        } catch (e: Exception) {
            null
        }
    }

    private fun clearStoredTokens() {
        prefs.edit { remove(KEY_TOKENS) }
    }

    // Initialize the service by checking for existing session
    init {
        viewModelScope.launch {
            checkExistingSession()
        }
    }
}
