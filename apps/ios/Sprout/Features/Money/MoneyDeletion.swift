import Appwrite
import AppwriteEnums
import Combine
import CryptoKit
import Foundation
import Security
import SwiftUI

struct MoneyDeletionReceipt: Codable {
    var owner: String
    var requestId: String
    var receipt: String
    var accepted: Bool
}
enum MoneyDeletionReceiptRead {
    static func decode(status: OSStatus, data: Data?) throws -> MoneyDeletionReceipt? {
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data,
              let saved = try? JSONDecoder().decode(MoneyDeletionReceipt.self, from: data),
              !saved.owner.isEmpty, UUID(uuidString: saved.requestId) != nil,
              saved.receipt.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil else {
            throw MoneyAPIError(code: "PRIVACY_RECEIPT", message: "Your private progress receipt could not be opened. Unlock this device and retry. Contact support if the issue continues; financial screens remain hidden.")
        }
        return saved
    }
}

struct MoneyDeletionProgress: Decodable {
    struct Steps: Decodable { var accessRevoked: Bool; var attachmentsRemoved: Bool; var financialRecordsRemoved: Bool; var identityAnonymized: Bool }
    var status: String
    var acceptedAt: String
    var updatedAt: String
    var steps: Steps
    var error: String?
    var retained: [String]
}

