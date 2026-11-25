import SwiftUI

// MARK: - Toast Types
enum ToastType {
    case success
    case error
    case warning
    case info
    
    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success:
            return SproutColor.success
        case .error:
            return SproutColor.error
        case .warning:
            return SproutColor.warning
        case .info:
            return SproutColor.info
        }
    }
    
    var hapticType: UINotificationFeedbackGenerator.FeedbackType {
        switch self {
        case .success:
            return .success
        case .error:
            return .error
        case .warning:
            return .warning
        case .info:
            return .success
        }
    }
}

// MARK: - Toast Item
struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
    let duration: Double
    
    init(message: String, type: ToastType, duration: Double = 3.0) {
        self.message = message
        self.type = type
        self.duration = duration
    }
    
    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toast Manager
@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var currentToast: ToastItem?
    private var workItem: DispatchWorkItem?
    
    private init() {}
    
    func showToast(_ message: String, type: ToastType, duration: Double = 3.0) {
        // Cancel any existing work item
        workItem?.cancel()
        
        // Generate haptic feedback
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()
        feedbackGenerator.notificationOccurred(type.hapticType)
        
        // Create new toast item
        let newToast = ToastItem(message: message, type: type, duration: duration)
        
        // Show toast with proper timing and animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            currentToast = newToast
        }
        
        // Create new work item for auto-dismiss
        workItem = DispatchWorkItem {
            self.hideToast()
        }
        
        // Schedule auto-dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem!)
    }
    
    func hideToast() {
        workItem?.cancel()
        withAnimation(.easeInOut(duration: 0.3)) {
            currentToast = nil
        }
    }
}

// MARK: - Convenience Methods
extension ToastManager {
    func showSuccess(_ message: String, duration: Double = 3.0) {
        showToast(message, type: .success, duration: duration)
    }
    
    func showError(_ message: String, duration: Double = 3.0) {
        showToast(message, type: .error, duration: duration)
    }
    
    func showWarning(_ message: String, duration: Double = 3.0) {
        showToast(message, type: .warning, duration: duration)
    }
    
    func showInfo(_ message: String, duration: Double = 3.0) {
        showToast(message, type: .info, duration: duration)
    }
}
