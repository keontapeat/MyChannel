//
//  VideoAPIService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import Foundation
import Combine

// MARK: - Video API Models
struct VideoResponse: Codable {
    let video: VideoDetail
}

struct VideosResponse: Codable {
    let videos: [VideoSummary]
    let pagination: PaginationInfo?
}

struct TMDBSearchResponse: Codable {
    let query: String
    let videos: [VideoSummary]
    let pagination: PaginationInfo
}

struct TrendingResponse: Codable {
    let timeframe: String
    let videos: [VideoSummary]
    let pagination: PaginationInfo
}

struct CategoryResponse: Codable {
    let category: String
    let videos: [VideoSummary]
    let pagination: PaginationInfo
}

struct RelatedVideosResponse: Codable {
    let videos: [VideoSummary]
}

struct PaginationInfo: Codable {
    let page: Int
    let limit: Int
    let hasMore: Bool
}

struct VideoSummary: Codable {
    let id: String
    let title: String
    let description: String?
    let thumbnailUrl: String?
    let duration: Int?
    let viewCount: Int
    let likeCount: Int
    let commentCount: Int
    let publishedAt: String?
    let createdAt: String
    let creator: CreatorSummary
}

class VideoDetail: Codable {
    let id: String
    let title: String
    let description: String?
    let thumbnailUrl: String?
    let videoUrl: String?
    let duration: Int?
    let fileSize: Int?
    let status: String
    let qualityVariants: [QualityVariant]
    let captions: [Caption]
    let chapters: [Chapter]
    let visibility: String
    let isLive: Bool
    let isPremium: Bool
    let viewCount: Int
    let likeCount: Int
    let dislikeCount: Int
    let commentCount: Int
    let shareCount: Int
    let category: String?
    let tags: [String]
    let language: String?
    let ageRestriction: Int
    let publishedAt: String?
    let createdAt: String
    let updatedAt: String
    let creator: CreatorDetail
}

struct QualityVariant: Codable {
    let quality: String
    let url: String
    let width: Int
    let height: Int
    let bitrate: String
}

struct Caption: Codable {
    let language: String
    let label: String
    let url: String
    let isDefault: Bool
}

struct Chapter: Codable {
    let title: String
    let startTime: Int
    let endTime: Int?
    let thumbnailUrl: String?
}

struct CreatorSummary: Codable {
    let id: String
    let username: String
    let displayName: String
    let avatarUrl: String?
    let verified: Bool
    let subscriberCount: Int
}

struct CreatorDetail: Codable {
    let id: String
    let username: String
    let displayName: String
    let avatarUrl: String?
    let bio: String?
    let verified: Bool
    let subscriberCount: Int
    let videoCount: Int
    let totalViews: Int
}

// MARK: - Upload Models
struct UploadSignedUrlRequest: Codable {
    let filename: String
}

struct UploadSignedUrlResponse: Codable {
    let url: String
    let method: String
    let bucket: String
    let object: String
    let getUrl: String
}

struct FinalizeUploadRequest: Codable {
    let object: String
    let bucket: String?
    let contentType: String?
}

struct FinalizeUploadResponse: Codable {
    let url: String
    let publicUrl: String
    let bucket: String
    let object: String
    let contentType: String?
}

struct CreateVideoRequest: Codable {
    let title: String
    let description: String?
    let category: String?
    let tags: [String]?
    let visibility: String
    let isPremium: Bool
    let language: String?
    let videoUrl: String?
    let thumbnailUrl: String?
    let allowComments: Bool?
    let madeForKids: Bool?
    let ageRestricted: Bool?
    let filmingLocation: String?
    let isPremiere: Bool?
    let scheduledAt: String?
}

struct CreateVideoResponse: Codable {
    let video: VideoDetail
}

// MARK: - Video API Service
class VideoAPIService: ObservableObject {
    static let shared = VideoAPIService()
    
    private let apiClient = APIClient.shared
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    
    private init() {}
    
    // MARK: - Video Retrieval
    func getVideo(id: String) async throws -> VideoDetail {
        let response: VideoResponse = try await apiClient.get(
            endpoint: "/v1/videos/\(id)",
            responseType: VideoResponse.self
        )
        return response.video
    }
    
    func getHomeFeed(page: Int = 1, limit: Int = 20) async throws -> VideosResponse {
        let queryParams = [
            "page": String(page),
            "limit": String(limit)
        ]
        
        return try await apiClient.get(
            endpoint: "/v1/feed/home",
            queryParameters: queryParams,
            responseType: VideosResponse.self
        )
    }
    
    func getTrending(
        timeframe: String = "week", 
        page: Int = 1, 
        limit: Int = 20
    ) async throws -> TrendingResponse {
        let queryParams = [
            "timeframe": timeframe,
            "page": String(page),
            "limit": String(limit)
        ]
        
        return try await apiClient.get(
            endpoint: "/v1/feed/trending",
            queryParameters: queryParams,
            responseType: TrendingResponse.self
        )
    }
    
    func getVideosByCategory(
        category: String,
        page: Int = 1,
        limit: Int = 20
    ) async throws -> CategoryResponse {
        let queryParams = [
            "page": String(page),
            "limit": String(limit)
        ]
        
        return try await apiClient.get(
            endpoint: "/v1/feed/category/\(category)",
            queryParameters: queryParams,
            responseType: CategoryResponse.self
        )
    }
    
