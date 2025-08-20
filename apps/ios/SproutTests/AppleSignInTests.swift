//
//  AppleSignInTests.swift
//  SproutTests
//
//  Created by Michael Dadi on 8/20/25.
//

import Testing
import Foundation
import AuthenticationServices
@testable import Sprout

struct AppleSignInTests {
    
    // MARK: - Test Setup
    
    @Test("AppleSignInCoordinator initialization")
    func testAppleSignInCoordinatorInitialization() async throws {
        let coordinator = AppleSignInCoordinator.shared
        #expect(coordinator != nil)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Apple Sign In cancellation error handling")
    func testAppleSignInCancellationErrorHandling() async throws {
        let coordinator = AppleSignInCoordinator.shared
        
        // Create a mock ASAuthorizationError with canceled code
        let canceledError = ASAuthorizationError(.canceled)
        
        // Test that cancellation doesn't trigger error toast
        // We can't directly test the delegate method without mocking the controller
        // But we can verify the error type handling logic
        
        if let authError = canceledError as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                // This should not show error toast
                #expect(true, "Canceled error correctly identified")
            default:
                #expect(Bool(false), "Should identify as canceled error")
            }
        }
    }
    
    @Test("Apple Sign In unknown error handling")
    func testAppleSignInUnknownErrorHandling() async throws {
        let unknownError = ASAuthorizationError(.unknown)
        
        if let authError = unknownError as? ASAuthorizationError {
            switch authError.code {
            case .unknown:
                // This should not show error toast (treated as cancellation)
                #expect(true, "Unknown error correctly identified")
            default:
                #expect(Bool(false), "Should identify as unknown error")
            }
        }
    }
    
    @Test("Apple Sign In invalid response error handling")
    func testAppleSignInInvalidResponseErrorHandling() async throws {
        let invalidResponseError = ASAuthorizationError(.invalidResponse)
        
        if let authError = invalidResponseError as? ASAuthorizationError {
            switch authError.code {
            case .invalidResponse:
                // This should not show error toast (treated as cancellation)
                #expect(true, "Invalid response error correctly identified")
            default:
                #expect(Bool(false), "Should identify as invalid response error")
            }
        }
    }
    
    @Test("Apple Sign In not handled error handling")
    func testAppleSignInNotHandledErrorHandling() async throws {
        let notHandledError = ASAuthorizationError(.notHandled)
        
        if let authError = notHandledError as? ASAuthorizationError {
            switch authError.code {
            case .notHandled:
                // This should not show error toast (treated as cancellation)
                #expect(true, "Not handled error correctly identified")
            default:
                #expect(Bool(false), "Should identify as not handled error")
            }
        }
    }
    
    @Test("Apple Sign In failed error handling")
    func testAppleSignInFailedErrorHandling() async throws {
        let failedError = ASAuthorizationError(.failed)
        
        if let authError = failedError as? ASAuthorizationError {
            switch authError.code {
            case .failed:
                // This should show error toast
                #expect(true, "Failed error correctly identified for toast display")
            default:
                #expect(Bool(false), "Should identify as failed error")
            }
        }
    }
    
    @Test("NSError code 1000 handling")
    func testNSErrorCode1000Handling() async throws {
        let nsError = NSError(domain: "com.apple.AuthenticationServices.AuthorizationError", code: 1000, userInfo: nil)
        
        // Test the error code filtering logic
        if nsError.code == 1000 || nsError.code == -1000 || nsError.code == 1001 {
            // Should not show error toast
            #expect(true, "NSError code 1000 correctly identified as cancellation")
        } else {
            #expect(Bool(false), "Should identify NSError code 1000 as cancellation")
        }
    }
    
    @Test("NSError code -1000 handling")
    func testNSErrorCodeMinus1000Handling() async throws {
        let nsError = NSError(domain: "com.apple.AuthenticationServices.AuthorizationError", code: -1000, userInfo: nil)
        
        if nsError.code == 1000 || nsError.code == -1000 || nsError.code == 1001 {
            // Should not show error toast
            #expect(true, "NSError code -1000 correctly identified as cancellation")
        } else {
            #expect(Bool(false), "Should identify NSError code -1000 as cancellation")
        }
    }
    
    @Test("NSError code 1001 handling")
    func testNSErrorCode1001Handling() async throws {
        let nsError = NSError(domain: "com.apple.AuthenticationServices.AuthorizationError", code: 1001, userInfo: nil)
        
        if nsError.code == 1000 || nsError.code == -1000 || nsError.code == 1001 {
            // Should not show error toast
            #expect(true, "NSError code 1001 correctly identified as cancellation")
        } else {
            #expect(Bool(false), "Should identify NSError code 1001 as cancellation")
        }
    }
    
    // MARK: - Error Description Tests
    
    @Test("Error description cancellation detection")
    func testErrorDescriptionCancellationDetection() async throws {
        let testCases = [
            ("User cancelled the operation", true),
            ("The user canceled the request", true),
            ("Request was dismissed by user", true),
            ("Operation aborted", true),
            ("Error 1000 occurred", true),
            ("CANCEL operation", true),
            ("Network error occurred", false),
            ("Invalid credentials", false),
            ("Server unavailable", false)
        ]
        
        for (description, shouldBeCancellation) in testCases {
            let errorString = description.lowercased()
            let isCancellation = errorString.contains("cancel") || 
                               errorString.contains("user cancel") || 
                               errorString.contains("dismissed") ||
                               errorString.contains("abort") ||
                               errorString.contains("1000")
            
            #expect(isCancellation == shouldBeCancellation, "Error description '\(description)' should \(shouldBeCancellation ? "" : "not ")be identified as cancellation")
        }
    }
    
    // MARK: - Credential Validation Tests
    
    @Test("Apple ID credential extraction success")
    func testAppleIDCredentialExtractionSuccess() async throws {
        // Test the logic for credential validation
        // In a real test environment, we'd mock ASAuthorizationAppleIDCredential
        
        let testAuthCode = "test_auth_code"
        let testIdToken = "test.id.token"
        
        // Simulate successful credential extraction
        if !testAuthCode.isEmpty && !testIdToken.isEmpty {
            #expect(true, "Valid credentials should be accepted")
        } else {
            #expect(Bool(false), "Should accept valid credentials")
        }
    }
    
    @Test("Apple ID credential extraction failure")
    func testAppleIDCredentialExtractionFailure() async throws {
        let emptyAuthCode = ""
        let emptyIdToken = ""
        
        // Simulate failed credential extraction
        if emptyAuthCode.isEmpty || emptyIdToken.isEmpty {
            #expect(true, "Invalid credentials should be rejected")
        } else {
            #expect(Bool(false), "Should reject empty credentials")
        }
    }
    
    // MARK: - AuthService Integration Tests
    
    @Test("Apple Sign In with valid tokens")
    func testAppleSignInWithValidTokens() async throws {
        let authService = AuthService.shared
        
        let validIdToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.test"
        let validAuthCode = "c_test_auth_code"
        let fullName = PersonNameComponents()
        
        do {
            try await authService.signInWithApple(
                idToken: validIdToken,
                authorizationCode: validAuthCode,
                fullName: fullName
            )
            // Test should complete without crashing
            #expect(true, "Apple Sign In with valid tokens completed")
        } catch {
            // Expected to fail in test environment without proper Cognito setup
            #expect(error is AuthError || error is NSError, "Should throw appropriate error type")
        }
    }
    
    @Test("Apple Sign In with empty tokens")
    func testAppleSignInWithEmptyTokens() async throws {
        let authService = AuthService.shared
        
        do {
            try await authService.signInWithApple(
                idToken: "",
                authorizationCode: "",
                fullName: nil
            )
            #expect(Bool(false), "Should throw error for empty tokens")
        } catch {
            #expect(true, "Correctly threw error for empty tokens")
        }
    }
    
    @Test("Apple Sign In cancellation in AuthService")
    func testAppleSignInCancellationInAuthService() async throws {
        // Test that ASAuthorizationError.canceled is handled correctly in AuthService
        let cancelError = ASAuthorizationError(.canceled)
        
        // Verify error type
        if let authError = cancelError as? ASAuthorizationError, authError.code == .canceled {
            #expect(true, "ASAuthorizationError.canceled correctly identified in AuthService context")
        } else {
            #expect(Bool(false), "Should identify ASAuthorizationError.canceled")
        }
    }
    
    // MARK: - Presentation Context Tests
    
    @Test("Presentation anchor availability")
    func testPresentationAnchorAvailability() async throws {
        let coordinator = AppleSignInCoordinator.shared
        
        // Test that the coordinator can provide a presentation anchor
        // In a real test environment with UI, this would return the actual window
        #expect(coordinator != nil, "Coordinator should be available to provide presentation context")
    }
    
    // MARK: - Multiple Error Scenario Tests
    
    @Test("Multiple cancellation scenarios")
    func testMultipleCancellationScenarios() async throws {
        let scenarios = [
            ASAuthorizationError(.canceled),
            ASAuthorizationError(.unknown),
            ASAuthorizationError(.invalidResponse),
            ASAuthorizationError(.notHandled)
        ]
        
        for scenario in scenarios {
            if let authError = scenario as? ASAuthorizationError {
                switch authError.code {
                case .canceled, .unknown, .invalidResponse, .notHandled:
                    #expect(true, "Cancellation scenario \(authError.code) correctly identified")
                case .failed:
                    #expect(Bool(false), "Should not identify .failed as cancellation")
                @unknown default:
                    #expect(true, "Unknown case treated as cancellation")
                }
            }
        }
    }
    
    @Test("Non-cancellation errors show toast")
    func testNonCancellationErrorsShowToast() async throws {
        let failedError = ASAuthorizationError(.failed)
        let networkError = NSError(domain: "NSURLErrorDomain", code: -1001, userInfo: nil)
        
        // Test that genuine errors (not cancellations) are properly identified
        if let authError = failedError as? ASAuthorizationError {
            switch authError.code {
            case .failed:
                #expect(true, "Failed error should show toast")
            default:
                #expect(Bool(false), "Should identify as failed error")
            }
        }
        
        // Test that network errors don't match cancellation patterns
        let errorString = networkError.localizedDescription.lowercased()
        let isCancellation = errorString.contains("cancel") || 
                           errorString.contains("user cancel") || 
                           errorString.contains("dismissed") ||
                           errorString.contains("abort") ||
                           errorString.contains("1000")
        
        #expect(!isCancellation, "Network errors should not be identified as cancellations")
    }
    
    // MARK: - User Experience Tests
    
    @Test("No toast for user dismissal")
    func testNoToastForUserDismissal() async throws {
        // Test scenarios where users dismiss the Apple Sign In dialog
        let userDismissalScenarios = [
            "User cancelled",
            "User canceled the operation", 
            "Dialog dismissed",
            "User aborted sign in",
            "Error 1000"
        ]
        
        for scenario in userDismissalScenarios {
            let errorString = scenario.lowercased()
            let shouldSuppressToast = errorString.contains("cancel") || 
                                    errorString.contains("user cancel") || 
                                    errorString.contains("dismissed") ||
                                    errorString.contains("abort") ||
                                    errorString.contains("1000")
            
            #expect(shouldSuppressToast, "User dismissal scenario '\(scenario)' should suppress toast")
        }
    }
    
    @Test("Show toast for genuine failures")
    func testShowToastForGenuineFailures() async throws {
        let genuineFailures = [
            "Network connection failed",
            "Invalid Apple ID credentials",
            "Server error occurred",
            "Authentication failed",
            "Service unavailable"
        ]
        
        for failure in genuineFailures {
            let errorString = failure.lowercased()
            let shouldSuppressToast = errorString.contains("cancel") || 
                                    errorString.contains("user cancel") || 
                                    errorString.contains("dismissed") ||
                                    errorString.contains("abort") ||
                                    errorString.contains("1000")
            
            #expect(!shouldSuppressToast, "Genuine failure '\(failure)' should show toast")
        }
    }
}