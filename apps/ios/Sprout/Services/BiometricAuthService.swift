import Foundation
import LocalAuthentication
import SwiftUI

enum BiometricAuthError: Error {
    case biometryNotAvailable
    case biometryNotEnrolled
    case biometryLockout
    case authenticationFailed
    case userCancel
    case userFallback
    case systemCancel
    case passcodeNotSet
    case unknown(Error)
    
    var localizedDescription: String {
        switch self {
        case .biometryNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometryNotEnrolled:
            return "No biometric data is enrolled on this device"
        case .biometryLockout:
            return "Biometric authentication is locked out. Use passcode instead"
        case .authenticationFailed:
            return "Authentication failed"
        case .userCancel:
            return "Authentication was cancelled by user"
        case .userFallback:
            return "User chose to use passcode instead"
        case .systemCancel:
            return "Authentication was cancelled by system"
        case .passcodeNotSet:
            return "Passcode is not set on this device"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID
    
    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .opticID:
            return "Optic ID"
        }
    }
    
    var iconName: String {
        switch self {
        case .none:
            return "lock"
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        case .opticID:
            return "opticid"
        }
    }
}

@MainActor
class BiometricAuthService: ObservableObject {
    static let shared = BiometricAuthService()
    
    @Published var isEnabled: Bool = false
    @Published var biometricType: BiometricType = .none
    @Published var isAvailable: Bool = false
    
    private let context = LAContext()
    private let userDefaults = UserDefaults.standard
    private let biometricEnabledKey = "biometric_auth_enabled"
    
    private init() {
        loadSettings()
        checkBiometricAvailability()
    }
    
    func loadSettings() {
        isEnabled = userDefaults.bool(forKey: biometricEnabledKey)
    }
    
    func saveSettings() {
        userDefaults.set(isEnabled, forKey: biometricEnabledKey)
    }
    
    func checkBiometricAvailability() {
        var error: NSError?
        let isAvailableResult = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        isAvailable = isAvailableResult
        
        if isAvailableResult {
            switch context.biometryType {
            case .touchID:
                biometricType = .touchID
            case .faceID:
                biometricType = .faceID
            case .opticID:
                biometricType = .opticID
            case .none:
                biometricType = .none
                isAvailable = false
            @unknown default:
                biometricType = .none
                isAvailable = false
            }
        } else {
            biometricType = .none
        }
    }
    
    func authenticate(reason: String = "Please authenticate to access your account") async -> Result<Bool, BiometricAuthError> {
        guard isAvailable else {
            return .failure(.biometryNotAvailable)
        }
        
        guard isEnabled else {
            return .failure(.biometryNotAvailable)
        }
        
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        context.localizedCancelTitle = "Cancel"
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return .success(result)
        } catch {
            let authError = mapLAError(error)
            return .failure(authError)
        }
    }
    
    func authenticateWithPasscode(reason: String = "Please authenticate to access your account") async -> Result<Bool, BiometricAuthError> {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        context.localizedCancelTitle = "Cancel"
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return .success(result)
        } catch {
            let authError = mapLAError(error)
            return .failure(authError)
        }
    }
    
    func enableBiometricAuth() {
        isEnabled = true
        saveSettings()
    }
    
    func disableBiometricAuth() {
        isEnabled = false
        saveSettings()
    }
    
    private func mapLAError(_ error: Error) -> BiometricAuthError {
        guard let laError = error as? LAError else {
            return .unknown(error)
        }
        
        switch laError.code {
        case .biometryNotAvailable:
            return .biometryNotAvailable
        case .biometryNotEnrolled:
            return .biometryNotEnrolled
        case .biometryLockout:
            return .biometryLockout
        case .authenticationFailed:
            return .authenticationFailed
        case .userCancel:
            return .userCancel
        case .userFallback:
            return .userFallback
        case .systemCancel:
            return .systemCancel
        case .passcodeNotSet:
            return .passcodeNotSet
        default:
            return .unknown(error)
        }
    }
}