#if DEBUG
    import SwiftUI

    /// Explicit fictional, read-only native review. Never selected in a release build.
    struct MoneyDesignReviewView: View {
        private var frame: String {
            ProcessInfo.processInfo.environment["SPROUT_MONEY_REVIEW_FRAME"] ?? "home"
        }

        var body: some View {
            Group {
                if frame == "welcome" {
                    MoneyWelcomeView()
                } else {
                    MoneyAppView(review: fixture, tab: tab, route: route, expense: frame == "add-expense")
                }
            }
            .environmentObject(DeepLinkManager.shared)
            .preferredColorScheme(ProcessInfo.processInfo.environment["SPROUT_MONEY_REVIEW_DARK"] == "true" ? .dark : nil)
            .overlay(alignment: .top) { Text("FICTIONAL DESIGN REVIEW").font(.system(size: 9, weight: .bold)).padding(4).background(.yellow.opacity(0.85)).allowsHitTesting(false).accessibilityIdentifier("money.designReview") }
        }

        private var fixture: MoneyWorkspace {
            var value = MoneyDesignFixture.workspace
            if ["connect-bank", "subscriptions-found", "your-plan"].contains(frame) {
                value.profile.onboarding = frame
            }
            if ProcessInfo.processInfo.environment["SPROUT_MONEY_REVIEW_DARK"] == "true" {
                value.profile.appearance = "dark"
            }
            return value
        }

        private var tab: MoneyTab {
            switch frame { case "budget": .budget; case "activity": .activity; case "subscriptions", "subscription-detail", "insights": .insights; case "profile": .profile; default: .home }
        }

        private var route: MoneyRoute? {
            switch frame { case "subscriptions": .subscriptions; case "subscription-detail": fixture.subscriptions.first.map { .subscription($0.id) }; default: nil }
        }
    }
#endif
