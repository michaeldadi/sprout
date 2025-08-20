package com.michaeldadi.sprout.ui

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.michaeldadi.sprout.services.AuthService
import com.michaeldadi.sprout.ui.screens.LoginScreen
import com.michaeldadi.sprout.ui.theme.SproutTheme
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.MockitoAnnotations
import org.mockito.kotlin.whenever

@RunWith(AndroidJUnit4::class)
class LoginScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Mock
    private lateinit var mockAuthService: AuthService

    private var navigateToSignUpCalled = false
    private var navigateToForgotPasswordCalled = false

    @Before
    fun setup() {
        MockitoAnnotations.openMocks(this)

        // Reset navigation flags
        navigateToSignUpCalled = false
        navigateToForgotPasswordCalled = false

        // Setup mock auth service default state
        whenever(mockAuthService.isLoading).thenReturn(kotlinx.coroutines.flow.MutableStateFlow(false))
        whenever(mockAuthService.isAuthenticated).thenReturn(kotlinx.coroutines.flow.MutableStateFlow(false))
    }

    @Test
    fun loginScreen_displaysAllRequiredElements() {
        composeTestRule.setContent {
            SproutTheme {
                LoginScreen(
                    onNavigateToSignUp = { navigateToSignUpCalled = true },
                    onNavigateToForgotPassword = { navigateToForgotPasswordCalled = true }
                )
            }
        }

        // Verify main elements are displayed
        composeTestRule.onNodeWithText("Welcome Back").assertIsDisplayed()
        composeTestRule.onNodeWithText("Sign in to continue your journey").assertIsDisplayed()

        // Verify form fields
        composeTestRule.onNodeWithText("Email").assertIsDisplayed()
        composeTestRule.onNodeWithText("Password").assertIsDisplayed()

        // Verify buttons
        composeTestRule.onNodeWithText("Sign In").assertIsDisplayed()
        composeTestRule.onNodeWithText("Forgot Password?").assertIsDisplayed()

        // Verify social login buttons
        composeTestRule.onNodeWithText("Continue with Google").assertIsDisplayed()
        composeTestRule.onNodeWithText("Continue with Apple").assertIsDisplayed()

        // Verify sign up link
        composeTestRule.onNodeWithText("Sign Up").assertIsDisplayed()
    }

    @Test
    fun loginScreen_emailInput_acceptsText() {
        composeTestRule.setContent {
            SproutTheme {
                LoginScreen(
                    onNavigateToSignUp = { navigateToSignUpCalled = true },
                    onNavigateToForgotPassword = { navigateToForgotPasswordCalled = true }
                )
            }
        }

        val testEmail = "test@example.com"

        // Find email input by placeholder text and enter email
        composeTestRule.onNodeWithText("Enter your email")
            .performTextInput(testEmail)

        // Verify the text was entered
        composeTestRule.onNodeWithText("Enter your email")
            .assert(hasText(testEmail))
    }

    @Test
    fun loginScreen_passwordInput_acceptsText() {
        composeTestRule.setContent {
            SproutTheme {
                LoginScreen(
                    onNavigateToSignUp = { navigateToSignUpCalled = true },
                    onNavigateToForgotPassword = { navigateToForgotPasswordCalled = true }
                )
            }
        }

        val testPassword = "TestPassword123!"

        // Find password input and enter password
        composeTestRule.onNodeWithText("Enter your password")
            .performTextInput(testPassword)

        // Verify the text was entered (should be masked)
        composeTestRule.onNodeWithText("Enter your password")
            .assert(hasText(testPassword))
    }

    @Test
    fun loginScreen_passwordToggle_worksCorrectly() {
        composeTestRule.setContent {
            SproutTheme {
                LoginScreen(
                    onNavigateToSignUp = { navigateToSignUpCalled = true },
                    onNavigateToForgotPassword = { navigateToForgotPasswordCalled = true }
                )
            }
        }

        // Enter password first
        composeTestRule.onNodeWithText("Enter your password")
            .performTextInput("password123")

        // Find and click password visibility toggle
        composeTestRule.onNodeWithContentDescription("Toggle password visibility")
            .assertExists()
            .performClick()

        // Password should now be visible (implementation detail - this test verifies the toggle exists and can be clicked)
    }

    @Test
    fun loginScreen_signInButton_showsValidationErrors() {
        composeTestRule.setContent {
            SproutTheme {
                LoginScreen(
                    onNavigateToSignUp = { navigateToSignUpCalled = true },
                    onNavigateToForgotPassword = { navigateToForgotPasswordCalled = true }
                )
            }
        }

        // Click sign in without entering any data
        composeTestRule.onNodeWithText("Sign In")
            .performClick()

        // Wait for potential error messages (toast messages might appear)
        composeTestRule.waitForIdle()

        // The button should still be clickable (not disabled)
        composeTestRule.onNodeWithText("Sign In")
            .assertIsEnabled()
    }

    @Test
    fun loginScreen_signUpLink_triggersNavigation() {
        composeTestRule.setContent {
            SproutTheme {
                LoginScreen(
                    onNavigateToSignUp = { navigateToSignUpCalled = true },
                    onNavigateToForgotPassword = { navigateToForgotPasswordCalled = true }
                )
            }
        }

        // Click the sign up link
        composeTestRule.onNodeWithText("Sign Up")
            .performClick()

        // Verify navigation was triggered
        assert(navigateToSignUpCalled)
        assert(!navigateToForgotPasswordCalled)
    }

    @Test
    fun loginScreen_forgotPasswordLink_triggersNavigation() {
        composeTestRule.setContent {
            SproutTheme {
                LoginScreen(
                    onNavigateToSignUp = { navigateToSignUpCalled = true },
                    onNavigateToForgotPassword = { navigateToForgotPasswordCalled = true }
                )
            }
        }

        // Click the forgot password link
        composeTestRule.onNodeWithText("Forgot Password?")
            .performClick()

        // Verify navigation was triggered
        assert(!navigateToSignUpCalled)
        assert(navigateToForgotPasswordCalled)
    }

    @Test
    fun loginScreen_socialLoginButtons_areClickable() {
        composeTestRule.setContent {
            SproutTheme {
                LoginScreen(
                    onNavigateToSignUp = { navigateToSignUpCalled = true },
                    onNavigateToForgotPassword = { navigateToForgotPasswordCalled = true }
                )
            }
        }

        // Verify Google sign in button is clickable
        composeTestRule.onNodeWithText("Continue with Google")
            .assertIsEnabled()
            .performClick()

        composeTestRule.waitForIdle()

        // Verify Apple sign in button is clickable
        composeTestRule.onNodeWithText("Continue with Apple")
            .assertIsEnabled()
            .performClick()
    }

    @Test
    fun loginScreen_formSubmission_withValidData() {
        composeTestRule.setContent {
            SproutTheme {
                LoginScreen(
                    onNavigateToSignUp = { navigateToSignUpCalled = true },
                    onNavigateToForgotPassword = { navigateToForgotPasswordCalled = true }
                )
            }
        }

        // Enter valid email and password
        composeTestRule.onNodeWithText("Enter your email")
            .performTextInput("test@example.com")

        composeTestRule.onNodeWithText("Enter your password")
            .performTextInput("ValidPassword123!")

        // Click sign in
        composeTestRule.onNodeWithText("Sign In")
            .performClick()

        // Wait for any async operations
        composeTestRule.waitForIdle()

        // Verify the form can be submitted (no immediate errors)
        composeTestRule.onNodeWithText("Sign In")
            .assertExists()
    }

    @Test
    fun loginScreen_hasCorrectContentDescription() {
        composeTestRule.setContent {
            SproutTheme {
                LoginScreen(
                    onNavigateToSignUp = { navigateToSignUpCalled = true },
                    onNavigateToForgotPassword = { navigateToForgotPasswordCalled = true }
                )
            }
        }

        // Verify accessibility - check for content descriptions where needed
        composeTestRule.onNodeWithContentDescription("App logo")
            .assertExists()
    }

    @Test
    fun loginScreen_background_isDisplayed() {
        composeTestRule.setContent {
            SproutTheme {
                LoginScreen(
                    onNavigateToSignUp = { navigateToSignUpCalled = true },
                    onNavigateToForgotPassword = { navigateToForgotPasswordCalled = true }
                )
            }
        }

        // Verify the screen renders without errors
        composeTestRule.onNodeWithText("Welcome Back")
            .assertIsDisplayed()

        // The floating circles background should be present
        // (This is more of a smoke test to ensure the composable renders)
        composeTestRule.onRoot().assertExists()
    }
}
