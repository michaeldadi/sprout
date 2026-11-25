//
//  ToastView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import SwiftUI

// MARK: - Toast View
struct ToastView: View {
    let toast: ToastItem
    @ObservedObject private var toastManager = ToastManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .foregroundStyle(toast.type.color)
                .font(SproutType.body.weight(.medium))
                .accessibilityHidden(true)

            Text(toast.message)
                .font(SproutType.body.weight(.medium))
                .foregroundStyle(SproutColor.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)

            Spacer(minLength: 8)

            Button(action: {
                toastManager.hideToast()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(SproutColor.textSecondary)
            }
            .accessibilityLabel("Dismiss message")
        }
        .padding(.horizontal, SproutSpacing.md)
        .padding(.vertical, SproutSpacing.sm)
        .background(SproutColor.surface, in: RoundedRectangle(cornerRadius: SproutShape.control))
        .overlay(RoundedRectangle(cornerRadius: SproutShape.control)
            .strokeBorder(toast.type.color, lineWidth: 1))
        .padding(.horizontal, SproutSpacing.screen)
        .padding(.top, 30)
    }
}

// MARK: - Toast Overlay Modifier
struct ToastOverlayModifier: ViewModifier {
    @ObservedObject private var toastManager = ToastManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: toastManager.currentToast != nil)
            )
    }
}

// MARK: - View Extension
extension View {
    func toastOverlay() -> some View {
        self.modifier(ToastOverlayModifier())
    }
}

// MARK: - Previews
#if DEBUG
struct ToastView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Success Toast
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack {
                    ToastView(
                        toast: ToastItem(
                            message: "Transaction saved successfully",
                            type: .success
                        )
                    )
                    Spacer()
                }
            }
            .previewDisplayName("Success Toast")

            // Error Toast
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack {
                    ToastView(
                        toast: ToastItem(
                            message: "Failed to sync data. Please try again.",
                            type: .error
                        )
                    )
                    Spacer()
                }
            }
            .previewDisplayName("Error Toast")

            // Warning Toast
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack {
                    ToastView(
                        toast: ToastItem(
                            message: "Your balance is running low",
                            type: .warning
                        )
                    )
                    Spacer()
                }
            }
            .previewDisplayName("Warning Toast")

            // Info Toast
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack {
                    ToastView(
                        toast: ToastItem(
                            message: "New features are available in settings",
                            type: .info
                        )
                    )
                    Spacer()
                }
            }
            .previewDisplayName("Info Toast")

            // Long Message Toast
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack {
                    ToastView(
                        toast: ToastItem(
                            message: "This is a very long message that demonstrates how the toast handles multiple lines of text gracefully",
                            type: .info
                        )
                    )
                    Spacer()
                }
            }
            .previewDisplayName("Long Message")

            // Dark Mode
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack {
                    ToastView(
                        toast: ToastItem(
                            message: "Dark mode toast appearance",
                            type: .success
                        )
                    )
                    Spacer()
                }
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")

            // Sample Screen with Toast Overlay
            NavigationView {
                List {
                    ForEach(0..<10) { index in
                        Text("Sample Row \(index + 1)")
                            .padding()
                    }
                }
                .navigationTitle("Transactions")
                .toastOverlay()
                .onAppear {
                    // Simulate showing a toast
                    ToastManager.shared.showSuccess("Preview loaded successfully")
                }
            }
            .previewDisplayName("In Context")
        }
    }
}

// Preview Helper - Standalone toast for testing
struct StandaloneToastPreview: View {
    @State private var showToast = false
    @State private var toastType: ToastType = .success

    var body: some View {
        VStack(spacing: 20) {
            Text("Toast Preview Tester")
                .font(.title)

            HStack(spacing: 10) {
                Button("Success") {
                    ToastManager.shared.showSuccess("Success message")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button("Error") {
                    ToastManager.shared.showError("Error message")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button("Warning") {
                    ToastManager.shared.showWarning("Warning message")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button("Info") {
                    ToastManager.shared.showInfo("Info message")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .toastOverlay()
    }
}

struct StandaloneToastPreview_Previews: PreviewProvider {
    static var previews: some View {
        StandaloneToastPreview()
            .previewDisplayName("Interactive Tester")
    }
}
#endif
