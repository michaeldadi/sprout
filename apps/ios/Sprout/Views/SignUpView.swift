import SwiftUI
import SafariServices
import AuthenticationServices
import GoogleSignIn

struct SignUpView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isShowingPassword = false
    @State private var isShowingConfirmPassword = false
    @State private var isAnimating = false
    @State private var agreeToTerms = false
    @State private var showingSafari = false
    @State private var safariURL: URL?
    @State private var showingVerificationView = false
    @State private var verificationCode = ""
    @FocusState private var firstNameFieldFocused: Bool
    @FocusState private var lastNameFieldFocused: Bool
    @FocusState private var emailFieldFocused: Bool
    @FocusState private var passwordFieldFocused: Bool
    @FocusState private var confirmPasswordFieldFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    // Navigation
    @Binding var showSignUp: Bool
    
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
            
            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 40) // Add space for notch
                    
                    // Logo and Welcome Text
                    VStack(spacing: 15) {
                        // App Icon/Logo
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.15))
                                .frame(width: 80, height: 80)
                                .blur(radius: 3)
                            
                            Image(systemName: "leaf.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(isAnimating ? 5 : -5))
                                .animation(
                                    Animation.easeInOut(duration: 2)
                                        .repeatForever(autoreverses: true),
                                    value: isAnimating
                                )
                        }
                        .padding(.bottom, 5)
                        
                        Text("Create your Account")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Join Sprout and start growing")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.bottom, 25)
                    
                    // Sign Up Form
                    VStack(spacing: 12) {
                        // Name Fields Row
                        HStack(spacing: 12) {
                            // First Name Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("First Name")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(width: 16)
                                    
                                    TextField("", text: $firstName)
                                        .placeholder(when: firstName.isEmpty) {
                                            Text("First")
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        .foregroundColor(.white)
                                        .textContentType(.givenName)
                                        .autocapitalization(.words)
                                        .focused($firstNameFieldFocused)
                                        .submitLabel(.next)
                                        .onSubmit {
                                            lastNameFieldFocused = true
                                        }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.15))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(firstNameFieldFocused ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                )
                            }
                            
                            // Last Name Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Last Name")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(width: 16)
                                    
                                    TextField("", text: $lastName)
                                        .placeholder(when: lastName.isEmpty) {
                                            Text("Last")
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        .foregroundColor(.white)
                                        .textContentType(.familyName)
                                        .autocapitalization(.words)
                                        .focused($lastNameFieldFocused)
                                        .submitLabel(.next)
                                        .onSubmit {
                                            emailFieldFocused = true
                                        }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.15))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(lastNameFieldFocused ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                )
                            }
                        }
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 16)
                                
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
                                    .submitLabel(.next)
                                    .onSubmit {
                                        passwordFieldFocused = true
                                    }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.15))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(emailFieldFocused ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1.5)
                            )
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 16)
                                
                                if isShowingPassword {
                                    TextField("", text: $password)
                                        .placeholder(when: password.isEmpty) {
                                            Text("Create password")
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        .foregroundColor(.white)
                                        .textContentType(.newPassword)
                                        .focused($passwordFieldFocused)
                                        .submitLabel(.next)
                                        .onSubmit {
                                            confirmPasswordFieldFocused = true
                                        }
                                } else {
                                    SecureField("", text: $password)
                                        .placeholder(when: password.isEmpty) {
                                            Text("Create password")
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        .foregroundColor(.white)
                                        .textContentType(.newPassword)
                                        .focused($passwordFieldFocused)
                                        .submitLabel(.next)
                                        .onSubmit {
                                            confirmPasswordFieldFocused = true
                                        }
                                }
                                
                                Button(action: {
                                    isShowingPassword.toggle()
                                }) {
                                    Image(systemName: isShowingPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.15))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(passwordFieldFocused ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1.5)
                            )
                        }
                        
                        // Confirm Password Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirm Password")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 16)
                                
                                if isShowingConfirmPassword {
                                    TextField("", text: $confirmPassword)
                                        .placeholder(when: confirmPassword.isEmpty) {
                                            Text("Confirm password")
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        .foregroundColor(.white)
                                        .textContentType(.newPassword)
                                        .focused($confirmPasswordFieldFocused)
                                        .submitLabel(.done)
                                        .onSubmit {
                                            handleSignUp()
                                        }
                                } else {
                                    SecureField("", text: $confirmPassword)
                                        .placeholder(when: confirmPassword.isEmpty) {
                                            Text("Confirm password")
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        .foregroundColor(.white)
                                        .textContentType(.newPassword)
                                        .focused($confirmPasswordFieldFocused)
                                        .submitLabel(.done)
                                        .onSubmit {
                                            handleSignUp()
                                        }
                                }
                                
                                Button(action: {
                                    isShowingConfirmPassword.toggle()
                                }) {
                                    Image(systemName: isShowingConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.15))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(confirmPasswordFieldFocused ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1.5)
                            )
                        }
                        
                        // Terms and Conditions
                        VStack(alignment: .leading, spacing: 12) {
                            // Agreement text with links
                            VStack(alignment: .center, spacing: 6) {
                                Text("By continuing, you agree to our")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                                
                                HStack(spacing: 4) {
                                    Button(action: {
                                        openTermsOfService()
                                    }) {
                                        Text("Terms of Service")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                            .underline()
                                    }
                                    
                                    Text("and")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Button(action: {
                                        openPrivacyPolicy()
                                    }) {
                                        Text("Privacy Policy")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                            .underline()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        // Sign Up Button
                        Button(action: {
                            withAnimation(.spring()) {
                                handleSignUp()
                            }
                        }) {
                            HStack {
                                if authService.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? Color(red: 0.15, green: 0.25, blue: 0.20) : Color(red: 0.30, green: 0.60, blue: 0.35)))
                                } else {
                                    Text("Create Account")
                                        .font(.system(size: 16, weight: .semibold))
                                    
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                            .foregroundColor(colorScheme == .dark ? Color(red: 0.15, green: 0.25, blue: 0.20) : Color(red: 0.30, green: 0.60, blue: 0.35))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .disabled(authService.isLoading)
                        .opacity(authService.isLoading ? 0.7 : 1.0)
                        .padding(.top, 8)
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 1)
                            
                            Text("OR")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 8)
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 12)
                        
                        // Social Sign Up Buttons
                        VStack(spacing: 10) {
                            SocialLoginButton(
                                icon: "applelogo",
                                text: "Continue with Apple",
                                backgroundColor: colorScheme == .dark ? Color.white : Color.black,
                                textColor: colorScheme == .dark ? .black : .white,
                                action: handleAppleSignUp
                            )
                            
                            SocialLoginButton(
                                icon: "google",
                                text: "Continue with Google",
                                backgroundColor: .white,
                                textColor: .black,
                                action: handleGoogleSignUp
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                        .frame(height: 20)
                    
                    // Login Link
                    HStack {
                        Text("Already have an account?")
                            .foregroundColor(.white.opacity(0.7))
                        
                        Button(action: {
                            showSignUp = false
                        }) {
                            Text("Sign In")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    }
                    .font(.system(size: 14))
                    .padding(.bottom, 30)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            firstNameFieldFocused = false
            lastNameFieldFocused = false
            emailFieldFocused = false
            passwordFieldFocused = false
            confirmPasswordFieldFocused = false
        }
        .toastOverlay()
        .sheet(isPresented: $showingSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $showingVerificationView) {
            VerificationView(email: email, isPresented: $showingVerificationView)
        }
        .onAppear {
            withAnimation {
                isAnimating = true
            }
        }
    }
    
    private func handleSignUp() {
        // Validate inputs
        guard !firstName.isEmpty else {
            ToastManager.shared.showError("Please enter your first name")
            return
        }
        
        guard !lastName.isEmpty else {
            ToastManager.shared.showError("Please enter your last name")
            return
        }
        
        guard !email.isEmpty else {
            ToastManager.shared.showError("Please enter your email")
            return
        }
        
        guard isValidEmail(email) else {
            ToastManager.shared.showError("Please enter a valid email address")
            return
        }
        
        guard !password.isEmpty else {
            ToastManager.shared.showError("Please create a password")
            return
        }
        
        guard password.count >= 8 else {
            ToastManager.shared.showError("Password must be at least 8 characters")
            return
        }
        
        guard password == confirmPassword else {
            ToastManager.shared.showError("Passwords do not match")
            return
        }
        
        // Dismiss keyboard
        firstNameFieldFocused = false
        lastNameFieldFocused = false
        emailFieldFocused = false
        passwordFieldFocused = false
        confirmPasswordFieldFocused = false
        
        // Sign up with Cognito
        Task {
            do {
                try await authService.signUp(email: email, password: password)
                await MainActor.run {
                    ToastManager.shared.showSuccess("Account created! Please check your email for verification code.")
                    showingVerificationView = true
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func openTermsOfService() {
        // Replace with your actual Terms of Service URL
        if let url = URL(string: "https://your-app.com/terms") {
            safariURL = url
            showingSafari = true
        }
    }
    
    private func openPrivacyPolicy() {
        // Replace with your actual Privacy Policy URL
        if let url = URL(string: "https://your-app.com/privacy") {
            safariURL = url
            showingSafari = true
        }
    }
    
    private func handleAppleSignUp() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = AppleSignInCoordinator.shared
        authorizationController.presentationContextProvider = AppleSignInCoordinator.shared
        authorizationController.performRequests()
    }
    
    private func handleGoogleSignUp() {
        guard let presentingViewController = getRootViewController() else {
            print("Could not get root view controller")
            ToastManager.shared.showError("Sign up failed. Please try again.")
            return
        }
        
        GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController) { signInResult, error in
                if let error = error {
                    print("Google Sign Up error: \(error.localizedDescription)")
                  
                    // Check if user cancelled sign-in request
                  if (error as NSError).code == GIDSignInError.Code.canceled.rawValue {
                      print("Google Sign Up canceled by user")
                      return
                    }

                    ToastManager.shared.showError("Google Sign Up failed")
                    return
                }
                
                guard let result = signInResult else {
                    print("No sign in result")
                    return
                }
                
                // Successfully signed in
                let user = result.user
                guard let idToken = user.idToken?.tokenString,
                      let email = user.profile?.email else {
                    print("Missing required Google credentials")
                    ToastManager.shared.showError("Google Sign Up failed")
                    return
                }
                
                let accessToken = user.accessToken.tokenString
                
                let fullName = user.profile?.name
                
                print("Google Sign Up successful!")
                print("User: \(fullName ?? "No name")")
                print("Email: \(email)")
                
                // Authenticate with Cognito
                Task {
                    do {
                        try await authService.signInWithGoogle(
                            idToken: idToken,
                            accessToken: accessToken,
                            email: email,
                            fullName: fullName
                        )
                        
                        await MainActor.run {
                            ToastManager.shared.showSuccess("Google Sign Up successful!")
                        }
                    } catch {
                        await MainActor.run {
                            print("Google Sign Up Cognito error: \(error.localizedDescription)")
                            ToastManager.shared.showError("Google Sign Up failed")
                        }
                    }
                }
            }
    }
    
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
}

// Safari View Controller Wrapper
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariViewController = SFSafariViewController(url: url)
        safariViewController.preferredBarTintColor = UIColor.systemBackground
        safariViewController.preferredControlTintColor = UIColor.systemGreen
        return safariViewController
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Apple Sign In Button
struct AppleSignInButton: UIViewRepresentable {
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
      let button = ASAuthorizationAppleIDButton(type: .continue, style: .black)
        button.cornerRadius = 15
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        // No updates needed
    }
}

// Preview
struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView(showSignUp: .constant(true))
    }
}
