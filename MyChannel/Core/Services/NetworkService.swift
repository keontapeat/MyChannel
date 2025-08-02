//
//  NetworkService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Network Service
@MainActor
class NetworkService: ObservableObject {
    static let shared = NetworkService()
    
    @Published var isConnected: Bool = true
    @Published var isLoading: Bool = false
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = AppConfig.API.timeout
        configuration.timeoutIntervalForResource = AppConfig.API.timeout * 2
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = URLSession(configuration: configuration)
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        
        setupNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        // Monitor network connectivity
        Timer.publish(every: 10.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkConnectivity()
            }
            .store(in: &cancellables)
    }
    
    private func checkConnectivity() {
        guard let url = URL(string: AppConfig.API.baseURL + "/health") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        session.dataTask(with: request) { [weak self] _, response, _ in
            DispatchQueue.main.async {
                self?.isConnected = (response as? HTTPURLResponse)?.statusCode == 200
            }
        }.resume()
    }
    
    // MARK: - Generic Request Method
    func request<T: Codable>(
        endpoint: APIEndpoint,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        headers: [String: String] = [:],
        responseType: T.Type
    ) async throws -> T {
        
        guard let url = URL(string: AppConfig.API.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        // Default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MyChannel iOS \(AppConfig.appVersion)", forHTTPHeaderField: "User-Agent")
        
        // Add auth header if available
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add Supabase headers
        request.setValue(AppConfig.API.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Log request in development
        if AppConfig.Features.enableNetworkLogging {
            logRequest(request)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Log response in development
            if AppConfig.Features.enableNetworkLogging {
                logResponse(response, data: data)
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Check status code
            switch httpResponse.statusCode {
            case 200...299:
                // Success - decode response
                do {
                    let decodedResponse = try decoder.decode(T.self, from: data)
                    return decodedResponse
                } catch {
                    throw NetworkError.decodingError(error)
                }
                
            case 401:
                throw NetworkError.unauthorized
            case 403:
                throw NetworkError.forbidden
            case 404:
                throw NetworkError.notFound
            case 429:
                throw NetworkError.rateLimited
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.httpError(httpResponse.statusCode)
            }
            
        } catch {
            if error is NetworkError {
                throw error
            } else {
                throw NetworkError.networkError(error)
            }
        }
    }
    
    // MARK: - Convenience Methods
    func get<T: Codable>(
        endpoint: APIEndpoint,
        responseType: T.Type,
        headers: [String: String] = [:]
    ) async throws -> T {
        return try await request(
            endpoint: endpoint,
            method: .GET,
            headers: headers,
            responseType: responseType
        )
    }
    
    func post<T: Codable, U: Codable>(
        endpoint: APIEndpoint,
        body: U,
        responseType: T.Type,
        headers: [String: String] = [:]
    ) async throws -> T {
        let bodyData = try encoder.encode(body)
        return try await request(
            endpoint: endpoint,
            method: .POST,
            body: bodyData,
            headers: headers,
            responseType: responseType
        )
    }
    
    func put<T: Codable, U: Codable>(
        endpoint: APIEndpoint,
        body: U,
        responseType: T.Type,
        headers: [String: String] = [:]
    ) async throws -> T {
        let bodyData = try encoder.encode(body)
        return try await request(
            endpoint: endpoint,
            method: .PUT,
            body: bodyData,
            headers: headers,
            responseType: responseType
        )
    }
    
    func delete<T: Codable>(
        endpoint: APIEndpoint,
        responseType: T.Type,
        headers: [String: String] = [:]
    ) async throws -> T {
        return try await request(
            endpoint: endpoint,
            method: .DELETE,
            headers: headers,
            responseType: responseType
        )
    }
    
    // MARK: - File Upload
    func uploadFile(
        endpoint: APIEndpoint,
        fileData: Data,
        fileName: String,
        mimeType: String,
        additionalFields: [String: String] = [:],
        progressHandler: @escaping (Double) -> Void = { _ in }
    ) async throws -> UploadResponse {
        
        guard let url = URL(string: AppConfig.API.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Add auth header
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add Supabase headers
        request.setValue(AppConfig.API.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        var body = Data()
        
        // Add additional fields
        for (key, value) in additionalFields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw NetworkError.httpError(httpResponse.statusCode)
            }
            
            let uploadResponse = try decoder.decode(UploadResponse.self, from: data)
            return uploadResponse
            
        } catch {
            throw NetworkError.networkError(error)
        }
    }
    
    // MARK: - Authentication Token
    private func getAuthToken() async -> String? {
        return KeychainHelper.shared.getString(for: "userToken")
    }
    
    // MARK: - Logging
    private func logRequest(_ request: URLRequest) {
        print("🌐 → \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            print("📋 Headers: \(headers)")
        }
        
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            print("📤 Body: \(bodyString)")
        }
    }
    
    private func logResponse(_ response: URLResponse, data: Data) {
        if let httpResponse = response as? HTTPURLResponse {
            let statusEmoji = httpResponse.statusCode < 400 ? "✅" : "❌"
            print("\(statusEmoji) ← \(httpResponse.statusCode) \(httpResponse.url?.absoluteString ?? "")")
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Response: \(responseString)")
        }
    }
}

// MARK: - HTTP Methods
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - API Endpoints
enum APIEndpoint {
    // Authentication
    case signIn
    case signUp
    case signOut
    case refreshToken
    
    // User
    case userProfile(String)
    case updateProfile
    case followUser(String)
    case unfollowUser(String)
    
    // Videos
    case videos
    case video(String)
    case uploadVideo
    case deleteVideo(String)
    case likeVideo(String)
    case unlikeVideo(String)
    
    // Comments
    case comments(String)
    case postComment(String)
    case deleteComment(String)
    
    // Search
    case search(String)
    case trending
    
    // Live Streams
    case liveStreams
    case startStream
    case endStream(String)
    
    // Custom endpoints
    case custom(String)
    
    var path: String {
        switch self {
        // Authentication
        case .signIn: return "/auth/sign-in"
        case .signUp: return "/auth/sign-up"
        case .signOut: return "/auth/sign-out"
        case .refreshToken: return "/auth/refresh"
        
        // User
        case .userProfile(let id): return "/users/\(id)"
        case .updateProfile: return "/users/me"
        case .followUser(let id): return "/users/\(id)/follow"
        case .unfollowUser(let id): return "/users/\(id)/unfollow"
        
        // Videos
        case .videos: return "/videos"
        case .video(let id): return "/videos/\(id)"
        case .uploadVideo: return "/videos/upload"
        case .deleteVideo(let id): return "/videos/\(id)"
        case .likeVideo(let id): return "/videos/\(id)/like"
        case .unlikeVideo(let id): return "/videos/\(id)/unlike"
        
        // Comments
        case .comments(let videoId): return "/videos/\(videoId)/comments"
        case .postComment(let videoId): return "/videos/\(videoId)/comments"
        case .deleteComment(let id): return "/comments/\(id)"
        
        // Search
        case .search(let query): return "/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        case .trending: return "/videos/trending"
        
        // Live Streams
        case .liveStreams: return "/streams"
        case .startStream: return "/streams/start"
        case .endStream(let id): return "/streams/\(id)/end"
        
        // Custom
        case .custom(let path): return path
        }
    }
}

// MARK: - Network Errors
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(Int)
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized access. Please sign in again."
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .httpError(let code):
            return "HTTP error (\(code))"
        }
    }
}

