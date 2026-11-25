//
//  ChatClientManager.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import Foundation
import StreamChat
import StreamChatSwiftUI
import Combine

@MainActor
class ChatClientManager: ObservableObject {
    static let shared = ChatClientManager()

    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .initialized
    @Published var connectionError: Error?

    private var hasInitialized = false
    private var connectionController: ChatConnectionController?
    private var cancellables = Set<AnyCancellable>()
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3

    private var chatClient: ChatClient?

    private(set) var streamChat: StreamChat?

    private init() {}

    // Get current ChatClient instance (safe access)
    var client: ChatClient {
      return ChatClient.shared
    }

    /// Initialize Stream Chat client with configuration
    func initialize() {
        guard !hasInitialized else { return }
        guard !AppConfig.shared.streamApiKey.isEmpty else { return }
        hasInitialized = true

        // Configure Stream Chat
        var config = ChatClientConfig(apiKey: .init(AppConfig.shared.streamApiKey))
        config.isLocalStorageEnabled = AppConfig.shared.streamLocalStorageEnabled
        config.staysConnectedInBackground = AppConfig.shared.streamStaysConnectedInBackground
        config.applicationGroupIdentifier = "group.com.michaeldadi.Sprout"

        // Create shared client
        chatClient = ChatClient(config: config)

        // Set shared client instance for Stream
        if let client = chatClient {
          ChatClient.shared = client

          streamChat = StreamChat(
            chatClient: client,
          )
        } else {
          fatalError("Failed to initialize Stream Chat client")
        }

        // Set up connection monitoring
        setupConnectionMonitoring()

        // Set log level based on environment
        #if DEBUG
        LogConfig.level = .info
        #else
        LogConfig.level = AppConfig.shared.isProduction ? .error : .warning
        #endif

        print("Stream Chat client initialized")
    }

