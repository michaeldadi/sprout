package com.michaeldadi.sprout.services

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.ComponentActivity
import androidx.browser.customtabs.CustomTabsIntent
import com.michaeldadi.sprout.config.AppConfig
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.Base64
import kotlin.random.Random
import org.json.JSONObject

/**
 * Native Apple Sign In service for Android that works without Cognito hosted UI
 * Uses Apple's REST API for authentication and then creates/signs in users with Cognito
 */
class AppleSignInService(
    private val context: Context,
    private val activity: ComponentActivity
) {
    companion object {
        // Apple Sign In REST API endpoints
        const val APPLE_AUTH_URL = "https://appleid.apple.com/auth/authorize"
        const val APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token"
        const val APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"

        // App-specific configuration
        const val REDIRECT_URI = "com.michaeldadi.sprout://auth/apple"
        const val RESPONSE_TYPE = "code id_token"
        const val RESPONSE_MODE = "form_post"
        const val SCOPE = "name email"

        // Store the current sign in completion and code verifier
        var currentSignInCompletion: CompletableDeferred<AppleSignInResult>? = null
        var codeVerifier: String? = null
    }

    /**
     * Initiates native Apple Sign In flow
     */
    suspend fun signIn(): AppleSignInResult = withContext(Dispatchers.Main) {
        try {
            // Generate PKCE parameters for security
            val verifier = generateCodeVerifier()
            val challenge = generateCodeChallenge(verifier)
            val state = generateState()

            // Store code verifier for later token exchange
            codeVerifier = verifier

            // Build Apple authorization URL
            val authUrl = buildAppleAuthorizationUrl(
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
     * Handles the OAuth callback from Apple
     */
    suspend fun handleCallback(intent: Intent) {
        val data = intent.data
        if (data != null && data.scheme == "com.michaeldadi.sprout" && data.host == "auth" && data.path == "/apple") {
            // Extract parameters from the callback
            val code = data.getQueryParameter("code")
            val idToken = data.getQueryParameter("id_token")
            val state = data.getQueryParameter("state")
            val error = data.getQueryParameter("error")
            val user = data.getQueryParameter("user") // Apple sends user info on first sign in

            val result = when {
                error != null -> {
                    AppleSignInResult.Error("Apple Sign In error: $error")
                }
                code != null -> {
                    // Exchange authorization code for access token
                    try {
                        val tokens = exchangeCodeForTokens(code)
                        val userInfo = parseUserInfo(idToken, user)

                        AppleSignInResult.Success(
                            authorizationCode = code,
                            idToken = tokens.idToken,
                            accessToken = tokens.accessToken,
                            refreshToken = tokens.refreshToken,
                            email = userInfo.email,
                            fullName = userInfo.fullName
                        )
                    } catch (e: Exception) {
                        AppleSignInResult.Error("Token exchange failed: ${e.message}")
                    }
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
     * Exchanges authorization code for tokens using Apple's token endpoint
     */
    private suspend fun exchangeCodeForTokens(authorizationCode: String): AppleTokens = withContext(Dispatchers.IO) {
        val url = URL(APPLE_TOKEN_URL)
        val connection = url.openConnection() as HttpURLConnection

        try {
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
            connection.doOutput = true

            // Prepare POST data
            val postData = buildString {
                append("client_id=").append(AppConfig.appleSignInServiceId)
                append("&client_secret=").append(generateClientSecret()) // You'll need to implement this
                append("&code=").append(authorizationCode)
                append("&grant_type=authorization_code")
                append("&redirect_uri=").append(REDIRECT_URI)
                codeVerifier?.let {
                    append("&code_verifier=").append(it)
                }
            }

            // Send request
            OutputStreamWriter(connection.outputStream).use { writer ->
                writer.write(postData)
                writer.flush()
            }

            // Read response
            val responseCode = connection.responseCode
            if (responseCode == 200) {
                val responseBody = connection.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(responseBody)

                AppleTokens(
                    accessToken = json.optString("access_token", ""),
                    idToken = json.optString("id_token", ""),
                    refreshToken = json.optString("refresh_token", ""),
                    tokenType = json.optString("token_type", "Bearer"),
                    expiresIn = json.optInt("expires_in", 3600)
                )
            } else {
                val errorBody = connection.errorStream?.bufferedReader()?.use { it.readText() } ?: "Unknown error"
                throw Exception("Token exchange failed: $errorBody")
            }
        } finally {
            connection.disconnect()
        }
    }

    /**
     * Parses user information from ID token and user parameter
     */
    private fun parseUserInfo(idToken: String?, userJson: String?): UserInfo {
        var email: String? = null
        var fullName: String? = null

        // Parse ID token if available
        idToken?.let { token ->
            try {
                val parts = token.split(".")
                if (parts.size >= 2) {
                    val payload = String(Base64.getUrlDecoder().decode(parts[1]))
                    val json = JSONObject(payload)
                    email = json.optString("email", "")
                }
            } catch (e: Exception) {
                // ID token parsing failed
            }
        }

        // Parse user info if available (only sent on first sign in)
        userJson?.let { json ->
            try {
                val userObj = JSONObject(json)
                val name = userObj.optJSONObject("name")
                if (name != null) {
                    val firstName = name.optString("firstName", "")
                    val lastName = name.optString("lastName", "")
                    fullName = "$firstName $lastName".trim()
                }
            } catch (e: Exception) {
                // User info parsing failed
            }
        }

        return UserInfo(email, fullName)
    }

    /**
     * Generates client secret JWT for Apple token exchange
     * This should ideally be done on your backend server
     */
    private fun generateClientSecret(): String {
        // IMPORTANT: In production, this should be generated on your backend server
        // using your Apple private key (.p8 file) and proper JWT signing
        // For now, return empty string - you'll need to implement this
        return ""
    }

    /**
     * Builds the Apple authorization URL
     */
    private fun buildAppleAuthorizationUrl(
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
     * Signs out from Apple
     */
    suspend fun signOut() {
        // Clear any cached Apple credentials
        codeVerifier = null
        currentSignInCompletion?.complete(AppleSignInResult.Cancelled)
        currentSignInCompletion = null
    }
}

/**
 * Data classes for Apple Sign In
 */
data class AppleTokens(
    val accessToken: String,
    val idToken: String,
    val refreshToken: String,
    val tokenType: String,
    val expiresIn: Int
)

data class UserInfo(
    val email: String?,
    val fullName: String?
)

/**
 * Result classes for Apple Sign In
 */
sealed class AppleSignInResult {
    data class Success(
        val authorizationCode: String,
        val idToken: String,
        val accessToken: String = "",
        val refreshToken: String = "",
        val email: String?,
        val fullName: String?
    ) : AppleSignInResult()

    object Cancelled : AppleSignInResult()

    data class Error(
        val message: String
    ) : AppleSignInResult()
}
