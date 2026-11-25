//
//  ConnectionStatusView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//


import SwiftUI
import StreamChat

// MARK: - Support Connection Banner
struct SupportConnectionBanner: View {
    @ObservedObject private var chatManager = ChatClientManager.shared

    var body: some View {
        if case .disconnected = chatManager.connectionStatus {
            HStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.white)
                    .font(.footnote)

                Text("Offline - Messages will send when reconnected")
                    .font(.footnote)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Button(action: {
                    chatManager.reconnect()
                }) {
                    Text("Retry")
                        .font(.footnote.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.red)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: chatManager.connectionStatus)
        }
    }
}

// MARK: - Connection Status Dot
struct ConnectionStatusDot: View {
    @ObservedObject private var chatManager = ChatClientManager.shared

    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .animation(.easeInOut(duration: 0.3), value: chatManager.connectionStatus)
    }

    private var statusColor: Color {
        switch chatManager.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .red
        case .disconnecting:
            return .orange
        case .initialized:
            return .gray
        @unknown default:
            return .gray
        }
    }
}

// MARK: - View Extension
extension View {
    func withConnectionBanner() -> some View {
        VStack(spacing: 0) {
            SupportConnectionBanner()
            self
        }
    }
}
