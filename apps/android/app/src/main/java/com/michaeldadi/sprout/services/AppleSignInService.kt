package com.michaeldadi.sprout.services

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.browser.customtabs.CustomTabsIntent
import com.michaeldadi.sprout.config.AppConfig
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.security.MessageDigest
import java.util.Base64
import kotlin.random.Random

/**
 * Apple Sign In service for Android using web-based OAuth flow
 */
class AppleSignInService(
    private val context: Context,
    private val activity: ComponentActivity
) {
    companion object {
        const val APPLE_AUTH_URL = "https://appleid.apple.com/auth/authorize"
        const val REDIRECT_URI = "com.michaeldadi.sprout://auth/apple/callback"
        const val RESPONSE_TYPE = "code id_token"
        const val RESPONSE_MODE = "form_post"
        const val SCOPE = "name email"
        
        // Store the current sign in completion
        var currentSignInCompletion: CompletableDeferred<AppleSignInResult>? = null
        var codeVerifier: String? = null
    }
    
    /**
     * Initiates Apple Sign In flow using Custom Tabs
     */
    suspend fun signIn(): AppleSignInResult = withContext(Dispatchers.Main) {
        try {
            // Generate PKCE parameters
            val verifier = generateCodeVerifier()
            val challenge = generateCodeChallenge(verifier)
            codeVerifier = verifier
            
            // Generate state for security
            val state = generateState()
            
            // Build the authorization URL
            val authUrl = buildAuthorizationUrl(
                clientId = AppConfig.appleSignInServiceId,
                redirectUri = REDIRECT_URI,
                state = state,
                codeChallenge = challenge
            )
            
            // Create a deferred result
            val deferred = CompletableDeferred<AppleSignInResult>()
            currentSignInCompletion = deferred
            
            // Launch Custom Tab
            val customTabsIntent = CustomTabsIntent.Builder()
                .setShowTitle(true)
                .build()
            
            customTabsIntent.launchUrl(activity, Uri.parse(authUrl))
            
            // Wait for the result
            deferred.await()
        } catch (e: Exception) {
            AppleSignInResult.Error(e.message ?: "Apple Sign In failed")
        }
    }
    
    /**
     * Handles the OAuth callback
     */
    fun handleCallback(intent: Intent) {
        val data = intent.data
        if (data != null && data.scheme == "com.michaeldadi.sprout" && data.host == "auth/apple/callback") {
            // Extract parameters from the callback
            val code = data.getQueryParameter("code")
            val idToken = data.getQueryParameter("id_token")
            val state = data.getQueryParameter("state")
            val error = data.getQueryParameter("error")
            
            val result = when {
                error != null -> {
                    AppleSignInResult.Error("Apple Sign In error: $error")
                }
                code != null && idToken != null -> {
                    // Parse the ID token to get user info
                    val userInfo = parseIdToken(idToken)
                    AppleSignInResult.Success(
                        authorizationCode = code,
                        idToken = idToken,
                        email = userInfo["email"],
                        fullName = userInfo["name"]
                    )
                }
                else -> {
                    AppleSignInResult.Error("Invalid response from Apple Sign In")
                }
            }
            
            // Complete the deferred result
            currentSignInCompletion?.complete(result)
            currentSignInCompletion = null
        }
    }
    
    /**
     * Builds the authorization URL for Apple Sign In
     */
    private fun buildAuthorizationUrl(
        clientId: String,
        redirectUri: String,
        state: String,
        codeChallenge: String
    ): String {
        return Uri.parse(APPLE_AUTH_URL).buildUpon()
            .appendQueryParameter("client_id", clientId)
            .appendQueryParameter("redirect_uri", redirectUri)
            .appendQueryParameter("response_type", RESPONSE_TYPE)
            .appendQueryParameter("response_mode", RESPONSE_MODE)
            .appendQueryParameter("scope", SCOPE)
            .appendQueryParameter("state", state)
            .appendQueryParameter("code_challenge", codeChallenge)
            .appendQueryParameter("code_challenge_method", "S256")
            .build()
            .toString()
    }
    
    /**
     * Generates a code verifier for PKCE
     */
    private fun generateCodeVerifier(): String {
        val chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        return (1..128)
            .map { chars[Random.nextInt(0, chars.length)] }
            .joinToString("")
    }
    
    /**
     * Generates a code challenge from the verifier
     */
    private fun generateCodeChallenge(verifier: String): String {
        val bytes = verifier.toByteArray(Charsets.US_ASCII)
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        return Base64.getUrlEncoder().withoutPadding().encodeToString(digest)
    }
    
    /**
     * Generates a random state parameter
     */
    private fun generateState(): String {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(
            ByteArray(32).apply { Random.nextBytes(this) }
        )
    }
    
    /**
     * Parses the ID token to extract user information
     */
    private fun parseIdToken(idToken: String): Map<String, String> {
        try {
            // Split the JWT token
            val parts = idToken.split(".")
            if (parts.size >= 2) {
                // Decode the payload (second part)
                val payload = String(Base64.getUrlDecoder().decode(parts[1]))
                
                // Simple JSON parsing - in production use a proper JSON library
                val email = payload.substringAfter("\"email\":\"").substringBefore("\"")
                val name = if (payload.contains("\"name\"")) {
                    payload.substringAfter("\"name\":\"").substringBefore("\"")
                } else null
                
                return mapOf(
                    "email" to email,
                    "name" to (name ?: "")
                )
            }
        } catch (e: Exception) {
            // Error parsing token
        }
        return emptyMap()
    }
    
    /**
     * Signs out from Apple
     */
    suspend fun signOut() {
        // Clear any cached Apple credentials
        // This is typically handled on the server side
        codeVerifier = null
    }
}

/**
 * Result classes for Apple Sign In
 */
sealed class AppleSignInResult {
    data class Success(
        val authorizationCode: String,
        val idToken: String,
        val email: String?,
        val fullName: String?
    ) : AppleSignInResult()
    
    object Cancelled : AppleSignInResult()
    
    data class Error(
        val message: String
    ) : AppleSignInResult()
}