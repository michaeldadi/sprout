//
//  AppleSignInCoordinatorExtension.swift
//  Sprout
//
//  Created by Michael Dadi on 8/19/25.
//

import AuthenticationServices
import CryptoKit

class AppleSignInCoordinator: NSObject, ObservableObject {
    static let shared = AppleSignInCoordinator()
    private var currentNonce: String?
    private var activeController: ASAuthorizationController?
    
    private override init() {
        super.init()
    }

    @MainActor
    func startSignIn() {
        guard currentNonce == nil else { return }
        let nonce = UUID().uuidString
        let hash = SHA256.hash(data: Data(nonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hash
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        currentNonce = nonce
        activeController = controller
        controller.performRequests()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard controller === activeController, let nonce = currentNonce else {
            ToastManager.shared.showError("Apple Sign In failed")
            return
        }
        currentNonce = nil
        activeController = nil
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("Failed to get Apple ID credential")
            ToastManager.shared.showError("Apple Sign In failed")
            return
        }
        
        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            print("Failed to extract Apple credentials")
            ToastManager.shared.showError("Apple Sign In failed")
            return
        }
        
        let fullName = appleIDCredential.fullName
        
        Task {
            do {
                let name = [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                try await AppwriteNativeSession.shared.signInWithApple(
                    idToken: identityToken,
                    nonce: nonce,
                    name: name.isEmpty ? nil : name
                )
                
                await MainActor.run {
                    ToastManager.shared.showSuccess("Apple Sign In successful!")
                }
            } catch {
                await MainActor.run {
                    print("Apple Sign In error: \(error.localizedDescription)")
                    
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
        currentNonce = nil
        activeController = nil
        print("Apple Sign In error occurred: \(error)")
        print("Error type: \(type(of: error))")
        print("Error code: \((error as NSError).code)")
        print("Error description: \(error.localizedDescription)")
        
        // Handle user cancel - check for multiple cancellation scenarios
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                print("Apple Sign In canceled by user (ASAuthorizationError.canceled)")
                return
            case .unknown:
                print("Apple Sign In unknown error - might be cancellation")
                return
            case .invalidResponse:
                print("Apple Sign In invalid response - might be cancellation")
                return
            case .notHandled:
                print("Apple Sign In not handled - might be cancellation")
                return
            case .failed:
                print("Apple Sign In failed - showing error")
            case .notInteractive:
                print("Apple Sign In not interactive - might be cancellation")
                return
            case .matchedExcludedCredential:
                print("Apple Sign In matched excluded credential - might be cancellation")
                return
            case .credentialImport:
                print("Apple Sign In credential import - might be cancellation")
                return
            case .credentialExport:
                print("Apple Sign In credential export - might be cancellation")
                return
            @unknown default:
                print("Apple Sign In unknown case - might be cancellation")
                return
            }
        }
        
        // Check NSError codes that might indicate cancellation
        let nsError = error as NSError
        if nsError.code == 1000 || nsError.code == -1000 || nsError.code == 1001 {
            print("Apple Sign In canceled via NSError code \(nsError.code)")
            return
        }
        
        // Check error description for cancellation indicators
        let errorString = error.localizedDescription.lowercased()
        if errorString.contains("cancel") || 
           errorString.contains("user cancel") || 
           errorString.contains("dismissed") ||
           errorString.contains("abort") ||
           errorString.contains("1000") {
            print("Apple Sign In appears to be cancelled based on description")
            return
        }
        
        print("Apple Sign In failed with genuine error - showing toast")
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
