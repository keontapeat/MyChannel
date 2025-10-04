//
//  NetworkManager.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import Foundation
import Network
import Combine

// MARK: - Network Manager
@MainActor
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType = .wifi
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else {
                    self?.connectionType = .other
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - API Error Types
public enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case serverError(Int, String?)
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serviceUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .serviceUnavailable:
            return "Service temporarily unavailable"
        }
    }
}

// MARK: - HTTP Method
// Use shared HTTPMethod from NetworkService.swift

// MARK: - API Request
struct APIRequest {
    let endpoint: String
    let method: HTTPMethod
    let headers: [String: String]?
    let body: Data?
    let queryParameters: [String: String]?
    
    init(
        endpoint: String,
        method: HTTPMethod = .GET,
        headers: [String: String]? = nil,
        body: Data? = nil,
        queryParameters: [String: String]? = nil
    ) {
        self.endpoint = endpoint
        self.method = method
        self.headers = headers
        self.body = body
        self.queryParameters = queryParameters
    }
}

// MARK: - API Response
// Use shared APIResponse from NetworkService.swift

// MARK: - API Client
class APIClient: ObservableObject {
    static let shared = APIClient()
    
    private let session: URLSession
    private let baseURL: String
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    @Published var isLoading = false
    @Published var lastError: APIError?
    
    // Authentication
    @Published var authToken: String?
    @Published var isAuthenticated = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Configure URL Session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024, // 10MB
            diskCapacity: 50 * 1024 * 1024,   // 50MB
            diskPath: "api_cache"
        )
        
        self.session = URLSession(configuration: config)
        self.baseURL = AppConfig.API.baseURL
        
        // Configure JSON handling
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        
        loadAuthToken()
    }
    
    // MARK: - Authentication Management
    private func loadAuthToken() {
        if let token = KeychainHelper.load(key: "auth_token") {
            self.authToken = String(data: token, encoding: .utf8)
            self.isAuthenticated = true
        }
    }
    
    func setAuthToken(_ token: String?) {
        self.authToken = token
        self.isAuthenticated = token != nil
        
        if let token = token {
            KeychainHelper.save(key: "auth_token", data: token.data(using: .utf8)!)
        } else {
            KeychainHelper.delete(key: "auth_token")
        }
    }
    
    // MARK: - Request Building
    private func buildURL(endpoint: String, queryParameters: [String: String]?) -> URL? {
        guard var urlComponents = URLComponents(string: baseURL + endpoint) else {
            return nil
        }
        
        if let queryParameters = queryParameters {
            urlComponents.queryItems = queryParameters.map { 
                URLQueryItem(name: $0.key, value: $0.value) 
            }
        }
        
        return urlComponents.url
    }
    
    private func buildURLRequest(from apiRequest: APIRequest) -> URLRequest? {
        guard let url = buildURL(
            endpoint: apiRequest.endpoint, 
            queryParameters: apiRequest.queryParameters
        ) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = apiRequest.method.rawValue
        request.httpBody = apiRequest.body
        
        // Default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MyChannel iOS/\(AppConfig.appVersion)", forHTTPHeaderField: "User-Agent")
        
        // Auth header
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Custom headers
        apiRequest.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return request
    }
    
    // MARK: - Generic Request Method
    func request<T: Codable>(
        _ apiRequest: APIRequest,
        responseType: T.Type
    ) async throws -> APIResponse<T> {
        guard let urlRequest = buildURLRequest(from: apiRequest) else {
            throw APIError.invalidURL
        }
        
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            await MainActor.run {
                isLoading = false
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(URLError(.badServerResponse))
            }
            
            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                await MainActor.run {
                    setAuthToken(nil)
                }
                throw APIError.unauthorized
            case 403:
                throw APIError.forbidden
            case 404:
                throw APIError.notFound
            case 429:
                throw APIError.rateLimited
            case 500...599:
                throw APIError.serviceUnavailable
            default:
                let errorMessage = String(data: data, encoding: .utf8)
                throw APIError.serverError(httpResponse.statusCode, errorMessage)
            }
            
            // Decode response
            do {
                let decodedData = try decoder.decode(T.self, from: data)
                return APIResponse(
                    data: decodedData,
                    message: nil,
                    success: true,
                    timestamp: Date()
                )
            } catch {
                throw APIError.decodingError(error)
            }
            
        } catch {
            await MainActor.run {
                isLoading = false
                if let apiError = error as? APIError {
                    lastError = apiError
                } else {
                    lastError = APIError.networkError(error)
                }
            }
            throw error
        }
    }
    
    // MARK: - Convenience Methods
    func get<T: Codable>(
        endpoint: String,
        queryParameters: [String: String]? = nil,
        headers: [String: String]? = nil,
        responseType: T.Type
    ) async throws -> T {
        let request = APIRequest(
            endpoint: endpoint,
            method: .GET,
            headers: headers,
            queryParameters: queryParameters
        )
        
        let response = try await self.request(request, responseType: responseType)
        return response.data
    }
    
    func post<T: Codable, U: Codable>(
        endpoint: String,
        body: T,
        headers: [String: String]? = nil,
        responseType: U.Type
    ) async throws -> U {
        let bodyData = try encoder.encode(body)
        
        let request = APIRequest(
            endpoint: endpoint,
            method: .POST,
            headers: headers,
            body: bodyData
        )
        
        let response = try await self.request(request, responseType: responseType)
        return response.data
    }
    
    func put<T: Codable, U: Codable>(
        endpoint: String,
        body: T,
        headers: [String: String]? = nil,
        responseType: U.Type
    ) async throws -> U {
        let bodyData = try encoder.encode(body)
        
        let request = APIRequest(
            endpoint: endpoint,
            method: .PUT,
            headers: headers,
            body: bodyData
        )
        
        let response = try await self.request(request, responseType: responseType)
        return response.data
    }
    
    func delete<T: Codable>(
        endpoint: String,
        headers: [String: String]? = nil,
        responseType: T.Type
    ) async throws -> T {
        let request = APIRequest(
            endpoint: endpoint,
            method: .DELETE,
            headers: headers
        )
        
        let response = try await self.request(request, responseType: responseType)
        return response.data
    }
}

// Using shared KeychainHelper and response models from Utilities/NetworkService

