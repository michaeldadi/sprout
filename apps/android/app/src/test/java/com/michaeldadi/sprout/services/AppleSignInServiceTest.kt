package com.michaeldadi.sprout.services

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.ComponentActivity
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.MockedStatic
import org.mockito.Mockito.*
import org.mockito.junit.MockitoJUnitRunner
import org.mockito.kotlin.any
import org.mockito.kotlin.whenever
import kotlin.test.assertEquals
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(MockitoJUnitRunner::class)
class AppleSignInServiceTest {

    @Mock
    private lateinit var mockContext: Context

    @Mock
    private lateinit var mockActivity: ComponentActivity

    @Mock
    private lateinit var mockIntent: Intent

    @Mock
    private lateinit var mockUri: Uri

    private lateinit var appleSignInService: AppleSignInService

    private lateinit var mockedUriStatic: MockedStatic<Uri>

    @Before
    fun setup() {
        appleSignInService = AppleSignInService(mockContext, mockActivity)

        // Mock static Uri methods
        mockedUriStatic = mockStatic(Uri::class.java)

        // Clear any existing completion state
        AppleSignInService.currentSignInCompletion = null
        AppleSignInService.codeVerifier = null
    }

    @After
    fun tearDown() {
        mockedUriStatic.close()
    }

    @Test
    fun `generateCodeVerifier should create valid PKCE verifier`() {
        // Use reflection to access private method
        val method = AppleSignInService::class.java.getDeclaredMethod("generateCodeVerifier")
        method.isAccessible = true

        val verifier = method.invoke(appleSignInService) as String

        // Should be 128 characters
        assertEquals(128, verifier.length)

        // Should only contain valid PKCE characters
        val validChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        assertTrue(verifier.all { it in validChars })
    }

    @Test
    fun `generateCodeChallenge should create valid challenge from verifier`() {
        // Use reflection to access private methods
        val generateVerifierMethod = AppleSignInService::class.java.getDeclaredMethod("generateCodeVerifier")
        generateVerifierMethod.isAccessible = true

        val generateChallengeMethod = AppleSignInService::class.java.getDeclaredMethod("generateCodeChallenge", String::class.java)
        generateChallengeMethod.isAccessible = true

        val verifier = generateVerifierMethod.invoke(appleSignInService) as String
        val challenge = generateChallengeMethod.invoke(appleSignInService, verifier) as String

        // Challenge should be base64 URL encoded (no padding)
        assertTrue(challenge.matches(Regex("[A-Za-z0-9_-]+")))
        assertTrue(challenge.isNotEmpty())

        // Same verifier should always produce same challenge
        val challenge2 = generateChallengeMethod.invoke(appleSignInService, verifier) as String
        assertEquals(challenge, challenge2)
    }

    @Test
    fun `generateState should create random state parameter`() {
        // Use reflection to access private method
        val method = AppleSignInService::class.java.getDeclaredMethod("generateState")
        method.isAccessible = true

        val state1 = method.invoke(appleSignInService) as String
        val state2 = method.invoke(appleSignInService) as String

        // States should be different (random)
        assertTrue(state1 != state2)

        // Should be base64 encoded
        assertTrue(state1.matches(Regex("[A-Za-z0-9_-]+")))
        assertTrue(state1.isNotEmpty())
    }

    @Test
    fun `buildAppleAuthorizationUrl should construct correct URL`() {
        // Use reflection to access private method
        val method = AppleSignInService::class.java.getDeclaredMethod(
            "buildAppleAuthorizationUrl",
            String::class.java,
            String::class.java,
            String::class.java,
            String::class.java
        )
        method.isAccessible = true

        // Mock Uri.parse and builder
        val mockUriBuilder = mock(Uri.Builder::class.java)
        whenever(mockUriBuilder.appendQueryParameter(any(), any())).thenReturn(mockUriBuilder)
        whenever(mockUriBuilder.build()).thenReturn(mockUri)
        whenever(mockUri.toString()).thenReturn("https://appleid.apple.com/auth/authorize?client_id=test")

        mockedUriStatic.`when`<Uri.Builder> { Uri.parse(any()).buildUpon() }.thenReturn(mockUriBuilder)

        val url = method.invoke(
            appleSignInService,
            "com.example.app",
            "com.example.app://auth/apple",
            "test-state",
            "test-challenge"
        ) as String

        assertTrue(url.contains("appleid.apple.com"))
    }

    @Test
    fun `parseUserInfo should extract email from ID token`() {
        // Use reflection to access private method
        val method = AppleSignInService::class.java.getDeclaredMethod(
            "parseUserInfo",
            String::class.java,
            String::class.java
        )
        method.isAccessible = true

        // Create a mock JWT token with base64 encoded payload
        // {"email":"test@example.com","sub":"123456"}
        val payload = """{"email":"test@example.com","sub":"123456"}"""
        val encodedPayload = java.util.Base64.getUrlEncoder().encodeToString(payload.toByteArray())
        val mockIdToken = "header.$encodedPayload.signature"

        val userInfo = method.invoke(appleSignInService, mockIdToken, null) as UserInfo

        assertEquals("test@example.com", userInfo.email)
    }

