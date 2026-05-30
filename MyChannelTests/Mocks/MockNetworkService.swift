import Foundation
import Combine
@testable import MyChannel

@MainActor
class MockNetworkService: NetworkService {
    
    var mockResponse: Any?
    var mockError: NetworkError?
    
    // For verifying which endpoints were called during a test
    var requestedEndpoints: [APIEndpoint] = []
    
    override func request<T: Codable>(
        endpoint: APIEndpoint,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        headers: [String: String] = [:],
        responseType: T.Type
    ) async throws -> T {
        
        requestedEndpoints.append(endpoint)
        
        // If an error is set, throw it immediately
        if let error = mockError {
            throw error
        }
        
        // If a mock response is set, attempt to return it
        if let response = mockResponse as? T {
            return response
        }
        
        // Fallback generic mocks based on type
        if T.self == [Video].self {
            return [] as! T
        }
        if T.self == User.self, let sample = User.sampleUsers.first {
            return sample as! T
        }
        if T.self == MessageResponse.self {
            return MessageResponse(message: "Mock success", success: true, timestamp: Date()) as! T
        }
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        
        throw NetworkError.invalidResponse
    }
}
