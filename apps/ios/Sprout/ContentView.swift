//
//  ContentView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/16/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @StateObject private var authService = AuthService.shared
    @State private var showSignUp = false
    @State private var showForgotPassword = false

    var body: some View {
        Group {
            if authService.isAuthenticated {
                // Main authenticated app with liquid glass bottom tabs
                LiquidGlassTabView()
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            } else {
                // Authentication flow
                Group {
                    if showForgotPassword {
                        ForgotPasswordView(showForgotPassword: $showForgotPassword)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom),
                                removal: .move(edge: .bottom)
                            ))
                    } else if showSignUp {
                        SignUpView(showSignUp: $showSignUp)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    } else {
                        LoginView(showSignUp: $showSignUp, showForgotPassword: $showForgotPassword)
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading),
                                removal: .move(edge: .trailing)
                            ))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: showSignUp || showForgotPassword)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: authService.isAuthenticated)
        .task {
            // Check for existing session on app launch
            await authService.checkExistingSession()
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
