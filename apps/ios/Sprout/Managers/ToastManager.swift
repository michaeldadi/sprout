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
            return Color.green
        case .error:
            return Color.red
        case .warning:
            return Color.orange
        case .info:
            return Color.blue
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
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var currentToast: ToastItem?
    private var workItem: DispatchWorkItem?
    
    public init() {}
    
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

// MARK: - Toast View
struct ToastView: View {
    let toast: ToastItem
    @ObservedObject private var toastManager = ToastManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
            
            Text(toast.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
            
            Spacer(minLength: 8)
            
            Button(action: {
                toastManager.hideToast()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(toast.type.color.opacity(0.9))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
        .padding(.top, 30)
    }
}

// MARK: - Toast Overlay Modifier
struct ToastOverlayModifier: ViewModifier {
    @ObservedObject private var toastManager = ToastManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(
                VStack {
                    if let toast = toastManager.currentToast {
                        ToastView(toast: toast)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }
                    Spacer()
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: toastManager.currentToast != nil)
            )
    }
}

// MARK: - View Extension
extension View {
    func toastOverlay() -> some View {
        self.modifier(ToastOverlayModifier())
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
