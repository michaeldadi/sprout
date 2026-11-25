import Foundation

/// Helper for localization strings with type safety
enum LocalizedString {
    // MARK: - Common
    case back
    case email
    case password
    case or
    case loading
    
    // MARK: - Authentication
    case welcomeBack
    case signInSubtitle
    case enterEmail
    case enterPassword
    case forgotPassword
    case signIn
    case dontHaveAccount
    case signUp
    case continueWithGoogle
    case continueWithApple
    
    // MARK: - Sign Up
    case createAccount
    case signUpSubtitle
    case firstName
    case lastName
    case first
    case last
    case createPassword
    case confirmPassword
    case confirmPasswordField
    case termsPrefix
    case termsOfService
    case and
    case privacyPolicy
    case createAccountButton
    case alreadyHaveAccount
    
    // MARK: - Email Verification
    case verifyEmail
    case verificationSent
    case verificationCode
    case enterCodePlaceholder
    case verifyEmailButton
    case didntReceiveCode
    
    // MARK: - Forgot Password
    case checkEmail
    case resetInstructionsSent
    case checkSpam
    case resendEmail
    case forgotPasswordTitle
    case forgotPasswordSubtitle
    case sendResetEmail
    case rememberPassword
    
    // MARK: - Error Messages
    case errorEnterEmail
    case errorEnterPassword
    case errorEnterFirstName
    case errorEnterLastName
    case errorPasswordsDontMatch
    case errorWeakPassword
    case errorInvalidEmail
    case errorEnterVerificationCode
    
    // MARK: - Success Messages
    case loginSuccessful
    case emailVerified
    case resetEmailSent
    case verificationCodeResent(String)
    case googleSigninSuccessful
    
    // MARK: - Generic Messages
    case signinFailed
    case googleSigninFailed
    case resetEmailSentAgain
    
