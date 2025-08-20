package com.michaeldadi.sprout.utils

import android.app.Application
import android.content.Context
import android.content.SharedPreferences
import androidx.activity.ComponentActivity
import aws.sdk.kotlin.services.cognitoidentityprovider.CognitoIdentityProviderClient
import aws.sdk.kotlin.services.cognitoidentityprovider.model.*
import com.michaeldadi.sprout.services.AppleSignInResult
import com.michaeldadi.sprout.services.GoogleSignInResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import org.mockito.Mockito.*
import org.mockito.kotlin.any
import org.mockito.kotlin.whenever
import java.util.*

/**
 * Utility class for creating mock objects and test data for Android tests
 */
object TestUtils {

    /**
     * Creates a mock Application with SharedPreferences setup
     */
    fun createMockApplication(): Application {
        val mockApp = mock(Application::class.java)
        val mockPrefs = createMockSharedPreferences()

        whenever(mockApp.getSharedPreferences(any<String>(), any<Int>()))
            .thenReturn(mockPrefs)

        return mockApp
    }

    /**
     * Creates a mock SharedPreferences with Editor
     */
    fun createMockSharedPreferences(): SharedPreferences {
        val mockPrefs = mock(SharedPreferences::class.java)
        val mockEditor = mock(SharedPreferences.Editor::class.java)

        whenever(mockPrefs.edit()).thenReturn(mockEditor)
        whenever(mockEditor.putString(any(), any())).thenReturn(mockEditor)
        whenever(mockEditor.remove(any())).thenReturn(mockEditor)
        whenever(mockEditor.apply()).then { }
        whenever(mockEditor.commit()).thenReturn(true)

        return mockPrefs
    }

    /**
     * Creates a mock CognitoIdentityProviderClient with common responses
     */
    fun createMockCognitoClient(): CognitoIdentityProviderClient {
        val mockClient = mock(CognitoIdentityProviderClient::class.java)

        // Setup default successful responses
        setupSuccessfulSignUp(mockClient)
        setupSuccessfulConfirmSignUp(mockClient)
        setupSuccessfulSignIn(mockClient)
        setupSuccessfulSignOut(mockClient)
        setupSuccessfulForgotPassword(mockClient)
        setupSuccessfulConfirmForgotPassword(mockClient)

        return mockClient
    }

    private fun setupSuccessfulSignUp(mockClient: CognitoIdentityProviderClient) {
        val signUpResponse = mock(SignUpResponse::class.java)
        whenever(signUpResponse.userSub).thenReturn("test-user-sub-${UUID.randomUUID()}")

        runBlocking {
            whenever(mockClient.signUp(any<SignUpRequest>()))
                .thenReturn(signUpResponse)
        }
    }

    private fun setupSuccessfulConfirmSignUp(mockClient: CognitoIdentityProviderClient) {
        val confirmResponse = mock(ConfirmSignUpResponse::class.java)

        runBlocking {
            whenever(mockClient.confirmSignUp(any<ConfirmSignUpRequest>()))
                .thenReturn(confirmResponse)
        }
    }

    private fun setupSuccessfulSignIn(mockClient: CognitoIdentityProviderClient) {
        val authResult = mock(AuthenticationResultType::class.java)
        whenever(authResult.accessToken).thenReturn("mock-access-token")
        whenever(authResult.idToken).thenReturn("mock-id-token")
        whenever(authResult.refreshToken).thenReturn("mock-refresh-token")
        whenever(authResult.expiresIn).thenReturn(3600)

        val signInResponse = mock(InitiateAuthResponse::class.java)
        whenever(signInResponse.authenticationResult).thenReturn(authResult)

        runBlocking {
            whenever(mockClient.initiateAuth(any<InitiateAuthRequest>()))
                .thenReturn(signInResponse)
        }
    }

    private fun setupSuccessfulSignOut(mockClient: CognitoIdentityProviderClient) {
        val signOutResponse = mock(GlobalSignOutResponse::class.java)

        runBlocking {
            whenever(mockClient.globalSignOut(any<GlobalSignOutRequest>()))
                .thenReturn(signOutResponse)
        }
    }

    private fun setupSuccessfulForgotPassword(mockClient: CognitoIdentityProviderClient) {
        val codeDeliveryDetails = mock(CodeDeliveryDetailsType::class.java)
        whenever(codeDeliveryDetails.deliveryMedium).thenReturn(DeliveryMediumType.Email)
        whenever(codeDeliveryDetails.destination).thenReturn("t***@example.com")

        val forgotPasswordResponse = mock(ForgotPasswordResponse::class.java)
        whenever(forgotPasswordResponse.codeDeliveryDetails).thenReturn(codeDeliveryDetails)

        runBlocking {
            whenever(mockClient.forgotPassword(any<ForgotPasswordRequest>()))
                .thenReturn(forgotPasswordResponse)
        }
    }

    private fun setupSuccessfulConfirmForgotPassword(mockClient: CognitoIdentityProviderClient) {
        val confirmResponse = mock(ConfirmForgotPasswordResponse::class.java)

        runBlocking {
            whenever(mockClient.confirmForgotPassword(any<ConfirmForgotPasswordRequest>()))
                .thenReturn(confirmResponse)
        }
    }

    /**
     * Creates test data for user credentials
     */
    data class TestUserCredentials(
        val firstName: String = "Test",
        val lastName: String = "User",
        val email: String = "test.user@example.com",
        val password: String = "TestPassword123!",
        val confirmationCode: String = "123456"
    )

