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
    suspend fun signInWithApple(idToken: String, authorizationCode: String, fullName: String?) {
        _isLoading.value = true
        try {
            // For federated authentication, we would typically use AdminInitiateAuth
            // with APPLE as the identity provider. For now, we'll create a user with Apple credentials
            val email = extractEmailFromAppleIdToken(idToken) ?: "apple_user@example.com"

            // Try to sign in first (user might already exist)
            try {
                signIn(email, authorizationCode)
            } catch (e: Exception) {
                // If sign in fails, try to create account
                signUpWithApple(email, idToken, fullName)
            }

        } catch (e: Exception) {
            println("Apple Sign In error: ${e.message}")
            throw AuthError.SignInFailed("Apple Sign In failed: ${e.message}")
        } finally {
            _isLoading.value = false
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
        // In a real implementation, you would decode the JWT token
        // For now, we'll return null and handle it in the calling function
        return null
    }

    // MARK: - Google Sign In
    suspend fun signInWithGoogle(idToken: String, accessToken: String, email: String, fullName: String?) {
        _isLoading.value = true
        try {
            // Try to sign in first (user might already exist)
            try {
                signIn(email, accessToken)
            } catch (e: Exception) {
                // If sign in fails, try to create account
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