@MainActor final class MoneyDeletionState: ObservableObject {
    static let shared = MoneyDeletionState()
    @Published private(set) var active: MoneyDeletionReceipt?
    @Published private(set) var progress: MoneyDeletionProgress?
    @Published private(set) var message: String?
    @Published private(set) var localCleanupIssue = false
    @Published private(set) var blocked = false
    @Published private(set) var needsAuthentication = false
    @Published private(set) var submitting = false
    private var pending: MoneyDeletionReceipt?
    private let service: String
    private var account: String {
        let project = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_PROJECT_ID") as? String ?? ""
        let endpoint = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_ENDPOINT") as? String ?? ""
        return SHA256.hash(data: Data("\(endpoint)/\(project)".utf8)).map { String(format: "%02x", $0) }.joined()
    }
    init(service: String = "com.michaeldadi.Sprout.privacy-receipt") { self.service = service; reloadReceipt() }
    func reloadReceipt() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true]
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        do {
            let saved = try MoneyDeletionReceiptRead.decode(status: status, data: value as? Data)
            pending = saved; active = saved
            blocked = false; message = nil
        } catch { blocked = true; message = error.localizedDescription }
    }
    private func persist(_ value: MoneyDeletionReceipt) throws {
        let data = try JSONEncoder().encode(value)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecItemNotFound {
            var add = query; add[kSecValueData as String] = data; add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { throw MoneyAPIError(code: "PRIVACY_RECEIPT", message: "Your private progress receipt could not be saved. Try again before requesting deletion.") }
        } else if update != errSecSuccess { throw MoneyAPIError(code: "PRIVACY_RECEIPT", message: "Your private progress receipt could not be saved.") }
        pending = value
    }
    func prepare(owner: String) throws -> MoneyDeletionReceipt {
        guard !blocked else { throw MoneyAPIError(code: "PRIVACY_RECEIPT", message: "Your previous privacy receipt needs review before another request can be created.") }
        if let pending { guard pending.owner == owner else { throw MoneyAPIError(code: "PRIVACY_RECEIPT", message: "A previous privacy request needs review.") }; return pending }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw MoneyAPIError(code: "PRIVACY_RECEIPT", message: "Could not create a private progress receipt.") }
        let token = Data(bytes).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let value = MoneyDeletionReceipt(owner: owner, requestId: UUID().uuidString.lowercased(), receipt: token, accepted: false); try persist(value); active = value; return value
    }
    func retrySubmission(email: String? = nil, password: String? = nil) async {
        guard !submitting, let saved = pending, !saved.accepted else { return }
        submitting = true; defer { submitting = false }
        // Check the anonymous receipt first: a lost response may already have revoked this session.
        await refresh()
        guard pending?.accepted != true else { return }
        do {
            if let email, let password { try await AppwriteNativeSession.shared.signIn(email: email, password: password, create: false, name: "") }
            let identity: AppwriteAccountIdentity
            do { identity = try await AppwriteNativeAuth.restore() }
            catch { if let error = error as? AppwriteError, [401, 403].contains(error.code ?? 0) { needsAuthentication = true }; throw error }
            guard identity.id == saved.owner else {
                try? await AppwriteNativeSession.shared.signOut()
                needsAuthentication = true
                message = "Sign in to the account that requested deletion. This receipt cannot affect another account."
                return
            }
            needsAuthentication = false
            let body = try JSONSerialization.data(withJSONObject: ["type": "delete", "requestId": saved.requestId, "receipt": saved.receipt, "_account": saved.owner])
            let result = try await Functions(AppwriteConnection.client()).createExecution(functionId: "sprout-api", body: String(decoding: body, as: UTF8.self), async: false, path: "/v1/privacy", method: .pOST, headers: ["x-sprout-account": saved.owner])
            guard (200 ..< 300).contains(result.responseStatusCode) else {
                throw MoneyAPIError(code: "PRIVACY_PENDING", message: "Sprout has not confirmed acceptance. Retry this saved request; financial screens remain hidden.")
            }
            try accept(saved)
            await refresh()
        } catch {
            message = needsAuthentication ? "Sign in again to retry this saved deletion request. If access was already revoked, refresh progress instead." : "Acceptance could not be confirmed. Your original request is saved; retry when connected."
        }
    }
    func accept(_ receipt: MoneyDeletionReceipt) throws {
        var value = receipt; value.accepted = true; try persist(value); active = value
        do { try MoneyStore.eraseLocal(owner: value.owner) } catch { localCleanupIssue = true }
    }
    func refresh() async {
        guard let saved = pending else { return }
        if saved.accepted { do { try MoneyStore.eraseLocal(owner: saved.owner); localCleanupIssue = false } catch { localCleanupIssue = true } }
        do {
            let endpoint = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_ENDPOINT") as? String ?? ""
            let project = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_PROJECT_ID") as? String ?? ""
            guard let url = URL(string: endpoint + "/functions/sprout-privacy-status/executions") else { return }
            var request = URLRequest(url: url); request.httpMethod = "POST"; request.httpShouldHandleCookies = false; request.timeoutInterval = 20
            request.setValue(project, forHTTPHeaderField: "X-Appwrite-Project"); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = try JSONSerialization.data(withJSONObject: ["receipt": saved.receipt])
            request.httpBody = try JSONSerialization.data(withJSONObject: ["async": false, "method": "POST", "path": "/", "body": String(decoding: body, as: UTF8.self)])
            let session = URLSession(configuration: .ephemeral); defer { session.invalidateAndCancel() }
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 201, let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any], let status = envelope["responseStatusCode"] as? Int, status == 200, let text = envelope["responseBody"] as? String else { throw MoneyAPIError(code: "PRIVACY_PROGRESS", message: "Progress is temporarily unavailable. Your receipt is saved on this device.") }
            progress = try JSONDecoder().decode(MoneyDeletionProgress.self, from: Data(text.utf8)); message = nil
            if !saved.accepted { try accept(saved) }
        } catch { message = "Progress is temporarily unavailable. Your receipt is saved on this device." }
    }
    func dismissCompleted() {
        guard progress?.status == "active_data_removed", let saved = active, saved.accepted else { return }
        do { try MoneyStore.eraseLocal(owner: saved.owner); localCleanupIssue = false }
        catch { localCleanupIssue = true; message = "Local cached records could not be removed. Retry cleanup before returning to welcome."; return }
        let status = SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { message = "Your completed receipt could not be cleared. Unlock this device and try again."; return }
        active = nil; pending = nil; progress = nil; message = nil
    }
}

