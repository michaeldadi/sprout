import Foundation
import AWSCognitoIdentityProvider
import ClientRuntime
import AuthenticationServices
import GoogleSignIn
import Security

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: CognitoUser?
    @Published var isLoading = false
    
    private let cognitoClient: CognitoIdentityProviderClient
    private let config = CognitoConfig.shared
    private let tokenAccount = "com.michaeldadi.Sprout.cognitoTokens"
    private let tokenService = "com.michaeldadi.Sprout.auth"
    
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

    func resendConfirmationCode(email: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await cognitoClient.resendConfirmationCode(input: ResendConfirmationCodeInput(
                clientId: config.clientId,
                username: email
            ))
        } catch {
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
                let userInfo = try decodeIdToken(idToken)
                guard let userId = userInfo.sub, !userId.isEmpty else {
                    throw AuthError.invalidSession
                }

                // Store tokens securely
                try storeTokens(
                    accessToken: accessToken,
                    idToken: idToken,
                    refreshToken: refreshToken
                )
                
                // Create user object
                self.currentUser = CognitoUser(
                    id: userId,
                    email: email,
                    username: userInfo.username ?? email,
                    fullName: userInfo.name,
                    accessToken: accessToken,
                    idToken: idToken,
                    refreshToken: refreshToken
                )
                
                self.isAuthenticated = true
                
            } else if response.challengeName != nil {
                // Handle challenges (like NEW_PASSWORD_REQUIRED, MFA, etc.)
                throw AuthError.challengeRequired(response.challengeName?.rawValue ?? "Unknown challenge")
            } else {
                throw AuthError.invalidSession
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
                
              // Decode the new ID token to get updated user info
              let userInfo = try decodeIdToken(idToken)
              guard let userId = userInfo.sub, !userId.isEmpty else {
                  throw AuthError.invalidSession
              }

              // Update user object with new tokens but preserve user info
              let updatedUser = CognitoUser(
                  id: userId,
                  email: userInfo.email ?? currentUser.email,  // Use new email or keep existing
                  username: userInfo.username ?? currentUser.username,  // Use new username or keep existing
                  fullName: userInfo.name ?? currentUser.fullName,  // Use new name or keep existing
                  accessToken: accessToken,
                  idToken: idToken,
                  refreshToken: currentUser.refreshToken  // Refresh token usually doesn't change
              )

              try storeTokens(
                  accessToken: accessToken,
                  idToken: idToken,
                  refreshToken: currentUser.refreshToken
              )

              self.currentUser = updatedUser
            } else {
                throw AuthError.invalidSession
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
                
                // Extract user attributes
                let email = response.userAttributes?.first(where: { $0.name == "email" })?.value ?? ""
                guard let sub = response.userAttributes?.first(where: { $0.name == "sub" })?.value,
                      !sub.isEmpty else {
                    throw AuthError.invalidSession
                }
                let givenName = response.userAttributes?.first(where: { $0.name == "given_name" })?.value
                let familyName = response.userAttributes?.first(where: { $0.name == "family_name" })?.value
                let fullName = [givenName, familyName].compactMap { $0 }.joined(separator: " ")

                self.currentUser = CognitoUser(
                    id: sub,
                    email: email,
                    username: response.username ?? email,
                    fullName: fullName.isEmpty ? nil : fullName,
                    accessToken: storedTokens.accessToken,
                    idToken: storedTokens.idToken,
                    refreshToken: storedTokens.refreshToken
                )
                self.isAuthenticated = true
            } catch {
                // Tokens are invalid, try to refresh
                if let storedTokens = getStoredTokens() {
                    self.currentUser = CognitoUser(
                        id: "",
                        email: "", // Will be filled after refresh
                        username: "",
                        fullName: "",
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
    
    // Social identity exchange needs a configured, server-verified provider flow.
    // Never use a provider access token as a Cognito password.
    func signInWithApple(idToken: String, authorizationCode: String, fullName: PersonNameComponents?) async throws {
        throw AuthError.signInFailed("Apple sign-in is not available yet")
    }

    func signInWithGoogle(idToken: String, accessToken: String, email: String, fullName: String?) async throws {
        throw AuthError.signInFailed("Google sign-in is not available yet")
    }

    // MARK: - Token Storage
    private func storeTokens(accessToken: String, idToken: String, refreshToken: String) throws {
        let tokens = StoredTokens(
            accessToken: accessToken,
            idToken: idToken,
            refreshToken: refreshToken
        )
        
        let data = try JSONEncoder().encode(tokens)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: tokenAccount
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem.merge(attributes) { _, newValue in newValue }
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw AuthError.tokenStorageFailed(addStatus) }
        } else if status != errSecSuccess {
            throw AuthError.tokenStorageFailed(status)
        }
        UserDefaults.standard.removeObject(forKey: "cognito_tokens")
    }
    
    private func getStoredTokens() -> StoredTokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data {
            return try? JSONDecoder().decode(StoredTokens.self, from: data)
        }

        // Migrate sessions written by earlier builds without discarding user data.
        guard let legacyData = UserDefaults.standard.data(forKey: "cognito_tokens"),
              let legacyTokens = try? JSONDecoder().decode(StoredTokens.self, from: legacyData) else {
            return nil
        }
        do {
            try storeTokens(
                accessToken: legacyTokens.accessToken,
                idToken: legacyTokens.idToken,
                refreshToken: legacyTokens.refreshToken
            )
            return legacyTokens
        } catch {
            return nil
        }
    }
    
    private func clearStoredTokens() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: tokenAccount
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: "cognito_tokens")
    }

    private func decodeIdToken(_ token: String) throws -> IdTokenClaims {
        // Split the JWT token
        let segments = token.components(separatedBy: ".")
        guard segments.count == 3 else {
            throw AuthError.tokenRefreshFailed("Invalid token format")
        }

        // Decode the payload (second segment)
        var base64 = segments[1]

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        guard let data = Data(base64Encoded: base64) else {
            throw AuthError.tokenRefreshFailed("Failed to decode token")
        }

        return try JSONDecoder().decode(IdTokenClaims.self, from: data)
    }
}

// MARK: - Models
struct CognitoUser {
    let id: String
    let email: String
    let username: String
    let fullName: String?
    let accessToken: String
    let idToken: String
    let refreshToken: String

    // Computed property for Stream Chat compatibility
    var displayName: String {
      return fullName ?? username
    }
}

struct StoredTokens: Codable {
    let accessToken: String
    let idToken: String
    let refreshToken: String
}

// MARK: - Errors
enum AuthError: LocalizedError {
    case invalidSession
    case tokenStorageFailed(OSStatus)
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
        case .invalidSession:
            return "The sign-in response did not include a valid account. Please try again."
        case .tokenStorageFailed:
            return "Could not securely save your session. Please try again."
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

struct IdTokenClaims: Decodable {
    let sub: String?  // User ID
    let email: String?
    let username: String?
    let name: String?
    let given_name: String?
    let family_name: String?

    enum CodingKeys: String, CodingKey {
        case sub, email, username, name
        case given_name = "given_name"
        case family_name = "family_name"
    }
}

// Response from your backend API for Apple Sign In
struct AppleSignInResponse {
    let accessToken: String?
    let idToken: String?
    let refreshToken: String?
}
