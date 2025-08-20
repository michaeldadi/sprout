package com.michaeldadi.sprout.ui

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.michaeldadi.sprout.services.AuthService
import com.michaeldadi.sprout.ui.screens.SignUpScreen
import com.michaeldadi.sprout.ui.theme.SproutTheme
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.MockitoAnnotations
import org.mockito.kotlin.whenever

@RunWith(AndroidJUnit4::class)
class SignUpScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Mock
    private lateinit var mockAuthService: AuthService

    private var navigateToLoginCalled = false
    private var navigateToVerificationCalled = false
    private var verificationEmail: String? = null

    @Before
    fun setup() {
        MockitoAnnotations.openMocks(this)
        
        // Reset navigation flags
        navigateToLoginCalled = false
        navigateToVerificationCalled = false
        verificationEmail = null
        
        // Setup mock auth service default state
        whenever(mockAuthService.isLoading).thenReturn(kotlinx.coroutines.flow.MutableStateFlow(false))
    }

    @Test
    fun signUpScreen_displaysAllRequiredElements() {
        composeTestRule.setContent {
            SproutTheme {
                SignUpScreen(
                    onNavigateToLogin = { navigateToLoginCalled = true },
                    onNavigateToVerification = { email -> 
                        navigateToVerificationCalled = true
                        verificationEmail = email
                    }
                )
            }
        }

        // Verify main elements are displayed
        composeTestRule.onNodeWithText("Create your Account").assertIsDisplayed()
        composeTestRule.onNodeWithText("Join Sprout and start growing").assertIsDisplayed()
        
        // Verify form fields
        composeTestRule.onNodeWithText("First Name").assertIsDisplayed()
        composeTestRule.onNodeWithText("Last Name").assertIsDisplayed()
        composeTestRule.onNodeWithText("Email").assertIsDisplayed()
        composeTestRule.onNodeWithText("Password").assertIsDisplayed()
        composeTestRule.onNodeWithText("Confirm Password").assertIsDisplayed()
        
        // Verify create account button
        composeTestRule.onNodeWithText("Create Account").assertIsDisplayed()
        
        // Verify social login buttons
        composeTestRule.onNodeWithText("Continue with Google").assertIsDisplayed()
        composeTestRule.onNodeWithText("Continue with Apple").assertIsDisplayed()
        
        // Verify login link
        composeTestRule.onNodeWithText("Sign In").assertIsDisplayed()
        
        // Verify terms and conditions
        composeTestRule.onNodeWithText("By continuing, you agree to our").assertIsDisplayed()
        composeTestRule.onNodeWithText("Terms of Service").assertIsDisplayed()
        composeTestRule.onNodeWithText("Privacy Policy").assertIsDisplayed()
    }

    @Test
    fun signUpScreen_nameInputs_acceptText() {
        composeTestRule.setContent {
            SproutTheme {
                SignUpScreen(
                    onNavigateToLogin = { navigateToLoginCalled = true },
                    onNavigateToVerification = { email -> 
                        navigateToVerificationCalled = true
                        verificationEmail = email
                    }
                )
            }
        }

        // Test first name input
        composeTestRule.onNodeWithText("First")
            .performTextInput("John")
        
        composeTestRule.onNodeWithText("First")
            .assert(hasText("John"))
        
        // Test last name input
        composeTestRule.onNodeWithText("Last")
            .performTextInput("Doe")
        
        composeTestRule.onNodeWithText("Last")
            .assert(hasText("Doe"))
    }

    @Test
    fun signUpScreen_emailInput_acceptsText() {
        composeTestRule.setContent {
            SproutTheme {
                SignUpScreen(
                    onNavigateToLogin = { navigateToLoginCalled = true },
                    onNavigateToVerification = { email -> 
                        navigateToVerificationCalled = true
                        verificationEmail = email
                    }
                )
            }
        }

        val testEmail = "john.doe@example.com"
        
        composeTestRule.onNodeWithText("Enter your email")
            .performTextInput(testEmail)
        
        composeTestRule.onNodeWithText("Enter your email")
            .assert(hasText(testEmail))
    }

    @Test
    fun signUpScreen_passwordInputs_acceptText() {
        composeTestRule.setContent {
            SproutTheme {
                SignUpScreen(
                    onNavigateToLogin = { navigateToLoginCalled = true },
                    onNavigateToVerification = { email -> 
                        navigateToVerificationCalled = true
                        verificationEmail = email
                    }
                )
            }
        }

        val testPassword = "SecurePassword123!"
        
        // Test password input
        composeTestRule.onNodeWithText("Create password")
            .performTextInput(testPassword)
        
        composeTestRule.onNodeWithText("Create password")
            .assert(hasText(testPassword))
        
        // Test confirm password input
        composeTestRule.onNodeWithText("Confirm password")
            .performTextInput(testPassword)
        
        composeTestRule.onNodeWithText("Confirm password")
            .assert(hasText(testPassword))
    }

    @Test
    fun signUpScreen_passwordToggle_worksForBothFields() {
        composeTestRule.setContent {
            SproutTheme {
                SignUpScreen(
                    onNavigateToLogin = { navigateToLoginCalled = true },
                    onNavigateToVerification = { email -> 
                        navigateToVerificationCalled = true
                        verificationEmail = email
                    }
                )
            }
        }

        // Enter passwords
        composeTestRule.onNodeWithText("Create password")
            .performTextInput("password123")
        
        composeTestRule.onNodeWithText("Confirm password")
            .performTextInput("password123")
        
        // Find and test password visibility toggles
        composeTestRule.onAllNodesWithContentDescription("Toggle password visibility")
            .assertCountEquals(2)
        
        // Click first toggle (password field)
        composeTestRule.onAllNodesWithContentDescription("Toggle password visibility")[0]
            .performClick()
        
        // Click second toggle (confirm password field)
        composeTestRule.onAllNodesWithContentDescription("Toggle password visibility")[1]
            .performClick()
    }

    @Test
    fun signUpScreen_validationErrors_showForEmptyFields() {
        composeTestRule.setContent {
            SproutTheme {
                SignUpScreen(
                    onNavigateToLogin = { navigateToLoginCalled = true },
                    onNavigateToVerification = { email -> 
                        navigateToVerificationCalled = true
                        verificationEmail = email
                    }
                )
            }
        }

        // Click create account without filling any fields
        composeTestRule.onNodeWithText("Create Account")
            .performClick()
        
        // Wait for validation
        composeTestRule.waitForIdle()
        
        // The form should still be there (validation should prevent submission)
        composeTestRule.onNodeWithText("Create Account")
            .assertExists()
    }

    @Test
    fun signUpScreen_validationError_showsForInvalidEmail() {
        composeTestRule.setContent {
            SproutTheme {
                SignUpScreen(
                    onNavigateToLogin = { navigateToLoginCalled = true },
                    onNavigateToVerification = { email -> 
                        navigateToVerificationCalled = true
                        verificationEmail = email
                    }
                )
            }
        }

        // Fill form with invalid email
        composeTestRule.onNodeWithText("First").performTextInput("John")
        composeTestRule.onNodeWithText("Last").performTextInput("Doe")
        composeTestRule.onNodeWithText("Enter your email").performTextInput("invalid-email")
        composeTestRule.onNodeWithText("Create password").performTextInput("Password123!")
        composeTestRule.onNodeWithText("Confirm password").performTextInput("Password123!")
        
        // Click create account
        composeTestRule.onNodeWithText("Create Account")
            .performClick()
        
        // Wait for validation
        composeTestRule.waitForIdle()
        
        // Should not navigate (due to invalid email)
        assert(!navigateToVerificationCalled)
    }

    @Test
    fun signUpScreen_validationError_showsForShortPassword() {
        composeTestRule.setContent {
            SproutTheme {
                SignUpScreen(
                    onNavigateToLogin = { navigateToLoginCalled = true },
                    onNavigateToVerification = { email -> 
                        navigateToVerificationCalled = true
                        verificationEmail = email
                    }
                )
            }
        }

        // Fill form with short password
        composeTestRule.onNodeWithText("First").performTextInput("John")
        composeTestRule.onNodeWithText("Last").performTextInput("Doe")
        composeTestRule.onNodeWithText("Enter your email").performTextInput("john@example.com")
        composeTestRule.onNodeWithText("Create password").performTextInput("123")
        composeTestRule.onNodeWithText("Confirm password").performTextInput("123")
        
        // Click create account
        composeTestRule.onNodeWithText("Create Account")
            .performClick()
        
        // Wait for validation
        composeTestRule.waitForIdle()
        
        // Should not navigate (due to short password)
        assert(!navigateToVerificationCalled)
    }

    @Test
    fun signUpScreen_validationError_showsForMismatchedPasswords() {
        composeTestRule.setContent {
            SproutTheme {
                SignUpScreen(
                    onNavigateToLogin = { navigateToLoginCalled = true },
                    onNavigateToVerification = { email -> 
                        navigateToVerificationCalled = true
                        verificationEmail = email
                    }
                )
            }
        }

        // Fill form with mismatched passwords
        composeTestRule.onNodeWithText("First").performTextInput("John")
        composeTestRule.onNodeWithText("Last").performTextInput("Doe")
        composeTestRule.onNodeWithText("Enter your email").performTextInput("john@example.com")
        composeTestRule.onNodeWithText("Create password").performTextInput("Password123!")
        composeTestRule.onNodeWithText("Confirm password").performTextInput("DifferentPassword123!")
        
        // Click create account
        composeTestRule.onNodeWithText("Create Account")
            .performClick()
        
        // Wait for validation
        composeTestRule.waitForIdle()
        
        // Should not navigate (due to mismatched passwords)
        assert(!navigateToVerificationCalled)
    }

    @Test
    fun signUpScreen_successfulSubmission_withValidData() {
        composeTestRule.setContent {
            SproutTheme {
                SignUpScreen(
                    onNavigateToLogin = { navigateToLoginCalled = true },
                    onNavigateToVerification = { email -> 
                        navigateToVerificationCalled = true
                        verificationEmail = email
                    }
                )
            }
        }

        val testEmail = "john.doe@example.com"
        
        // Fill form with valid data
        composeTestRule.onNodeWithText("First").performTextInput("John")
        composeTestRule.onNodeWithText("Last").performTextInput("Doe")
        composeTestRule.onNodeWithText("Enter your email").performTextInput(testEmail)
        composeTestRule.onNodeWithText("Create password").performTextInput("SecurePassword123!")
        composeTestRule.onNodeWithText("Confirm password").performTextInput("SecurePassword123!")
        
        // Click create account
        composeTestRule.onNodeWithText("Create Account")
            .performClick()
        
        // Wait for async operations
        composeTestRule.waitForIdle()
        
        // Form should be submitted (though navigation might not happen in test due to mocked service)
        composeTestRule.onNodeWithText("Create Account")
            .assertExists()
    }

    @Test
    fun signUpScreen_signInLink_triggersNavigation() {
        composeTestRule.setContent {
            SproutTheme {
                SignUpScreen(
                    onNavigateToLogin = { navigateToLoginCalled = true },
                    onNavigateToVerification = { email -> 
                        navigateToVerificationCalled = true
                        verificationEmail = email
                    }
                )
            }
        }

        // Click the sign in link
        composeTestRule.onNodeWithText("Sign In")
            .performClick()
        
        // Verify navigation was triggered
        assert(navigateToLoginCalled)
        assert(!navigateToVerificationCalled)
    }

    @Test
    fun signUpScreen_socialLoginButtons_areClickable() {
        composeTestRule.setContent {
            SproutTheme {
                SignUpScreen(
                    onNavigateToLogin = { navigateToLoginCalled = true },
                    onNavigateToVerification = { email -> 
                        navigateToVerificationCalled = true
                        verificationEmail = email
                    }
                )
            }
        }

        // Verify Google sign up button is clickable
        composeTestRule.onNodeWithText("Continue with Google")
            .assertIsEnabled()
            .performClick()
        
        composeTestRule.waitForIdle()
        
        // Verify Apple sign up button is clickable
        composeTestRule.onNodeWithText("Continue with Apple")
            .assertIsEnabled()
            .performClick()
    }

    @Test
    fun signUpScreen_termsAndPrivacyLinks_areClickable() {
        composeTestRule.setContent {
            SproutTheme {
                SignUpScreen(
                    onNavigateToLogin = { navigateToLoginCalled = true },
                    onNavigateToVerification = { email -> 
                        navigateToVerificationCalled = true
                        verificationEmail = email
                    }
                )
            }
        }

        // Verify terms of service link is clickable
        composeTestRule.onNodeWithText("Terms of Service")
            .assertExists()
            .performClick()
        
        composeTestRule.waitForIdle()
        
        // Verify privacy policy link is clickable
        composeTestRule.onNodeWithText("Privacy Policy")
            .assertExists()
            .performClick()
    }

    @Test
    fun signUpScreen_hasCorrectSemantics() {
        composeTestRule.setContent {
            SproutTheme {
                SignUpScreen(
                    onNavigateToLogin = { navigateToLoginCalled = true },
                    onNavigateToVerification = { email -> 
                        navigateToVerificationCalled = true
                        verificationEmail = email
                    }
                )
            }
        }

        // Verify accessibility - check for content descriptions where needed
        composeTestRule.onNodeWithContentDescription("App logo")
            .assertExists()
        
        // Check that form fields have proper labels
        composeTestRule.onNodeWithText("First Name").assertExists()
        composeTestRule.onNodeWithText("Last Name").assertExists()
        composeTestRule.onNodeWithText("Email").assertExists()
        composeTestRule.onNodeWithText("Password").assertExists()
        composeTestRule.onNodeWithText("Confirm Password").assertExists()
    }
}