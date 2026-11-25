//
//  SplashScreenView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//


import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale = 0.7
    @State private var logoOpacity = 0.0
    @State private var textOpacity = 0.0
    @State private var isAnimating = false

    let onComplete: () -> Void

    init(onComplete: @escaping () -> Void = {}) {
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.8, blue: 0.4),
                    Color(red: 0.05, green: 0.6, blue: 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Logo
                ZStack {
                    // Background circle
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 140, height: 140)
                        .blur(radius: 10)

                    // App icon/logo
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // App name
                VStack(spacing: 8) {
                    Text("Sprout")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Grow Your Wealth")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .opacity(textOpacity)

                Spacer()

                // Loading indicator
                VStack(spacing: 16) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 6)

                            // Progress
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white)
                                .frame(width: geometry.size.width * 0.3, height: 6)
                                .offset(x: isAnimating ? geometry.size.width * 0.7 : 0)
                                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: isAnimating)
                        }
                    }
                    .frame(height: 6)
                    .frame(maxWidth: 200)

                    Text("Loading...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .opacity(textOpacity)
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Logo animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // Text fade in
        withAnimation(.easeIn(duration: 0.6).delay(0.3)) {
            textOpacity = 1.0
        }

        // Start indeterminate animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAnimating = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            onComplete()
        }
    }
}

// MARK: - Previews
#if DEBUG
struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SplashScreenView {
                print("Splash complete")
            }
            .previewDisplayName("Full Splash")
        }
    }
}
#endif
