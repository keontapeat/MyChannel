//
//  APIService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import Foundation
import SwiftUI

@MainActor
class APIService: ObservableObject {
    static let shared = APIService()
    
    private let baseURL = "https://api.mychannel.com/v1"
    private let session = URLSession.shared
    
    @Published var isConnected = false
    @Published var apiError: APIError?
    
    private init() {
        checkConnectivity()
    }
    
    // MARK: - Network Connectivity
    func checkConnectivity() {
        isConnected = true // For now, assume connected
    }
    
    // MARK: - Video API
    func uploadVideo(_ videoData: Data, metadata: VideoMetadata) async throws -> Video {
        // Simulate upload with progress
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        return Video(
            title: metadata.title,
            description: metadata.description,
            thumbnailURL: "https://picsum.photos/400/225?random=\(Int.random(in: 1...100))",
            videoURL: "https://example.com/uploaded-video.mp4",
            duration: 300,
            viewCount: 0,
            likeCount: 0,
            commentCount: 0,
            creator: User.sampleUsers[0],
            tags: metadata.tags,
            category: metadata.category,
            isPublic: metadata.isPublic
        )
    }
    
    func fetchVideos(page: Int = 0, limit: Int = 20) async throws -> [Video] {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return Array(Video.sampleVideos.suffix(limit))
    }
    
    func likeVideo(_ videoId: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        print("Liked video: \(videoId)")
    }
    
    func trackView(videoId: String, duration: TimeInterval) async throws {
        print("Tracked view for video \(videoId), duration: \(duration)")
    }
    
    // MARK: - User API
    func authenticateUser(email: String, password: String) async throws -> AuthResponse {
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        let mockUser = User.sampleUsers[0]
        return AuthResponse(
            user: mockUser,
            token: "mock_access_token",
            refreshToken: "mock_refresh_token",
            expiresIn: 3600
        )
    }
    
    func fetchUserProfile(_ userId: String) async throws -> User {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return User.sampleUsers.first { $0.id == userId } ?? User.sampleUsers[0]
    }
    
    // MARK: - Comments API  
    func postComment(videoId: String, text: String, parentId: String? = nil) async throws -> APIVideoComment {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return APIVideoComment(
            author: User.sampleUsers[0],
            text: text,
            likeCount: 0,
            replyCount: 0,
            createdAt: Date()
        )
    }
    
    func fetchComments(videoId: String) async throws -> [APIVideoComment] {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return APIVideoComment.sampleComments
    }
}

// MARK: - Supporting Models
struct VideoMetadata: Codable {
    let title: String
    let description: String
    let tags: [String]
    let category: VideoCategory
    let isPublic: Bool
    let thumbnailData: Data?
}

struct AuthResponse: Codable {
    let user: User
    let token: String
    let refreshToken: String
    let expiresIn: TimeInterval
}

enum APIError: Error, LocalizedError {
    case noConnection
    case serverError
    case authenticationFailed
    case uploadFailed
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .serverError:
            return "Server error occurred"
        case .authenticationFailed:
            return "Authentication failed"
        case .uploadFailed:
            return "Upload failed"
        case .decodingError:
            return "Data decoding error"
        }
    }
}

// MARK: - APIVideoComment Model (to avoid conflicts)
struct APIVideoComment: Identifiable, Codable {
    let id: String
    let author: User
    let text: String
    let likeCount: Int
    let replyCount: Int
    let createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        author: User,
        text: String,
        likeCount: Int = 0,
        replyCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.author = author
        self.text = text
        self.likeCount = likeCount
        self.replyCount = replyCount
        self.createdAt = createdAt
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

extension APIVideoComment {
    static let sampleComments: [APIVideoComment] = [
        APIVideoComment(
            author: User.sampleUsers[1],
            text: "Amazing video! Thanks for sharing this knowledge!",
            likeCount: 156,
            replyCount: 12,
            createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
        ),
        APIVideoComment(
            author: User.sampleUsers[2],
            text: "Finally someone who knows what they're talking about! 🔥",
            likeCount: 89,
            replyCount: 5,
            createdAt: Calendar.current.date(byAdding: .hour, value: -4, to: Date()) ?? Date()
        )
    ]
}

#Preview {
    VStack {
        Text("API Service")
            .font(.largeTitle)
            .padding()
        
        Text("Backend integration for production")
            .foregroundColor(.secondary)
    }
}