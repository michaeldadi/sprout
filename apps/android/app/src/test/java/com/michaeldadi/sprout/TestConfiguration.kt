package com.michaeldadi.sprout

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.rules.TestRule
import org.junit.runner.Description
import org.junit.runners.model.Statement

/**
 * Test configuration and utilities for Android tests
 */
object TestConfiguration {
    
    /**
     * Test rule for setting up coroutine test environment
     */
    @OptIn(ExperimentalCoroutinesApi::class)
    class CoroutineTestRule : TestRule {
        
        private val testDispatcher = StandardTestDispatcher()
        val testScope = TestScope(testDispatcher)
        
        override fun apply(base: Statement, description: Description): Statement {
            return object : Statement() {
                override fun evaluate() {
                    Dispatchers.setMain(testDispatcher)
                    try {
                        base.evaluate()
                    } finally {
                        Dispatchers.resetMain()
                    }
                }
            }
        }
    }
    
    /**
     * Configuration constants for tests
     */
    object Constants {
        const val TEST_EMAIL = "test@example.com"
        const val TEST_PASSWORD = "TestPassword123!"
        const val TEST_FIRST_NAME = "Test"
        const val TEST_LAST_NAME = "User"
        const val TEST_CONFIRMATION_CODE = "123456"
        
        const val INVALID_EMAIL = "invalid-email"
        const val WEAK_PASSWORD = "123"
        const val EMPTY_STRING = ""
        
        const val MOCK_ACCESS_TOKEN = "mock-access-token"
        const val MOCK_ID_TOKEN = "mock-id-token"
        const val MOCK_REFRESH_TOKEN = "mock-refresh-token"
        
        const val APPLE_ID_TOKEN_VALID = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwiYXVkIjoiY29tLmV4YW1wbGUuYXBwIiwiZXhwIjoxNjAwMDAwMDAwLCJpYXQiOjE2MDAwMDAwMDAsInN1YiI6IjAwMDAwMC4xMjM0NTY3ODkwYWJjZGVmIiwiZW1haWwiOiJ0ZXN0QGV4YW1wbGUuY29tIn0.signature"
        const val APPLE_AUTHORIZATION_CODE = "c12345abcdef.0.123456789"
        
        const val GOOGLE_ID_TOKEN = "mock-google-id-token"
        
        const val DEFAULT_TIMEOUT_MS = 5000L
    }
    
    /**
     * Error messages for testing
     */
    object ErrorMessages {
        const val NETWORK_ERROR = "Network error occurred"
        const val INVALID_CREDENTIALS = "Invalid credentials"
        const val USER_NOT_FOUND = "User not found"
        const val EMAIL_ALREADY_EXISTS = "Email already exists"
        const val INVALID_CONFIRMATION_CODE = "Invalid confirmation code"
        const val PASSWORD_TOO_WEAK = "Password does not meet requirements"
        const val APPLE_SIGN_IN_FAILED = "Apple Sign In failed"
        const val GOOGLE_SIGN_IN_FAILED = "Google Sign In failed"
    }
}