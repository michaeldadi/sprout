package com.michaeldadi.sprout.services

import android.app.Application
import android.content.SharedPreferences
import aws.sdk.kotlin.services.cognitoidentityprovider.CognitoIdentityProviderClient
import aws.sdk.kotlin.services.cognitoidentityprovider.model.*
import com.michaeldadi.sprout.models.AuthError
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
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
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(MockitoJUnitRunner::class)
class AuthServiceTest {

    @Mock
    private lateinit var mockApplication: Application

    @Mock
    private lateinit var mockCognitoClient: CognitoIdentityProviderClient

    @Mock
    private lateinit var mockSharedPreferences: SharedPreferences

    @Mock
    private lateinit var mockEditor: SharedPreferences.Editor

    private lateinit var authService: AuthService

    @Before
    fun setup() {
        // Mock SharedPreferences
        whenever(mockApplication.getSharedPreferences(any<String>(), any<Int>()))
            .thenReturn(mockSharedPreferences)
        whenever(mockSharedPreferences.edit()).thenReturn(mockEditor)
        whenever(mockEditor.putString(any(), any())).thenReturn(mockEditor)
        whenever(mockEditor.apply()).then { }

        // Create AuthService instance
        authService = AuthService(mockApplication)

        // Use reflection to inject mocked CognitoClient
        val cognitoClientField = AuthService::class.java.getDeclaredField("cognitoClient")
        cognitoClientField.isAccessible = true
        cognitoClientField.set(authService, mockCognitoClient)
    }

    @Test
    fun `signUp should complete successfully with valid credentials`() = runTest {
        // Arrange
        val email = "test@example.com"
        val password = "TestPassword123!"
        val mockResponse = mock(SignUpResponse::class.java)
        whenever(mockResponse.userSub).thenReturn("test-user-sub")

        whenever(mockCognitoClient.signUp(any<SignUpRequest>())).thenReturn(mockResponse)

        // Act & Assert - Should not throw exception
        authService.signUp(email, password)

        // Verify loading state
        assertFalse(authService.isLoading.first())
    }

    @Test
    fun `signUp should throw AuthError when Cognito fails`() = runTest {
        // Arrange
        val email = "test@example.com"
        val password = "TestPassword123!"

        whenever(mockCognitoClient.signUp(any<SignUpRequest>()))
            .thenThrow(RuntimeException("Cognito error"))

        // Act & Assert
        assertFailsWith<AuthError.SignUpFailed> {
            authService.signUp(email, password)
        }

        assertFalse(authService.isLoading.first())
    }

    @Test
    fun `confirmSignUp should complete successfully`() = runTest {
        // Arrange
        val email = "test@example.com"
        val code = "123456"
        val mockResponse = mock(ConfirmSignUpResponse::class.java)

        whenever(mockCognitoClient.confirmSignUp(any<ConfirmSignUpRequest>()))
            .thenReturn(mockResponse)

        // Act & Assert - Should not throw exception
        authService.confirmSignUp(email, code)

        assertFalse(authService.isLoading.first())
    }

    @Test
    fun `confirmSignUp should throw AuthError when confirmation fails`() = runTest {
        // Arrange
        val email = "test@example.com"
        val code = "invalid"

        whenever(mockCognitoClient.confirmSignUp(any<ConfirmSignUpRequest>()))
            .thenThrow(RuntimeException("Invalid confirmation code"))

        // Act & Assert
        assertFailsWith<AuthError.ConfirmationFailed> {
            authService.confirmSignUp(email, code)
        }
    }

