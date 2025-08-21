//
//  NetworkManager.swift
//  Sprout
//
//  Created by Michael Dadi on 8/19/25.
//


// NetworkManager.swift
import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    
    private let config = AppConfig.shared
    private let session = URLSession.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        // Validate config on initialization
        config.validate()
        
        // Configure date encoding/decoding
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    @MainActor  func makeAPIRequest(endpoint: String, method: String = "GET") -> URLRequest? {
        guard let url = URL(string: "\(config.apiBaseURL)/\(endpoint)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(Secrets.apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if available
        if let token = AuthService.shared.currentUser?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    // Sync operations
    func syncTransaction(_ transaction: Transaction) async throws -> SyncResponse {
        guard var request = await makeAPIRequest(endpoint: "transactions/\(transaction.id)", method: transaction.createdAt == transaction.updatedAt ? "POST" : "PUT") else {
            throw URLError(.badURL)
        }
        
        let syncData = TransactionSyncData(from: transaction)
        request.httpBody = try encoder.encode(syncData)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        
        return try decoder.decode(SyncResponse.self, from: data)
    }
    
    func deleteTransaction(transactionId: String) async throws {
        guard let request = await makeAPIRequest(endpoint: "transactions/\(transactionId)", method: "DELETE") else {
            throw URLError(.badURL)
        }
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
    }
    
    func fetchSyncData(since date: Date) async throws -> SyncDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: date)
        
        guard let request = await makeAPIRequest(endpoint: "sync?since=\(dateString)") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        
        return try decoder.decode(SyncDataResponse.self, from: data)
    }
    
    // Upload receipt image
    func uploadReceipt(imageData: Data, for transactionId: String) async throws -> String {
        guard var request = await makeAPIRequest(endpoint: "transactions/\(transactionId)/receipt", method: "POST") else {
            throw URLError(.badURL)
        }
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"receipt\"; filename=\"receipt.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        
        let uploadResponse = try decoder.decode(ReceiptUploadResponse.self, from: data)
        return uploadResponse.receiptUrl
    }
}
