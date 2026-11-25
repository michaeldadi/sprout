//
//  ProfileView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/23/25.
//

import SwiftUI

public struct ProfileView: View {
  @State private var displaySettings = false

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          Text("Account Details")
      }
    }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Profile")
      .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
              Button(action: {
                  displaySettings = true
              }) {
                  Image(systemName: "gearshape.fill")
                      .font(.system(size: 18))
                      .foregroundColor(Color(.accent))
              }
          }
      }
      .sheet(isPresented: $displaySettings) {
          SettingsView()
      }
    }
  }
}
