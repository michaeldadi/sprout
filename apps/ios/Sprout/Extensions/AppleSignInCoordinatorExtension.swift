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
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email
            
            print("Apple Sign In successful!")
            print("User ID: \(userIdentifier)")
            print("Full Name: \(fullName?.formatted() ?? "Not provided")")
            print("Email: \(email ?? "Not provided")")
            
            // Handle successful sign-in here
            ToastManager.shared.showSuccess("Apple Sign In successful!")
            
            // TODO: Send credentials to your backend API
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
