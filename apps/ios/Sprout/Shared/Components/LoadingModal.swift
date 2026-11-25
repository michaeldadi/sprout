//
//  LoadingView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//


import SwiftUI

// MARK: - Loading Style
enum LoadingStyle {
    case minimal
    case detailed
    case progress
    case success

    var iconName: String {
        switch self {
        case .minimal, .detailed, .progress:
            return "circle.dotted"
        case .success:
            return "checkmark.circle.fill"
        }
    }
}

// MARK: - Loading Modal Component
struct LoadingModal: View {
    let message: String
    let subtitle: String?
    let style: LoadingStyle
    let progress: Double?
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var animationAmount = 0.0
    @State private var scaleAmount = 0.8
    @State private var opacity = 0.0
    @State private var successScale = 0.3

    init(
        message: String,
        subtitle: String? = nil,
        style: LoadingStyle = .minimal,
        progress: Double? = nil,
        isPresented: Binding<Bool>
    ) {
        self.message = message
        self.subtitle = subtitle
        self.style = style
        self.progress = progress
        self._isPresented = isPresented
    }

    var body: some View {
        ZStack {
            // Background overlay
            Color.black
                .opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // Prevent dismissal by tapping background
                }
                .transition(.opacity)

            // Modal content
            VStack(spacing: 0) {
                switch style {
                case .minimal:
                    minimalView
                case .detailed:
                    detailedView
                case .progress:
                    progressView
                case .success:
                    successView
                }
            }
            .frame(maxWidth: 280)
            .scaleEffect(reduceMotion ? 1 : scaleAmount)
            .opacity(opacity)
            .transition(.scale.combined(with: .opacity))
            .onAppear {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    scaleAmount = 1.0
                    opacity = 1.0
                }
            }
        }
    }

    // MARK: - Minimal Style
    private var minimalView: some View {
        HStack(spacing: 16) {
            LoadingIndicator(style: .circular)
                .frame(width: 24, height: 24)

            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }

    // MARK: - Detailed Style
    private var detailedView: some View {
        VStack(spacing: 20) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 60, height: 60)

                LoadingIndicator(style: .dots)
                    .frame(width: 40, height: 40)
            }

            VStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
    }

    // MARK: - Progress Style
    private var progressView: some View {
        VStack(spacing: 24) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(SproutColor.separator, lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: progress ?? 0)
                    .stroke(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: progress)

                Text("\(Int((progress ?? 0) * 100))%")
                    .font(SproutType.sectionTitle.monospacedDigit())
                    .foregroundColor(.primary)
            }

            VStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
    }

    // MARK: - Success Style
    private var successView: some View {
        VStack(spacing: 20) {
            // Success checkmark
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 72, height: 72)

                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.green)
                    .scaleEffect(successScale)
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                            successScale = 1.0
                        }
                    }
            }

            VStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
    }
}

// MARK: - Loading Indicator
struct LoadingIndicator: View {
    enum Style {
        case circular
        case dots
        case pulse
    }

    let style: Style
    @State private var isAnimating = false

    var body: some View {
        switch style {
        case .circular:
            circularIndicator
        case .dots:
            dotsIndicator
        case .pulse:
            pulseIndicator
        }
    }

    private var circularIndicator: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }

    private var dotsIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 0.5 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }

    private var pulseIndicator: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.3))
            .frame(width: 40, height: 40)
            .overlay(
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 20, height: 20)
            )
            .scaleEffect(isAnimating ? 1.2 : 0.8)
            .opacity(isAnimating ? 0.7 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - View Extension
extension View {
    func loadingModal(
        isPresented: Binding<Bool>,
        message: String,
        subtitle: String? = nil,
        style: LoadingStyle = .minimal,
        progress: Double? = nil
    ) -> some View {
        self.overlay(
            Group {
                if isPresented.wrappedValue {
                    LoadingModal(
                        message: message,
                        subtitle: subtitle,
                        style: style,
                        progress: progress,
                        isPresented: isPresented
                    )
                }
            }
        )
    }
}

// MARK: - Loading Manager (Optional)
@MainActor
class LoadingManager: ObservableObject {
    static let shared = LoadingManager()

    @Published var isLoading = false
    @Published var loadingMessage = ""
    @Published var loadingSubtitle: String?
    @Published var loadingStyle: LoadingStyle = .minimal
    @Published var progress: Double?

    private init() {}

    func show(
        message: String,
        subtitle: String? = nil,
        style: LoadingStyle = .minimal
    ) {
        loadingMessage = message
        loadingSubtitle = subtitle
        loadingStyle = style
        progress = nil
        isLoading = true
    }

    func showProgress(
        message: String,
        subtitle: String? = nil,
        progress: Double
    ) {
        loadingMessage = message
        loadingSubtitle = subtitle
        loadingStyle = .progress
        self.progress = progress
        isLoading = true
    }

    func showSuccess(
        message: String,
        subtitle: String? = nil,
        dismissAfter: Double = 2.0
    ) {
        loadingMessage = message
        loadingSubtitle = subtitle
        loadingStyle = .success
        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + dismissAfter) {
            self.hide()
        }
    }

    func hide() {
        withAnimation(.easeOut(duration: 0.3)) {
            isLoading = false
        }
    }
}

// MARK: - Preview
#if DEBUG
struct LoadingModal_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Minimal style
            ZStack {
                Color.gray.opacity(0.1).ignoresSafeArea()
                LoadingModal(
                    message: "Loading...",
                    style: .minimal,
                    isPresented: .constant(true)
                )
            }
            .previewDisplayName("Minimal")

            // Detailed style
            ZStack {
                Color.gray.opacity(0.1).ignoresSafeArea()
                LoadingModal(
                    message: "Syncing Transactions",
                    subtitle: "This may take a moment",
                    style: .detailed,
                    isPresented: .constant(true)
                )
            }
            .previewDisplayName("Detailed")

            // Progress style
            ZStack {
                Color.gray.opacity(0.1).ignoresSafeArea()
                LoadingModal(
                    message: "Uploading Receipt",
                    subtitle: "2.4 MB of 5.1 MB",
                    style: .progress,
                    progress: 0.47,
                    isPresented: .constant(true)
                )
            }
            .previewDisplayName("Progress")

            // Success style
            ZStack {
                Color.gray.opacity(0.1).ignoresSafeArea()
                LoadingModal(
                    message: "Transaction Added",
                    subtitle: "Successfully saved",
                    style: .success,
                    isPresented: .constant(true)
                )
            }
            .previewDisplayName("Success")
        }
    }
}
#endif
