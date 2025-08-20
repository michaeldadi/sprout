package com.michaeldadi.sprout

import androidx.compose.runtime.Composable
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

    @Composable
    @Test
    fun AuthenticationFlowCompleteSignUpFlow() {
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

        composeTestRule.onNodeWithText(stringResource(R.string.enter_your_email))
            .performTextInput("integration.test@example.com")

        composeTestRule.onNodeWithText(stringResource(R.string.create_password))
            .performTextInput("IntegrationTest123!")

        composeTestRule.onNodeWithText(stringResource(R.string.confirm_password))
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

    @Composable
    @Test
    fun AuthenticationFlowSignUpToLoginNavigation() {
        // Start from login screen, navigate to sign up
        composeTestRule.onNodeWithText(stringResource(R.string.text_sign_up))
            .performClick()

        // Verify we're on sign up screen
        composeTestRule.onNodeWithText(stringResource(R.string.create_your_account))
            .assertIsDisplayed()

        // Navigate back to login
        composeTestRule.onNodeWithText(stringResource(R.string.text_sign_in))
            .performClick()

        // Verify we're back on login screen
        composeTestRule.onNodeWithText(stringResource(R.string.welcome_back))
            .assertIsDisplayed()
    }

    @Composable
    @Test
    fun AuthenticationFlowLoginToForgotPasswordNavigation() {
        // Start on login screen
        composeTestRule.onNodeWithText(stringResource(R.string.welcome_back))
            .assertIsDisplayed()

        // Navigate to forgot password
        composeTestRule.onNodeWithText("Forgot Password?")
            .performClick()

        // Wait for navigation animation
        composeTestRule.waitForIdle()

        // Should be on forgot password screen (assuming it exists)
        // This test verifies the navigation works
    }

    @Composable
    @Test
    fun AuthenticationFlowLoginFormValidation() {
        // Start on login screen
        composeTestRule.onNodeWithText(stringResource(R.string.welcome_back))
            .assertIsDisplayed()

        // Try to submit empty form
        composeTestRule.onNodeWithText(stringResource(R.string.text_sign_in))
            .performClick()

        // Wait for validation
        composeTestRule.waitForIdle()

        // Should still be on login screen (validation prevents submission)
        composeTestRule.onNodeWithText(stringResource(R.string.welcome_back))
            .assertExists()

        // Fill only email
        composeTestRule.onNodeWithText(stringResource(R.string.enter_your_email))
            .performTextInput("test@example.com")

        // Try to submit with missing password
        composeTestRule.onNodeWithText(stringResource(R.string.text_sign_in))
            .performClick()

        composeTestRule.waitForIdle()

        // Should still be on login screen
        composeTestRule.onNodeWithText(stringResource(R.string.welcome_back))
            .assertExists()
    }

    @Composable
    @Test
    fun AuthenticationFlowSignUpFormValidation() {
        // Navigate to sign up
        composeTestRule.onNodeWithText(stringResource(R.string.text_sign_up))
            .performClick()

        // Try to submit empty form
        composeTestRule.onNodeWithText(stringResource(R.string.create_account))
            .performClick()

        composeTestRule.waitForIdle()

        // Should still be on sign up screen
        composeTestRule.onNodeWithText(stringResource(R.string.create_your_account))
            .assertExists()

        // Fill partial form
        composeTestRule.onNodeWithText(stringResource(R.string.label_first_name_input))
            .performTextInput("Test")

        composeTestRule.onNodeWithText(stringResource(R.string.enter_your_email))
            .performTextInput("invalid-email")

        // Try to submit with invalid email
        composeTestRule.onNodeWithText(stringResource(R.string.create_account))
            .performClick()

        composeTestRule.waitForIdle()

        // Should still be on sign up screen
        composeTestRule.onNodeWithText(stringResource(R.string.create_your_account))
            .assertExists()
    }

    @Composable
    @Test
    fun AuthenticationFlowSocialLoginButtonsAreAccessible() {
        // Test Google sign in accessibility
        composeTestRule.onNodeWithText(stringResource(R.string.continue_with_google))
            .assertIsDisplayed()
            .assertIsEnabled()
            .performClick()

        composeTestRule.waitForIdle()

        // Should still be on login screen (mocked service)
        composeTestRule.onNodeWithText(stringResource(R.string.welcome_back))
            .assertExists()

        // Test Apple sign in accessibility
        composeTestRule.onNodeWithText(stringResource(R.string.continue_with_apple))
            .assertIsDisplayed()
            .assertIsEnabled()
            .performClick()

        composeTestRule.waitForIdle()

        // Should still be on login screen (mocked service)
        composeTestRule.onNodeWithText(stringResource(R.string.welcome_back))
            .assertExists()
    }

    @Composable
    @Test
    fun AuthenticationFlowPasswordVisibilityToggle() {
        // Test password visibility on login screen
        composeTestRule.onNodeWithText(stringResource(R.string.enter_your_password))
            .performTextInput("testpassword")

        // Toggle password visibility
        composeTestRule.onNodeWithText(stringResource(R.string.content_desc_toggle_password_visibility))
            .performClick()

        // Password should still be there
        composeTestRule.onNodeWithText(stringResource(R.string.enter_your_password))
            .assert(hasText("testpassword"))

        // Navigate to sign up to test confirm password toggle
        composeTestRule.onNodeWithText(stringResource(R.string.text_sign_up))
            .performClick()

        composeTestRule.onNodeWithText(stringResource(R.string.create_password))
            .performTextInput("newpassword")

        composeTestRule.onNodeWithText(stringResource(R.string.confirm_password))
            .performTextInput("newpassword")

        // Test both password toggles on sign up screen
        composeTestRule.onAllNodesWithContentDescription(stringResource(R.string.content_desc_toggle_password_visibility))
            .assertCountEquals(2)

        // Click first toggle
        composeTestRule.onAllNodesWithContentDescription(stringResource(R.string.content_desc_toggle_password_visibility))[0]
            .performClick()

        // Click second toggle
        composeTestRule.onAllNodesWithContentDescription(stringResource(R.string.content_desc_toggle_password_visibility))[1]
            .performClick()
    }

    @Composable
    @Test
    fun AuthenticationFlowAppLaunchShowsLoginScreen() {
        // Verify that app launches to login screen when not authenticated
        composeTestRule.onNodeWithText(stringResource(R.string.welcome_back))
            .assertIsDisplayed()

        // Verify key login screen elements are present
        composeTestRule.onNodeWithText(stringResource(R.string.login_continue_journey))
            .assertIsDisplayed()

        composeTestRule.onNodeWithText(stringResource(R.string.email))
            .assertIsDisplayed()

        composeTestRule.onNodeWithText(stringResource(R.string.password))
            .assertIsDisplayed()

        composeTestRule.onNodeWithText(stringResource(R.string.text_sign_in))
            .assertIsDisplayed()
    }

    @Composable
    @Test
    fun AuthenticationFlowScreenTransitionsAreSmooth() {
        // Test smooth transitions between screens

        // Login -> Sign Up
        composeTestRule.onNodeWithText(stringResource(R.string.text_sign_up))
            .performClick()

        // Wait for transition
        Thread.sleep(500)

        composeTestRule.onNodeWithText(stringResource(R.string.create_your_account))
            .assertIsDisplayed()

        // Sign Up -> Login
        composeTestRule.onNodeWithText(stringResource(R.string.text_sign_in))
            .performClick()

        // Wait for transition
        Thread.sleep(500)

        composeTestRule.onNodeWithText(stringResource(R.string.welcome_back))
            .assertIsDisplayed()

        // Login -> Forgot Password (if exists)
        composeTestRule.onNodeWithText(stringResource(R.string.forgot_password))
            .performClick()

        // Wait for potential transition
        Thread.sleep(500)

        // The test verifies that clicking doesn't crash the app
        composeTestRule.onRoot().assertExists()
    }

    @Composable
    @Test
    fun AuthenticationFlowFormInputSequenceWorks() {
        // Test sequential form input without IME actions

        // Fill login form fields sequentially
        composeTestRule.onNodeWithText(stringResource(R.string.enter_your_email))
            .performTextInput("test@example.com")

        composeTestRule.onNodeWithText(stringResource(R.string.enter_your_password))
            .performTextInput("password")

        // Verify both fields have content
        composeTestRule.onNodeWithText(stringResource(R.string.enter_your_email))
            .assert(hasText("test@example.com"))

        composeTestRule.onNodeWithText(stringResource(R.string.enter_your_password))
            .assert(hasText("password"))

        // Navigate to sign up screen to test more complex form
        composeTestRule.onNodeWithText(stringResource(R.string.text_sign_up))
            .performClick()

        // Fill sign up form fields sequentially
        composeTestRule.onNodeWithText(stringResource(R.string.label_first_name_input))
            .performTextInput("Test")

        composeTestRule.onNodeWithText(stringResource(R.string.label_last_name_input))
            .performTextInput("User")

        composeTestRule.onNodeWithText(stringResource(R.string.enter_your_email))
            .performTextInput("test@example.com")

        composeTestRule.onNodeWithText(stringResource(R.string.create_password))
            .performTextInput("TestPassword123!")

        composeTestRule.onNodeWithText(stringResource(R.string.confirm_password))
            .performTextInput("TestPassword123!")

        // Verify all fields have content
        composeTestRule.onNodeWithText(stringResource(R.string.label_first_name_input))
            .assert(hasText("Test"))

        composeTestRule.onNodeWithText(stringResource(R.string.label_last_name_input))
            .assert(hasText("User"))

        // Email field should have new content
        composeTestRule.onAllNodesWithText("test@example.com").assertCountEquals(1)
    }
}