struct MoneyDeletionProgressView: View {
    @ObservedObject private var state = MoneyDeletionState.shared
    @Environment(\.scenePhase) private var phase
    var body: some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 24) {
                Text("Account deletion").font(.largeTitle.bold())
                Text(state.active?.accepted == true ? "Your request was accepted. New financial work is stopped." : "Your deletion request is saved on this device. Waiting for the server to confirm acceptance; financial screens remain hidden.")
                if let progress = state.progress {
                    Text(progress.status == "active_data_removed" ? "Active financial data removed" : progress.status.replacingOccurrences(of: "_", with: " ").capitalized).font(.title2.bold()).accessibilityIdentifier("privacy.deletionStatus")
                    MoneyCard {
                        Label("Account access revoked", systemImage: progress.steps.accessRevoked ? "checkmark.circle.fill" : "clock")
                        Label("Private attachments removed", systemImage: progress.steps.attachmentsRemoved ? "checkmark.circle.fill" : "clock")
                        Label("Financial records removed", systemImage: progress.steps.financialRecordsRemoved ? "checkmark.circle.fill" : "clock")
                        Label("Identity anonymized", systemImage: progress.steps.identityAnonymized ? "checkmark.circle.fill" : "clock")
                    }
                    if progress.status == "needs_attention" { Text("This request needs support before the remaining steps can finish.") }
                    ForEach(progress.retained, id: \.self) { Text($0).font(.footnote).foregroundStyle(SproutColor.textSecondary) }
                    if progress.status == "active_data_removed" { Button("Return to welcome") { state.dismissCompleted() }.buttonStyle(MoneyPrimaryButtonStyle()).disabled(state.active?.accepted != true) }
                } else { ProgressView("Checking progress…") }
                if state.localCleanupIssue { Text("Server deletion continues. Local cached records need cleanup on this device. Restart Sprout or contact support.").font(.footnote) }
                if let message = state.message { Text(message).font(.footnote) }
                Button("Refresh deletion progress") { Task { await state.refresh() } }
                if state.active?.accepted == false { MoneyDeletionRetryView() }
            }.padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity, alignment: .center) }.background(SproutColor.canvas).foregroundStyle(SproutColor.textPrimary)
        }.task(id: phase) { if phase == .active { await state.retrySubmission(); for _ in 0 ..< 120 { if state.active?.accepted == true { try? await AppwriteNativeSession.shared.signOut() }; await state.refresh(); if ["active_data_removed", "needs_attention"].contains(state.progress?.status ?? "") { break }; try? await Task.sleep(for: .seconds(5)); if Task.isCancelled { break } } } }
    }
}

private struct MoneyDeletionRetryView: View {
    @ObservedObject private var state = MoneyDeletionState.shared
    @State private var email = ""
    @State private var password = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if state.needsAuthentication {
                TextField("Account email", text: $email).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Password", text: $password).textContentType(.password)
            }
            Button("Retry original deletion request") { Task {
                let secret = password; password = ""
                await state.retrySubmission(email: state.needsAuthentication ? email : nil, password: state.needsAuthentication ? secret : nil)
            } }.disabled(state.submitting || (state.needsAuthentication && (email.isEmpty || password.isEmpty)))
        }
    }
}

struct MoneyDeletionRecoveryView: View {
    @ObservedObject private var state = MoneyDeletionState.shared
    @State private var retrying = false
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Privacy receipt needs attention", systemImage: "lock.shield")
            } description: {
                Text(state.message ?? "Your private progress receipt could not be opened. Financial screens remain hidden.")
            } actions: {
                Button("Retry private receipt") { Task {
                    retrying = true; defer { retrying = false }
                    state.reloadReceipt()
                    guard !state.blocked else { return }
                    await state.refresh()
                    if state.active?.accepted == true { try? await AppwriteNativeSession.shared.signOut() }
                    else if state.active == nil { await AppwriteNativeSession.shared.restore() }
                } }.disabled(retrying).buttonStyle(MoneyPrimaryButtonStyle())
            }.background(SproutColor.canvas)
        }
    }
}
