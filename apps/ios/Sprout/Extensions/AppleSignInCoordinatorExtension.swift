//
//  AppleSignInCoordinatorExtension.swift
//  Sprout
//
//  Created by Michael Dadi on 8/19/25.
//

import AuthenticationServices

class AppleSignInCoordinator: NSObject, ObservableObject {
    static let shared = AppleSignInCoordinator()
    
    private override init() {
        super.init()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("Failed to get Apple ID credential")
            ToastManager.shared.showError("Apple Sign In failed")
            return
        }
        
        // Extract the authorization code and identity token
        guard let authorizationCodeData = appleIDCredential.authorizationCode,
              let authorizationCode = String(data: authorizationCodeData, encoding: .utf8),
              let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            print("Failed to extract Apple credentials")
            ToastManager.shared.showError("Apple Sign In failed")
            return
        }
        
        let userIdentifier = appleIDCredential.user
        let fullName = appleIDCredential.fullName
        let email = appleIDCredential.email
        
        print("Apple Sign In successful!")
        print("User ID: \(userIdentifier)")
        print("Full Name: \(fullName?.formatted() ?? "Not provided")")
        print("Email: \(email ?? "Not provided")")
        
        // Authenticate with Cognito
        Task {
            do {
                try await AuthService.shared.signInWithApple(
                    idToken: identityToken,
                    authorizationCode: authorizationCode,
                    fullName: fullName
                )
                
                await MainActor.run {
                    ToastManager.shared.showSuccess("Apple Sign In successful!")
                }
            } catch {
                await MainActor.run {
                    print("Apple Sign In Cognito error: \(error.localizedDescription)")
                    
                    // Check if this is a cancellation error (ASAuthorizationError 1000)
                    if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                        print("Apple Sign In was cancelled by user - not showing error toast")
                        return
                    }
                    
                    // Check if the error description contains cancellation indicators
                    let errorString = error.localizedDescription.lowercased()
                    if errorString.contains("cancel") || errorString.contains("1000") {
                        print("Apple Sign In appears to be cancelled - not showing error toast")
                        return
                    }
                    
                    ToastManager.shared.showError("Apple Sign In failed")
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle user cancel
        if let error = error as? ASAuthorizationError, error.code == .canceled {
            print("Apple Sign In canceled by user")
            return
        }
      
        print("Apple Sign In failed: \(error.localizedDescription)")
        ToastManager.shared.showError("Apple Sign In failed")
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
