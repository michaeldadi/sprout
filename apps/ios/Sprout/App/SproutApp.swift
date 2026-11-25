//
//  SproutApp.swift
//  Sprout
//
//  Created by Michael Dadi on 8/16/25.
//

import GoogleSignIn
import SwiftData
import SwiftUI

@main
struct SproutApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var deepLinks = DeepLinkManager.shared

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                RootView()
                    .tint(SproutColor.action)
                    .environmentObject(deepLinks)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                deepLinks.handleUniversalLink(userActivity)
            }
            .onOpenURL { url in
                if !GIDSignIn.sharedInstance.handle(url) {
                    deepLinks.handleDeepLink(url)
                }
            }
        }
    }
}
