package com.michaeldadi.sprout.services

import android.app.Application
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
    private lateinit var mockTokenStore: AuthTokenStore

    private lateinit var authService: AuthService

    @Before
    fun setup() {
        authService = AuthService(mockApplication, mockCognitoClient, mockTokenStore)
    }

    @Test
    fun `signUp should complete successfully with valid credentials`() = runTest {
        // Arrange
        val email = "test@example.com"
        val password = "TestPassword123!"
        val mockResponse = mock(SignUpResponse::class.java)

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
    fun `signIn rejects a response without a complete session`() = runTest {
        val incomplete = mock(AuthenticationResultType::class.java)
        whenever(incomplete.accessToken).thenReturn("access-token")
        whenever(incomplete.idToken).thenReturn("id-token")
        val response = mock(InitiateAuthResponse::class.java)
        whenever(response.authenticationResult).thenReturn(incomplete)
        whenever(mockCognitoClient.initiateAuth(any<InitiateAuthRequest>())).thenReturn(response)

        assertFailsWith<AuthError.SignInFailed> {
            authService.signIn("test@example.com", "password")
        }
        assertFalse(authService.isAuthenticated.first())
        verify(mockTokenStore, never()).save(any())
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
    fun `legacy Apple token method fails closed without creating a Cognito user`() = runTest {
        assertFailsWith<AuthError.SignInFailed> {
            authService.signInWithApple("provider-token", "test@example.com", "Test User")
        }
        verifyNoInteractions(mockCognitoClient)
    }

    @Test
    fun `legacy Google token method fails closed without creating a Cognito user`() = runTest {
        assertFailsWith<AuthError.SignInFailed> {
            authService.signInWithGoogle("provider-token", "test@example.com", "Test User")
        }
        verifyNoInteractions(mockCognitoClient)
    }
}
