import Foundation
import AWSCognitoIdentityProvider
import ClientRuntime
import AuthenticationServices
import GoogleSignIn

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: CognitoUser?
    @Published var isLoading = false
    
    private let cognitoClient: CognitoIdentityProviderClient
    private let config = CognitoConfig.shared
    
    private init() {
        // Configure AWS SDK
        do {
            self.cognitoClient = try CognitoIdentityProviderClient(region: config.region)
        } catch {
            fatalError("Failed to initialize Cognito client: \(error)")
        }
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let signUpInput = SignUpInput(
            clientId: config.clientId,
            password: password,
            userAttributes: [
                CognitoIdentityProviderClientTypes.AttributeType(name: "email", value: email)
            ],
            username: email
        )
        
        do {
            let response = try await cognitoClient.signUp(input: signUpInput)
            print("Sign up successful: \(response)")
        } catch {
            print("Sign up error: \(error)")
            throw AuthError.signUpFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Confirm Sign Up
    func confirmSignUp(email: String, confirmationCode: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let confirmInput = ConfirmSignUpInput(
            clientId: config.clientId,
            confirmationCode: confirmationCode,
            username: email
        )
        
        do {
            let response = try await cognitoClient.confirmSignUp(input: confirmInput)
            print("Confirmation successful: \(response)")
        } catch {
            print("Confirmation error: \(error)")
            throw AuthError.confirmationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let authInput = InitiateAuthInput(
            authFlow: .userPasswordAuth,
            authParameters: [
                "USERNAME": email,
                "PASSWORD": password
            ],
            clientId: config.clientId
        )
        
        do {
            let response = try await cognitoClient.initiateAuth(input: authInput)
            
            if let accessToken = response.authenticationResult?.accessToken,
               let idToken = response.authenticationResult?.idToken,
               let refreshToken = response.authenticationResult?.refreshToken {
                
                // Store tokens securely
                try storeTokens(
                    accessToken: accessToken,
                    idToken: idToken,
                    refreshToken: refreshToken
                )
                
                // Create user object
                self.currentUser = CognitoUser(
                    email: email,
                    accessToken: accessToken,
                    idToken: idToken,
                    refreshToken: refreshToken
                )
                
                self.isAuthenticated = true
                
            } else if response.challengeName != nil {
                // Handle challenges (like NEW_PASSWORD_REQUIRED, MFA, etc.)
                throw AuthError.challengeRequired(response.challengeName?.rawValue ?? "Unknown challenge")
            }
            
        } catch {
            print("Sign in error: \(error)")
            throw AuthError.signInFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Sign Out
    func signOut() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if let accessToken = currentUser?.accessToken {
                let signOutInput = GlobalSignOutInput(accessToken: accessToken)
                _ = try await cognitoClient.globalSignOut(input: signOutInput)
            }
        } catch {
            print("Sign out error: \(error)")
        }
        
        // Clear local state regardless of API call result
        clearStoredTokens()
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    // MARK: - Forgot Password
    func forgotPassword(email: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let forgotPasswordInput = ForgotPasswordInput(
            clientId: config.clientId,
            username: email
        )
        
        do {
            let response = try await cognitoClient.forgotPassword(input: forgotPasswordInput)
            print("Forgot password initiated: \(response)")
        } catch {
            print("Forgot password error: \(error)")
            throw AuthError.forgotPasswordFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Confirm Forgot Password
    func confirmForgotPassword(email: String, confirmationCode: String, newPassword: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let confirmInput = ConfirmForgotPasswordInput(
            clientId: config.clientId,
            confirmationCode: confirmationCode,
            password: newPassword,
            username: email
        )
        
        do {
            let response = try await cognitoClient.confirmForgotPassword(input: confirmInput)
            print("Password reset successful: \(response)")
        } catch {
            print("Password reset error: \(error)")
            throw AuthError.passwordResetFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Refresh Token
    func refreshSession() async throws {
        guard let currentUser = currentUser else {
            throw AuthError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let refreshInput = InitiateAuthInput(
            authFlow: .refreshTokenAuth,
            authParameters: [
                "REFRESH_TOKEN": currentUser.refreshToken
            ],
            clientId: config.clientId
        )
        
        do {
            let response = try await cognitoClient.initiateAuth(input: refreshInput)
            
            if let accessToken = response.authenticationResult?.accessToken,
               let idToken = response.authenticationResult?.idToken {
                
                // Update tokens
                let updatedUser = CognitoUser(
                    email: currentUser.email,
                    accessToken: accessToken,
                    idToken: idToken,
                    refreshToken: currentUser.refreshToken // Refresh token usually doesn't change
                )
                
                try storeTokens(
                    accessToken: accessToken,
                    idToken: idToken,
                    refreshToken: currentUser.refreshToken
                )
                
                self.currentUser = updatedUser
            }
            
        } catch {
            print("Token refresh error: \(error)")
            // If refresh fails, sign out the user
            await signOut()
            throw AuthError.tokenRefreshFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Check Existing Session
    func checkExistingSession() async {
        if let storedTokens = getStoredTokens() {
            // Validate tokens by making a test request
            let testInput = GetUserInput(accessToken: storedTokens.accessToken)
            
            do {
                let response = try await cognitoClient.getUser(input: testInput)
                
                // Create user from stored data
                if let email = response.userAttributes?.first(where: { $0.name == "email" })?.value {
                    self.currentUser = CognitoUser(
                        email: email,
                        accessToken: storedTokens.accessToken,
                        idToken: storedTokens.idToken,
                        refreshToken: storedTokens.refreshToken
                    )
                    self.isAuthenticated = true
                }
            } catch {
                // Tokens are invalid, try to refresh
                if let storedTokens = getStoredTokens() {
                    self.currentUser = CognitoUser(
                        email: "", // Will be filled after refresh
                        accessToken: storedTokens.accessToken,
                        idToken: storedTokens.idToken,
                        refreshToken: storedTokens.refreshToken
                    )
                    
                    do {
                        try await refreshSession()
                    } catch {
                        // Refresh failed, clear everything
                        clearStoredTokens()
                    }
                }
            }
        }
    }
    
    // MARK: - Apple Sign In
    func signInWithApple(idToken: String, authorizationCode: String, fullName: PersonNameComponents?) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Create identity token for Cognito federated authentication
        let authInput = InitiateAuthInput(
            authFlow: .userPasswordAuth,
            authParameters: [
                "USERNAME": "apple_\(UUID().uuidString)",
                "PASSWORD": authorizationCode
            ],
            clientId: config.clientId
        )
        
        do {
            // For federated authentication, we would typically use AdminInitiateAuth
            // with APPLE as the identity provider. For now, we'll create a user with Apple credentials
            let email = extractEmailFromAppleIdToken(idToken) ?? "apple_user@example.com"
            
            // Try to sign in first (user might already exist)
            do {
                try await signIn(email: email, password: authorizationCode)
            } catch {
                // If sign in fails, try to create account
                try await signUpWithApple(email: email, idToken: idToken, fullName: fullName)
            }
            
        } catch {
            print("Apple Sign In error: \(error)")
            throw AuthError.signInFailed("Apple Sign In failed: \(error.localizedDescription)")
        }
    }
    
    private func signUpWithApple(email: String, idToken: String, fullName: PersonNameComponents?) async throws {
        let signUpInput = SignUpInput(
            clientId: config.clientId,
            password: UUID().uuidString, // Generate random password for Apple users
            userAttributes: [
                CognitoIdentityProviderClientTypes.AttributeType(name: "email", value: email),
                CognitoIdentityProviderClientTypes.AttributeType(name: "given_name", value: fullName?.givenName ?? ""),
                CognitoIdentityProviderClientTypes.AttributeType(name: "family_name", value: fullName?.familyName ?? "")
            ],
            username: email
        )
        
        let response = try await cognitoClient.signUp(input: signUpInput)
        print("Apple user sign up successful: \(response)")
        
        // Auto-confirm the user since Apple has already verified the email
        let confirmInput = AdminConfirmSignUpInput(
            userPoolId: config.userPoolId,
            username: email
        )
        
        // Note: AdminConfirmSignUp requires admin privileges
        // In production, you'd handle this server-side
        print("Would auto-confirm Apple user: \(email)")
    }
    
    private func extractEmailFromAppleIdToken(_ idToken: String) -> String? {
        // In a real implementation, you would decode the JWT token
        // For now, we'll return nil and handle it in the calling function
        return nil
    }
    
    // MARK: - Google Sign In
    func signInWithGoogle(idToken: String, accessToken: String, email: String, fullName: String?) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Try to sign in first (user might already exist)
            do {
                try await signIn(email: email, password: accessToken)
            } catch {
                // If sign in fails, try to create account
                try await signUpWithGoogle(email: email, idToken: idToken, fullName: fullName)
            }
            
        } catch {
            print("Google Sign In error: \(error)")
            throw AuthError.signInFailed("Google Sign In failed: \(error.localizedDescription)")
        }
    }
    
    private func signUpWithGoogle(email: String, idToken: String, fullName: String?) async throws {
        let names = fullName?.components(separatedBy: " ") ?? []
        let givenName = names.first ?? ""
        let familyName = names.count > 1 ? names.dropFirst().joined(separator: " ") : ""
        
        let signUpInput = SignUpInput(
            clientId: config.clientId,
            password: UUID().uuidString, // Generate random password for Google users
            userAttributes: [
                CognitoIdentityProviderClientTypes.AttributeType(name: "email", value: email),
                CognitoIdentityProviderClientTypes.AttributeType(name: "given_name", value: givenName),
                CognitoIdentityProviderClientTypes.AttributeType(name: "family_name", value: familyName)
            ],
            username: email
        )
        
        let response = try await cognitoClient.signUp(input: signUpInput)
        print("Google user sign up successful: \(response)")
        
        // Auto-confirm the user since Google has already verified the email
        print("Would auto-confirm Google user: \(email)")
    }
    
    // MARK: - Token Storage (using Keychain would be more secure)
    private func storeTokens(accessToken: String, idToken: String, refreshToken: String) throws {
        let tokens = StoredTokens(
            accessToken: accessToken,
            idToken: idToken,
            refreshToken: refreshToken
        )
        
        let data = try JSONEncoder().encode(tokens)
        UserDefaults.standard.set(data, forKey: "cognito_tokens")
    }
    
    private func getStoredTokens() -> StoredTokens? {
        guard let data = UserDefaults.standard.data(forKey: "cognito_tokens") else {
            return nil
        }
        
        return try? JSONDecoder().decode(StoredTokens.self, from: data)
    }
    
    private func clearStoredTokens() {
        UserDefaults.standard.removeObject(forKey: "cognito_tokens")
    }
}

// MARK: - Models
struct CognitoUser {
    let email: String
    let accessToken: String
    let idToken: String
    let refreshToken: String
}

struct StoredTokens: Codable {
    let accessToken: String
    let idToken: String
    let refreshToken: String
}

// MARK: - Errors
enum AuthError: LocalizedError {
    case signUpFailed(String)
    case confirmationFailed(String)
    case signInFailed(String)
    case challengeRequired(String)
    case forgotPasswordFailed(String)
    case passwordResetFailed(String)
    case tokenRefreshFailed(String)
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .signUpFailed(let message):
            return "Sign up failed: \(message)"
        case .confirmationFailed(let message):
            return "Confirmation failed: \(message)"
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .challengeRequired(let challenge):
            return "Challenge required: \(challenge)"
        case .forgotPasswordFailed(let message):
            return "Password reset request failed: \(message)"
        case .passwordResetFailed(let message):
            return "Password reset failed: \(message)"
        case .tokenRefreshFailed(let message):
            return "Token refresh failed: \(message)"
        case .notAuthenticated:
            return "User is not authenticated"
        }
    }
}