    @Test
    fun `parseUserInfo should extract full name from user JSON`() {
        // Use reflection to access private method
        val method = AppleSignInService::class.java.getDeclaredMethod(
            "parseUserInfo",
            String::class.java,
            String::class.java
        )
        method.isAccessible = true

        val userJson = """{"name":{"firstName":"John","lastName":"Doe"}}"""

        val userInfo = method.invoke(appleSignInService, null, userJson) as UserInfo

        assertEquals("John Doe", userInfo.fullName)
    }

    @Test
    fun `handleCallback should process successful authorization code`() = runTest {
        // Arrange
        whenever(mockIntent.data).thenReturn(mockUri)
        whenever(mockUri.scheme).thenReturn("com.michaeldadi.sprout")
        whenever(mockUri.host).thenReturn("auth")
        whenever(mockUri.path).thenReturn("/apple")
        whenever(mockUri.getQueryParameter("code")).thenReturn("auth-code")
        whenever(mockUri.getQueryParameter("id_token")).thenReturn("id-token")
        whenever(mockUri.getQueryParameter("state")).thenReturn("test-state")
        whenever(mockUri.getQueryParameter("error")).thenReturn(null)
        whenever(mockUri.getQueryParameter("user")).thenReturn(null)

        // Set up code verifier for token exchange
        AppleSignInService.codeVerifier = "test-verifier"

        // Mock the completion deferred
        val completion = kotlinx.coroutines.CompletableDeferred<AppleSignInResult>()
        AppleSignInService.currentSignInCompletion = completion

        // Act
        appleSignInService.handleCallback(mockIntent)

        // Wait for completion
        val result = completion.await()

        // Assert
        assertTrue(result is AppleSignInResult.Success)
        assertEquals("auth-code", result.authorizationCode)
    }

    @Test
    fun `handleCallback should handle error from Apple`() = runTest {
        // Arrange
        whenever(mockIntent.data).thenReturn(mockUri)
        whenever(mockUri.scheme).thenReturn("com.michaeldadi.sprout")
        whenever(mockUri.host).thenReturn("auth")
        whenever(mockUri.path).thenReturn("/apple")
        whenever(mockUri.getQueryParameter("error")).thenReturn("user_cancelled")
        whenever(mockUri.getQueryParameter("code")).thenReturn(null)

        // Mock the completion deferred
        val completion = kotlinx.coroutines.CompletableDeferred<AppleSignInResult>()
        AppleSignInService.currentSignInCompletion = completion

        // Act
        appleSignInService.handleCallback(mockIntent)

        // Wait for completion
        val result = completion.await()

        // Assert
        assertTrue(result is AppleSignInResult.Error)
        assertTrue(result.message.contains("user_cancelled"))
    }

    @Test
    fun `handleCallback should handle invalid response`() = runTest {
        // Arrange
        whenever(mockIntent.data).thenReturn(mockUri)
        whenever(mockUri.scheme).thenReturn("com.michaeldadi.sprout")
        whenever(mockUri.host).thenReturn("auth")
        whenever(mockUri.path).thenReturn("/apple")
        whenever(mockUri.getQueryParameter("error")).thenReturn(null)
        whenever(mockUri.getQueryParameter("code")).thenReturn(null)
        whenever(mockUri.getQueryParameter("id_token")).thenReturn(null)

        // Mock the completion deferred
        val completion = kotlinx.coroutines.CompletableDeferred<AppleSignInResult>()
        AppleSignInService.currentSignInCompletion = completion

        // Act
        appleSignInService.handleCallback(mockIntent)

        // Wait for completion
        val result = completion.await()

        // Assert
        assertTrue(result is AppleSignInResult.Error)
        assertTrue(result.message.contains("Invalid response"))
    }

    @Test
    fun `handleCallback should ignore non-Apple callbacks`() = runTest {
        // Arrange - Different scheme
        whenever(mockIntent.data).thenReturn(mockUri)
        whenever(mockUri.scheme).thenReturn("different-scheme")

        // Mock the completion deferred (should not be completed)
        val completion = kotlinx.coroutines.CompletableDeferred<AppleSignInResult>()
        AppleSignInService.currentSignInCompletion = completion

        // Act
        appleSignInService.handleCallback(mockIntent)

        // Assert - Completion should not be triggered
        assertTrue(completion.isActive) // Still waiting
    }

    @Test
    fun `signOut should clear stored state`() = runTest {
        // Arrange
        AppleSignInService.codeVerifier = "test-verifier"
        val completion = kotlinx.coroutines.CompletableDeferred<AppleSignInResult>()
        AppleSignInService.currentSignInCompletion = completion

        // Act
        appleSignInService.signOut()

        // Assert
        assertEquals(null, AppleSignInService.codeVerifier)
        assertTrue(completion.isCompleted)

        val result = completion.await()
        assertTrue(result is AppleSignInResult.Cancelled)
    }

    @Test
    fun `generateClientSecret should return empty string for security`() {
        // Use reflection to access private method
        val method = AppleSignInService::class.java.getDeclaredMethod("generateClientSecret")
        method.isAccessible = true

        val clientSecret = method.invoke(appleSignInService) as String

        // Should return empty string as documented in the method
        assertEquals("", clientSecret)
    }
}