    @Test
    fun `signIn should authenticate user successfully`() = runTest {
        // Arrange
        val email = "test@example.com"
        val password = "TestPassword123!"

        val authResult = mock(AuthenticationResultType::class.java)
        whenever(authResult.accessToken).thenReturn("access-token")
        whenever(authResult.idToken).thenReturn("id-token")
        whenever(authResult.refreshToken).thenReturn("refresh-token")

        val mockResponse = mock(InitiateAuthResponse::class.java)
        whenever(mockResponse.authenticationResult).thenReturn(authResult)

        whenever(mockCognitoClient.initiateAuth(any<InitiateAuthRequest>()))
            .thenReturn(mockResponse)

        // Act
        authService.signIn(email, password)

        // Assert
        assertTrue(authService.isAuthenticated.first())
        assertEquals(email, authService.currentUser.first()?.email)
    }

    @Test
    fun `signIn should handle challenge required`() = runTest {
        // Arrange
        val email = "test@example.com"
        val password = "TestPassword123!"

        val mockResponse = mock(InitiateAuthResponse::class.java)
        whenever(mockResponse.challengeName).thenReturn(ChallengeNameType.NewPasswordRequired)

        whenever(mockCognitoClient.initiateAuth(any<InitiateAuthRequest>()))
            .thenReturn(mockResponse)

        // Act & Assert
        assertFailsWith<AuthError.ChallengeRequired> {
            authService.signIn(email, password)
        }
    }

    @Test
    fun `signIn should throw AuthError when authentication fails`() = runTest {
        // Arrange
        val email = "test@example.com"
        val password = "wrong-password"

        whenever(mockCognitoClient.initiateAuth(any<InitiateAuthRequest>()))
            .thenThrow(RuntimeException("Authentication failed"))

        // Act & Assert
        assertFailsWith<AuthError.SignInFailed> {
            authService.signIn(email, password)
        }
    }

    @Test
    fun `signOut should clear user state`() = runTest {
        // Arrange
        val mockResponse = mock(GlobalSignOutResponse::class.java)
        whenever(mockCognitoClient.globalSignOut(any<GlobalSignOutRequest>()))
            .thenReturn(mockResponse)

        // First sign in a user
        val authResult = mock(AuthenticationResultType::class.java)
        whenever(authResult.accessToken).thenReturn("access-token")
        whenever(authResult.idToken).thenReturn("id-token")
        whenever(authResult.refreshToken).thenReturn("refresh-token")

        val signInResponse = mock(InitiateAuthResponse::class.java)
        whenever(signInResponse.authenticationResult).thenReturn(authResult)

        whenever(mockCognitoClient.initiateAuth(any<InitiateAuthRequest>()))
            .thenReturn(signInResponse)

        authService.signIn("test@example.com", "password")
        assertTrue(authService.isAuthenticated.first())

        // Act
        authService.signOut()

        // Assert
        assertFalse(authService.isAuthenticated.first())
        assertEquals(null, authService.currentUser.first())
    }

    @Test
    fun `forgotPassword should initiate password reset`() = runTest {
        // Arrange
        val email = "test@example.com"
        val mockResponse = mock(ForgotPasswordResponse::class.java)

        whenever(mockCognitoClient.forgotPassword(any<ForgotPasswordRequest>()))
            .thenReturn(mockResponse)

        // Act & Assert - Should not throw exception
        authService.forgotPassword(email)

        assertFalse(authService.isLoading.first())
    }

    @Test
    fun `confirmForgotPassword should reset password successfully`() = runTest {
        // Arrange
        val email = "test@example.com"
        val code = "123456"
        val newPassword = "NewPassword123!"
        val mockResponse = mock(ConfirmForgotPasswordResponse::class.java)

        whenever(mockCognitoClient.confirmForgotPassword(any<ConfirmForgotPasswordRequest>()))
            .thenReturn(mockResponse)

        // Act & Assert - Should not throw exception
        authService.confirmForgotPassword(email, code, newPassword)

        assertFalse(authService.isLoading.first())
    }

