//
//  SettingsView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/23/25.
//

import SwiftUI
import AuthenticationServices

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    @State private var showingDeleteAccount = false
    @State private var showingAccountSettings = false
    @State private var showingNotificationSettings = false
    @State private var showingSubscriptionSettings = false
    @State private var showingSignOutConfirmation = false

    private let accentColor = Color(red: 0.40, green: 0.70, blue: 0.45)

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Section
                    ProfileSectionView()
                        .padding(.horizontal)
                        .padding(.top, 20)

                    // Settings Sections
                    VStack(spacing: 20) {
                        // Account Settings
                        SettingsSectionView(title: "Account") {
                            SettingsRowView(
                                icon: "person.circle",
                                title: "Account Settings",
                                subtitle: "Email, password, and profile",
                                action: { showingAccountSettings = true }
                            )

                            SettingsRowView(
                                icon: "creditcard",
                                title: "Subscription",
                                subtitle: "Manage your plan and billing",
                                action: { showingSubscriptionSettings = true }
                            )
                        }

                        // Notifications
                        SettingsSectionView(title: "Preferences") {
                            SettingsRowView(
                                icon: "bell",
                                title: "Notifications",
                                subtitle: "Push notifications and alerts",
                                action: { showingNotificationSettings = true }
                            )
                        }

                        // Support & Info
                        SettingsSectionView(title: "Support & Information") {
                            SettingsRowView(
                                icon: "questionmark.circle",
                                title: "Help & Support",
                                subtitle: "Get help and contact support",
                                action: { /* TODO: Implement help */ }
                            )

                            SettingsRowView(
                                icon: "doc.text",
                                title: "Privacy Policy",
                                subtitle: "Read our privacy policy",
                                action: { /* TODO: Implement privacy policy */ }
                            )

                            SettingsRowView(
                                icon: "doc.text",
                                title: "Terms of Service",
                                subtitle: "Read our terms of service",
                                action: { /* TODO: Implement terms */ }
                            )
                        }

                        // Danger Zone
                        SettingsSectionView(title: "Account Actions") {
                            SettingsRowView(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "Sign Out",
                                subtitle: "Sign out of your account",
                                isDestructive: false,
                                action: { showingSignOutConfirmation = true }
                            )

                            SettingsRowView(
                                icon: "trash",
                                title: "Delete Account",
                                subtitle: "Permanently delete your account",
                                isDestructive: true,
                                action: { showingDeleteAccount = true }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 30)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                    .foregroundColor(accentColor)
                }
            }
            .sheet(isPresented: $showingAccountSettings) {
                AccountSettingsView()
            }
            .sheet(isPresented: $showingNotificationSettings) {
                NotificationSettingsView()
            }
            .sheet(isPresented: $showingSubscriptionSettings) {
                SubscriptionSettingsView()
            }
            .sheet(isPresented: $showingDeleteAccount) {
                DeleteAccountView()
            }
            .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    private func signOut() {
        dismiss()

        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            await authService.signOut()
        }
    }
}

// MARK: - Profile Section
struct ProfileSectionView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        HStack(spacing: 15) {
            // Profile Picture
            Circle()
                .fill(Color(red: 0.40, green: 0.70, blue: 0.45).opacity(0.1))
                .frame(width: 60, height: 60)
                .overlay {
                    Text(initials)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.40, green: 0.70, blue: 0.45))
                }

            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(authService.currentUser?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var displayName: String {
        authService.currentUser?.displayName ?? "User"
    }

    private var initials: String {
        let name = displayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else if let first = components.first {
            return String(first.prefix(2))
        }
        return "U"
    }
}

// MARK: - Settings Section
struct SettingsSectionView<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                content
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Settings Row
struct SettingsRowView: View {
    let icon: String
    let title: String
    let subtitle: String?
    let isDestructive: Bool
    let action: () -> Void

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isDestructive = isDestructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isDestructive ? .red : Color(red: 0.40, green: 0.70, blue: 0.45))
                    .frame(width: 24, height: 24)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? .red : .primary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Chevron
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
