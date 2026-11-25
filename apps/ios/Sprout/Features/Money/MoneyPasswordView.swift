import SwiftUI

struct MoneyPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    let owner: String
    @State private var account: AppwriteAccountSecurity?
    @State private var current = ""
    @State private var new = ""
    @State private var confirmation = ""
    @State private var busy = false
    @State private var error: String?
    @State private var succeeded = false
    var body: some View {
        NavigationStack {
            Form {
                Text("Change the password for this Sprout account. Your device lock is managed separately.").font(.footnote)
                if account == nil && error == nil { ProgressView("Checking account security…") }
                if let error { Text(error).foregroundStyle(SproutColor.error).accessibilityIdentifier("money.security.error"); Button("Check again") { Task { await verify() } }.disabled(busy) }
                if account != nil {
                    SecureField("Current password", text: $current).textContentType(.password)
                    SecureField("New password", text: $new).textContentType(.newPassword)
                    SecureField("Confirm new password", text: $confirmation).textContentType(.newPassword)
                    Text("Use 8–256 characters. Your account's password-strength rules also apply.").font(.footnote)
                    Button("Update password") { Task { await update() } }.disabled(busy || current.isEmpty || new.count < 8 || new.count > 256 || new != confirmation)
                }
                if busy { ProgressView("Updating account security…") }
            }.autocorrectionDisabled().textInputAutocapitalization(.never).scrollDismissesKeyboard(.immediately)
                .scrollContentBackground(.hidden).background(SproutColor.canvas)
                .navigationTitle("Change password").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(busy) } }
        }.interactiveDismissDisabled(busy).task { await verify() }
            .alert("Password updated", isPresented: $succeeded) { Button("Done") { dismiss() } } message: { Text("Use your new password the next time you sign in.") }
            .onDisappear { current = ""; new = ""; confirmation = "" }
    }
    private func verify() async {
        error = nil; account = nil
        do { account = try await AppwriteAccountSecurity.verified(owner: owner) }
        catch { self.error = "Connect to Sprout and sign in again if necessary to verify this account's password credential." }
    }
    private func update() async {
        guard let account, !busy else { return }; busy = true; error = nil; defer { busy = false }
        do { try await account.changePassword(current: current, new: new); current = ""; new = ""; confirmation = ""; succeeded = true }
        catch { self.error = error.localizedDescription }
    }
}