    /**
     * Creates test data for Apple Sign In
     */
    data class TestAppleSignInData(
        val idToken: String = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwiYXVkIjoiY29tLmV4YW1wbGUuYXBwIiwiZXhwIjoxNjAwMDAwMDAwLCJpYXQiOjE2MDAwMDAwMDAsInN1YiI6IjAwMDAwMC4xMjM0NTY3ODkwYWJjZGVmIiwiZW1haWwiOiJ0ZXN0QGV4YW1wbGUuY29tIn0.signature",
        val authorizationCode: String = "c12345abcdef.0.123456789",
        val email: String = "test@example.com",
        val fullName: String = "Test User"
    )

    /**
     * Creates mock Apple Sign In results
     */
    fun createSuccessfulAppleSignInResult(data: TestAppleSignInData = TestAppleSignInData()): AppleSignInResult.Success {
        return AppleSignInResult.Success(
            authorizationCode = data.authorizationCode,
            idToken = data.idToken,
            accessToken = "",
            refreshToken = "",
            email = data.email,
            fullName = data.fullName
        )
    }

    fun createCancelledAppleSignInResult(): AppleSignInResult.Cancelled {
        return AppleSignInResult.Cancelled
    }

    fun createErrorAppleSignInResult(message: String = "Apple Sign In failed"): AppleSignInResult.Error {
        return AppleSignInResult.Error(message)
    }

    /**
     * Creates mock Google Sign In results
     */
    fun createSuccessfulGoogleSignInResult(): GoogleSignInResult.Success {
        return GoogleSignInResult.Success(
            idToken = "mock-google-id-token",
            email = "test@example.com",
            displayName = "Test User",
            photoUrl = null
        )
    }

    fun createCancelledGoogleSignInResult(): GoogleSignInResult.Cancelled {
        return GoogleSignInResult.Cancelled
    }

    fun createErrorGoogleSignInResult(message: String = "Google Sign In failed"): GoogleSignInResult.Error {
        return GoogleSignInResult.Error(message)
    }

    /**
     * Creates a mock ComponentActivity
     */
    fun createMockComponentActivity(): ComponentActivity {
        return mock(ComponentActivity::class.java)
    }

    /**
     * Creates a mock Context
     */
    fun createMockContext(): Context {
        return mock(Context::class.java)
    }

    /**
     * Test dispatcher for coroutines
     */
    fun createTestDispatcher(): TestDispatcher {
        return UnconfinedTestDispatcher()
    }

    /**
     * Creates test JWT tokens for testing token parsing
     */
    object TestJWTTokens {

        fun createValidAppleIdToken(): String {
            // Header
            val header = """{"typ":"JWT","alg":"RS256","kid":"fh6acinc"}"""

            // Payload with test data
            val payload = """{"iss":"https://appleid.apple.com","aud":"com.example.app","exp":1600000000,"iat":1600000000,"sub":"000000.123456789abcdef","email":"test@example.com","email_verified":"true"}"""

            // Mock signature
            val signature = "mock-signature"

            return "${encodeBase64Url(header)}.${encodeBase64Url(payload)}.$signature"
        }

        fun createInvalidAppleIdToken(): String {
            return "invalid.token"
        }

        private fun encodeBase64Url(input: String): String {
            return Base64.getUrlEncoder().withoutPadding().encodeToString(input.toByteArray())
        }
    }

    /**
     * Creates mock StateFlows for AuthService
     */
    fun createMockAuthServiceStateFlows(): Triple<MutableStateFlow<Boolean>, MutableStateFlow<Boolean>, MutableStateFlow<Any?>> {
        val isLoading = MutableStateFlow(false)
        val isAuthenticated = MutableStateFlow(false)
        val currentUser = MutableStateFlow<Any?>(null)

        return Triple(isLoading, isAuthenticated, currentUser)
    }

    /**
     * Assertion helpers for tests
     */
    object Assertions {

        fun assertValidEmail(email: String): Boolean {
            val emailRegex = "^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$".toRegex()
            return email.matches(emailRegex)
        }

        fun assertValidPassword(password: String): Boolean {
            return password.length >= 8 &&
                   password.any { it.isDigit() } &&
                   password.any { it.isUpperCase() } &&
                   password.any { it.isLowerCase() }
        }

        fun assertValidAppleIdToken(token: String): Boolean {
            val parts = token.split(".")
            return parts.size == 3 && parts.all { it.isNotBlank() }
        }
    }

    /**
     * Test data generators
     */
    object DataGenerators {

        fun generateRandomEmail(): String {
            val random = UUID.randomUUID().toString().take(8)
            return "test$random@example.com"
        }

        fun generateRandomPassword(): String {
            val random = UUID.randomUUID().toString().take(8)
            return "Test${random}123!"
        }

        fun generateRandomString(length: Int = 10): String {
            val chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
            return (1..length)
                .map { chars.random() }
                .joinToString("")
        }
    }

    /**
     * Test configuration for different scenarios
     */
    object TestScenarios {

        val VALID_SIGN_UP = TestUserCredentials(
            firstName = "John",
            lastName = "Doe",
            email = "john.doe@example.com",
            password = "SecurePassword123!",
            confirmationCode = "123456"
        )

        val VALID_SIGN_IN = TestUserCredentials(
            email = "existing.user@example.com",
            password = "ExistingPassword123!"
        )

        val INVALID_EMAIL = TestUserCredentials(
            email = "invalid-email",
            password = "ValidPassword123!"
        )

        val WEAK_PASSWORD = TestUserCredentials(
            email = "test@example.com",
            password = "123" // Too short
        )

        val EMPTY_FIELDS = TestUserCredentials(
            firstName = "",
            lastName = "",
            email = "",
            password = ""
        )
    }
}
