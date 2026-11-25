import Foundation
import AppIntents
import SwiftUI

@MainActor
class SiriShortcutsService: ObservableObject {
    static let shared = SiriShortcutsService()

    @Published var availableShortcuts: [SproutShortcut] = []

    private init() {
        setupAvailableShortcuts()
    }

    private func setupAvailableShortcuts() {
        availableShortcuts = []
    }

    // For iOS 16+ App Intents
    @available(iOS 16.0, *)
    func updateShortcuts() {
        // Financial intents stay hidden until their data source is implemented.
    }
}

struct SproutShortcut: Identifiable {
    let id = UUID()
    let identifier: String
    let title: String
    let subtitle: String
    let systemImageName: String
    let suggestedPhrase: String
}

// MARK: - SwiftUI View
struct SiriShortcutsView: View {
    @StateObject private var siriService = SiriShortcutsService.shared

    var body: some View {
        NavigationView {
            listContent
        }
    }

    @ViewBuilder
    private var listContent: some View {
        List {
            Section {
                Text("Voice shortcuts for financial data are unavailable in this build.")
            }
        }
        .navigationTitle("Siri Shortcuts")
    }

    private func openShortcutsApp() {
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
    }
}

struct ShortcutRow: View {
    let shortcut: SproutShortcut

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: shortcut.systemImageName)
                .font(.title2)
                .foregroundStyle(.green.gradient)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(shortcut.title)
                    .font(.headline)

                Text(shortcut.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\"Hey Siri, \(shortcut.suggestedPhrase)\"")
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .italic()
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
