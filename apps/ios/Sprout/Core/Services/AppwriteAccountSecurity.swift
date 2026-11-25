import Foundation

/// Password operations use a verified, short-lived JWT and an isolated cookie-free
/// connection. Switching the app's session cannot retarget an in-flight update.
@MainActor
final class AppwriteAccountSecurity {
    private let owner: String
    private let token: String
    private let endpoint: URL
    private let project: String
    private let transport: URLSession
    private init(owner: String, token: String, endpoint: URL, project: String) {
        self.owner = owner; self.token = token; self.endpoint = endpoint; self.project = project
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false; config.httpCookieStorage = nil; config.urlCache = nil
        config.timeoutIntervalForRequest = 20; config.timeoutIntervalForResource = 30
        transport = URLSession(configuration: config, delegate: AccountSecurityNoRedirect(), delegateQueue: nil)
    }
    deinit { transport.invalidateAndCancel() }
    static func verified(owner: String) async throws -> AppwriteAccountSecurity {
        guard AppwriteNativeSession.shared.identity?.id == owner else { throw failure("Sign in to this account again.") }
        let jwt = try await AppwriteConnection.account().createJWT()
        let endpoint = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_ENDPOINT") as? String ?? "", project = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_PROJECT_ID") as? String ?? ""
        guard let url = URL(string: endpoint), url.scheme == "https", url.path == "/v1" else { throw failure("Account security is unavailable in this build.") }
        let session = AppwriteAccountSecurity(owner: owner, token: jwt.jwt, endpoint: url, project: project)
        let facts = try await session.call(method: "GET", path: "account")
        guard let updated = facts["passwordUpdate"] as? String, !updated.isEmpty else { throw failure("This account does not have a password credential.") }
        return session
    }
    func changePassword(current: String, new: String) async throws {
        guard AppwriteNativeSession.shared.identity?.id == owner else { throw Self.failure("The signed-in account changed. Reopen account security.") }
        _ = try await call(method: "PATCH", path: "account/password", body: ["oldPassword": current, "password": new])
    }
    private func call(method: String, path: String, body: [String: String]? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: endpoint.appendingPathComponent(path)); request.httpMethod = method
        request.setValue(project, forHTTPHeaderField: "X-Appwrite-Project"); request.setValue(token, forHTTPHeaderField: "X-Appwrite-JWT"); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let data: Data, response: URLResponse
        do { (data, response) = try await transport.data(for: request) }
        catch { throw Self.failure(method == "PATCH" ? "The password update could not be confirmed. Try signing in with your new password before making another change." : "Connect to Sprout to verify your account security.") }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let kind = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["type"] as? String ?? ""
            throw Self.failure(kind.hasPrefix("user_jwt") || kind == "user_session_not_found" ? "Your session expired. Sign in again." : "The change was not confirmed. Check your current password and your account's password requirements, then retry.")
        }
        guard let facts = try JSONSerialization.jsonObject(with: data) as? [String: Any], facts["$id"] as? String == owner else { throw Self.failure("Account ownership could not be verified.") }
        return facts
    }
    private static func failure(_ message: String) -> NSError { NSError(domain: "SproutAccountSecurity", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}
private final class AccountSecurityNoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
