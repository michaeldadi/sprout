#if DEBUG
import SwiftUI

/// Isolated native review surface. It mounts actual shared controls with fictional data.
struct FoundationReviewView: View {
    @State private var dark = false
    @State private var selected = false
    @State private var search = ""
    @State private var showError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SproutSpacing.md) {
                Text("Sprout foundations").font(SproutType.screenTitle)
                Text("DEMO DATA • 8 Nov 2026 • USD • no account connected")
                    .font(SproutType.label).foregroundStyle(SproutColor.textSecondary)
                Toggle("Dark theme", isOn: $dark).tint(SproutColor.action)
                Divider()
                Text("Existing shared auth control").font(SproutType.sectionTitle)
                SocialLoginButton(icon: "apple.logo", text: "Continue with Apple",
                                  backgroundColor: .white, textColor: .black)
                Text("Semantic actions").font(SproutType.sectionTitle)
                SproutActionButton(title: "Review activity", action: { selected.toggle() })
                SproutActionButton(title: "Selected: \(selected ? "yes" : "no")", role: .secondary,
                                   action: { selected.toggle() })
                SproutActionButton(title: "Unavailable action", isEnabled: false, action: {})
                SproutActionButton(title: "Loading action", isBusy: true, action: {})
                SproutActionButton(title: "Destructive example", role: .destructive, action: {})
                Text("Amounts and long rows").font(SproutType.sectionTitle)
                SproutAmountText(amount: Decimal(string: "1245600.25"), currencyCode: "USD", isLarge: true)
                SproutTransactionRow(title: "A fictional merchant with a very long descriptive name",
                                     detail: "8 Nov • Possible recurring payment",
                                     amount: Decimal(string: "-12456.78"), currencyCode: "USD",
                                     status: "Sync pending", isSelected: selected, action: { selected.toggle() })
                SproutTransactionRow(title: "Unknown amount", detail: "No verified balance",
                                     amount: nil, currencyCode: "USD", isEnabled: false, action: {})
                Text("Input and feedback").font(SproutType.sectionTitle)
                SproutInputField(title: "Search activity", placeholder: "Merchant", text: $search,
                                 helper: "Try a fictional merchant", error: showError ? "Enter a search term" : nil)
                SproutActionButton(title: "Toggle validation", role: .quiet, action: { showError.toggle() })
                SproutStatusBanner(title: "Some data needs review",
                                   detail: "A fictional account has not synced yet.", kind: .warning)
                SproutStatusBanner(title: "Could not refresh",
                                   detail: "Try again when a connection is available.", kind: .error)
                SproutStatePanel(title: "No activity yet",
                                 detail: "A connected account would show verified transactions here.")
                SproutStatePanel(title: "Loading activity", detail: "Waiting for a response.", isLoading: true)
            }
            .padding(.horizontal, SproutSpacing.screen)
            .padding(.vertical, SproutSpacing.lg)
        }
        .background(SproutColor.canvas.ignoresSafeArea())
        .preferredColorScheme(dark ? .dark : .light)
    }
}

#Preview("Foundations") { FoundationReviewView() }
#endif
