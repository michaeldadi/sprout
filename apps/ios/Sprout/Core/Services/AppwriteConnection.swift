import Appwrite
import Foundation

@MainActor
enum AppwriteConnection {
    private static var configuredClient: Client?

    static func client() throws -> Client {
        if let configuredClient { return configuredClient }
        guard let endpoint = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_ENDPOINT") as? String,
              let projectID = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_PROJECT_ID") as? String,
              !endpoint.isEmpty, !projectID.isEmpty,
              !endpoint.contains("$("), !projectID.contains("$("),
              let components = URLComponents(string: endpoint),
              components.scheme == "https", components.host != nil,
              components.path == "/v1", components.query == nil,
              !projectID.contains("/") else {
            throw AppwriteConfigurationError.missingOrInvalid
        }
        let client = Client().setEndpoint(endpoint).setProject(projectID)
        configuredClient = client
        return client
    }

    /// The SDK stores Set-Cookie values by regional host in UserDefaults. An
    /// expired server session does not clear that jar. Preserve other projects.
    static func clearSessionCookies() {
        guard let endpoint = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_ENDPOINT") as? String, let host = URL(string: endpoint)?.host, let project = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_PROJECT_ID") as? String else { return }
        let cookies = UserDefaults.standard.stringArray(forKey: host) ?? []
        let remaining = AppwriteSessionCookies.removing(project: project, from: cookies)
        if remaining.isEmpty { UserDefaults.standard.removeObject(forKey: host) } else { UserDefaults.standard.set(remaining, forKey: host) }
    }

    static func account() throws -> Account { Account(try client()) }

    static func ping() async throws {
        _ = try await client().ping()
    }
}

private enum AppwriteConfigurationError: LocalizedError {
    case missingOrInvalid

    var errorDescription: String? {
        "Appwrite endpoint and project ID must be supplied by this build's environment"
    }
}

enum AppwriteSessionCookies {
    static func removing(project: String, from values: [String]) -> [String] {
        let names = Set(["a_session_\(project)", "a_session_\(project)_legacy"])
        return values.filter { cookie in
            guard let separator = cookie.firstIndex(of: "=") else { return true }
            return !names.contains(cookie[..<separator].trimmingCharacters(in: .whitespaces))
        }
    }
}
