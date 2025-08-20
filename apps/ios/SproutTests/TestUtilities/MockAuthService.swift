//
//  MockAuthService.swift
//  SproutTests
//
//  Created by Michael Dadi on 8/20/25.
//

import Foundation
import AWSCognitoIdentityProvider
import AuthenticationServices
@testable import Sprout

@MainActor
class MockAuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: CognitoUser?
    @Published var isLoading = false
    
    // Mock state control
    var shouldSucceed = true
    var shouldThrowError = false
    var errorToThrow: AuthError = .signInFailed("Mock error")
    var simulateNetworkDelay = false
    var networkDelayDuration: TimeInterval = 0.5
    
    // Call tracking
    var signUpCallCount = 0
    var signInCallCount = 0
    var signOutCallCount = 0
    var confirmSignUpCallCount = 0
    var forgotPasswordCallCount = 0
    var refreshSessionCallCount = 0
    
    // Last call parameters
    var lastSignUpEmail: String?
    var lastSignUpPassword: String?
    var lastSignInEmail: String?
    var lastSignInPassword: String?
    var lastConfirmationEmail: String?
    var lastConfirmationCode: String?
    
    init() {}
    
    // MARK: - Mock Sign Up
    func signUp(email: String, password: String) async throws {
        signUpCallCount += 1
        lastSignUpEmail = email
        lastSignUpPassword = password
        
        isLoading = true
        defer { isLoading = false }
        
        if simulateNetworkDelay {
            try await Task.sleep(nanoseconds: UInt64(networkDelayDuration * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if !shouldSucceed {
            throw AuthError.signUpFailed("Mock sign up failure")
        }
        
        // Simulate successful sign up
    }
    
    // MARK: - Mock Confirm Sign Up
    func confirmSignUp(email: String, confirmationCode: String) async throws {
        confirmSignUpCallCount += 1
        lastConfirmationEmail = email
        lastConfirmationCode = confirmationCode
        
        isLoading = true
        defer { isLoading = false }
        
        if simulateNetworkDelay {
            try await Task.sleep(nanoseconds: UInt64(networkDelayDuration * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if !shouldSucceed {
            throw AuthError.confirmationFailed("Mock confirmation failure")
        }
        
        // Simulate successful confirmation
    }
    
    // MARK: - Mock Sign In
    func signIn(email: String, password: String) async throws {
        signInCallCount += 1
        lastSignInEmail = email
        lastSignInPassword = password
        
        isLoading = true
        defer { isLoading = false }
        
        if simulateNetworkDelay {
            try await Task.sleep(nanoseconds: UInt64(networkDelayDuration * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if !shouldSucceed {
            throw AuthError.signInFailed("Mock sign in failure")
        }
        
        // Simulate successful sign in
        self.currentUser = CognitoUser(
            email: email,
            accessToken: "mock_access_token",
            idToken: "mock_id_token",
            refreshToken: "mock_refresh_token"
        )
        self.isAuthenticated = true
    }
    
    // MARK: - Mock Sign Out
    func signOut() async {
        signOutCallCount += 1
        
        isLoading = true
        defer { isLoading = false }
        
        if simulateNetworkDelay {
            try? await Task.sleep(nanoseconds: UInt64(networkDelayDuration * 1_000_000_000))
        }
        
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    // MARK: - Mock Forgot Password
    func forgotPassword(email: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        if simulateNetworkDelay {
            try await Task.sleep(nanoseconds: UInt64(networkDelayDuration * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if !shouldSucceed {
            throw AuthError.forgotPasswordFailed("Mock forgot password failure")
        }
    }
    
    // MARK: - Mock Confirm Forgot Password
    func confirmForgotPassword(email: String, confirmationCode: String, newPassword: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        if simulateNetworkDelay {
            try await Task.sleep(nanoseconds: UInt64(networkDelayDuration * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if !shouldSucceed {
            throw AuthError.passwordResetFailed("Mock password reset failure")
        }
    }
    
    // MARK: - Mock Refresh Session
    func refreshSession() async throws {
        refreshSessionCallCount += 1
        
        isLoading = true
        defer { isLoading = false }
        
        if simulateNetworkDelay {
            try await Task.sleep(nanoseconds: UInt64(networkDelayDuration * 1_000_000_000))
        }
        
        if !isAuthenticated {
            throw AuthError.notAuthenticated
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if !shouldSucceed {
            throw AuthError.tokenRefreshFailed("Mock token refresh failure")
        }
        
        // Simulate successful token refresh
        if let currentUser = currentUser {
            self.currentUser = CognitoUser(
                email: currentUser.email,
                accessToken: "refreshed_access_token",
                idToken: "refreshed_id_token",
                refreshToken: currentUser.refreshToken
            )
        }
    }
    
    // MARK: - Mock Check Existing Session
    func checkExistingSession() async {
        if simulateNetworkDelay {
            try? await Task.sleep(nanoseconds: UInt64(networkDelayDuration * 1_000_000_000))
        }
        
        // Mock existing session behavior
        // In real implementation, this would check stored tokens
    }
    
    // MARK: - Mock Apple Sign In
    func signInWithApple(idToken: String, authorizationCode: String, fullName: PersonNameComponents?) async throws {
        isLoading = true
        defer { isLoading = false }
        
        if simulateNetworkDelay {
            try await Task.sleep(nanoseconds: UInt64(networkDelayDuration * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if !shouldSucceed {
            throw AuthError.signInFailed("Mock Apple Sign In failure")
        }
        
        // Simulate successful Apple Sign In
        let mockEmail = "apple.user@icloud.com"
        self.currentUser = CognitoUser(
            email: mockEmail,
            accessToken: "apple_access_token",
            idToken: idToken,
            refreshToken: "apple_refresh_token"
        )
        self.isAuthenticated = true
    }
    
    // MARK: - Mock Google Sign In
    func signInWithGoogle(idToken: String, accessToken: String, email: String, fullName: String?) async throws {
        isLoading = true
        defer { isLoading = false }
        
        if simulateNetworkDelay {
            try await Task.sleep(nanoseconds: UInt64(networkDelayDuration * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if !shouldSucceed {
            throw AuthError.signInFailed("Mock Google Sign In failure")
        }
        
        // Simulate successful Google Sign In
        self.currentUser = CognitoUser(
            email: email,
            accessToken: accessToken,
            idToken: idToken,
            refreshToken: "google_refresh_token"
        )
        self.isAuthenticated = true
    }
    
    // MARK: - Test Utilities
    func reset() {
        isAuthenticated = false
        currentUser = nil
        isLoading = false
        shouldSucceed = true
        shouldThrowError = false
        errorToThrow = .signInFailed("Mock error")
        simulateNetworkDelay = false
        networkDelayDuration = 0.5
        
        // Reset call counts
        signUpCallCount = 0
        signInCallCount = 0
        signOutCallCount = 0
        confirmSignUpCallCount = 0
        forgotPasswordCallCount = 0
        refreshSessionCallCount = 0
        
        // Reset last call parameters
        lastSignUpEmail = nil
        lastSignUpPassword = nil
        lastSignInEmail = nil
        lastSignInPassword = nil
        lastConfirmationEmail = nil
        lastConfirmationCode = nil
    }
    
    func simulateAuthenticatedUser(email: String = "test@example.com") {
        self.currentUser = CognitoUser(
            email: email,
            accessToken: "test_access_token",
            idToken: "test_id_token",
            refreshToken: "test_refresh_token"
        )
        self.isAuthenticated = true
    }
}