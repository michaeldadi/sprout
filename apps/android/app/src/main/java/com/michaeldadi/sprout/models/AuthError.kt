package com.michaeldadi.sprout.models

/**
 * Authentication error types
 * Mirrors the iOS AuthError enum
 */
sealed class AuthError(message: String) : Exception(message) {
    class SignUpFailed(message: String) : AuthError("Sign up failed: $message")
    class ConfirmationFailed(message: String) : AuthError("Confirmation failed: $message")
    class SignInFailed(message: String) : AuthError("Sign in failed: $message")
    class ChallengeRequired(challenge: String) : AuthError("Challenge required: $challenge")
    class ForgotPasswordFailed(message: String) : AuthError("Password reset request failed: $message")
    class PasswordResetFailed(message: String) : AuthError("Password reset failed: $message")
    class TokenRefreshFailed(message: String) : AuthError("Token refresh failed: $message")
    object NotAuthenticated : AuthError("User is not authenticated")
}