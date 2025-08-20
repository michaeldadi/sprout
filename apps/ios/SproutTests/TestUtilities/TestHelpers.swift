//
//  TestHelpers.swift
//  SproutTests
//
//  Created by Michael Dadi on 8/20/25.
//

import Foundation
import Testing
import AuthenticationServices
@testable import Sprout

// MARK: - Test Helpers

struct TestHelpers {
    
    // MARK: - Email Validation Helpers
    
    static let validEmails = [
        "test@example.com",
        "user.name@domain.org",
        "firstname.lastname@subdomain.domain.com",
        "valid+tag@example.co.uk"
    ]
    
    static let invalidEmails = [
        "",
        "invalid",
        "invalid@",
        "@invalid.com",
        "invalid@.com",
        "invalid.com",
        "test@",
        "@test.com",
        "test..test@example.com",
        "test@example..com"
    ]
    
    // MARK: - Password Validation Helpers
    
    static let validPasswords = [
        "ValidPass123!",
        "SecurePassword456@",
        "ComplexPass789#",
        "StrongPassword012$"
    ]
    
    static let weakPasswords = [
        "",
        "123",
        "abc",
        "password",
        "12345678",
        "abcdefgh",
        "Password",
        "password123",
        "Password!"
    ]
    
    // MARK: - Mock Data Generators
    
    static func generateRandomEmail() -> String {
        let domains = ["example.com", "test.org", "demo.net", "sample.io"]
        let username = "user\(Int.random(in: 1000...9999))"
        let domain = domains.randomElement() ?? "example.com"
        return "\(username)@\(domain)"
    }
    
    static func generateRandomPassword() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
        return String((0..<12).map { _ in chars.randomElement()! })
    }
    
    static func generateMockUser(email: String? = nil) -> CognitoUser {
        return CognitoUser(
            email: email ?? generateRandomEmail(),
            accessToken: "mock_access_token_\(UUID().uuidString)",
            idToken: "mock_id_token_\(UUID().uuidString)",
            refreshToken: "mock_refresh_token_\(UUID().uuidString)"
        )
    }
    
    // MARK: - Error Helpers
    
    static func createMockASAuthorizationError(code: ASAuthorizationError.Code) -> ASAuthorizationError {
        return ASAuthorizationError(code)
    }
    
    static func createMockNSError(domain: String = "TestDomain", code: Int = 1000) -> NSError {
        return NSError(domain: domain, code: code, userInfo: [
            NSLocalizedDescriptionKey: "Mock error for testing"
        ])
    }
    
    // MARK: - Async Testing Helpers
    
    static func waitForCondition(
        timeout: TimeInterval = 5.0,
        condition: @escaping () -> Bool
    ) async -> Bool {
        let endTime = Date().addingTimeInterval(timeout)
        
        while Date() < endTime {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        return false
    }
    
    static func waitForLoadingToComplete(
        authService: AuthService,
        timeout: TimeInterval = 5.0
    ) async -> Bool {
        return await waitForCondition(timeout: timeout) {
            !authService.isLoading
        }
    }
    
    // MARK: - Validation Helpers
    
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    static func isStrongPassword(_ password: String) -> Bool {
        // Check minimum length
        guard password.count >= 8 else { return false }
        
        // Check for uppercase letter
        guard password.range(of: "[A-Z]", options: .regularExpression) != nil else { return false }
        
        // Check for lowercase letter
        guard password.range(of: "[a-z]", options: .regularExpression) != nil else { return false }
        
        // Check for number
        guard password.range(of: "[0-9]", options: .regularExpression) != nil else { return false }
        
        // Check for special character
        guard password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil else { return false }
        
        return true
    }
    
    // MARK: - Test Data
    
    struct TestUser {
        let email: String
        let password: String
        let firstName: String
        let lastName: String
        
        static let validUser = TestUser(
            email: "test.user@example.com",
            password: "TestPassword123!",
            firstName: "Test",
            lastName: "User"
        )
        
        static let anotherValidUser = TestUser(
            email: "another.user@example.com",
            password: "AnotherPassword456@",
            firstName: "Another",
            lastName: "User"
        )
    }
    
    // MARK: - Apple Sign In Test Data
    
    struct AppleSignInTestData {
        static let validIdToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.test.token"
        static let validAuthCode = "valid_apple_auth_code"
        static let mockUserIdentifier = "001234.test.apple.user"
        
        static let mockFullName: PersonNameComponents = {
            var name = PersonNameComponents()
            name.givenName = "Apple"
            name.familyName = "User"
            return name
        }()
    }
    
    // MARK: - Google Sign In Test Data
    
    struct GoogleSignInTestData {
        static let validIdToken = "google.test.id.token"
        static let validAccessToken = "google_test_access_token"
        static let mockEmail = "google.user@gmail.com"
        static let mockFullName = "Google Test User"
    }
    
    // MARK: - Error Scenarios
    
    enum TestErrorScenario {
        case networkError
        case invalidCredentials
        case userNotFound
        case weakPassword
        case invalidEmail
        case serverError
        case timeout
        
        var error: AuthError {
            switch self {
            case .networkError:
                return .signInFailed("Network error occurred")
            case .invalidCredentials:
                return .signInFailed("Invalid credentials")
            case .userNotFound:
                return .signInFailed("User not found")
            case .weakPassword:
                return .signUpFailed("Password is too weak")
            case .invalidEmail:
                return .signUpFailed("Invalid email format")
            case .serverError:
                return .signInFailed("Server error")
            case .timeout:
                return .signInFailed("Request timeout")
            }
        }
    }
}

