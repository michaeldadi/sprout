//
//  SubscriptionSettingsView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/23/25.
//

import SwiftUI
import StoreKit

struct SubscriptionSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentSubscription: SubscriptionStatus = .none
    @State private var isLoading = true
    @State private var showingCancelConfirmation = false
    @State private var showingRestorePurchases = false

    private let accentColor = Color(red: 0.40, green: 0.70, blue: 0.45)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Loading subscription info...")
                            .padding(.top, 50)
                    } else {
                        subscriptionContent
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Subscription")
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
                loadSubscriptionStatus()
            }
            .alert("Cancel Subscription", isPresented: $showingCancelConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Confirm", role: .destructive) {
                    cancelSubscription()
                }
            } message: {
                Text("Are you sure you want to cancel your subscription? You'll continue to have access until the end of your billing period.")
            }
        }
    }

    @ViewBuilder
    private var subscriptionContent: some View {
        switch currentSubscription {
        case .none:
            noSubscriptionView
        case .active(let info):
            activeSubscriptionView(info: info)
        case .cancelled(let info):
            cancelledSubscriptionView(info: info)
        case .expired(let info):
            expiredSubscriptionView(info: info)
        }
    }

    // MARK: - No Subscription View
    private var noSubscriptionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle")
                .font(.system(size: 60))
                .foregroundColor(accentColor)
                .padding(.top, 20)

            VStack(spacing: 8) {
                Text("No Active Subscription")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Upgrade to Premium to unlock all features and get the most out of Sprout.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                // TODO: Present subscription plans
            } label: {
                HStack {
                    Spacer()
                    Text("View Plans")
                        .font(.body)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding()
                .background(accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            Button("Restore Purchases") {
                restorePurchases()
            }
            .font(.subheadline)
            .foregroundColor(accentColor)
        }
    }

    // MARK: - Active Subscription View
    private func activeSubscriptionView(info: SubscriptionInfo) -> some View {
        VStack(spacing: 20) {
            // Status Header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)

                Text("Premium Active")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("You have access to all Premium features")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Subscription Details
            SettingsSectionView(title: "Subscription Details") {
                VStack(spacing: 0) {
                    subscriptionDetailRow(title: "Plan", value: info.planName)
                    Divider().padding(.leading, 20)
                    subscriptionDetailRow(title: "Price", value: info.priceFormatted)
                    Divider().padding(.leading, 20)
                    subscriptionDetailRow(title: "Next Billing", value: info.nextBillingDateFormatted)
                    Divider().padding(.leading, 20)
                    subscriptionDetailRow(title: "Status", value: "Active")
                }
            }

            // Management Options
            SettingsSectionView(title: "Manage Subscription") {
                VStack(spacing: 0) {
                    managementRow(
                        icon: "arrow.up.circle",
                        title: "Change Plan",
                        subtitle: "Upgrade or downgrade your plan",
                        action: { /* TODO: Change plan */ }
                    )

                    Divider().padding(.leading, 55)

                    managementRow(
                        icon: "xmark.circle",
                        title: "Cancel Subscription",
                        subtitle: "Cancel your subscription",
                        isDestructive: true,
                        action: { showingCancelConfirmation = true }
                    )
                }
            }

            // App Store Management
            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                HStack {
                    Spacer()
                    Text("Manage in App Store")
                        .font(.body)
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .foregroundColor(accentColor)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Cancelled Subscription View
    private func cancelledSubscriptionView(info: SubscriptionInfo) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)

                Text("Subscription Cancelled")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Your subscription will end on \(info.expirationDateFormatted). You can reactivate anytime before then.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                // TODO: Reactivate subscription
            } label: {
                HStack {
                    Spacer()
                    Text("Reactivate Subscription")
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

    // MARK: - Expired Subscription View
    private func expiredSubscriptionView(info: SubscriptionInfo) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)

                Text("Subscription Expired")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Your subscription expired on \(info.expirationDateFormatted). Renew to continue using Premium features.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                // TODO: Renew subscription
            } label: {
                HStack {
                    Spacer()
                    Text("Renew Subscription")
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

    // MARK: - Helper Views
    private func subscriptionDetailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .fontWeight(.medium)

            Spacer()

            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }

    private func managementRow(
        icon: String,
        title: String,
        subtitle: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isDestructive ? .red : accentColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? .red : .primary)

                    Text(subtitle)
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

    // MARK: - Functions
    private func loadSubscriptionStatus() {
        Task {
            // TODO: Load actual subscription status from StoreKit
            // For now, simulate loading
            try await Task.sleep(nanoseconds: 1_000_000_000)

            // Mock data - replace with actual subscription check
            currentSubscription = .active(SubscriptionInfo(
                planName: "Premium Monthly",
                price: 9.99,
                currency: "USD",
                nextBillingDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date(),
                expirationDate: nil
            ))

            isLoading = false
        }
    }

    private func cancelSubscription() {
        // TODO: Handle subscription cancellation
        print("Cancel subscription requested")
    }

    private func restorePurchases() {
        showingRestorePurchases = true

        Task {
            do {
                // TODO: Implement restore purchases with StoreKit
                try await Task.sleep(nanoseconds: 2_000_000_000)
                showingRestorePurchases = false
            } catch {
                showingRestorePurchases = false
            }
        }
    }
}

// MARK: - Models
enum SubscriptionStatus {
    case none
    case active(SubscriptionInfo)
    case cancelled(SubscriptionInfo)
    case expired(SubscriptionInfo)
}

struct SubscriptionInfo {
    let planName: String
    let price: Double
    let currency: String
    let nextBillingDate: Date?
    let expirationDate: Date?

    var priceFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }

    var nextBillingDateFormatted: String {
        guard let date = nextBillingDate else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    var expirationDateFormatted: String {
        guard let date = expirationDate else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}