import Appwrite

@MainActor
enum AppwriteConnection {
    static let client = Client()
        .setEndpoint("https://nyc.cloud.appwrite.io/v1")
        .setProject("6af0e4b00015b4aa04e3")

    static func ping() async throws {
        _ = try await client.ping()
    }
}
