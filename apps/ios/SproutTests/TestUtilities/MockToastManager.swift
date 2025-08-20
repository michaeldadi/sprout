//
//  MockToastManager.swift
//  SproutTests
//
//  Created by Michael Dadi on 8/20/25.
//

import Foundation
@testable import Sprout

class MockToastManager: ObservableObject {
    
    // Track toast calls
    var successToasts: [String] = []
    var errorToasts: [String] = []
    var infoToasts: [String] = []
    
    // Call counts
    var successCallCount: Int { successToasts.count }
    var errorCallCount: Int { errorToasts.count }
    var infoCallCount: Int { infoToasts.count }
    var totalCallCount: Int { successCallCount + errorCallCount + infoCallCount }
    
    // Last displayed messages
    var lastSuccessMessage: String? { successToasts.last }
    var lastErrorMessage: String? { errorToasts.last }
    var lastInfoMessage: String? { infoToasts.last }
    
    func showSuccess(_ message: String) {
        successToasts.append(message)
        print("📱 Mock Toast Success: \(message)")
    }
    
    func showError(_ message: String) {
        errorToasts.append(message)
        print("📱 Mock Toast Error: \(message)")
    }
    
    func showInfo(_ message: String) {
        infoToasts.append(message)
        print("📱 Mock Toast Info: \(message)")
    }
    
    // Test utilities
    func reset() {
        successToasts.removeAll()
        errorToasts.removeAll()
        infoToasts.removeAll()
    }
    
    func hasToast(containing text: String) -> Bool {
        let allToasts = successToasts + errorToasts + infoToasts
        return allToasts.contains { $0.contains(text) }
    }
    
    func hasSuccessToast(containing text: String) -> Bool {
        return successToasts.contains { $0.contains(text) }
    }
    
    func hasErrorToast(containing text: String) -> Bool {
        return errorToasts.contains { $0.contains(text) }
    }
    
    func hasErrorToast(exactly text: String) -> Bool {
        return errorToasts.contains(text)
    }
    
    func hasNoToasts() -> Bool {
        return totalCallCount == 0
    }
    
    func hasAnyErrorToast() -> Bool {
        return errorCallCount > 0
    }
    
    func hasNoErrorToasts() -> Bool {
        return errorCallCount == 0
    }
}