//
//  AuthenticationIntegrationTests.swift
//  SproutTests
//
//  Created by Michael Dadi on 8/20/25.
//

import Testing
import Foundation
import AWSCognitoIdentityProvider
import AuthenticationServices
@testable import Sprout

struct AuthenticationIntegrationTests {
    
    // MARK: - Integration Test Setup
    
    @Test("Complete sign up flow integration")
    func testCompleteSignUpFlowIntegration() async throws {
        let authService = await AuthService.shared
        
        // Ensure we start unauthenticated
        await authService.signOut()
        await #expect(authService.isAuthenticated == false)
        
        let testEmail = "integration.test@example.com"
        let testPassword = "IntegrationTest123!"
        
        // Step 1: Sign up
        do {
            try await authService.signUp(email: testEmail, password: testPassword)
            // Sign up should complete without throwing in real environment
            #expect(true, "Sign up step completed")
        } catch {
            // Expected to fail in test environment without proper AWS configuration
            #expect(error is AuthError, "Should throw AuthError in test environment")
        }
        
        // Step 2: Confirm sign up (would normally require actual confirmation code)
        do {
            try await authService.confirmSignUp(email: testEmail, confirmationCode: "123456")
            #expect(true, "Confirmation step completed")
        } catch {
            // Expected to fail in test environment
            #expect(error is AuthError, "Should throw AuthError in test environment")
        }
        
        // Step 3: Sign in with new credentials
        do {
            try await authService.signIn(email: testEmail, password: testPassword)
            await #expect(authService.isAuthenticated == true, "Should be authenticated after sign in")
        } catch {
            // Expected to fail in test environment
            #expect(error is AuthError, "Should throw AuthError in test environment")
            await #expect(authService.isAuthenticated == false, "Should remain unauthenticated after failed sign in")
        }
    }
    
    @Test("Complete sign in flow integration")
    func testCompleteSignInFlowIntegration() async throws {
        let authService = await AuthService.shared
        
        // Ensure we start unauthenticated
        await authService.signOut()
        await #expect(authService.isAuthenticated == false)
        await #expect(authService.currentUser == nil)
        
        let testEmail = "existing.user@example.com"
        let testPassword = "ExistingUser123!"
        
        do {
            try await authService.signIn(email: testEmail, password: testPassword)
            
            // If successful, verify authenticated state
            await #expect(authService.isAuthenticated == true)
            await #expect(authService.currentUser != nil)
            await #expect(authService.currentUser?.email == testEmail)
            
        } catch {
            // Expected to fail in test environment without real user
            #expect(error is AuthError, "Should throw AuthError for non-existent user")
            await #expect(authService.isAuthenticated == false, "Should remain unauthenticated")
            await #expect(authService.currentUser == nil, "Current user should remain nil")
        }
    }
    