// MARK: - Response Models
struct APIResponse<T: Codable>: Codable {
    let data: T
    let message: String?
    let success: Bool
    let timestamp: Date
}

struct UploadResponse: Codable {
    let fileUrl: String
    let fileName: String
    let fileSize: Int
    let mimeType: String
    let uploadId: String
}

struct ErrorResponse: Codable {
    let error: String
    let message: String
    let code: Int
    let timestamp: Date
}

// MARK: - Request/Response Models
struct SignInRequest: Codable {
    let email: String
    let password: String
    let deviceId: String
}

struct SignInResponse: Codable {
    let user: User
    let accessToken: String
    let refreshToken: String
    let expiresIn: TimeInterval
}

struct SignUpRequest: Codable {
    let email: String
    let password: String
    let username: String
    let displayName: String
    let deviceId: String
}

struct VideoUploadRequest: Codable {
    let title: String
    let description: String
    let category: String
    let tags: [String]
    let isPublic: Bool
    let thumbnailUrl: String?
    let scheduledAt: Date?
}

struct EmptyRequest: Codable {}
struct EmptyResponse: Codable {}

// MARK: - Mock Network Service for Development
#if DEBUG
class MockNetworkService: NetworkService {
    override func request<T: Codable>(
        endpoint: APIEndpoint,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        headers: [String: String] = [:],
        responseType: T.Type
    ) async throws -> T {
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64.random(in: 500_000_000...2_000_000_000))
        
        // Mock responses based on endpoint
        switch endpoint {
        case .videos:
            if let videos = Video.sampleVideos as? T {
                return videos
            }
        case .userProfile:
            if let user = User.sampleUsers.first as? T {
                return user
            }
        case .trending:
            if let trending = Video.sampleVideos.filter({ $0.viewCount > 100000 }) as? T {
                return trending
            }
        default:
            break
        }
        
        // Default mock response
        throw NetworkError.notFound
    }
}
#endif

#Preview("Network Service Status") {
    VStack(spacing: 20) {
        Text("Network Service")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        HStack {
            Circle()
                .fill(NetworkService.shared.isConnected ? .green : .red)
                .frame(width: 12, height: 12)
            
            Text(NetworkService.shared.isConnected ? "Connected" : "Disconnected")
                .font(.headline)
        }
        
        if NetworkService.shared.isLoading {
            ProgressView("Loading...")
        }
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Configuration:")
                .font(.headline)
            
            Text("Base URL: \(AppConfig.API.baseURL)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Timeout: \(AppConfig.API.timeout)s")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Environment: \(AppConfig.environment.displayName)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        Spacer()
    }
    .padding()
}