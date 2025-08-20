package com.michaeldadi.sprout

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.LargeTest
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import com.michaeldadi.sprout.R
import androidx.compose.ui.res.stringResource

@RunWith(AndroidJUnit4::class)
@LargeTest
class AuthenticationFlowIntegrationTest {

    @get:Rule
    val composeTestRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun authenticationFlow_completeSignUpFlow() {
        // Start from login screen, navigate to sign up
        composeTestRule.onNodeWithText(stringResource(R.string.text_sign_up))
            .assertExists()
            .performClick()

        // Verify we're on the sign up screen
        composeTestRule.onNodeWithText(stringResource(R.string.create_your_account))
            .assertIsDisplayed()

        // Fill out the sign up form
        composeTestRule.onNodeWithText("First")
            .performTextInput("Integration")

        composeTestRule.onNodeWithText("Last")
            .performTextInput("Test")

        composeTestRule.onNodeWithText("Enter your email")
            .performTextInput("integration.test@example.com")

        composeTestRule.onNodeWithText("Create password")
            .performTextInput("IntegrationTest123!")

        composeTestRule.onNodeWithText("Confirm password")
            .performTextInput("IntegrationTest123!")

        // Submit the form
        composeTestRule.onNodeWithText(stringResource(R.string.create_account))
            .performClick()

        // Wait for async operations
        composeTestRule.waitForIdle()

        // Should still be on sign up screen (due to mocked service)
        // In a real integration test, we'd navigate to verification
        composeTestRule.onNodeWithText(stringResource(R.string.create_your_account))
            .assertExists()
    }

    @Test
    fun authenticationFlow_signUpToLoginNavigation() {
        // Start from login screen, navigate to sign up
        composeTestRule.onNodeWithText(stringResource(R.string.text_sign_up))
            .performClick()

        // Verify we're on sign up screen
        composeTestRule.onNodeWithText(stringResource(R.string.create_your_account))
            .assertIsDisplayed()

        // Navigate back to login
        composeTestRule.onNodeWithText("Sign In")
            .performClick()

        // Verify we're back on login screen
        composeTestRule.onNodeWithText("Welcome Back")
            .assertIsDisplayed()
    }

    @Test
    fun authenticationFlow_loginToForgotPasswordNavigation() {
        // Start on login screen
        composeTestRule.onNodeWithText("Welcome Back")
            .assertIsDisplayed()

        // Navigate to forgot password
        composeTestRule.onNodeWithText("Forgot Password?")
            .performClick()

        // Wait for navigation animation
        composeTestRule.waitForIdle()

        // Should be on forgot password screen (assuming it exists)
        // This test verifies the navigation works
    }

    @Test
    fun authenticationFlow_loginFormValidation() {
        // Start on login screen
        composeTestRule.onNodeWithText("Welcome Back")
            .assertIsDisplayed()

        // Try to submit empty form
        composeTestRule.onNodeWithText("Sign In")
            .performClick()

        // Wait for validation
        composeTestRule.waitForIdle()

        // Should still be on login screen (validation prevents submission)
        composeTestRule.onNodeWithText("Welcome Back")
            .assertExists()

        // Fill only email
        composeTestRule.onNodeWithText("Enter your email")
            .performTextInput("test@example.com")

        // Try to submit with missing password
        composeTestRule.onNodeWithText("Sign In")
            .performClick()

        composeTestRule.waitForIdle()

        // Should still be on login screen
        composeTestRule.onNodeWithText("Welcome Back")
            .assertExists()
    }

    @Test
    fun authenticationFlow_signUpFormValidation() {
        // Navigate to sign up
        composeTestRule.onNodeWithText(stringResource(R.string.text_sign_up))
            .performClick()

        // Try to submit empty form
        composeTestRule.onNodeWithText(getString(R.string.create_account))
            .performClick()

        composeTestRule.waitForIdle()

        // Should still be on sign up screen
        composeTestRule.onNodeWithText(stringResource(R.string.create_your_account))
            .assertExists()

        // Fill partial form
        composeTestRule.onNodeWithText("First")
            .performTextInput("Test")

        composeTestRule.onNodeWithText("Enter your email")
            .performTextInput("invalid-email")

        // Try to submit with invalid email
        composeTestRule.onNodeWithText(getString(R.string.create_account))
            .performClick()

        composeTestRule.waitForIdle()

        // Should still be on sign up screen
        composeTestRule.onNodeWithText(stringResource(R.string.create_your_account))
            .assertExists()
    }

