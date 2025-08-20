//
//  LiquidGlassTabBar.swift
//  Sprout
//
//  Created by Claude on 8/20/25.
//

import SwiftUI

struct LiquidGlassTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [TabItem]
    
    @State private var activeTabFrame: CGRect = .zero
    @State private var backgroundOpacity: Double = 0.0
    @Namespace private var tabSelection
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Liquid glass background
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.25),
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // Active tab indicator with liquid morphing effect
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.2)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 80, height: 56)
                    .offset(
                        x: {
                            let tabWidth = (geometry.size.width - 72) / CGFloat(tabs.count) // Account for total horizontal padding
                            let centerOffset = tabWidth * CGFloat(selectedTab)
                            let startingOffset = -(geometry.size.width - 72) / 2 + tabWidth / 2
                            return startingOffset + centerOffset
                        }()
                    )
                    .animation(
                        .interactiveSpring(
                            response: 0.6,
                            dampingFraction: 0.7
                        ),
                        value: selectedTab
                    )
                
                // Tab buttons
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        Button(action: {
                            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7)) {
                                selectedTab = index
                            }
                        }) {
                            VStack(spacing: 4) {
                                // Icon with liquid scale animation
                                Image(systemName: selectedTab == index ? tab.selectedIcon : tab.icon)
                                    .font(.system(size: 22, weight: .medium, design: .rounded))
                                    .foregroundStyle(
                                        selectedTab == index ?
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.2, green: 0.8, blue: 0.4),
                                                Color(red: 0.1, green: 0.6, blue: 0.3)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.primary.opacity(0.6),
                                                Color.primary.opacity(0.4)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .scaleEffect(selectedTab == index ? 1.2 : 1.0)
                                    .animation(
                                        .interactiveSpring(
                                            response: 0.4,
                                            dampingFraction: 0.6
                                        ),
                                        value: selectedTab
                                    )
                                
                                // Label with liquid fade
                                if selectedTab == index {
                                    Text(tab.title)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(red: 0.2, green: 0.8, blue: 0.4),
                                                    Color(red: 0.1, green: 0.6, blue: 0.3)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .transition(.asymmetric(
                                            insertion: .scale.combined(with: .opacity),
                                            removal: .scale.combined(with: .opacity)
                                        ))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(LiquidTabButtonStyle())
                        .background(
                            GeometryReader { tabGeometry in
                                Color.clear
                                    .preference(
                                        key: TabFramePreferenceKey.self,
                                        value: [index: tabGeometry.frame(in: .named("TabBarContainer"))]
                                    )
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 80)
            .padding(.horizontal, 20)
            .coordinateSpace(name: "TabBarContainer")
            .onPreferenceChange(TabFramePreferenceKey.self) { frames in
                if let frame = frames[selectedTab] {
                    activeTabFrame = frame
                }
            }
        }
        .frame(height: 80)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                backgroundOpacity = 1.0
            }
        }
    }
}

// MARK: - Supporting Types

struct TabItem {
    let icon: String
    let selectedIcon: String
    let title: String
    let content: AnyView
    
    init<Content: View>(
        icon: String,
        selectedIcon: String? = nil,
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.selectedIcon = selectedIcon ?? icon + ".fill"
        self.title = title
        self.content = AnyView(content())
    }
}

struct LiquidTabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct TabFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Main Tab Container View

struct LiquidGlassTabView: View {
    @State private var selectedTab = 0
    @StateObject private var authService = AuthService.shared
    
    let tabs: [TabItem] = [
        TabItem(icon: "house", title: "Home") {
            HomeTabView()
        },
        TabItem(icon: "chart.line.uptrend.xyaxis", title: "Analytics") {
            AnalyticsTabView()
        },
        TabItem(icon: "plus.circle", selectedIcon: "plus.circle.fill", title: "Create") {
            CreateTabView()
        },
        TabItem(icon: "bell", title: "Notifications") {
            NotificationsTabView()
        },
        TabItem(icon: "person.circle", title: "Profile") {
            ProfileTabView()
        }
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background with subtle gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.98, blue: 0.95),
                    Color(red: 0.92, green: 0.96, blue: 0.92)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Content area
            tabs[selectedTab].content
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.8), value: selectedTab)
            
            // Liquid glass tab bar
            VStack {
                Spacer()
                LiquidGlassTabBar(selectedTab: $selectedTab, tabs: tabs)
                    .padding(.bottom, 34) // Safe area padding
            }
        }
    }
}

// MARK: - Tab Content Views (Placeholder implementations)

struct HomeTabView: View {
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Welcome header with glassmorphism
                    VStack(spacing: 12) {
                        Text("Welcome to Sprout 🌱")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.2, green: 0.8, blue: 0.4),
                                        Color(red: 0.1, green: 0.6, blue: 0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        if let user = authService.currentUser {
                            Text("Hello, \(user.email)!")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 40)
                    
                    // Quick actions with glass cards
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(quickActions, id: \.title) { action in
                            QuickActionCard(action: action)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 100) // Space for tab bar
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private var quickActions: [QuickAction] {
        [
            QuickAction(icon: "leaf.fill", title: "Track Growth", color: .green),
            QuickAction(icon: "chart.bar.fill", title: "View Stats", color: .blue),
            QuickAction(icon: "camera.fill", title: "Take Photo", color: .purple),
            QuickAction(icon: "note.text", title: "Add Note", color: .orange)
        ]
    }
}

struct QuickAction {
    let icon: String
    let title: String
    let color: Color
}

struct QuickActionCard: View {
    let action: QuickAction
    
    var body: some View {
        Button(action: {}) {
            VStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(action.color)
                
                Text(action.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AnalyticsTabView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Analytics")
                    .font(.largeTitle)
                    .bold()
                Text("Your growth analytics will appear here")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Analytics")
        }
    }
}

struct CreateTabView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Create")
                    .font(.largeTitle)
                    .bold()
                Text("Add new content here")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Create")
        }
    }
}

struct NotificationsTabView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Notifications")
                    .font(.largeTitle)
                    .bold()
                Text("Your notifications will appear here")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Notifications")
        }
    }
}

struct ProfileTabView: View {
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Profile header
                VStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    if let user = authService.currentUser {
                        Text(user.email)
                            .font(.title2)
                            .bold()
                    }
                }
                .padding(.top)
                
                Spacer()
                
                // Sign out button
                Button(action: {
                    Task {
                        await authService.signOut()
                    }
                }) {
                    Text("Sign Out")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 100) // Space for tab bar
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    LiquidGlassTabView()
}
