package com.michaeldadi.sprout.services

import android.content.Context
import androidx.activity.ComponentActivity
import androidx.credentials.*
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.michaeldadi.sprout.config.AppConfig
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.MockitoJUnit
import org.mockito.junit.MockitoRule
import org.mockito.kotlin.any
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.eq
import org.mockito.kotlin.whenever
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class GoogleSignInServiceTest {

    @get:Rule
    val mockitoRule: MockitoRule = MockitoJUnit.rule()

    @Mock
    private lateinit var mockContext: Context

    @Mock
    private lateinit var mockActivity: ComponentActivity

    @Mock
    private lateinit var mockCredentialManager: CredentialManager

    @Mock
    private lateinit var mockGetCredentialResponse: GetCredentialResponse

    @Mock
    private lateinit var mockGoogleIdTokenCredential: GoogleIdTokenCredential

    private lateinit var googleSignInService: GoogleSignInService
    private val testServerClientId = "test-web-client.apps.googleusercontent.com"

    @Before
    fun setup() {
        googleSignInService = GoogleSignInService(mockContext, mockActivity, mockCredentialManager, testServerClientId)
    }

    @Test
    fun `signIn should return success result with valid credentials`() = runTest {
        // Arrange
        val mockIdToken = "mock-id-token"
        val mockEmail = "test@example.com"
        val mockDisplayName = "Test User"

        whenever(mockGetCredentialResponse.credential).thenReturn(mockGoogleIdTokenCredential)
        whenever(mockGoogleIdTokenCredential.idToken).thenReturn(mockIdToken)
        whenever(mockGoogleIdTokenCredential.id).thenReturn(mockEmail)
        whenever(mockGoogleIdTokenCredential.displayName).thenReturn(mockDisplayName)

        whenever(mockCredentialManager.getCredential(any(), any<GetCredentialRequest>()))
            .thenReturn(mockGetCredentialResponse)

        // Act
        val result = googleSignInService.signIn()

        // Assert
        assertTrue(result is GoogleSignInResult.Success, "Unexpected result: $result")
        val successResult = result
        assertEquals(mockIdToken, successResult.idToken)
        assertEquals(mockEmail, successResult.email)
        assertEquals(mockDisplayName, successResult.displayName)
    }

    @Test
    fun `signIn should return cancelled result when user cancels`() = runTest {
        // Arrange
        val mockException = androidx.credentials.exceptions.GetCredentialCancellationException("User cancelled")
        whenever(mockCredentialManager.getCredential(any(), any<GetCredentialRequest>()))
            .thenAnswer { throw mockException }

        // Act
        val result = googleSignInService.signIn()

        // Assert
        assertTrue(result is GoogleSignInResult.Cancelled)
    }

    @Test
    fun `signIn should return error result when no credential available`() = runTest {
        // Arrange
        val mockException = NoCredentialException("No credential available")
        whenever(mockCredentialManager.getCredential(any(), any<GetCredentialRequest>()))
            .thenAnswer { throw mockException }

        // Act
        val result = googleSignInService.signIn()

        // Assert
        assertTrue(result is GoogleSignInResult.Error)
        assertTrue(result.message.contains("No credential available"))
    }

    @Test
    fun `signIn should return error result when credential is not GoogleIdTokenCredential`() = runTest {
        // Arrange
        val mockWrongCredential = mock(Credential::class.java)
        whenever(mockGetCredentialResponse.credential).thenReturn(mockWrongCredential)
        whenever(mockCredentialManager.getCredential(any(), any<GetCredentialRequest>()))
            .thenReturn(mockGetCredentialResponse)

        // Act
        val result = googleSignInService.signIn()

        // Assert
        assertTrue(result is GoogleSignInResult.Error)
        assertTrue(result.message.contains("Unknown credential type"))
    }

    @Test
    fun `signIn should handle missing display name gracefully`() = runTest {
        // Arrange
        val mockIdToken = "mock-id-token"
        val mockEmail = "test@example.com"

        whenever(mockGetCredentialResponse.credential).thenReturn(mockGoogleIdTokenCredential)
        whenever(mockGoogleIdTokenCredential.idToken).thenReturn(mockIdToken)
        whenever(mockGoogleIdTokenCredential.id).thenReturn(mockEmail)
        whenever(mockGoogleIdTokenCredential.displayName).thenReturn(null)

        whenever(mockCredentialManager.getCredential(any(), any<GetCredentialRequest>()))
            .thenReturn(mockGetCredentialResponse)

        // Act
        val result = googleSignInService.signIn()

        // Assert
        assertTrue(result is GoogleSignInResult.Success, "Unexpected result: $result")
        val successResult = result
        assertEquals(mockIdToken, successResult.idToken)
        assertEquals(mockEmail, successResult.email)
        assertEquals(null, successResult.displayName)
    }

    @Test
    fun `signIn should handle empty email gracefully`() = runTest {
        // Arrange
        val mockIdToken = "mock-id-token"
        val mockDisplayName = "Test User"

        whenever(mockGetCredentialResponse.credential).thenReturn(mockGoogleIdTokenCredential)
        whenever(mockGoogleIdTokenCredential.idToken).thenReturn(mockIdToken)
        whenever(mockGoogleIdTokenCredential.id).thenReturn("")
        whenever(mockGoogleIdTokenCredential.displayName).thenReturn(mockDisplayName)

        whenever(mockCredentialManager.getCredential(any(), any<GetCredentialRequest>()))
            .thenReturn(mockGetCredentialResponse)

        // Act
        val result = googleSignInService.signIn()

        // Assert
        assertTrue(result is GoogleSignInResult.Success, "Unexpected result: $result")
        val successResult = result
        assertEquals(mockIdToken, successResult.idToken)
        assertEquals("", successResult.email)
        assertEquals(mockDisplayName, successResult.displayName)
    }

    @Test
    fun `signIn should create proper GetCredentialRequest`() = runTest {
        // Arrange
        whenever(mockGetCredentialResponse.credential).thenReturn(mockGoogleIdTokenCredential)
        whenever(mockGoogleIdTokenCredential.idToken).thenReturn("token")
        whenever(mockGoogleIdTokenCredential.id).thenReturn("test@example.com")
        whenever(mockGoogleIdTokenCredential.displayName).thenReturn("Test")

        whenever(mockCredentialManager.getCredential(any(), any<GetCredentialRequest>()))
            .thenReturn(mockGetCredentialResponse)

        // Act
        googleSignInService.signIn()

        val requestCaptor = argumentCaptor<GetCredentialRequest>()
        verify(mockCredentialManager).getCredential(eq(mockActivity), requestCaptor.capture())
        val googleOption = requestCaptor.firstValue.credentialOptions.single() as GetGoogleIdOption
        assertEquals(testServerClientId, googleOption.serverClientId)
        assertEquals(false, googleOption.filterByAuthorizedAccounts)
    }

    @Test
    fun `signOut should complete without errors`() = runTest {
        // Act & Assert - Should not throw exception
        googleSignInService.signOut()

        // For now, signOut is a no-op, but this test ensures the method exists
        // and can be called without issues
    }

    @Test
    fun `GoogleSignInResult Success should contain all required fields`() {
        // Test the data class structure
        val result = GoogleSignInResult.Success(
            idToken = "test-token",
            email = "test@example.com",
            displayName = "Test User",
            photoUrl = null
        )

        assertEquals("test-token", result.idToken)
        assertEquals("test@example.com", result.email)
        assertEquals("Test User", result.displayName)
    }

    @Test
    fun `GoogleSignInResult Error should contain message`() {
        val errorMessage = "Authentication failed"
        val result = GoogleSignInResult.Error(errorMessage)

        assertEquals(errorMessage, result.message)
    }

    @Test
    fun `GoogleSignInResult Cancelled should be object`() {
        val result = GoogleSignInResult.Cancelled

        // Just verify it's the correct type
        assertTrue(result is GoogleSignInResult.Cancelled)
        assertEquals(GoogleSignInResult.Cancelled, result)
    }
}