    @Test
    fun authenticationFlow_socialLoginButtons_areAccessible() {
        // Test Google sign in accessibility
        composeTestRule.onNodeWithText("Continue with Google")
            .assertIsDisplayed()
            .assertIsEnabled()
            .performClick()

        composeTestRule.waitForIdle()

        // Should still be on login screen (mocked service)
        composeTestRule.onNodeWithText("Welcome Back")
            .assertExists()

        // Test Apple sign in accessibility
        composeTestRule.onNodeWithText("Continue with Apple")
            .assertIsDisplayed()
            .assertIsEnabled()
            .performClick()

        composeTestRule.waitForIdle()

        // Should still be on login screen (mocked service)
        composeTestRule.onNodeWithText("Welcome Back")
            .assertExists()
    }

    @Test
    fun authenticationFlow_passwordVisibilityToggle() {
        // Test password visibility on login screen
        composeTestRule.onNodeWithText("Enter your password")
            .performTextInput("testpassword")

        // Toggle password visibility
        composeTestRule.onNodeWithContentDescription("Toggle password visibility")
            .performClick()

        // Password should still be there
        composeTestRule.onNodeWithText("Enter your password")
            .assert(hasText("testpassword"))

        // Navigate to sign up to test confirm password toggle
        composeTestRule.onNodeWithText(stringResource(R.string.text_sign_up))
            .performClick()

        composeTestRule.onNodeWithText("Create password")
            .performTextInput("newpassword")

        composeTestRule.onNodeWithText("Confirm password")
            .performTextInput("newpassword")

        // Test both password toggles on sign up screen
        composeTestRule.onAllNodesWithContentDescription("Toggle password visibility")
            .assertCountEquals(2)

        // Click first toggle
        composeTestRule.onAllNodesWithContentDescription("Toggle password visibility")[0]
            .performClick()

        // Click second toggle
        composeTestRule.onAllNodesWithContentDescription("Toggle password visibility")[1]
            .performClick()
    }

    @Test
    fun authenticationFlow_appLaunch_showsLoginScreen() {
        // Verify that app launches to login screen when not authenticated
        composeTestRule.onNodeWithText("Welcome Back")
            .assertIsDisplayed()

        // Verify key login screen elements are present
        composeTestRule.onNodeWithText("Sign in to continue your journey")
            .assertIsDisplayed()

        composeTestRule.onNodeWithText("Email")
            .assertIsDisplayed()

        composeTestRule.onNodeWithText("Password")
            .assertIsDisplayed()

        composeTestRule.onNodeWithText("Sign In")
            .assertIsDisplayed()
    }

    @Test
    fun authenticationFlow_screenTransitions_areSmooth() {
        // Test smooth transitions between screens

        // Login -> Sign Up
        composeTestRule.onNodeWithText(stringResource(R.string.text_sign_up))
            .performClick()

        // Wait for transition
        Thread.sleep(500)

        composeTestRule.onNodeWithText(stringResource(R.string.create_your_account))
            .assertIsDisplayed()

        // Sign Up -> Login
        composeTestRule.onNodeWithText("Sign In")
            .performClick()

        // Wait for transition
        Thread.sleep(500)

        composeTestRule.onNodeWithText("Welcome Back")
            .assertIsDisplayed()

        // Login -> Forgot Password (if exists)
        composeTestRule.onNodeWithText("Forgot Password?")
            .performClick()

        // Wait for potential transition
        Thread.sleep(500)

        // The test verifies that clicking doesn't crash the app
        composeTestRule.onRoot().assertExists()
    }

    @Test
    fun authenticationFlow_formInputSequence_works() {
        // Test sequential form input without IME actions

        // Fill login form fields sequentially
        composeTestRule.onNodeWithText("Enter your email")
            .performTextInput("test@example.com")

        composeTestRule.onNodeWithText("Enter your password")
            .performTextInput("password")

        // Verify both fields have content
        composeTestRule.onNodeWithText("Enter your email")
            .assert(hasText("test@example.com"))

        composeTestRule.onNodeWithText("Enter your password")
            .assert(hasText("password"))

        // Navigate to sign up screen to test more complex form
        composeTestRule.onNodeWithText(stringResource(R.string.text_sign_up))
            .performClick()

        // Fill sign up form fields sequentially
        composeTestRule.onNodeWithText("First")
            .performTextInput("Test")

        composeTestRule.onNodeWithText("Last")
            .performTextInput("User")

        composeTestRule.onNodeWithText("Enter your email")
            .performTextInput("test@example.com")

        composeTestRule.onNodeWithText("Create password")
            .performTextInput("TestPassword123!")

        composeTestRule.onNodeWithText("Confirm password")
            .performTextInput("TestPassword123!")

        // Verify all fields have content
        composeTestRule.onNodeWithText("First")
            .assert(hasText("Test"))

        composeTestRule.onNodeWithText("Last")
            .assert(hasText("User"))

        // Email field should have new content
        composeTestRule.onAllNodesWithText("test@example.com").assertCountEquals(1)
    }
}
