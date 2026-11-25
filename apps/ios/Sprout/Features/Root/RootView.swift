//
//  RootView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import SwiftUI

struct RootView: View {
    @State private var bootstrapped = false
    @StateObject private var deletion = MoneyDeletionState.shared
    @StateObject private var appwriteSession = AppwriteNativeSession.shared

    @ViewBuilder var body: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-money-design-review") { MoneyDesignReviewView() }
        else { authenticatedBody }
        #else
        authenticatedBody
        #endif
    }

    private var authenticatedBody: some View {
        ZStack {
            if deletion.blocked { MoneyDeletionRecoveryView() }
            else if deletion.active != nil {
                MoneyDeletionProgressView()
            } else if let identity = appwriteSession.identity {
                MoneyAppView(identity: identity).id(identity.id)
            } else if appwriteSession.restoring {
                ProgressView("Opening Sprout…").frame(maxWidth: .infinity, maxHeight: .infinity).background(SproutColor.canvas)
            } else {
                MoneyWelcomeView()
            }
        }
        .task {
            guard !bootstrapped else { return }; bootstrapped = true
            guard !deletion.blocked else { return }
            await deletion.refresh()
            if deletion.active?.accepted == true {
                if let owner = deletion.active?.owner { try? MoneyStore.eraseLocal(owner: owner) }
                try? await appwriteSession.signOut()
            } else if deletion.active == nil { await appwriteSession.restore() }
        }
    }
}

private struct AppwriteAccountGateView: View {
    let identity: AppwriteAccountIdentity
    @State private var signOutError: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.largeTitle)
            Text("Signed in to Sprout")
                .font(.title2.bold())
            Text(identity.email)
                .font(.subheadline)
            Text("Your financial data isn't available in this build yet.")
                .multilineTextAlignment(.center)
            if let signOutError {
                Text(signOutError).foregroundStyle(.red)
            }
            Button("Sign out") {
                Task {
                    do {
                        try await AppwriteNativeSession.shared.signOut()
                    } catch {
                        signOutError = "Could not sign out. Try again."
                    }
                }
            }
        }
        .padding(24)
    }
}
