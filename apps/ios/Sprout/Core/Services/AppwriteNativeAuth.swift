import Appwrite
import AppwriteEnums
import Combine
import CryptoKit
import Foundation
import OSLog

/// Opt-in Debug transport failure for native persistence acceptance. Shipping
/// builds have no argument-controlled failure path.
enum AppwriteTransportTestFault {
    static func check() throws {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-sprout-test-offline") { throw URLError(.notConnectedToInternet) }
        #endif
    }
}

struct AppwriteAccountIdentity: Codable {
    let id: String
    let email: String
    let name: String
    var hasPassword: Bool? = nil
}

/** Native provider tokens are exchanged for an Appwrite session; they are never stored as app credentials. */
@MainActor
enum AppwriteNativeAuth {
    static func signInWithApple(idToken: String, nonce: String, name: String?) async throws -> AppwriteAccountIdentity {
        let account = try AppwriteConnection.account()
        _ = try await account.createIdTokenSession(
            provider: .apple,
            idToken: idToken,
            nonce: nonce,
            name: name
        )
        return try await identity(from: account)
    }

    static func signInWithGoogle(idToken: String, name: String?) async throws -> AppwriteAccountIdentity {
        let account = try AppwriteConnection.account()
        _ = try await account.createIdTokenSession(
            provider: .google,
            idToken: idToken,
            name: name
        )
        return try await identity(from: account)
    }

    static func restore() async throws -> AppwriteAccountIdentity {
        try AppwriteTransportTestFault.check()
        return try await identity(from: AppwriteConnection.account())
    }

    static func signOut() async throws {
        do {
            _ = try await AppwriteConnection.account().deleteSession(sessionId: "current")
            AppwriteConnection.clearSessionCookies()
        } catch let error as AppwriteError where [401, 404].contains(error.code ?? 0) || (error.code == 403 && error.type == "user_blocked") {
            AppwriteConnection.clearSessionCookies()
        }
        // A transport failure leaves the cookie available for the pending
        // revocation on the next sign-in; local identity was already removed.
    }

    private static func identity(from account: Account) async throws -> AppwriteAccountIdentity {
        let user = try await account.get()
        return AppwriteAccountIdentity(id: user.id, email: user.email, name: user.name, hasPassword: !user.passwordUpdate.isEmpty)
    }
}

@MainActor
final class AppwriteNativeSession: ObservableObject {
    static let shared = AppwriteNativeSession()

    @Published private(set) var identity: AppwriteAccountIdentity?
    @Published private(set) var restoring = true

    private init() {}
    private var generation = 0
    private var restoreInFlight = false
    private var cacheKey: String {
        let endpoint = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_ENDPOINT") as? String ?? ""
        let project = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_PROJECT_ID") as? String ?? ""
        return "sprout.identity." + SHA256.hash(data: Data("\(endpoint)/\(project)".utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private func remember(_ value: AppwriteAccountIdentity?) {
        identity = value
        if let value, let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: cacheKey) }
        else { UserDefaults.standard.removeObject(forKey: cacheKey) }
    }
    private func prepareSignIn() async throws {
        generation += 1
        if UserDefaults.standard.bool(forKey: cacheKey + ".signedOut") {
            do { try await AppwriteNativeAuth.signOut() }
            catch let error as AppwriteError where error.code == 401 { /* Session already expired. */ }
        }
    }
    private func signedIn(_ value: AppwriteAccountIdentity) {
        restoring = false; UserDefaults.standard.removeObject(forKey: cacheKey + ".signedOut"); remember(value)
    }

    func restore() async {
        guard !restoreInFlight else { return }
        restoreInFlight = true; defer { restoreInFlight = false }
        guard identity == nil, !UserDefaults.standard.bool(forKey: cacheKey + ".signedOut") else { restoring = false; return }
        restoring = true; defer { restoring = false }
        let attempt = generation
        if let data = UserDefaults.standard.data(forKey: cacheKey), let cached = try? JSONDecoder().decode(AppwriteAccountIdentity.self, from: data) { identity = cached }
        do {
            let restored = try await AppwriteNativeAuth.restore()
            guard generation == attempt else { return }; remember(restored)
        } catch let error as AppwriteError where (400 ..< 500).contains(error.code ?? 0) && ![408, 429].contains(error.code ?? 0) {
            guard generation == attempt else { return }; AppwriteConnection.clearSessionCookies(); remember(nil)
        } catch { /* Keep the prior identity for offline cache access. Every upload still verifies the server session and expected account. */ }
    }

    func signInWithApple(idToken: String, nonce: String, name: String?) async throws {
        try await prepareSignIn(); signedIn(try await AppwriteNativeAuth.signInWithApple(idToken: idToken, nonce: nonce, name: name))
    }

    func signInWithGoogle(idToken: String, name: String?) async throws {
        try await prepareSignIn(); signedIn(try await AppwriteNativeAuth.signInWithGoogle(idToken: idToken, name: name))
    }

    func signOut() async throws {
        AnalyticsManager.shared.setUserId(nil)
        generation += 1; restoring = false; UserDefaults.standard.set(true, forKey: cacheKey + ".signedOut"); remember(nil)
        try await AppwriteNativeAuth.signOut()
    }

    func signIn(email: String, password: String, create: Bool, name: String) async throws {
        var stage = "session preparation"
        do {
            try await prepareSignIn()
            let account = try AppwriteConnection.account()
            if create { stage = "account creation"; _ = try await account.create(userId: ID.unique(), email: email, password: password, name: name) }
            stage = "email session"
            _ = try await account.createEmailPasswordSession(email: email, password: password)
            stage = "identity verification"
            signedIn(try await AppwriteNativeAuth.restore())
        } catch {
            #if DEBUG
            let logger = Logger(subsystem: "com.michaeldadi.Sprout", category: "authentication")
            if let error = error as? AppwriteError {
                let field = ["email", "password", "name", "userId", "duration"].first { error.message.contains("`\($0)`") } ?? "unspecified"
                logger.error("Authentication error: \(stage, privacy: .public), code \(error.code ?? 0, privacy: .public), type \(error.type ?? "unknown", privacy: .public), field \(field, privacy: .public)")
            }
            else { logger.error("Authentication error: \(stage, privacy: .public), transport or local failure") }
            #endif
            throw error
        }
    }
}
