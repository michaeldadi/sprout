import LinkKit
import SwiftUI

struct MoneyBankConnectionView: View {
    @EnvironmentObject private var store: MoneyStore
    @State private var token: String?
    @State private var presented = false
    @State private var busy = false
    @State private var message: String?
    @State private var repairID: String?
    @State private var requestID = UUID().uuidString.lowercased()

    var body: some View {
        if let token {
            content.plaidLink(isPresented: $presented, token: token, onSuccess: { success in
                presented = false
                Task { await exchange(success.publicToken) }
            }, onExit: { exit in
                presented = false; busy = false
                message = exit.error == nil ? "Bank linking was closed. You can continue with manual tracking." : "The bank connection did not complete. Try again or continue with manual tracking."
            }, onEvent: nil, onLoad: nil, errorView: AnyView(Text("Bank linking could not open. Try again.")))
        } else {
            content
        }
    }

    private var content: some View {
        MoneyPage(title: "Linked accounts") {
            MoneyInsightPill(text: "Read-only bank access. You choose what to connect.")
            MoneyCard {
                Text("A clearer picture, with less work.").font(.title2.bold())
                Text("Your plan includes \(store.workspace?.entitlements.connectionLimit ?? 1) live bank connection(s). One connection may contain several accounts.").foregroundStyle(SproutColor.textSecondary)
                Button("Connect a bank") { Task { await begin() } }.buttonStyle(MoneyPrimaryButtonStyle()).disabled(busy || store.workspace?.capabilities.linking != true)
                if store.workspace?.capabilities.linking != true {
                    Text("Bank linking has not been enabled for this environment.").font(.footnote)
                }
            }
            ForEach(store.workspace?.connections ?? []) { connection in
                MoneyCard {
                    LabeledContent("Connection", value: connection.data.status.capitalized)
                    Text(connection.data.status == "ready" ? "Historical ingestion completed. Bank freshness still depends on the institution." : "Token exchange and historical import are separate steps. Importing can continue after you leave this screen.").font(.footnote)
                    Button("Repair this connection") { Task { await begin(connection.id) } }.disabled(busy)
                }
            }
            if busy {
                ProgressView("Connecting securely…")
            }
            if let message {
                Text(message).font(.footnote).foregroundStyle(SproutColor.textSecondary)
            }
            Button("Refresh connection status") { Task { await store.refresh() } }
        }
    }

    private func begin(_ connectionID: String? = nil) async {
        busy = true; message = nil; repairID = connectionID; requestID = UUID().uuidString.lowercased()
        do {
            var body: [String: Any] = ["platform": "ios"]
            if let connectionID {
                body["connectionId"] = connectionID
            }
            let result = try await store.request(path: connectionID == nil ? "/v1/bank/link-token" : "/v1/bank/repair", body: JSONSerialization.data(withJSONObject: body))
            let value = try JSONSerialization.jsonObject(with: result) as? [String: Any]
            guard let value = value?["link_token"] as? String else { throw MoneyAPIError(code: "LINK_TOKEN", message: "Bank linking could not start.") }
            token = value; presented = true
        } catch { message = error.localizedDescription; busy = false }
    }

    private func exchange(_ publicToken: String) async {
        do {
            let body: [String: Any] = repairID.map { ["connectionId": $0, "requestId": requestID] } ?? ["publicToken": publicToken, "requestId": requestID]
            _ = try await store.request(path: repairID == nil ? "/v1/bank/exchange" : "/v1/bank/repaired", body: JSONSerialization.data(withJSONObject: body))
            message = "Connected. Historical import will continue in the background."
            await store.refresh()
        } catch { message = error.localizedDescription }
        busy = false; token = nil
    }
}