    /// Get the localized string
    var localized: String {
        switch self {
        // Common
        case .back: return NSLocalizedString("back", comment: "Back button")
        case .email: return NSLocalizedString("email", comment: "Email field")
        case .password: return NSLocalizedString("password", comment: "Password field")
        case .or: return NSLocalizedString("or", comment: "Or divider")
        case .loading: return NSLocalizedString("loading", comment: "Loading state")
            
        // Authentication
        case .welcomeBack: return NSLocalizedString("welcome_back", comment: "Welcome back title")
        case .signInSubtitle: return NSLocalizedString("sign_in_subtitle", comment: "Sign in subtitle")
        case .enterEmail: return NSLocalizedString("enter_email", comment: "Email placeholder")
        case .enterPassword: return NSLocalizedString("enter_password", comment: "Password placeholder")
        case .forgotPassword: return NSLocalizedString("forgot_password", comment: "Forgot password link")
        case .signIn: return NSLocalizedString("sign_in", comment: "Sign in button")
        case .dontHaveAccount: return NSLocalizedString("dont_have_account", comment: "Sign up prompt")
        case .signUp: return NSLocalizedString("sign_up", comment: "Sign up button")
        case .continueWithGoogle: return NSLocalizedString("continue_with_google", comment: "Google sign in")
        case .continueWithApple: return NSLocalizedString("continue_with_apple", comment: "Apple sign in")
            
        // Sign Up
        case .createAccount: return NSLocalizedString("create_account", comment: "Create account title")
        case .signUpSubtitle: return NSLocalizedString("sign_up_subtitle", comment: "Sign up subtitle")
        case .firstName: return NSLocalizedString("first_name", comment: "First name field")
        case .lastName: return NSLocalizedString("last_name", comment: "Last name field")
        case .first: return NSLocalizedString("first", comment: "First name placeholder")
        case .last: return NSLocalizedString("last", comment: "Last name placeholder")
        case .createPassword: return NSLocalizedString("create_password", comment: "Create password placeholder")
        case .confirmPassword: return NSLocalizedString("confirm_password", comment: "Confirm password placeholder")
        case .confirmPasswordField: return NSLocalizedString("confirm_password_field", comment: "Confirm password field")
        case .termsPrefix: return NSLocalizedString("terms_prefix", comment: "Terms agreement prefix")
        case .termsOfService: return NSLocalizedString("terms_of_service", comment: "Terms of service link")
        case .and: return NSLocalizedString("and", comment: "And conjunction")
        case .privacyPolicy: return NSLocalizedString("privacy_policy", comment: "Privacy policy link")
        case .createAccountButton: return NSLocalizedString("create_account_button", comment: "Create account button")
        case .alreadyHaveAccount: return NSLocalizedString("already_have_account", comment: "Login prompt")
            
        // Email Verification
        case .verifyEmail: return NSLocalizedString("verify_email", comment: "Verify email title")
        case .verificationSent: return NSLocalizedString("verification_sent", comment: "Verification sent message")
        case .verificationCode: return NSLocalizedString("verification_code", comment: "Verification code field")
        case .enterCodePlaceholder: return NSLocalizedString("enter_code_placeholder", comment: "Code placeholder")
        case .verifyEmailButton: return NSLocalizedString("verify_email_button", comment: "Verify email button")
        case .didntReceiveCode: return NSLocalizedString("didnt_receive_code", comment: "Resend code link")
            
        // Forgot Password
        case .checkEmail: return NSLocalizedString("check_email", comment: "Check email title")
        case .resetInstructionsSent: return NSLocalizedString("reset_instructions_sent", comment: "Reset instructions message")
        case .checkSpam: return NSLocalizedString("check_spam", comment: "Check spam message")
        case .resendEmail: return NSLocalizedString("resend_email", comment: "Resend email button")
        case .forgotPasswordTitle: return NSLocalizedString("forgot_password_title", comment: "Forgot password title")
        case .forgotPasswordSubtitle: return NSLocalizedString("forgot_password_subtitle", comment: "Forgot password subtitle")
        case .sendResetEmail: return NSLocalizedString("send_reset_email", comment: "Send reset email button")
        case .rememberPassword: return NSLocalizedString("remember_password", comment: "Remember password prompt")
            
        // Error Messages
        case .errorEnterEmail: return NSLocalizedString("error_enter_email", comment: "Enter email error")
        case .errorEnterPassword: return NSLocalizedString("error_enter_password", comment: "Enter password error")
        case .errorEnterFirstName: return NSLocalizedString("error_enter_first_name", comment: "Enter first name error")
        case .errorEnterLastName: return NSLocalizedString("error_enter_last_name", comment: "Enter last name error")
        case .errorPasswordsDontMatch: return NSLocalizedString("error_passwords_dont_match", comment: "Passwords don't match error")
        case .errorWeakPassword: return NSLocalizedString("error_weak_password", comment: "Weak password error")
        case .errorInvalidEmail: return NSLocalizedString("error_invalid_email", comment: "Invalid email error")
        case .errorEnterVerificationCode: return NSLocalizedString("error_enter_verification_code", comment: "Enter verification code error")
            
        // Success Messages
        case .loginSuccessful: return NSLocalizedString("login_successful", comment: "Login success message")
        case .emailVerified: return NSLocalizedString("email_verified", comment: "Email verified message")
        case .resetEmailSent: return NSLocalizedString("reset_email_sent", comment: "Reset email sent message")
        case .verificationCodeResent(let email): return String(format: NSLocalizedString("verification_code_resent", comment: "Code resent message"), email)
        case .googleSigninSuccessful: return NSLocalizedString("google_signin_successful", comment: "Google signin success")
            
        // Generic Messages
        case .signinFailed: return NSLocalizedString("signin_failed", comment: "Sign in failed message")
        case .googleSigninFailed: return NSLocalizedString("google_signin_failed", comment: "Google signin failed")
        case .resetEmailSentAgain: return NSLocalizedString("reset_email_sent_again", comment: "Reset email sent again")
        }
    }
}

// MARK: - String Extension for convenience
extension String {
    /// Get localized string using the key
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Get localized string with arguments
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}