    @Test
    fun `signInWithApple should create new user when email extraction succeeds`() = runTest {
        // Arrange
        val idToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6ImZoNmFjIn0.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwiYXVkIjoiY29tLmV4YW1wbGUuYXBwIiwiZXhwIjoxNjAwMDAwMDAwLCJpYXQiOjE2MDAwMDAwMDAsInN1YiI6IjAwMDAwMC4xMjM0NTY3ODkwYWJjZGVmIiwiZW1haWwiOiJ0ZXN0QGV4YW1wbGUuY29tIiwiZW1haWxfdmVyaWZpZWQiOiJ0cnVlIn0.signature"
        val email = "test@example.com"
        val fullName = "Test User"

        // Mock signUp first (user doesn't exist)
        whenever(mockCognitoClient.initiateAuth(any<InitiateAuthRequest>()))
            .thenThrow(RuntimeException("UserNotFoundException"))

        val signUpResponse = mock(SignUpResponse::class.java)
        whenever(signUpResponse.userSub).thenReturn("test-user-sub")
        whenever(mockCognitoClient.signUp(any<SignUpRequest>()))
            .thenReturn(signUpResponse)

        // Then mock successful sign in
        val authResult = mock(AuthenticationResultType::class.java)
        whenever(authResult.accessToken).thenReturn("access-token")
        whenever(authResult.idToken).thenReturn("id-token")
        whenever(authResult.refreshToken).thenReturn("refresh-token")

        val signInResponse = mock(InitiateAuthResponse::class.java)
        whenever(signInResponse.authenticationResult).thenReturn(authResult)

        whenever(mockCognitoClient.initiateAuth(any<InitiateAuthRequest>()))
            .thenReturn(signInResponse)

        // Act
        authService.signInWithApple(idToken, email, fullName)

        // Assert
        assertTrue(authService.isAuthenticated.first())
    }

    @Test
    fun `signInWithGoogle should authenticate successfully`() = runTest {
        // Arrange
        val idToken = "google-id-token"
        val email = "test@example.com"
        val fullName = "Test User"

        val authResult = mock(AuthenticationResultType::class.java)
        whenever(authResult.accessToken).thenReturn("access-token")
        whenever(authResult.idToken).thenReturn("id-token")
        whenever(authResult.refreshToken).thenReturn("refresh-token")

        val mockResponse = mock(InitiateAuthResponse::class.java)
        whenever(mockResponse.authenticationResult).thenReturn(authResult)

        whenever(mockCognitoClient.initiateAuth(any<InitiateAuthRequest>()))
            .thenReturn(mockResponse)

        // Act
        authService.signInWithGoogle(idToken, email, fullName)

        // Assert
        assertTrue(authService.isAuthenticated.first())
        assertEquals(email, authService.currentUser.first()?.email)
    }

    @Test
    fun `generateAppleUserPassword should create deterministic password`() {
        // Test the deterministic password generation
        val email = "test@example.com"
        val idToken = "test-token"

        // Use reflection to access private method
        val method = AuthService::class.java.getDeclaredMethod("generateAppleUserPassword", String::class.java, String::class.java)
        method.isAccessible = true

        val password1 = method.invoke(authService, email, idToken) as String
        val password2 = method.invoke(authService, email, idToken) as String

        // Same inputs should generate same password
        assertEquals(password1, password2)

        // Password should meet requirements (contains Aa1!)
        assertTrue(password1.contains("Aa1!"))
        assertTrue(password1.length > 10)
    }

    @Test
    fun `validateAppleIdToken should validate token format`() {
        // Use reflection to access private method
        val method = AuthService::class.java.getDeclaredMethod("validateAppleIdToken", String::class.java)
        method.isAccessible = true

        // Valid JWT format (3 parts separated by dots)
        val validToken = "header.payload.signature"
        assertTrue(method.invoke(authService, validToken) as Boolean)

        // Invalid format
        val invalidToken = "invalid.token"
        assertFalse(method.invoke(authService, invalidToken) as Boolean)

        // Empty token
        assertFalse(method.invoke(authService, "") as Boolean)
    }
}
