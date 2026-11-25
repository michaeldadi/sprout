//
//  AuthenticationView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import SwiftUI

struct AuthenticationView: View {
    @State private var showSignUp = false
    @State private var showForgotPassword = false

    var body: some View {
        ZStack {
            if !showSignUp && !showForgotPassword {
              LoginView(showSignUp: Binding(
                  get: { showSignUp },
                  set: { newValue in
                      withAnimation(.easeInOut(duration: 0.3)) {
                          showSignUp = newValue
                      }
                  }
              ), showForgotPassword: Binding(
                  get: { showForgotPassword },
                  set: { newValue in
                      withAnimation(.easeInOut(duration: 0.3)) {
                          showForgotPassword = newValue
                      }
                  }
              ))
              .transition(.asymmetric(
                  insertion: .move(edge: .leading),
                  removal: .move(edge: .leading)
              ))
            }

            if showSignUp {
                SignUpView(showSignUp: Binding(
                    get: { showSignUp },
                    set: { newValue in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSignUp = newValue
                        }
                    }
                ))
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
            }

            if showForgotPassword {
                ForgotPasswordView(showForgotPassword: Binding(
                    get: { showForgotPassword },
                    set: { newValue in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showForgotPassword = newValue
                        }
                    }
                ))
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom),
                    removal: .move(edge: .bottom)
                ))
            }
        }
    }
}

#Preview {
    AuthenticationView()
}
