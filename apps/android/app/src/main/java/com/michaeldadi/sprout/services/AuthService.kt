package com.michaeldadi.sprout.services

import android.app.Application
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

/**
 * Authentication service for handling Cognito authentication
 * Mirrors the iOS AuthService.swift structure and functionality
 */
class AuthService @JvmOverloads constructor(
    application: Application,
    private val cognitoClient: CognitoIdentityProviderClient = CognitoIdentityProviderClient {
        region = CognitoConfig.region
    },
    private val tokenStore: AuthTokenStore = AuthTokenStore(application)
) : AndroidViewModel(application) {

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

    suspend fun resendConfirmationCode(email: String) {
        _isLoading.value = true
        try {
            cognitoClient.resendConfirmationCode(ResendConfirmationCodeRequest {
                clientId = CognitoConfig.clientId
                username = email
            })
        } catch (e: Exception) {
            throw AuthError.ConfirmationFailed(e.message ?: "Could not resend the code")
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

            val authResult = response.authenticationResult ?: run {
                response.challengeName?.let { challengeName ->
                    throw AuthError.ChallengeRequired(challengeName.toString())
                }
                throw AuthError.SignInFailed("No session was returned")
            }
            val accessToken = authResult.accessToken ?: throw AuthError.SignInFailed("Missing session token")
            val idToken = authResult.idToken ?: throw AuthError.SignInFailed("Missing identity token")
            val refreshToken = authResult.refreshToken ?: throw AuthError.SignInFailed("Missing refresh token")

            storeTokens(accessToken, idToken, refreshToken)
            _currentUser.value = CognitoUser(
                email = email,
                accessToken = accessToken,
                idToken = idToken,
                refreshToken = refreshToken
            )
            _isAuthenticated.value = true

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

    // Social identity exchange needs a configured, server-verified provider flow.
    // Never create password users from a client-provided social token.
    suspend fun signInWithApple(idToken: String, email: String?, fullName: String?): Nothing {
        throw AuthError.SignInFailed("Apple sign-in is not available yet")
    }

    suspend fun signInWithGoogle(idToken: String, email: String, fullName: String?): Nothing {
        throw AuthError.SignInFailed("Google sign-in is not available yet")
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
                val email = response.userAttributes.find { it.name == "email" }?.value
                    ?.takeIf { it.isNotBlank() }
                    ?: throw AuthError.SignInFailed("Account identity is unavailable")
                _currentUser.value = CognitoUser(
                    email = email,
                    accessToken = storedTokens.accessToken,
                    idToken = storedTokens.idToken,
                    refreshToken = storedTokens.refreshToken
                )
                _isAuthenticated.value = true
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

            val authResult = response.authenticationResult
                ?: throw AuthError.TokenRefreshFailed("No session was returned")
            val accessToken = authResult.accessToken
                ?: throw AuthError.TokenRefreshFailed("Missing session token")
            val idToken = authResult.idToken
                ?: throw AuthError.TokenRefreshFailed("Missing identity token")
            val refreshedUser = cognitoClient.getUser(GetUserRequest { this.accessToken = accessToken })
            val email = refreshedUser.userAttributes.find { it.name == "email" }?.value
                ?.takeIf { it.isNotBlank() }
                ?: throw AuthError.TokenRefreshFailed("Account identity is unavailable")

            storeTokens(accessToken, idToken, storedTokens.refreshToken)
            _currentUser.value = CognitoUser(email, accessToken, idToken, storedTokens.refreshToken)
            _isAuthenticated.value = true

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
        tokenStore.save(StoredTokens(accessToken, idToken, refreshToken))
    }

    private fun getStoredTokens(): StoredTokens? = tokenStore.read()

    private fun clearStoredTokens() {
        tokenStore.clear()
    }

    // Initialize the service by checking for existing session
    init {
        viewModelScope.launch {
            checkExistingSession()
        }
    }
}