    func searchVideos(
        query: String,
        page: Int = 1,
        limit: Int = 20
    ) async throws -> TMDBSearchResponse {
        let queryParams = [
            "q": query,
            "page": String(page),
            "limit": String(limit)
        ]
        
        return try await apiClient.get(
            endpoint: "/v1/search",
            queryParameters: queryParams,
            responseType: TMDBSearchResponse.self
        )
    }
    
    func getRelatedVideos(videoId: String, limit: Int = 12) async throws -> [VideoSummary] {
        let queryParams = ["limit": String(limit)]
        
        let response: RelatedVideosResponse = try await apiClient.get(
            endpoint: "/v1/videos/\(videoId)/related",
            queryParameters: queryParams,
            responseType: RelatedVideosResponse.self
        )
        
        return response.videos
    }
    
    // MARK: - Video Upload
    func getSignedUploadUrl(filename: String) async throws -> UploadSignedUrlResponse {
        let request = UploadSignedUrlRequest(filename: filename)
        
        return try await apiClient.post(
            endpoint: "/v1/uploads/signed-url",
            body: request,
            responseType: UploadSignedUrlResponse.self
        )
    }
    
    func uploadVideoFile(data: Data, to signedUrl: String) async throws {
        await MainActor.run {
            isUploading = true
            uploadProgress = 0.0
        }
        
        guard let url = URL(string: signedUrl) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
        
        // Use async/await for URLSession
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            await MainActor.run {
                isUploading = false
                uploadProgress = 1.0
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode else {
                throw APIError.serverError(
                    (response as? HTTPURLResponse)?.statusCode ?? 500,
                    "Upload failed"
                )
            }
            
        } catch {
            await MainActor.run {
                isUploading = false
                uploadProgress = 0.0
            }
            
            if let apiError = error as? APIError {
                throw apiError
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    func finalizeUpload(
        object: String,
        bucket: String? = nil,
        contentType: String? = nil
    ) async throws -> FinalizeUploadResponse {
        let request = FinalizeUploadRequest(
            object: object,
            bucket: bucket,
            contentType: contentType
        )
        
        return try await apiClient.post(
            endpoint: "/v1/uploads/finalize",
            body: request,
            responseType: FinalizeUploadResponse.self
        )
    }
    
    func createVideo(
        title: String,
        description: String? = nil,
        category: String? = nil,
        tags: [String]? = nil,
        visibility: String = "public",
        isPremium: Bool = false,
        language: String? = "en",
        videoUrl: String? = nil,
        thumbnailUrl: String? = nil,
        allowComments: Bool? = nil,
        madeForKids: Bool? = nil,
        ageRestricted: Bool? = nil,
        filmingLocation: String? = nil,
        isPremiere: Bool? = nil,
        scheduledAt: String? = nil
    ) async throws -> VideoDetail {
        let request = CreateVideoRequest(
            title: title,
            description: description,
            category: category,
            tags: tags,
            visibility: visibility,
            isPremium: isPremium,
            language: language,
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl,
            allowComments: allowComments,
            madeForKids: madeForKids,
            ageRestricted: ageRestricted,
            filmingLocation: filmingLocation,
            isPremiere: isPremiere,
            scheduledAt: scheduledAt
        )
        
        let response: CreateVideoResponse = try await apiClient.post(
            endpoint: "/v1/creator/videos",
            body: request,
            responseType: CreateVideoResponse.self
        )
        
        return response.video
    }
    
    // MARK: - Video Interactions
    func recordView(videoId: String) async throws {
        let request = ["videoId": videoId]
        
        let _: MessageResponse = try await apiClient.post(
            endpoint: "/v1/events/view",
            body: request,
            responseType: MessageResponse.self
        )
    }
    
    func likeVideo(videoId: String) async throws {
        let _: MessageResponse = try await apiClient.post(
            endpoint: "/v1/videos/\(videoId)/like",
            body: EmptyResponse(),
            responseType: MessageResponse.self
        )
    }
    
    func unlikeVideo(videoId: String) async throws {
        let _: MessageResponse = try await apiClient.delete(
            endpoint: "/v1/videos/\(videoId)/like",
            responseType: MessageResponse.self
        )
    }
    
    func dislikeVideo(videoId: String) async throws {
        let _: MessageResponse = try await apiClient.post(
            endpoint: "/v1/videos/\(videoId)/dislike",
            body: EmptyResponse(),
            responseType: MessageResponse.self
        )
    }
    
    func removeDislike(videoId: String) async throws {
        let _: MessageResponse = try await apiClient.delete(
            endpoint: "/v1/videos/\(videoId)/dislike",
            responseType: MessageResponse.self
        )
    }
    
    // MARK: - Full Upload Flow
    func uploadVideo(
        videoData: Data,
        title: String,
        description: String? = nil,
        category: String? = nil,
        tags: [String]? = nil,
        visibility: String = "public",
        isPremium: Bool = false
    ) async throws -> VideoDetail {
        
        // 1. Get signed upload URL
        let filename = "video_\(UUID().uuidString).mp4"
        let signedUrlResponse = try await getSignedUploadUrl(filename: filename)
        
        // 2. Upload video file
        try await uploadVideoFile(data: videoData, to: signedUrlResponse.url)
        
        // 3. Finalize upload
        let finalizeResponse = try await finalizeUpload(
            object: signedUrlResponse.object,
            bucket: signedUrlResponse.bucket,
            contentType: "video/mp4"
        )
        
        // 4. Create video record
        let video = try await createVideo(
            title: title,
            description: description,
            category: category,
            tags: tags,
            visibility: visibility,
            isPremium: isPremium,
            videoUrl: finalizeResponse.publicUrl
        )
        
        return video
    }
}