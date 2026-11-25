//
//  NotificationSettingsView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/23/25.
//

import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var notificationSettings = NotificationPreferences()
    @State private var systemNotificationsEnabled = false
    @State private var isLoading = true
    @State private var showingSystemSettings = false

    private let accentColor = Color(red: 0.40, green: 0.70, blue: 0.45)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Loading notification settings...")
                            .padding(.top, 50)
                    } else {
                        notificationContent
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }
            }
            .onAppear {
                loadNotificationSettings()
            }
        }
    }

    @ViewBuilder
    private var notificationContent: some View {
        if !systemNotificationsEnabled {
            systemNotificationsDisabledView
        } else {
            enabledNotificationSettings
        }
    }

    // MARK: - System Notifications Disabled View
    private var systemNotificationsDisabledView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash.circle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .padding(.top, 20)

            VStack(spacing: 8) {
                Text("Notifications Disabled")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("To receive notifications from Sprout, please enable them in your device settings.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                openSystemSettings()
            } label: {
                HStack {
                    Spacer()
                    Text("Open Settings")
                        .font(.body)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding()
                .background(accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Enabled Notification Settings
    private var enabledNotificationSettings: some View {
        VStack(spacing: 20) {
            // Push Notifications Section
            SettingsSectionView(title: "Push Notifications") {
                VStack(spacing: 0) {
                    notificationToggleRow(
                        title: "Transaction Alerts",
                        subtitle: "Get notified about new transactions",
                        isOn: $notificationSettings.transactionAlerts
                    )

                    Divider().padding(.leading, 20)

                    notificationToggleRow(
                        title: "Budget Notifications",
                        subtitle: "Alerts when approaching budget limits",
                        isOn: $notificationSettings.budgetAlerts
                    )

                    Divider().padding(.leading, 20)

                    notificationToggleRow(
                        title: "Bill Reminders",
                        subtitle: "Reminders for upcoming bills",
                        isOn: $notificationSettings.billReminders
                    )

                    Divider().padding(.leading, 20)

                    notificationToggleRow(
                        title: "Goals Progress",
                        subtitle: "Updates on your financial goals",
                        isOn: $notificationSettings.goalProgress
                    )
                }
            }

            // Marketing & Updates Section
            SettingsSectionView(title: "Marketing & Updates") {
                VStack(spacing: 0) {
                    notificationToggleRow(
                        title: "Product Updates",
                        subtitle: "New features and app updates",
                        isOn: $notificationSettings.productUpdates
                    )

                    Divider().padding(.leading, 20)

                    notificationToggleRow(
                        title: "Tips & Insights",
                        subtitle: "Financial tips and insights",
                        isOn: $notificationSettings.tipsAndInsights
                    )

                    Divider().padding(.leading, 20)

                    notificationToggleRow(
                        title: "Promotional Offers",
                        subtitle: "Special offers and promotions",
                        isOn: $notificationSettings.promotionalOffers
                    )
                }
            }

            // Notification Schedule Section
            SettingsSectionView(title: "Notification Schedule") {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quiet Hours")
                                .font(.body)
                                .fontWeight(.medium)

                            Text("Pause notifications during these hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: $notificationSettings.quietHoursEnabled)
                            .tint(accentColor)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)

                    if notificationSettings.quietHoursEnabled {
                        Divider().padding(.leading, 20)

                        VStack(spacing: 10) {
                            HStack {
                                Text("From")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Spacer()

                                DatePicker("", selection: $notificationSettings.quietHoursStart, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }

                            HStack {
                                Text("To")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Spacer()

                                DatePicker("", selection: $notificationSettings.quietHoursEnd, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 15)
                    }
                }
            }

            // Notification Frequency Section
            SettingsSectionView(title: "Frequency") {
                VStack(spacing: 0) {
                    ForEach(NotificationFrequency.allCases, id: \.self) { frequency in
                        Button {
                            notificationSettings.frequency = frequency
                            saveNotificationSettings()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(frequency.title)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)

                                    Text(frequency.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if notificationSettings.frequency == frequency {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(accentColor)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 15)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        if frequency != NotificationFrequency.allCases.last {
                            Divider().padding(.leading, 20)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Views
    private func notificationToggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .tint(accentColor)
                .onChange(of: isOn.wrappedValue) {
                    saveNotificationSettings()
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }

    // MARK: - Functions
    private func loadNotificationSettings() {
        Task {
            // Check system notification permission
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            systemNotificationsEnabled = settings.authorizationStatus == .authorized

            // Load user notification preferences
            notificationSettings = loadUserNotificationPreferences()

            isLoading = false
        }
    }

    private func loadUserNotificationPreferences() -> NotificationPreferences {
        // TODO: Load from UserDefaults or backend
        return NotificationPreferences()
    }

    private func saveNotificationSettings() {
        // TODO: Save to UserDefaults and/or backend
        print("Saving notification settings: \(notificationSettings)")
    }

    private func openSystemSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Models
struct NotificationPreferences {
    var transactionAlerts = true
    var budgetAlerts = true
    var billReminders = true
    var goalProgress = true
    var productUpdates = true
    var tipsAndInsights = false
    var promotionalOffers = false
    var quietHoursEnabled = false
    var quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    var frequency = NotificationFrequency.normal
}

enum NotificationFrequency: CaseIterable {
    case minimal
    case normal
    case frequent

    var title: String {
        switch self {
        case .minimal:
            return "Minimal"
        case .normal:
            return "Normal"
        case .frequent:
            return "Frequent"
        }
    }

    var description: String {
        switch self {
        case .minimal:
            return "Only critical notifications"
        case .normal:
            return "Balanced notification frequency"
        case .frequent:
            return "All available notifications"
        }
    }
}
