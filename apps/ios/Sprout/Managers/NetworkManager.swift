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
    
    private init() {
        // Validate config on initialization
        config.validate()
    }
    
    func makeAPIRequest(endpoint: String) -> URLRequest? {
        guard let url = URL(string: "\(config.apiBaseURL)/\(endpoint)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue(Secrets.apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return request
    }
    
    // Example API call
    func fetchData() async throws -> Data {
        guard let request = makeAPIRequest(endpoint: "data") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(for: request)
        return data
    }
}
