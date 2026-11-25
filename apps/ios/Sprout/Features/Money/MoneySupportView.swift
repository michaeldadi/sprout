import SwiftUI

struct MoneySupportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var unavailable = false
    private let address = "support@getsprout.io" // Existing Android AppConfig support destination.
    var body: some View {
        NavigationStack {
            MoneyPage(title: "Help & support") {
                MoneyCard {
                    Text("Contact Sprout").font(.title3.bold())
                    Text("Write to the support team using your email app.")
                    Button("Email support") { if let url = URL(string: "mailto:\(address)?subject=Sprout%20support") { openURL(url) { accepted in unavailable = !accepted } } }.buttonStyle(MoneyPrimaryButtonStyle())
                    Text(address).textSelection(.enabled).font(.footnote)
                    if unavailable { Text("No email app is available. Copy the address into your preferred mail service.").font(.footnote) }
                }
                MoneyCard { Text("In-app chat").font(.headline); Text("Chat is awaiting account-identity setup. Email is the contact option for this build.").foregroundStyle(SproutColor.textSecondary) }
                MoneyCard { Text("Your data").font(.headline); Text("Import, export, account deletion and saved-change reviews are available in Profile. Your export includes ready retained receipt copies.").font(.footnote) }
                Text("Sprout \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")").font(.caption).foregroundStyle(SproutColor.textSecondary)
            }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}
