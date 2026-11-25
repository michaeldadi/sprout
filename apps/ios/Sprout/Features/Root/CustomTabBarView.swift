//
//  CustomTabBarView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/23/25.
//

import SwiftUI

struct CustomTabBarView: View {
    @Binding var selectedTab: Tab
    @Environment(\.colorScheme) var colorScheme

    private var activeColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.30, green: 0.60, blue: 0.35)
        } else {
            return Color(red: 0.40, green: 0.70, blue: 0.45)
        }
    }

    private var backgroundColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.15, green: 0.25, blue: 0.20).opacity(0.95)
        } else {
            return Color.white
        }
    }

    private var strokeColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.1)
        } else {
            return Color.gray.opacity(0.1)
        }
    }

    var body: some View {
        HStack {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    activeColor: activeColor,
                    action: {
                        withAnimation(.bouncy()) {
                            selectedTab = tab
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 6)
        .frame(width: UIScreen.main.bounds.width - 72, height: 52)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(strokeColor, lineWidth: 1)
        )
        .shadow(
            color: colorScheme == .light ? Color.black.opacity(0.1) : Color.clear,
            radius: colorScheme == .light ? 10 : 0,
            x: 0,
            y: colorScheme == .light ? 5 : 0
        )
    }
}

struct TabBarButton: View {
    let tab: Tab
    let isSelected: Bool
    let activeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.rawValue)
                    .font(.system(size: 20))
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(isSelected ? activeColor : Color.gray)
                    .fontWeight(isSelected ? .bold : .regular)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
            }
        }
    }
}

#Preview {
    CustomTabBarView(selectedTab: .constant(.dashboard))
}
