//
//  MainTabView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @EnvironmentObject private var authService: AuthService
    @State private var selectedTab: Tab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(onViewActivity: { selectedTab = .transactions })
                .tabItem { Label(Tab.dashboard.title, systemImage: Tab.dashboard.rawValue) }
                .tag(Tab.dashboard)
            BudgetView()
                .tabItem { Label(Tab.budget.title, systemImage: Tab.budget.rawValue) }
                .tag(Tab.budget)
            TransactionsView()
                .tabItem { Label(Tab.transactions.title, systemImage: Tab.transactions.rawValue) }
                .tag(Tab.transactions)
            ProfileView()
                .tabItem { Label(Tab.profile.title, systemImage: Tab.profile.rawValue) }
                .tag(Tab.profile)
        }
        .sheet(isPresented: $deepLinkManager.showingSupportChat) {
            SupportChatView()
        }
        .onChange(of: deepLinkManager.selectedTab) { oldValue, newValue in
            // Sync with deep link manager
            if let tab = Tab.fromIndex(newValue) {
                selectedTab = tab
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Update deep link manager when tab changes
            deepLinkManager.selectedTab = newValue.index
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated { deepLinkManager.processPendingDeepLinkIfNeeded() }
        }
        .onAppear {
            // Process any pending deep link after authentication
            deepLinkManager.processPendingDeepLinkIfNeeded()

            // Sync initial tab from deep link manager
            if let tab = Tab.fromIndex(deepLinkManager.selectedTab) {
                selectedTab = tab
            }
        }
    }
}
