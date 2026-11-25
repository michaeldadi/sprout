//
//  DeleteAccountView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/23/25.
//

import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    @State private var selectedReasons: Set<DeletionReason> = []
    @State private var otherFeedback = ""
    @State private var confirmationText = ""
    @State private var isDeleting = false
    @State private var showingConfirmation = false

    private let accentColor = Color(red: 0.40, green: 0.70, blue: 0.45)
    private let requiredConfirmationText = "DELETE"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    // Warning Header
                    warningHeader

                    // Feedback Section
                    feedbackSection

                    // Confirmation Section
                    confirmationSection

                    // Delete Button
                    deleteButton
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 50)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }
            }
            .alert("Delete Account", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Forever", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
        }
    }

    // MARK: - Warning Header
    private var warningHeader: some View {
        VStack(spacing: 15) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)

            VStack(spacing: 8) {
                Text("Delete Your Account")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("This action is permanent and cannot be undone. All your data, including transactions, budgets, and settings will be permanently deleted.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Feedback Section
    private var feedbackSection: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Help us improve")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            Text("We're sorry to see you go. Could you tell us why you're deleting your account? This helps us improve Sprout for everyone.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)

            // Deletion Reasons
            VStack(spacing: 8) {
                ForEach(DeletionReason.allCases, id: \.self) { reason in
                    reasonSelectionRow(reason: reason)
                }
            }
            .padding(.top, 10)

            // Additional Feedback
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Additional feedback (optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }

                TextEditor(text: $otherFeedback)
                    .frame(minHeight: 100)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
            }
            .padding(.top, 15)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Confirmation Section
    private var confirmationSection: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Confirm Deletion")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            Text("To confirm account deletion, please type \"\(requiredConfirmationText)\" below:")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)

            TextField("Type \(requiredConfirmationText)", text: $confirmationText)
                .textFieldStyle(CustomTextFieldStyle())
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Delete Button
    private var deleteButton: some View {
        Button {
            showingConfirmation = true
        } label: {
            HStack {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                }

                Text(isDeleting ? "Deleting..." : "Delete My Account Forever")
                    .font(.body)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isDeleteButtonEnabled ? Color.red : Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!isDeleteButtonEnabled || isDeleting)
    }

    // MARK: - Helper Views
    private func reasonSelectionRow(reason: DeletionReason) -> some View {
        Button {
            if selectedReasons.contains(reason) {
                selectedReasons.remove(reason)
            } else {
                selectedReasons.insert(reason)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedReasons.contains(reason) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(selectedReasons.contains(reason) ? accentColor : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(reason.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    if let description = reason.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Computed Properties
    private var isDeleteButtonEnabled: Bool {
        confirmationText.uppercased() == requiredConfirmationText
    }

    // MARK: - Functions
    private func deleteAccount() {
        isDeleting = true

        Task {
            do {
                // Submit feedback first
                await submitDeletionFeedback()

                // Then delete the account
                // TODO: Implement actual account deletion through auth service
                try await Task.sleep(nanoseconds: 2_000_000_000) // Simulate network call

                await authService.signOut()
                dismiss()

            } catch {
                // Handle error
                print("Account deletion failed: \(error)")
            }

            isDeleting = false
        }
    }

    private func submitDeletionFeedback() async {
        guard !selectedReasons.isEmpty || !otherFeedback.isEmpty else { return }

        let feedback = DeletionFeedback(
            reasons: Array(selectedReasons),
            additionalFeedback: otherFeedback.trimmingCharacters(in: .whitespacesAndNewlines),
            userId: authService.currentUser?.id ?? "",
            timestamp: Date()
        )

        // TODO: Submit feedback to backend
        print("Submitting deletion feedback: \(feedback)")
    }
}

// MARK: - Models
enum DeletionReason: String, CaseIterable {
    case notUseful = "not_useful"
    case tooExpensive = "too_expensive"
    case foundAlternative = "found_alternative"
    case privacyConcerns = "privacy_concerns"
    case tooComplicated = "too_complicated"
    case missingFeatures = "missing_features"
    case technicalIssues = "technical_issues"
    case temporaryBreak = "temporary_break"
    case other = "other"

    var title: String {
        switch self {
        case .notUseful:
            return "Not useful for my needs"
        case .tooExpensive:
            return "Too expensive"
        case .foundAlternative:
            return "Found a better alternative"
        case .privacyConcerns:
            return "Privacy concerns"
        case .tooComplicated:
            return "Too complicated to use"
        case .missingFeatures:
            return "Missing features I need"
        case .technicalIssues:
            return "Technical issues"
        case .temporaryBreak:
            return "Taking a temporary break"
        case .other:
            return "Other reason"
        }
    }

    var description: String? {
        switch self {
        case .notUseful:
            return "The app doesn't meet my financial management needs"
        case .tooExpensive:
            return "The subscription cost is too high for me"
        case .foundAlternative:
            return "I'm switching to a different app or service"
        case .privacyConcerns:
            return "I'm concerned about how my data is handled"
        case .tooComplicated:
            return "The interface is confusing or hard to navigate"
        case .missingFeatures:
            return "Important features are missing"
        case .technicalIssues:
            return "The app has bugs or performance problems"
        case .temporaryBreak:
            return "I plan to come back later"
        case .other:
            return "Please provide details in the feedback box below"
        }
    }
}

struct DeletionFeedback {
    let reasons: [DeletionReason]
    let additionalFeedback: String
    let userId: String
    let timestamp: Date
}