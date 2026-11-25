//
//  AccountSettingsView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/23/25.
//

import SwiftUI

struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    @State private var email = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isUpdating = false
    @State private var showingEmailUpdate = false
    @State private var showingPasswordUpdate = false
    @State private var alertMessage = ""
    @State private var showingAlert = false

    private let accentColor = Color(red: 0.40, green: 0.70, blue: 0.45)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Info Section
                    SettingsSectionView(title: "Profile Information") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text(authService.currentUser?.email ?? "")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Change") {
                                showingEmailUpdate = true
                                email = authService.currentUser?.email ?? ""
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(accentColor)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 15)
                    }

                    // Security Section
                    SettingsSectionView(title: "Security") {
                        Button {
                            showingPasswordUpdate = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Password")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)

                                    Text("Change your password")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 15)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Account Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }
            }
            .alert("Account Update", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingEmailUpdate) {
                EmailUpdateView(
                    currentEmail: authService.currentUser?.email ?? "",
                    onUpdate: { newEmail in
                        updateEmail(newEmail)
                    }
                )
            }
            .sheet(isPresented: $showingPasswordUpdate) {
                PasswordUpdateView(
                    onUpdate: { current, new in
                        updatePassword(current: current, new: new)
                    }
                )
            }
        }
    }

    private func updateEmail(_ newEmail: String) {
        isUpdating = true

        Task {
            do {
                // TODO: Implement email update through auth service
                alertMessage = "Email update request sent. Please check your email to confirm the change."
                showingAlert = true
            } catch {
                alertMessage = "Failed to update email: \(error.localizedDescription)"
                showingAlert = true
            }

            isUpdating = false
        }
    }

    private func updatePassword(current: String, new: String) {
        isUpdating = true

        Task {
            do {
                // TODO: Implement password update through auth service
                alertMessage = "Password updated successfully."
                showingAlert = true
            } catch {
                alertMessage = "Failed to update password: \(error.localizedDescription)"
                showingAlert = true
            }

            isUpdating = false
        }
    }
}

// MARK: - Email Update View
struct EmailUpdateView: View {
    @Environment(\.dismiss) private var dismiss

    let currentEmail: String
    let onUpdate: (String) -> Void

    @State private var newEmail = ""
    @State private var password = ""

    private let accentColor = Color(red: 0.40, green: 0.70, blue: 0.45)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Email")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        Text(currentEmail)
                            .font(.body)
                            .padding()
                            .background(Color(.quaternarySystemFill))
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Email")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("Enter new email", text: $newEmail)
                            .textFieldStyle(CustomTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Password")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        SecureField("Enter current password", text: $password)
                            .textFieldStyle(CustomTextFieldStyle())
                            .textContentType(.password)
                    }

                    Button {
                        onUpdate(newEmail)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Update Email")
                                .font(.body)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding()
                        .background(accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(newEmail.isEmpty || password.isEmpty)
                    .opacity(newEmail.isEmpty || password.isEmpty ? 0.6 : 1.0)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Change Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }
            }
        }
    }
}

// MARK: - Password Update View
struct PasswordUpdateView: View {
    @Environment(\.dismiss) private var dismiss

    let onUpdate: (String, String) -> Void

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    private let accentColor = Color(red: 0.40, green: 0.70, blue: 0.45)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Password")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        SecureField("Enter current password", text: $currentPassword)
                            .textFieldStyle(CustomTextFieldStyle())
                            .textContentType(.password)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Password")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        SecureField("Enter new password", text: $newPassword)
                            .textFieldStyle(CustomTextFieldStyle())
                            .textContentType(.newPassword)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm New Password")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        SecureField("Confirm new password", text: $confirmPassword)
                            .textFieldStyle(CustomTextFieldStyle())
                            .textContentType(.newPassword)
                    }

                    if !newPassword.isEmpty && newPassword != confirmPassword {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button {
                        onUpdate(currentPassword, newPassword)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Update Password")
                                .font(.body)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding()
                        .background(accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isValid)
                    .opacity(isValid ? 1.0 : 0.6)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }
            }
        }
    }

    private var isValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 8
    }
}

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
    }
}