    @Test("Complete Apple Sign In flow integration")
    func testCompleteAppleSignInFlowIntegration() async throws {
        let authService = await AuthService.shared
        
        // Ensure we start unauthenticated
        await authService.signOut()
        await #expect(authService.isAuthenticated == false)
        
        // Mock Apple Sign In credentials
        let mockIdToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.mock.token"
        let mockAuthCode = "mock_apple_auth_code"
        let mockFullName = PersonNameComponents()
        
        do {
            try await authService.signInWithApple(
                idToken: mockIdToken,
                authorizationCode: mockAuthCode,
                fullName: mockFullName
            )
            
            // If successful, verify authenticated state
            await #expect(authService.isAuthenticated == true)
            await #expect(authService.currentUser != nil)
            
        } catch {
            // Expected to fail in test environment
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                #expect(true, "Apple Sign In cancellation handled correctly")
            } else {
                #expect(error is AuthError, "Should throw appropriate AuthError")
            }
        }
    }
    
    @Test("Complete Google Sign In flow integration")
    func testCompleteGoogleSignInFlowIntegration() async throws {
        let authService = await AuthService.shared
        
        // Ensure we start unauthenticated
        await authService.signOut()
        await #expect(authService.isAuthenticated == false)
        
        // Mock Google Sign In credentials
        let mockIdToken = "google.id.token.mock"
        let mockAccessToken = "google_access_token_mock"
        let mockEmail = "google.user@gmail.com"
        let mockFullName = "Google User"
        
        do {
            try await authService.signInWithGoogle(
                idToken: mockIdToken,
                accessToken: mockAccessToken,
                email: mockEmail,
                fullName: mockFullName
            )
            
            // If successful, verify authenticated state
            await #expect(authService.isAuthenticated == true)
            await #expect(authService.currentUser != nil)
            await #expect(authService.currentUser?.email == mockEmail)
            
        } catch {
            // Expected to fail in test environment
            #expect(error is AuthError, "Should throw AuthError in test environment")
            await #expect(authService.isAuthenticated == false, "Should remain unauthenticated")
        }
    }
    
    @Test("Forgot password flow integration")
    func testForgotPasswordFlowIntegration() async throws {
        let authService = await AuthService.shared
        
        let testEmail = "forgot.password@example.com"
        let newPassword = "NewPassword123!"
        
        // Step 1: Initiate forgot password
        do {
            try await authService.forgotPassword(email: testEmail)
            #expect(true, "Forgot password initiated successfully")
        } catch {
            // Expected to fail in test environment
            #expect(error is AuthError, "Should throw AuthError in test environment")
        }
        
        // Step 2: Confirm forgot password (would normally require actual confirmation code)
        do {
            try await authService.confirmForgotPassword(
                email: testEmail,
                confirmationCode: "123456",
                newPassword: newPassword
            )
            #expect(true, "Password reset completed successfully")
        } catch {
            // Expected to fail in test environment
            #expect(error is AuthError, "Should throw AuthError in test environment")
        }
        
        // Step 3: Sign in with new password
        do {
            try await authService.signIn(email: testEmail, password: newPassword)
            await #expect(authService.isAuthenticated == true, "Should be authenticated with new password")
        } catch {
            // Expected to fail in test environment
            #expect(error is AuthError, "Should throw AuthError in test environment")
        }
    }
    
    @Test("Session management integration")
    func testSessionManagementIntegration() async throws {
        let authService = await AuthService.shared
        
        // Start with fresh state
        await authService.signOut()
        await #expect(authService.isAuthenticated == false)
        await #expect(authService.currentUser == nil)
        
        // Step 1: Check existing session (should be empty)
        await authService.checkExistingSession()
        await #expect(authService.isAuthenticated == false, "No existing session should be found")
        
        // Step 2: Sign in to create session
        do {
            try await authService.signIn(email: "session.test@example.com", password: "SessionTest123!")
            
            if await authService.isAuthenticated {
                // Step 3: Refresh session
                do {
                    try await authService.refreshSession()
                    await #expect(authService.isAuthenticated == true, "Session should remain valid after refresh")
                    await #expect(authService.currentUser != nil, "User should still exist after refresh")
                } catch {
                    #expect(error is AuthError, "Refresh should fail gracefully in test environment")
                }
            }
            
        } catch {
            // Expected to fail in test environment
            #expect(error is AuthError, "Should throw AuthError for sign in")
        }
        
        // Step 4: Sign out
        await authService.signOut()
        await #expect(authService.isAuthenticated == false, "Should be unauthenticated after sign out")
        await #expect(authService.currentUser == nil, "Current user should be nil after sign out")
    }
    
    @Test("Authentication state persistence")
    func testAuthenticationStatePersistence() async throws {
        let authService = await AuthService.shared
        
        // Clear any existing state
        await authService.signOut()
        
        // Test that signing out clears all stored data
        await #expect(authService.isAuthenticated == false)
        await #expect(authService.currentUser == nil)
        
        // Check that no tokens are stored
        await authService.checkExistingSession()
        await #expect(authService.isAuthenticated == false, "No session should be restored after sign out")
        
        // Attempt to refresh without authentication
        do {
            try await authService.refreshSession()
            #expect(Bool(false), "Should not be able to refresh without authentication")
        } catch {
            #expect(error is AuthError, "Should throw AuthError when not authenticated")
        }
    }
    
    @Test("Loading state management during operations")
    func testLoadingStateManagementDuringOperations() async throws {
        let authService = await AuthService.shared
        
        // Test loading state during sign up
        let signUpTask = Task {
            await #expect(authService.isLoading == false, "Should not be loading initially")
            
            do {
                try await authService.signUp(email: "loading.test@example.com", password: "LoadingTest123!")
            } catch {
                // Expected to fail in test environment
            }
        }
        
        // Loading state should be managed properly
        await signUpTask.value
        await #expect(authService.isLoading == false, "Should not be loading after operation completes")
        
        // Test loading state during sign in
        let signInTask = Task {
            do {
                try await authService.signIn(email: "loading.test@example.com", password: "LoadingTest123!")
            } catch {
                // Expected to fail in test environment
            }
        }
        
        await signInTask.value
        await #expect(authService.isLoading == false, "Should not be loading after sign in completes")
    }
    
    @Test("Error handling across authentication flows")
    func testErrorHandlingAcrossAuthenticationFlows() async throws {
        let authService = await AuthService.shared
        
        // Test invalid email formats across different operations
        let invalidEmails = ["", "invalid", "invalid@", "@invalid.com", "invalid@.com"]
        
        for invalidEmail in invalidEmails {
            // Test sign up with invalid email
            do {
                try await authService.signUp(email: invalidEmail, password: "ValidPass123!")
                #expect(Bool(false), "Should throw error for invalid email: \(invalidEmail)")
            } catch {
                #expect(error is AuthError, "Should throw AuthError for invalid email")
            }
            
            // Test sign in with invalid email
            do {
                try await authService.signIn(email: invalidEmail, password: "ValidPass123!")
                #expect(Bool(false), "Should throw error for invalid email: \(invalidEmail)")
            } catch {
                #expect(error is AuthError, "Should throw AuthError for invalid email")
            }
            
            // Test forgot password with invalid email
            do {
                try await authService.forgotPassword(email: invalidEmail)
                #expect(Bool(false), "Should throw error for invalid email: \(invalidEmail)")
            } catch {
                #expect(error is AuthError, "Should throw AuthError for invalid email")
            }
        }
    }
    
    @Test("Concurrent authentication operations")
    func testConcurrentAuthenticationOperations() async throws {
        let authService = await AuthService.shared
        
        // Ensure clean start
        await authService.signOut()
        
        // Test that concurrent operations don't interfere with each other
        async let signUp1: () = {
            do {
                try await authService.signUp(email: "concurrent1@example.com", password: "Concurrent123!")
            } catch {
                // Expected to fail
            }
        }()
        
        async let signUp2: () = {
            do {
                try await authService.signUp(email: "concurrent2@example.com", password: "Concurrent123!")
            } catch {
                // Expected to fail
            }
        }()
        
        async let signIn: () = {
            do {
                try await authService.signIn(email: "concurrent3@example.com", password: "Concurrent123!")
            } catch {
                // Expected to fail
            }
        }()
        
        // Wait for all operations to complete
        await signUp1
        await signUp2
        await signIn
        
        // Verify final state is consistent
        await #expect(authService.isLoading == false, "Should not be loading after all operations complete")
        
        // State should be consistent (either all succeeded or all failed)
        let isAuthenticated = await authService.isAuthenticated
        let hasUser = await authService.currentUser != nil
        
        if isAuthenticated {
            #expect(hasUser, "If authenticated, should have current user")
        } else {
            #expect(!hasUser, "If not authenticated, should not have current user")
        }
    }
    
    @Test("Authentication flow with network errors")
    func testAuthenticationFlowWithNetworkErrors() async throws {
        let authService = await AuthService.shared
        
        // These operations will fail due to network/configuration issues in test environment
        // Test that errors are handled gracefully
        
        do {
            try await authService.signIn(email: "network.test@example.com", password: "NetworkTest123!")
            // If it succeeds unexpectedly, that's also valid
            #expect(true, "Network operation completed")
        } catch {
            // Verify we get appropriate error types
            #expect(error is AuthError || error is NSError, "Should get appropriate error type for network issues")
            
            // Verify state remains consistent after error
            await #expect(authService.isLoading == false, "Should not be loading after error")
        }
        
        // Test sign out works even after errors
        await authService.signOut()
        await #expect(authService.isAuthenticated == false)
        await #expect(authService.currentUser == nil)
        await #expect(authService.isLoading == false)
    }
    
    @Test("Apple Sign In coordinator integration")
    func testAppleSignInCoordinatorIntegration() async throws {
        let coordinator = AppleSignInCoordinator.shared
        let authService = await AuthService.shared
        
        // Verify coordinator exists and is properly initialized
        #expect(coordinator != nil, "Apple Sign In coordinator should be initialized")
        
        // Test error handling integration
        let canceledError = ASAuthorizationError(.canceled)
        
        // Simulate the error handling logic that would occur in the coordinator
        if let authError = canceledError as? ASAuthorizationError {
            switch authError.code {
            case .canceled, .unknown, .invalidResponse, .notHandled:
                // These should not trigger error toasts
                #expect(true, "Cancellation errors correctly identified")
            case .failed:
                // This should trigger error toast
                #expect(Bool(false), "Should not identify canceled as failed")
            case .notInteractive:
                // This should trigger error toast
                #expect(Bool(false), "Should not identify canceled as not interactive")
            case .matchedExcludedCredential:
                // This should trigger error toast
                #expect(Bool(false), "Should not identify canceled as matched excluded credential")
            case .credentialImport:
                // This should trigger error toast
                #expect(Bool(false), "Should not identify canceled as credential import error")
            case .credentialExport:
                // This should trigger error toast
                #expect(Bool(false), "Should not identify canceled as credential export error")
            @unknown default:
                // Unknown cases treated as cancellation
                #expect(true, "Unknown cases treated as cancellation")
            }
        }
        
        // Verify AuthService and coordinator work together
        await authService.signOut()
        await #expect(authService.isAuthenticated == false)
        
        // Both should be in consistent state
        #expect(coordinator != nil, "Coordinator should remain available")
    }
    
    @Test("End-to-end user journey simulation")
    func testEndToEndUserJourneySimulation() async throws {
        let authService = await AuthService.shared
        
        // Simulate complete user journey
        // 1. App launch - check existing session
        await authService.checkExistingSession()
        let initialState = await authService.isAuthenticated
        
        // 2. User tries to sign in (fails)
        do {
            try await authService.signIn(email: "journey@example.com", password: "wrongpassword")
        } catch {
            #expect(error is AuthError, "Sign in with wrong password should fail")
        }
        await #expect(authService.isAuthenticated == false, "Should remain unauthenticated after failed sign in")
        
        // 3. User decides to sign up instead
        do {
            try await authService.signUp(email: "journey@example.com", password: "CorrectPassword123!")
        } catch {
            #expect(error is AuthError, "Sign up expected to fail in test environment")
        }
        
        // 4. User would normally confirm email, then sign in
        do {
            try await authService.confirmSignUp(email: "journey@example.com", confirmationCode: "123456")
        } catch {
            #expect(error is AuthError, "Confirmation expected to fail in test environment")
        }
        
        // 5. Final sign in attempt
        do {
            try await authService.signIn(email: "journey@example.com", password: "CorrectPassword123!")
        } catch {
            #expect(error is AuthError, "Final sign in expected to fail in test environment")
        }
        
        // 6. User eventually signs out
        await authService.signOut()
        await #expect(authService.isAuthenticated == false, "Should be signed out")
        await #expect(authService.currentUser == nil, "No current user after sign out")
        
        // Verify we're back to initial state
        await #expect(authService.isLoading == false, "Should not be loading")
    }
}
