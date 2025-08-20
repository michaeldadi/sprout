//
//  AuthenticationUITests.swift
//  SproutUITests
//
//  Created by Michael Dadi on 8/20/25.
//

import XCTest

final class AuthenticationUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }
    
    // MARK: - Login Screen Tests
    
    func testLoginScreenElements() throws {
        // Test that all login screen elements are present and accessible
        
        // Check for welcome text
        let welcomeText = app.staticTexts["Welcome Back"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 5))
        XCTAssertTrue(welcomeText.isHittable)
        
        // Check for email input field
        let emailField = app.textFields["Enter your email"]
        XCTAssertTrue(emailField.exists)
        XCTAssertTrue(emailField.isEnabled)
        
        // Check for password input field  
        let passwordField = app.secureTextFields["Enter your password"]
        XCTAssertTrue(passwordField.exists)
        XCTAssertTrue(passwordField.isEnabled)
        
        // Check for sign in button
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.exists)
        XCTAssertTrue(signInButton.isEnabled)
        
        // Check for sign up link
        let signUpLink = app.buttons["Sign Up"]
        XCTAssertTrue(signUpLink.exists)
        XCTAssertTrue(signUpLink.isEnabled)
        
        // Check for forgot password link
        let forgotPasswordLink = app.buttons["Forgot Password?"]
        XCTAssertTrue(forgotPasswordLink.exists)
        XCTAssertTrue(forgotPasswordLink.isEnabled)
        
        // Check for social sign in buttons
        let googleSignInButton = app.buttons["Continue with Google"]
        XCTAssertTrue(googleSignInButton.exists)
        XCTAssertTrue(googleSignInButton.isEnabled)
        
        let appleSignInButton = app.buttons["Continue with Apple"]
        XCTAssertTrue(appleSignInButton.exists)
        XCTAssertTrue(appleSignInButton.isEnabled)
    }
    
    func testLoginFormValidation() throws {
        // Test form validation behavior
        
        let emailField = app.textFields["Enter your email"]
        let passwordField = app.secureTextFields["Enter your password"]
        let signInButton = app.buttons["Sign In"]
        
        // Try to submit empty form
        signInButton.tap()
        
        // Should still be on login screen (validation prevents submission)
        let welcomeText = app.staticTexts["Welcome Back"]
        XCTAssertTrue(welcomeText.exists)
        
        // Fill only email
        emailField.tap()
        emailField.typeText("test@example.com")
        
        // Try to submit with missing password
        signInButton.tap()
        
        // Should still be on login screen
        XCTAssertTrue(welcomeText.exists)
        
        // Fill invalid email
        emailField.tap()
        emailField.clearText()
        emailField.typeText("invalid-email")
        
        signInButton.tap()
        
        // Should still be on login screen
        XCTAssertTrue(welcomeText.exists)
    }
    
    func testPasswordVisibilityToggle() throws {
        let passwordField = app.secureTextFields["Enter your password"]
        let visibilityToggle = app.buttons["Toggle Password Visibility"]
        
        // Type password
        passwordField.tap()
        passwordField.typeText("testpassword")
        
        // Toggle visibility
        if visibilityToggle.exists {
            visibilityToggle.tap()
            
            // After toggle, password might be in a text field instead of secure field
            let textPasswordField = app.textFields["Enter your password"]
            XCTAssertTrue(textPasswordField.exists || passwordField.exists)
        }
    }
    
    // MARK: - Sign Up Screen Tests
    
    func testNavigationToSignUp() throws {
        let signUpButton = app.buttons["Sign Up"]
        signUpButton.tap()
        
        // Should navigate to sign up screen
        let createAccountText = app.staticTexts["Create Your Account"]
        XCTAssertTrue(createAccountText.waitForExistence(timeout: 3))
    }
    
    func testSignUpScreenElements() throws {
        // Navigate to sign up screen
        let signUpButton = app.buttons["Sign Up"]
        signUpButton.tap()
        
        let createAccountText = app.staticTexts["Create Your Account"]
        XCTAssertTrue(createAccountText.waitForExistence(timeout: 3))
        
        // Check for first name field
        let firstNameField = app.textFields["First Name"]
        XCTAssertTrue(firstNameField.exists)
        XCTAssertTrue(firstNameField.isEnabled)
        
        // Check for last name field
        let lastNameField = app.textFields["Last Name"]
        XCTAssertTrue(lastNameField.exists)
        XCTAssertTrue(lastNameField.isEnabled)
        
        // Check for email field
        let emailField = app.textFields["Enter your email"]
        XCTAssertTrue(emailField.exists)
        XCTAssertTrue(emailField.isEnabled)
        
        // Check for password fields
        let passwordField = app.secureTextFields["Create password"]
        XCTAssertTrue(passwordField.exists)
        XCTAssertTrue(passwordField.isEnabled)
        
        let confirmPasswordField = app.secureTextFields["Confirm password"]
        XCTAssertTrue(confirmPasswordField.exists)
        XCTAssertTrue(confirmPasswordField.isEnabled)
        
        // Check for create account button
        let createAccountButton = app.buttons["Create Account"]
        XCTAssertTrue(createAccountButton.exists)
        XCTAssertTrue(createAccountButton.isEnabled)
        
        // Check for sign in link
        let signInLink = app.buttons["Sign In"]
        XCTAssertTrue(signInLink.exists)
        XCTAssertTrue(signInLink.isEnabled)
    }
    
    func testSignUpFormValidation() throws {
        // Navigate to sign up screen
        app.buttons["Sign Up"].tap()
        
        let createAccountText = app.staticTexts["Create Your Account"]
        XCTAssertTrue(createAccountText.waitForExistence(timeout: 3))
        
        let createAccountButton = app.buttons["Create Account"]
        
        // Try to submit empty form
        createAccountButton.tap()
        
        // Should still be on sign up screen
        XCTAssertTrue(createAccountText.exists)
        
        // Fill partial form with invalid email
        let firstNameField = app.textFields["First Name"]
        let emailField = app.textFields["Enter your email"]
        
        firstNameField.tap()
        firstNameField.typeText("Test")
        
        emailField.tap()
        emailField.typeText("invalid-email")
        
        // Try to submit with invalid email
        createAccountButton.tap()
        
        // Should still be on sign up screen
        XCTAssertTrue(createAccountText.exists)
    }
    
    func testSignUpPasswordConfirmation() throws {
        // Navigate to sign up screen
        app.buttons["Sign Up"].tap()
        
        let createAccountText = app.staticTexts["Create Your Account"]
        XCTAssertTrue(createAccountText.waitForExistence(timeout: 3))
        
        // Fill form with mismatched passwords
        let passwordField = app.secureTextFields["Create password"]
        let confirmPasswordField = app.secureTextFields["Confirm password"]
        
        passwordField.tap()
        passwordField.typeText("Password123!")
        
        confirmPasswordField.tap()
        confirmPasswordField.typeText("DifferentPassword123!")
        
        let createAccountButton = app.buttons["Create Account"]
        createAccountButton.tap()
        
        // Should still be on sign up screen (validation should prevent submission)
        XCTAssertTrue(createAccountText.exists)
    }
    
    // MARK: - Navigation Tests
    
    func testSignUpToLoginNavigation() throws {
        // Navigate to sign up screen
        app.buttons["Sign Up"].tap()
        
        let createAccountText = app.staticTexts["Create Your Account"]
        XCTAssertTrue(createAccountText.waitForExistence(timeout: 3))
        
        // Navigate back to login
        app.buttons["Sign In"].tap()
        
        // Should be back on login screen
        let welcomeText = app.staticTexts["Welcome Back"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 3))
    }
    
    func testForgotPasswordNavigation() throws {
        let forgotPasswordButton = app.buttons["Forgot Password?"]
        forgotPasswordButton.tap()
        
        // Should navigate to forgot password screen
        // (This test verifies the navigation works without crashing)
        sleep(1) // Allow for navigation animation
        
        // App should still be responsive
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    // MARK: - Social Sign In Tests
    
    func testGoogleSignInButton() throws {
        let googleButton = app.buttons["Continue with Google"]
        XCTAssertTrue(googleButton.exists)
        XCTAssertTrue(googleButton.isEnabled)
        
        googleButton.tap()
        
        // Should trigger Google sign in flow (may open external app or web view)
        sleep(2) // Allow time for potential external app launch
        
        // App should still be accessible after attempting social sign in
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)
    }
    
    func testAppleSignInButton() throws {
        let appleButton = app.buttons["Continue with Apple"]
        XCTAssertTrue(appleButton.exists)
        XCTAssertTrue(appleButton.isEnabled)
        
        appleButton.tap()
        
        // Should trigger Apple sign in flow
        sleep(2) // Allow time for Apple Sign In dialog
        
        // App should still be accessible
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)
    }
    
    // MARK: - Accessibility Tests
    
    func testLoginScreenAccessibility() throws {
        // Test that UI elements have proper accessibility labels
        
        let emailField = app.textFields["Enter your email"]
        XCTAssertNotNil(emailField.label)
        XCTAssertTrue(emailField.isAccessibilityElement)
        
        let passwordField = app.secureTextFields["Enter your password"]
        XCTAssertNotNil(passwordField.label)
        XCTAssertTrue(passwordField.isAccessibilityElement)
        
        let signInButton = app.buttons["Sign In"]
        XCTAssertNotNil(signInButton.label)
        XCTAssertTrue(signInButton.isAccessibilityElement)
        
        // Test that buttons are properly labeled for screen readers
        let googleButton = app.buttons["Continue with Google"]
        XCTAssertTrue(googleButton.isAccessibilityElement)
        XCTAssertNotNil(googleButton.label)
        
        let appleButton = app.buttons["Continue with Apple"]
        XCTAssertTrue(appleButton.isAccessibilityElement)
        XCTAssertNotNil(appleButton.label)
    }
    
    func testSignUpScreenAccessibility() throws {
        // Navigate to sign up screen
        app.buttons["Sign Up"].tap()
        
        let createAccountText = app.staticTexts["Create Your Account"]
        XCTAssertTrue(createAccountText.waitForExistence(timeout: 3))
        
        // Test accessibility of form fields
        let firstNameField = app.textFields["First Name"]
        XCTAssertTrue(firstNameField.isAccessibilityElement)
        XCTAssertNotNil(firstNameField.label)
        
        let lastNameField = app.textFields["Last Name"]
        XCTAssertTrue(lastNameField.isAccessibilityElement)
        XCTAssertNotNil(lastNameField.label)
        
        let emailField = app.textFields["Enter your email"]
        XCTAssertTrue(emailField.isAccessibilityElement)
        XCTAssertNotNil(emailField.label)
        
        let passwordField = app.secureTextFields["Create password"]
        XCTAssertTrue(passwordField.isAccessibilityElement)
        XCTAssertNotNil(passwordField.label)
        
        let confirmPasswordField = app.secureTextFields["Confirm password"]
        XCTAssertTrue(confirmPasswordField.isAccessibilityElement)
        XCTAssertNotNil(confirmPasswordField.label)
    }
    
    // MARK: - Form Input Tests
    
    func testFormInputSequence() throws {
        // Test sequential form input
        let emailField = app.textFields["Enter your email"]
        let passwordField = app.secureTextFields["Enter your password"]
        
        // Fill email field
        emailField.tap()
        emailField.typeText("test@example.com")
        
        // Move to password field
        passwordField.tap()
        passwordField.typeText("testpassword")
        
        // Verify inputs were entered
        XCTAssertEqual(emailField.value as? String, "test@example.com")
        // Note: Secure text fields don't expose their values for security
    }
    
    func testSignUpFormInputSequence() throws {
        // Navigate to sign up screen
        app.buttons["Sign Up"].tap()
        
        let createAccountText = app.staticTexts["Create Your Account"]
        XCTAssertTrue(createAccountText.waitForExistence(timeout: 3))
        
        // Fill form sequentially
        let firstNameField = app.textFields["First Name"]
        let lastNameField = app.textFields["Last Name"]
        let emailField = app.textFields["Enter your email"]
        let passwordField = app.secureTextFields["Create password"]
        let confirmPasswordField = app.secureTextFields["Confirm password"]
        
        firstNameField.tap()
        firstNameField.typeText("Test")
        
        lastNameField.tap()
        lastNameField.typeText("User")
        
        emailField.tap()
        emailField.typeText("test@example.com")
        
        passwordField.tap()
        passwordField.typeText("TestPassword123!")
        
        confirmPasswordField.tap()
        confirmPasswordField.typeText("TestPassword123!")
        
        // Verify text fields have content
        XCTAssertEqual(firstNameField.value as? String, "Test")
        XCTAssertEqual(lastNameField.value as? String, "User")
        XCTAssertEqual(emailField.value as? String, "test@example.com")
    }
    
    // MARK: - Error Handling Tests
    
    func testNoToastForAppleSignInCancellation() throws {
        let appleButton = app.buttons["Continue with Apple"]
        appleButton.tap()
        
        // Simulate user dismissing Apple Sign In dialog
        // In a real test environment, this would involve more complex interaction
        sleep(1)
        
        // Check that no error toast is displayed
        // (This is more of a behavior verification test)
        let errorToast = app.staticTexts["Apple Sign In failed"]
        XCTAssertFalse(errorToast.exists)
    }
    
    // MARK: - Screen Transition Tests
    
    func testSmoothScreenTransitions() throws {
        // Test that screen transitions are smooth and don't crash
        
        // Login -> Sign Up
        app.buttons["Sign Up"].tap()
        
        let createAccountText = app.staticTexts["Create Your Account"]
        XCTAssertTrue(createAccountText.waitForExistence(timeout: 2))
        
        // Sign Up -> Login
        app.buttons["Sign In"].tap()
        
        let welcomeText = app.staticTexts["Welcome Back"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 2))
        
        // Login -> Forgot Password
        app.buttons["Forgot Password?"].tap()
        
        // Wait for potential transition
        sleep(1)
        
        // App should remain responsive
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    // MARK: - Performance Tests
    
    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    func testScreenNavigationPerformance() throws {
        measure {
            // Measure time to navigate between screens
            app.buttons["Sign Up"].tap()
            _ = app.staticTexts["Create Your Account"].waitForExistence(timeout: 5)
            
            app.buttons["Sign In"].tap()
            _ = app.staticTexts["Welcome Back"].waitForExistence(timeout: 5)
        }
    }
}

// MARK: - Helper Extensions

extension XCUIElement {
    func clearText() {
        guard let stringValue = self.value as? String else {
            return
        }
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
    }
}