// MARK: - Custom Expectations

extension TestHelpers {
    
    static func expectAuthServiceState(
        _ authService: AuthService,
        isAuthenticated: Bool,
        hasUser: Bool,
        isLoading: Bool = false,
        file: StaticString = #file,
        line: UInt = #line
    ) {
      #expect(authService.isAuthenticated == isAuthenticated, "AuthService.isAuthenticated should be \(isAuthenticated)", sourceLocation: SourceLocation(from: file as! Decoder))
      #expect((authService.currentUser != nil) == hasUser, "AuthService.currentUser existence should be \(hasUser)", sourceLocation: SourceLocation(from: file as! Decoder))
      #expect(authService.isLoading == isLoading, "AuthService.isLoading should be \(isLoading)", sourceLocation: SourceLocation(from: file as! Decoder))
    }
    
    static func expectMockAuthServiceCalls(
        _ mockService: MockAuthService,
        signUpCount: Int? = nil,
        signInCount: Int? = nil,
        signOutCount: Int? = nil,
        confirmSignUpCount: Int? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        if let expectedSignUpCount = signUpCount {
          #expect(mockService.signUpCallCount == expectedSignUpCount, "SignUp should be called \(expectedSignUpCount) times", sourceLocation: SourceLocation(from: file as! Decoder))
        }
        
        if let expectedSignInCount = signInCount {
          #expect(mockService.signInCallCount == expectedSignInCount, "SignIn should be called \(expectedSignInCount) times", sourceLocation: SourceLocation(from: file as! Decoder))
        }
        
        if let expectedSignOutCount = signOutCount {
          #expect(mockService.signOutCallCount == expectedSignOutCount, "SignOut should be called \(expectedSignOutCount) times", sourceLocation: SourceLocation(from: file as! Decoder))
        }
        
        if let expectedConfirmSignUpCount = confirmSignUpCount {
          #expect(mockService.confirmSignUpCallCount == expectedConfirmSignUpCount, "ConfirmSignUp should be called \(expectedConfirmSignUpCount) times", sourceLocation: SourceLocation(from: file as! Decoder))
        }
    }
}

// MARK: - Performance Testing Helpers

extension TestHelpers {
    
    static func measureAsync<T>(
        name: String = "Async Operation",
        operation: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("⏱️ \(name) completed in \(String(format: "%.3f", timeElapsed)) seconds")
        return result
    }
    
    static func measureAndExpectPerformance<T>(
        name: String = "Async Operation",
        expectedMaxDuration: TimeInterval,
        operation: () async throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
      #expect(timeElapsed <= expectedMaxDuration, "\(name) should complete within \(expectedMaxDuration)s but took \(String(format: "%.3f", timeElapsed))s", sourceLocation: SourceLocation(from: file as! Decoder))
        
        return result
    }
}
