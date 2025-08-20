import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isShowingPassword = false
    @State private var isAnimating = false
    enum Field: Hashable { case email, password }
    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) var colorScheme
    
    // Navigation
    @Binding var showSignUp: Bool
    @Binding var showForgotPassword: Bool
    
    var body: some View {
        ZStack {
            backgroundGradient
            FloatingCirclesView(isAnimating: $isAnimating)
            
            // This layer will always gets taps to dismiss the keyboard
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { focusedField = nil }
            
            mainContent
        }
        .toastOverlay()
        .onAppear {
            withAnimation {
                isAnimating = true
            }
            // Disable input accessory view to prevent constraint conflicts
            UITextField.appearance().inputAssistantItem.leadingBarButtonGroups = []
            UITextField.appearance().inputAssistantItem.trailingBarButtonGroups = []
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: gradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var gradientColors: [Color] {
        colorScheme == .dark ? [
            Color(red: 0.15, green: 0.25, blue: 0.20),
            Color(red: 0.20, green: 0.35, blue: 0.25),
            Color(red: 0.25, green: 0.45, blue: 0.30)
        ] : [
            Color(red: 0.60, green: 0.85, blue: 0.65),
            Color(red: 0.50, green: 0.80, blue: 0.60),
            Color(red: 0.70, green: 0.90, blue: 0.75)
        ]
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)
            logoSection
            loginFormSection
            Spacer()
            signUpLink
        }
    }
    
    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 20) {
            appLogo
            welcomeText
        }
        .padding(.bottom, 30)
    }
    
    private var appLogo: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.15))
                .frame(width: 100, height: 100)
                .blur(radius: 3)
            
            Image(systemName: "leaf.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.white)
                .rotationEffect(.degrees(isAnimating ? 5 : -5))
                .animation(
                    Animation.easeInOut(duration: 2)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
        .padding(.bottom, 5)
    }
    
    private var welcomeText: some View {
        VStack(spacing: 8) {
            Text("Welcome Back")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Sign in to continue your journey")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    // MARK: - Login Form
    private var loginFormSection: some View {
        VStack(spacing: 15) {
            emailField
            passwordField
            forgotPasswordButton
            signInButton
            dividerSection
            socialLoginButtons
        }
        .padding(.horizontal, 30)
        .scrollDismissesKeyboard(.interactively)
        .keyboardType(.default)
    }
    
    private var emailField: some View {
      CustomTextField<LoginView.Field>(
            title: "Email",
            icon: "envelope.fill",
            placeholder: "Enter your email",
            text: $email,
            isSecure: false,
            keyboardType: .emailAddress,
            contentType: .emailAddress,
            submitLabel: .next,
            onSubmit: {
              focusedField = .password
            },
            isShowingPassword: .constant(false),
            focus: $focusedField,
            equals: .email
        )
    }
    
    private var passwordField: some View {
        CustomTextField(
            title: "Password",
            icon: "lock.fill",
            placeholder: "Enter your password",
            text: $password,
            isSecure: !isShowingPassword,
            keyboardType: .default,
            contentType: .password,
            submitLabel: .done,
            onSubmit: handleLogin,
            showPasswordToggle: true,
            isShowingPassword: $isShowingPassword,
            focus: $focusedField,
            equals: .password
        )
    }
    
    private var forgotPasswordButton: some View {
        HStack {
            Spacer()
            Button(action: { showForgotPassword = true }) {
                Text("Forgot Password?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.top, -10)
    }
    
    private var signInButton: some View {
        Button(action: {
            withAnimation(.spring()) {
                handleLogin()
            }
        }) {
            HStack {
                Text("Sign In")
                    .font(.system(size: 18, weight: .semibold))
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(buttonTextColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.white)
            .cornerRadius(15)
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        }
        .padding(.top, 10)
    }
    
    private var buttonTextColor: Color {
        colorScheme == .dark ?
            Color(red: 0.15, green: 0.25, blue: 0.20) :
            Color(red: 0.30, green: 0.60, blue: 0.35)
    }
    
    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1)
            
            Text("OR")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 10)
            
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 15)
    }
    
    private var socialLoginButtons: some View {
        VStack(spacing: 15) {
            AppleSignInButton()
                .frame(height: 50)
                .cornerRadius(15)
                .onTapGesture {
                    handleAppleSignIn()
                }
            
            SocialLoginButton(
                icon: "google",
                text: "Continue with Google",
                backgroundColor: .white,
                textColor: .black,
                action: {
                  handleGoogleSignIn()
                }
            )
        }
    }
    
    private var signUpLink: some View {
        HStack {
            Text("Don't have an account?")
                .foregroundColor(.white.opacity(0.7))
            
            Button(action: { showSignUp = true }) {
                Text("Sign Up")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .font(.system(size: 16))
        .padding(.top, 20)
        .padding(.bottom, 30)
    }
    
    // MARK: - Helper Methods
    private func dismissKeyboard() {
        focusedField = nil
    }
    
    private func handleLogin() {
        guard !email.isEmpty else {
            showToastWithHaptic("Please enter your email")
            return
        }
        
        guard !password.isEmpty else {
            showToastWithHaptic("Please enter your password")
            return
        }
        
        ToastManager.shared.showSuccess("Login successful! Welcome back.")
        print("Login with email: \(email)")
    }
    
    private func showToastWithHaptic(_ message: String) {
        ToastManager.shared.showError(message)
    }
    
    private func handleAppleSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = AppleSignInCoordinator.shared
        authorizationController.presentationContextProvider = AppleSignInCoordinator.shared
        authorizationController.performRequests()
    }
  
    private func handleGoogleSignIn() {
        guard let presentingViewController = getRootViewController() else {
            print("Could not get root view controller")
            ToastManager.shared.showError("Sign in failed. Please try again.")
            return
        }
        
        GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController) { signInResult, error in
                if let error = error {
                    print("Google Sign In error: \(error.localizedDescription)")
                  
                    // Check if user cancelled sign-in request
                  if (error as NSError).code == GIDSignInError.Code.canceled.rawValue {
                      print("Google Sign In canceled by user")
                      return
                    }

                    ToastManager.shared.showError("Google Sign In failed")
                    return
                }
                
                guard let result = signInResult else {
                    print("No sign in result")
                    return
                }
                
                // Successfully signed in
                let user = result.user
                let idToken = user.idToken?.tokenString
                let email = user.profile?.email
                let fullName = user.profile?.name
                
                print("Google Sign In successful!")
                print("User: \(fullName ?? "No name")")
                print("Email: \(email ?? "No email")")
                
                ToastManager.shared.showSuccess("Google Sign In successful!")
                
                // TODO: Send credentials to your backend API
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

// MARK: - Custom TextField Component
struct CustomTextField<FocusKey: Hashable>: View {
    let title: String
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .next
    var onSubmit: () -> Void = {}
    var showPasswordToggle: Bool = false
    @Binding var isShowingPassword: Bool

    // Parent-provided focus
    var focus: FocusState<FocusKey?>.Binding?
    var equals: FocusKey?

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            HStack {
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 20)

                if isSecure && !isShowingPassword {
                    SecureField("", text: $text)
                        .textContentType(.password)
                        .modifier(ConditionalFocus(focus: focus, equals: equals))
                        .placeholder(when: text.isEmpty) {
                            Text(placeholder).foregroundColor(.white.opacity(0.5))
                        }
                        .foregroundColor(.white)
                        .submitLabel(submitLabel)
                        .onSubmit(onSubmit)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboardType)
                        .textContentType(contentType)
                        .autocorrectionDisabled(contentType == .username)
                        .textInputAutocapitalization(.never)
                        .modifier(ConditionalFocus(focus: focus, equals: equals))
                        .placeholder(when: text.isEmpty) {
                            Text(placeholder).foregroundColor(.white.opacity(0.5))
                        }
                        .foregroundColor(.white)
                        .submitLabel(submitLabel)
                        .onSubmit(onSubmit)
                }

                if showPasswordToggle {
                    Button(action: { isShowingPassword.toggle() }) {
                        Image(systemName: isShowingPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.15))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isFocused ? Color.white.opacity(0.5) : .clear, lineWidth: 2)
            )
        }
    }

    // Reads parent focus
    private var isFocused: Bool {
        guard let focus else { return false }
        return focus.wrappedValue == equals
    }
}

// Social Login Button Component
struct SocialLoginButton: View {
    let icon: String
    let text: String
    let backgroundColor: Color
    var textColor: Color = .white
    var action: () -> Void = {}
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            action()
        }) {
            HStack(spacing: 12) {
                if icon == "google" {
                    Image("GoogleLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                }
                
                Text(text)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(backgroundColor)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.white.opacity(0.2), lineWidth: backgroundColor == .white ? 0 : 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
}

private struct ConditionalFocus<FocusKey: Hashable>: ViewModifier {
    let focus: FocusState<FocusKey?>.Binding?
    let equals: FocusKey?
    func body(content: Content) -> some View {
        if let focus, let equals {
            content.focused(focus, equals: equals)
        } else {
            content
        }
    }
}

// Preview
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(showSignUp: .constant(false), showForgotPassword: .constant(false))
    }
}
