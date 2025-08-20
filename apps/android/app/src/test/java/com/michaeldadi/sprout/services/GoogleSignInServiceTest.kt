package com.michaeldadi.sprout.services

import android.content.Context
import androidx.activity.ComponentActivity
import androidx.credentials.*
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.MockitoJUnitRunner
import org.mockito.kotlin.any
import org.mockito.kotlin.whenever
import kotlin.test.assertEquals
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(MockitoJUnitRunner::class)
class GoogleSignInServiceTest {

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

    @Before
    fun setup() {
        // Mock CredentialManager.create to return our mock
        mockStatic(CredentialManager::class.java).use { mockedStatic ->
            mockedStatic.`when`<CredentialManager> { CredentialManager.create(any()) }
                .thenReturn(mockCredentialManager)

            googleSignInService = GoogleSignInService(mockContext, mockActivity)
        }

        // Use reflection to inject the mocked CredentialManager
        val credentialManagerField = GoogleSignInService::class.java.getDeclaredField("credentialManager")
        credentialManagerField.isAccessible = true
        credentialManagerField.set(googleSignInService, mockCredentialManager)
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
        assertTrue(result is GoogleSignInResult.Success)
        val successResult = result
        assertEquals(mockIdToken, successResult.idToken)
        assertEquals(mockEmail, successResult.email)
        assertEquals(mockDisplayName, successResult.displayName)
    }

    @Test
    fun `signIn should return cancelled result when user cancels`() = runTest {
        // Arrange
        val mockException = android.credentials.GetCredentialException("User cancelled")
        whenever(mockCredentialManager.getCredential(any(), any<GetCredentialRequest>()))
            .thenThrow(mockException)

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
            .thenThrow(mockException)

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
        assertTrue(result.message.contains("Invalid credential type"))
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
        assertTrue(result is GoogleSignInResult.Success)
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
        assertTrue(result is GoogleSignInResult.Success)
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

        // Assert - Verify the request was made with correct parameters
        verify(mockCredentialManager).getCredential(
            eq(mockActivity),
            any<GetCredentialRequest>()
        )
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
