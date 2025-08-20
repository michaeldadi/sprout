import SwiftUI

struct VerificationView: View {
    @State private var verificationCode = ""
    @State private var isAnimating = false
    @FocusState private var codeFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    let email: String
    @Binding var isPresented: Bool
    
    // Auth service
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        ZStack {
            // Gradient Background
            LinearGradient(
                gradient: Gradient(colors: colorScheme == .dark ? [
                    Color(red: 0.15, green: 0.25, blue: 0.20),
                    Color(red: 0.20, green: 0.35, blue: 0.25),
                    Color(red: 0.25, green: 0.45, blue: 0.30)
                ] : [
                    Color(red: 0.60, green: 0.85, blue: 0.65),
                    Color(red: 0.50, green: 0.80, blue: 0.60),
                    Color(red: 0.70, green: 0.90, blue: 0.75)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Floating circles animation
            FloatingCirclesView(isAnimating: $isAnimating)
            
            VStack(spacing: 30) {
                // Back Button
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // Email Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.15))
                        .frame(width: 80, height: 80)
                        .blur(radius: 3)
                    
                    Image(systemName: "envelope.badge.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(.white)
                }
                
                // Title and Description
                VStack(spacing: 12) {
                    Text("Verify Your Email")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("We've sent a verification code to")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(email)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                
                // Verification Code Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Verification Code")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    HStack {
                        Image(systemName: "number")
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 20)
                        
                        TextField("", text: $verificationCode)
                            .placeholder(when: verificationCode.isEmpty) {
                                Text("Enter 6-digit code").foregroundColor(.white.opacity(0.5))
                            }
                            .foregroundColor(.white)
                            .keyboardType(.numberPad)
                            .focused($codeFocused)
                            .onChange(of: verificationCode) { newValue in
                                // Limit to 6 digits
                                if newValue.count > 6 {
                                    verificationCode = String(newValue.prefix(6))
                                }
                                // Auto-submit when 6 digits entered
                                if verificationCode.count == 6 {
                                    handleVerification()
                                }
                            }
                    }
                    .padding()
                    .background(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.15))
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(codeFocused ? Color.white.opacity(0.5) : .clear, lineWidth: 2)
                    )
                }
                .padding(.horizontal, 30)
                
                // Verify Button
                Button(action: handleVerification) {
                    HStack {
                        if authService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? 
                                    Color(red: 0.15, green: 0.25, blue: 0.20) : 
                                    Color(red: 0.30, green: 0.60, blue: 0.35)))
                        } else {
                            Text("Verify Email")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundColor(colorScheme == .dark ? 
                        Color(red: 0.15, green: 0.25, blue: 0.20) : 
                        Color(red: 0.30, green: 0.60, blue: 0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                }
                .disabled(authService.isLoading || verificationCode.count < 6)
                .opacity(authService.isLoading || verificationCode.count < 6 ? 0.7 : 1.0)
                .padding(.horizontal, 30)
                
                // Resend Code
                Button(action: resendCode) {
                    Text("Didn't receive the code? Resend")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
            }
        }
        .toastOverlay()
        .onAppear {
            withAnimation {
                isAnimating = true
            }
            // Auto-focus the code field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                codeFocused = true
            }
        }
    }
    
    private func handleVerification() {
        guard verificationCode.count == 6 else {
            ToastManager.shared.showError("Please enter a 6-digit verification code")
            return
        }
        
        codeFocused = false
        
        Task {
            do {
                try await authService.confirmSignUp(email: email, confirmationCode: verificationCode)
                await MainActor.run {
                    ToastManager.shared.showSuccess("Email verified! You can now sign in.")
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.showError(error.localizedDescription)
                    // Clear the code on error
                    verificationCode = ""
                    codeFocused = true
                }
            }
        }
    }
    
    private func resendCode() {
        // In a real implementation, you would call authService.resendConfirmationCode
        ToastManager.shared.showInfo("Verification code resent to \(email)")
    }
}

// Preview
struct VerificationView_Previews: PreviewProvider {
    static var previews: some View {
        VerificationView(email: "user@example.com", isPresented: .constant(true))
    }
}
