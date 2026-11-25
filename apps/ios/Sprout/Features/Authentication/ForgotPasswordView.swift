import SwiftUI

struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var isAnimating = false
    @State private var isSubmitted = false
    @State private var resetCode = ""
    @State private var newPassword = ""
    @State private var isSubmitting = false
    @FocusState private var emailFieldFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    // Navigation
    @Binding var showForgotPassword: Bool
    
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
            
            VStack(spacing: 0) {
                // Back Button
                HStack {
                    Button(action: {
                        showForgotPassword = false
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                            .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                if isSubmitted {
                    ScrollView {
                    VStack(spacing: 25) {
                        // Success Icon
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.15))
                                .frame(width: 100, height: 100)
                                .blur(radius: 3)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .foregroundColor(.white)
                                .scaleEffect(isAnimating ? 1.1 : 1.0)
                                .animation(
                                    Animation.easeInOut(duration: 2)
                                        .repeatForever(autoreverses: true),
                                    value: isAnimating
                                )
                        }
                        
                        VStack(spacing: 15) {
                            Text("Reset Your Password")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("Enter the code sent to")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                            
                            Text(email)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }

                        VStack(spacing: 14) {
                            TextField("Verification code", text: $resetCode)
                                .textContentType(.oneTimeCode)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Password reset code")

                            SecureField("New password", text: $newPassword)
                                .textContentType(.newPassword)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("New password")

                            Button(action: handleConfirmReset) {
                                Group {
                                    if isSubmitting {
                                        ProgressView()
                                    } else {
                                        Text("Reset Password")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isSubmitting || resetCode.isEmpty || newPassword.isEmpty)
                        }
                        .padding(.horizontal, 30)
                        
                        VStack(spacing: 15) {
                            Text("Didn't receive the email? Check your spam folder or")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                            
                            Button(action: {
                                handleResendEmail()
                            }) {
                                Text("Resend Email")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .underline()
                            }
                            .disabled(isSubmitting)
                        }
                        .padding(.top, 10)
                    }
                    .padding(.vertical, 24)
                    }
                    
                } else {
                    // Input State
                    VStack(spacing: 30) {
                        // Logo and Welcome Text
                        VStack(spacing: 20) {
                            // App Icon/Logo
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.15))
                                    .frame(width: 100, height: 100)
                                    .blur(radius: 3)
                                
                                Image(systemName: "key.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(isAnimating ? 5 : -5))
                                    .animation(
                                        Animation.easeInOut(duration: 2)
                                            .repeatForever(autoreverses: true),
                                        value: isAnimating
                                    )
                            }
                            .padding(.bottom, 10)
                            
                            Text("Forgot Password")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("Enter your email address and we'll send you instructions to reset your password")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        
                        // Email Input Form
                        VStack(spacing: 20) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(width: 20)
                                    
                                    TextField("", text: $email)
                                        .placeholder(when: email.isEmpty) {
                                            Text("Enter your email")
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        .foregroundColor(.white)
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .focused($emailFieldFocused)
                                        .submitLabel(.send)
                                        .onSubmit {
                                            handleSendResetEmail()
                                        }
                                }
                                .padding()
                                .background(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.15))
                                .cornerRadius(15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(emailFieldFocused ? Color.white.opacity(0.5) : Color.clear, lineWidth: 2)
                                )
                            }
                            
                            // Send Reset Email Button
                            Button(action: {
                                withAnimation(.spring()) {
                                    handleSendResetEmail()
                                }
                            }) {
                                HStack {
                                    Text("Send Reset Email")
                                        .font(.system(size: 18, weight: .semibold))
                                    
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(colorScheme == .dark ? Color(red: 0.15, green: 0.25, blue: 0.20) : Color(red: 0.30, green: 0.60, blue: 0.35))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Color.white)
                                .cornerRadius(15)
                                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                            }
                            .disabled(isSubmitting)
                            .padding(.top, 10)
                        }
                        .padding(.horizontal, 30)
                    }
                }
                
                Spacer()
                
                // Back to Login Link
                HStack {
                    Text("Remember your password?")
                        .foregroundColor(.white.opacity(0.7))
                    
                    Button(action: {
                        showForgotPassword = false
                    }) {
                        Text("Sign In")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
                .font(.system(size: 16))
                .padding(.bottom, 50)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            emailFieldFocused = false
        }
        .toastOverlay()
        .onAppear {
            withAnimation {
                isAnimating = true
            }
        }
    }
    
    private func handleSendResetEmail() {
        guard !isSubmitting else { return }
        // Validate email
        guard !email.isEmpty else {
            ToastManager.shared.showError("Please enter your email address")
            return
        }
        
        guard isValidEmail(email) else {
            ToastManager.shared.showError("Please enter a valid email address")
            return
        }
        
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await AuthService.shared.forgotPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
                withAnimation(.easeInOut(duration: 0.3)) { isSubmitted = true }
                ToastManager.shared.showSuccess("Reset code sent. Check your email.")
            } catch {
                ToastManager.shared.showError(error.localizedDescription)
            }
        }
    }
    
    private func handleResendEmail() {
        guard !isSubmitting else { return }
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await AuthService.shared.forgotPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
                ToastManager.shared.showInfo("A new reset code was sent.")
            } catch {
                ToastManager.shared.showError(error.localizedDescription)
            }
        }
    }

    private func handleConfirmReset() {
        guard !isSubmitting else { return }
        guard newPassword.count >= 8 else {
            ToastManager.shared.showError("Use a password with at least 8 characters.")
            return
        }
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await AuthService.shared.confirmForgotPassword(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    confirmationCode: resetCode.trimmingCharacters(in: .whitespacesAndNewlines),
                    newPassword: newPassword
                )
                newPassword = ""
                ToastManager.shared.showSuccess("Password changed. Sign in with your new password.")
                showForgotPassword = false
            } catch {
                ToastManager.shared.showError(error.localizedDescription)
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

// Preview
struct ForgotPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ForgotPasswordView(showForgotPassword: .constant(true))
    }
}