    private func setupConnectionMonitoring() {
        guard let client = chatClient else {
            print("ChatClient not initialized")
            return
        }

        connectionController = client.connectionController()

        // Subscribe to connection status changes
        connectionController?.connectionStatusPublisher
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] status in
                self?.handleConnectionStatusChange(status)
            }
            .store(in: &cancellables)
    }

    private func cancelReconnectTask() {
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    private func handleConnectionStatusChange(_ status: ConnectionStatus) {
        connectionStatus = status

        switch status {
        case .connected:
            isConnected = true
            connectionError = nil
            reconnectAttempts = 0
            cancelReconnectTask()
            print("✅ Stream Chat connected")

        case .connecting:
            print("🔄 Stream Chat connecting...")

        case .disconnected(let error):
            isConnected = false
            connectionError = error
            print("⚠️ Stream Chat disconnected: \(error?.localizedDescription ?? "Unknown error")")
            startAutoReconnect()

        case .disconnecting:
            print("🔄 Stream Chat disconnecting...")

        case .initialized:
            isConnected = false
            print("📱 Stream Chat initialized")

        @unknown default:
            break
        }
    }

    /// Manual reconnect attempt
    func reconnect() {
        print("Manual reconnect requested")
        reconnectAttempts = 0
        cancelReconnectTask()

        Task {
            await attemptReconnection()
        }
    }

    private func startAutoReconnect() {
        cancelReconnectTask()

        guard reconnectAttempts < maxReconnectAttempts else {
            print("Max reconnect attempts reached")
            return
        }

        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

            guard !Task.isCancelled else { return }

            if case .disconnected = connectionStatus {
                reconnectAttempts += 1
                print("Auto-reconnect attempt \(reconnectAttempts)/\(maxReconnectAttempts)")
                await attemptReconnection()
            }
        }
    }

    private func attemptReconnection() async {
        guard let client = chatClient, client.currentUserId != nil else {
            print("No user to reconnect")
            return
        }

        // Try to synchronize the current user controller to trigger reconnection
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            client.currentUserController().synchronize { error in
                if let error = error {
                    print("Reconnection failed: \(error)")
                } else {
                    print("Reconnection initiated")
                }
                continuation.resume()
            }
        }
    }

    /// Connect user to Stream Chat
    func connectUser(userId: String, userName: String, userEmail: String, imageURL: URL? = nil) async {
        guard let client = chatClient else {
            print("ChatClient not initialized")
            return
        }

        guard client.currentUserId == nil else {
            print("User already connected to Stream Chat")
            isConnected = true
            return
        }

        // Create user info
        let userInfo = UserInfo(
            id: userId,
            name: userName,
            imageURL: imageURL,
            extraData: [
                "email": .string(userEmail),
                "platform": .string("iOS"),
                "app_version": .string(Bundle.main.appVersion),
                "environment": .string(AppConfig.shared.environmentName)
            ]
        )

        do {
            // Get token from your backend
            let token = try await fetchStreamToken(for: userId)

            // Save token to Keychain for notification extension
            _ = KeychainService.shared.saveStreamToken(token.rawValue)

            // Connect user
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                client.connectUser(userInfo: userInfo, token: token) { [weak self] error in
                    if let error = error {
                        print("❌ Error connecting to Stream Chat: \(error)")
                        self?.isConnected = false
                    } else {
                        print("✅ Successfully connected to Stream Chat as \(userName)")
                        self?.isConnected = true

                        // Initialize support channel after successful connection
                        Task {
                            await MainActor.run {
                                SupportChatManager.shared.initializeSupportChannel()
                            }
                        }
                    }
                    continuation.resume()
                }
            }
        } catch {
            print("❌ Failed to get Stream token: \(error)")
            isConnected = false
        }
    }

    /// Disconnect from Stream Chat
    func disconnect() async {
        _ = KeychainService.shared.deleteStreamToken()
        guard let client = chatClient, client.currentUserId != nil else {
            print("No user connected to disconnect")
            return
        }

        // Cancel any reconnection attempts
        cancelReconnectTask()

        // Clean up support chat
        SupportChatManager.shared.cleanup()

        // Disconnect from Stream
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            client.disconnect { [weak self] in
                print("Disconnected from Stream Chat")
                self?.isConnected = false
                continuation.resume()
            }
        }
    }

    /// Register device token for push notifications
    func registerDeviceToken(_ deviceToken: Data) {
        guard let client = chatClient, client.currentUserId != nil else {
            print("No user connected to register device token")
            return
        }

        client.currentUserController().addDevice(.apn(token: deviceToken)) { error in
            if let error = error {
                print("❌ Error adding device token: \(error)")
            } else {
                print("✅ Device token registered with Stream Chat")
            }
        }
    }

    /// Fetch Stream Chat token from your backend
    private func fetchStreamToken(for userId: String) async throws -> Token {
        let token = try await NetworkManager.shared.getStreamChatToken(userId: userId)
        return try Token(rawValue: token)
    }

    deinit {
        reconnectTask?.cancel()
        cancellables.forEach { $0.cancel() }
    }
}

// MARK: - Extension for ChatClient
extension ChatClient {
    private static var _shared: ChatClient?

    /// Shared instance of ChatClient for the entire app
    /// This will be set by ChatClientManager during initialization
    static var shared: ChatClient {
        get {
            guard let client = _shared else {
                fatalError("""
                    ChatClient.shared was accessed before initialization.
                    Make sure to call ChatClientManager.shared.initialize() before accessing ChatClient.shared.
                    This should typically be done in your App's init() or application(_:didFinishLaunchingWithOptions:).
                    """)
            }
            return client
        }
        set {
            _shared = newValue
        }
    }

    /// Check if the shared client has been initialized
    static var isInitialized: Bool {
        return _shared != nil
    }
}

// MARK: - Extension for StreamChat
extension ChatClientManager {
    /// Get the StreamChat instance for SwiftUI views
    /// This should be used when injecting into SwiftUI environment
    var streamChatInstance: StreamChat {
        guard let streamChat = streamChat else {
            fatalError("""
                StreamChat instance not initialized.
                Make sure to call ChatClientManager.shared.initialize() before accessing streamChatInstance.
                """)
        }
        return streamChat
    }
}
