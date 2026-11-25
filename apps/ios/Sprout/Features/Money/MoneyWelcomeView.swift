import Appwrite
import AuthenticationServices
import GoogleSignIn
import SwiftUI
import UIKit

private enum MoneyEmailMode: String, Identifiable {
    case create, signIn
    var id: String { rawValue }
}

struct MoneyWelcomeView: View {
    @State private var emailAuth: MoneyEmailMode?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Label("sprout", systemImage: "leaf.fill").font(.title.bold()).foregroundStyle(SproutColor.action)
                    ZStack {
                        RoundedRectangle(cornerRadius: 44).fill(SproutColor.surfaceSubtle)
                        VStack(spacing: 20) {
                            Image(systemName: "leaf.circle.fill").font(.system(size: 80)).foregroundStyle(SproutColor.action).accessibilityHidden(true)
                            MoneyInsightPill(text: "A little clarity. A little more room to grow.")
                            HStack { Label("Your money", systemImage: "chart.xyaxis.line"); Spacer(); Image(systemName: "checkmark.circle.fill").foregroundStyle(SproutColor.action) }.font(.headline).padding().background(SproutColor.surface, in: RoundedRectangle(cornerRadius: 22))
                        }.padding(24)
                    }.frame(minHeight: 300).accessibilityElement(children: .ignore).accessibilityLabel("Sprout helps you see your financial picture and take action.")
                    Text("Make room for\nwhat matters.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Sprout watches your money, shows you what's coming, and helps you take care of it.").font(.title3).foregroundStyle(SproutColor.textSecondary)
                    Button("Get started") { emailAuth = .create }.buttonStyle(MoneyPrimaryButtonStyle()).buttonBorderShape(.capsule).controlSize(.large).frame(maxWidth: .infinity)
                    Button("I already have an account") { emailAuth = .signIn }.frame(maxWidth: .infinity)
                    MoneyAppleSignInControl().frame(height: 50).clipShape(Capsule())
                    Button { Task { await google() } } label: { HStack { Text("G").bold(); Text("Continue with Google") }.frame(maxWidth: .infinity).padding(10) }.buttonStyle(.bordered).buttonBorderShape(.capsule)
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(SproutColor.error)
                    }
                    HStack { Link("Terms", destination: URL(string: "https://getsprout.appwrite.network/terms")!); Text("·"); Link("Privacy", destination: URL(string: "https://getsprout.appwrite.network/privacy")!) }.font(.footnote).frame(maxWidth: .infinity)
                }.padding(24).frame(maxWidth: 540).frame(maxWidth: .infinity)
            }.background(SproutColor.canvas).foregroundStyle(SproutColor.textPrimary).tint(SproutColor.action)
                .sheet(item: $emailAuth) { mode in MoneyEmailAuthView(create: mode == .create) }
        }
    }

    private func google() async {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String, clientID.hasSuffix(".apps.googleusercontent.com"),
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let controller = scene.windows.first?.rootViewController else { error = "Google sign-in isn't configured for this build."; return }
        do { let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: controller); guard let token = result.user.idToken?.tokenString else { return }; try await AppwriteNativeSession.shared.signInWithGoogle(idToken: token, name: result.user.profile?.name) }
        catch { self.error = "Google sign-in didn't complete. You can try again or use email." }
    }
}

/// The presented form owns its input state. Submission reads the same live
/// values as the controls, and dismissal releases the entered password.
private struct MoneyEmailAuthView: View {
    let create: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var authenticating = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                if create { TextField("Name", text: $name).textContentType(.name) }
                TextField("Email", text: $email).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Password", text: $password).textContentType(create ? .newPassword : .password).textInputAutocapitalization(.never).autocorrectionDisabled()
                if let error { Text(error).foregroundStyle(SproutColor.error) }
                Button(create ? "Create account" : "Sign in") { Task { await signIn() } }.disabled(authenticating || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                if authenticating { ProgressView("Signing in…") }
            }
            .navigationTitle(create ? "Start growing" : "Welcome back")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { password = ""; dismiss() } } }
        }
    }
    private func signIn() async {
        guard !authenticating else { return }
        guard (8 ... 256).contains(password.count) else { error = "Enter a password between 8 and 256 characters."; return }
        authenticating = true; error = nil; defer { authenticating = false }
        do {
            try await AppwriteNativeSession.shared.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, create: create, name: name)
            password = ""
        } catch {
            switch (error as? AppwriteError)?.code {
            case 400: self.error = "Review your email and password, then try again."
            case 401: self.error = "That email and password combination wasn't accepted. Review both and try again."
            case 403: self.error = "This account can't sign in right now. Contact support if you need help."
            case 409: self.error = create ? "An account already uses this email. Close this form and sign in." : "This device already has an active session. Close this form and sign out before trying again."
            case 429: self.error = "Too many sign-in attempts. Wait a moment, then try again."
            default: self.error = "Couldn't reach Sprout. Check your connection and try again."
            }
        }
    }
}

private struct MoneyAppleSignInControl: UIViewRepresentable {
    func makeUIView(context _: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .continue, style: .black)
        button.cornerRadius = 25
        button.addAction(UIAction { _ in AppleSignInCoordinator.shared.startSignIn() }, for: .touchUpInside)
        return button
    }

    func updateUIView(_: ASAuthorizationAppleIDButton, context _: Context) {}
}
