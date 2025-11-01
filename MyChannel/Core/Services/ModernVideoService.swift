//
//  ModernVideoService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import Combine
import AVFoundation

// MARK: - Video Cache Manager
class VideoCacheManager: ObservableObject {
    static let shared = VideoCacheManager()
    
    private let cache = NSCache<NSString, VideoDetail>()
    private let maxCacheSize = 100 // Maximum number of cached videos
    
    private init() {
        cache.countLimit = maxCacheSize
    }
    
    func cacheVideo(_ video: VideoDetail) {
        cache.setObject(video, forKey: video.id as NSString)
    }
    
    func getCachedVideo(id: String) -> VideoDetail? {
        return cache.object(forKey: id as NSString)
    }
    
    func removeCachedVideo(id: String) {
        cache.removeObject(forKey: id as NSString)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - Modern Video Service
@MainActor
class ModernVideoService: ObservableObject {
    static let shared = ModernVideoService()
    
    // MARK: - Published Properties
    @Published var currentVideo: VideoDetail?
    @Published var homeFeedVideos: [VideoSummary] = []
    @Published var trendingVideos: [VideoSummary] = []
    @Published var searchResults: [VideoSummary] = []
    @Published var relatedVideos: [VideoSummary] = []
    
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var lastError: String?
    
    // Upload state
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadStatus: String = ""
    
    // Pagination
    @Published var hasMoreHomeFeed = true
    @Published var hasMoreTrending = true
    @Published var hasMoreSearch = true
    
    // MARK: - Private Properties
    private let videoAPIService = VideoAPIService.shared
    private let cacheManager = VideoCacheManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Pagination state
    private var currentHomePage = 1
    private var currentTrendingPage = 1
    private var currentSearchPage = 1
    private var currentSearchQuery = ""
    
    // MARK: - Initialization
    private init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Observe upload progress from API service
        videoAPIService.$isUploading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isUploading, on: self)
            .store(in: &cancellables)
        
        videoAPIService.$uploadProgress
            .receive(on: DispatchQueue.main)
            .assign(to: \.uploadProgress, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Video Retrieval
    func getVideo(id: String, forceRefresh: Bool = false) async throws -> VideoDetail {
        // Check cache first
        if !forceRefresh, let cachedVideo = cacheManager.getCachedVideo(id: id) {
            currentVideo = cachedVideo
            return cachedVideo
        }
        
        isLoading = true
        lastError = nil
        
        do {
            let video = try await videoAPIService.getVideo(id: id)
            
            // Cache the video
            cacheManager.cacheVideo(video)
            currentVideo = video
            isLoading = false
            
            // Record view
            Task {
                try? await videoAPIService.recordView(videoId: id)
            }
            
            return video
            
        } catch {
            isLoading = false
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func loadHomeFeed(refresh: Bool = false) async throws {
        if refresh {
            currentHomePage = 1
            hasMoreHomeFeed = true
        }
        
        guard hasMoreHomeFeed else { return }
        
        if refresh {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        
        lastError = nil
        
        do {
            let response = try await videoAPIService.getHomeFeed(
                page: currentHomePage,
                limit: 20
            )
            
            if refresh {
                homeFeedVideos = response.videos
            } else {
                homeFeedVideos.append(contentsOf: response.videos)
            }
            
            hasMoreHomeFeed = response.pagination?.hasMore ?? false
            if hasMoreHomeFeed {
                currentHomePage += 1
            }
            
            isLoading = false
            isLoadingMore = false
            
        } catch {
            isLoading = false
            isLoadingMore = false
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func loadTrendingVideos(timeframe: String = "week", refresh: Bool = false) async throws {
        if refresh {
            currentTrendingPage = 1
            hasMoreTrending = true
        }
        
        guard hasMoreTrending else { return }
        
        if refresh {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        
        lastError = nil
        
        do {
            let response = try await videoAPIService.getTrending(
                timeframe: timeframe,
                page: currentTrendingPage,
                limit: 20
            )
            
            if refresh {
                trendingVideos = response.videos
            } else {
                trendingVideos.append(contentsOf: response.videos)
            }
            
            hasMoreTrending = response.pagination.hasMore
            if hasMoreTrending {
                currentTrendingPage += 1
            }
            
            isLoading = false
            isLoadingMore = false
            
        } catch {
            isLoading = false
            isLoadingMore = false
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func searchVideos(query: String, refresh: Bool = false) async throws {
        if refresh || query != currentSearchQuery {
            currentSearchPage = 1
            currentSearchQuery = query
            hasMoreSearch = true
        }
        
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        
        guard hasMoreSearch else { return }
        
        if refresh || query != currentSearchQuery {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        
        lastError = nil
        
        do {
            let response = try await videoAPIService.searchVideos(
                query: query,
                page: currentSearchPage,
                limit: 20
            )
            
            if refresh || query != currentSearchQuery {
                searchResults = response.videos
            } else {
                searchResults.append(contentsOf: response.videos)
            }
            
            hasMoreSearch = response.pagination.hasMore
            if hasMoreSearch {
                currentSearchPage += 1
            }
            
            isLoading = false
            isLoadingMore = false
            
        } catch {
            isLoading = false
            isLoadingMore = false
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func loadRelatedVideos(for videoId: String) async throws {
        do {
            let videos = try await videoAPIService.getRelatedVideos(
                videoId: videoId,
                limit: 12
            )
            
            relatedVideos = videos
            
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func getVideosByCategory(_ category: String, page: Int = 1) async throws -> [VideoSummary] {
        let response = try await videoAPIService.getVideosByCategory(
            category: category,
            page: page,
            limit: 20
        )
        
        return response.videos
    }
    
    // MARK: - Video Interactions
    func likeVideo(id: String) async throws {
        do {
            try await videoAPIService.likeVideo(videoId: id)
            
            // Refresh current video if it's the one being liked
            if currentVideo?.id == id {
                try await refreshCurrentVideo()
            }
            
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func unlikeVideo(id: String) async throws {
        do {
            try await videoAPIService.unlikeVideo(videoId: id)
            
            // Refresh current video if it's the one being unliked
            if currentVideo?.id == id {
                try await refreshCurrentVideo()
            }
            
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func dislikeVideo(id: String) async throws {
        do {
            try await videoAPIService.dislikeVideo(videoId: id)
            
            // Refresh current video if it's the one being disliked
            if currentVideo?.id == id {
                try await refreshCurrentVideo()
            }
            
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Video Upload
    func uploadVideo(
        videoURL: URL,
        title: String,
        description: String? = nil,
        category: String? = nil,
        tags: [String]? = nil,
        visibility: String = "public",
        isPremium: Bool = false
    ) async throws -> VideoDetail {
        
        uploadStatus = "Preparing upload..."
        uploadProgress = 0.0
        
        do {
            // Read video data
            let videoData = try Data(contentsOf: videoURL)
            
            uploadStatus = "Uploading video..."
            
            // Upload using API service
            let video = try await videoAPIService.uploadVideo(
                videoData: videoData,
                title: title,
                description: description,
                category: category,
                tags: tags,
                visibility: visibility,
                isPremium: isPremium
            )
            
            uploadStatus = "Upload completed!"
            uploadProgress = 1.0
            
            // Cache the uploaded video
            cacheManager.cacheVideo(video)
            
            // Reset upload state after a delay
            Task {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                await MainActor.run {
                    uploadStatus = ""
                    uploadProgress = 0.0
                }
            }
            
            return video
            
        } catch {
            uploadStatus = "Upload failed: \(error.localizedDescription)"
            uploadProgress = 0.0
            
            // Reset error status after a delay
            Task {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                await MainActor.run {
                    uploadStatus = ""
                }
            }
            
            throw error
        }
    }
    
    // MARK: - Utility Methods
    func refreshCurrentVideo() async throws {
        guard let videoId = currentVideo?.id else { return }
        let _ = try await getVideo(id: videoId, forceRefresh: true)
    }
    
    func clearCache() {
        cacheManager.clearCache()
    }
    
    func getVideoThumbnail(for video: VideoSummary) -> String? {
        return video.thumbnailUrl
    }
    
    func formatDuration(_ duration: Int?) -> String {
        guard let duration = duration else { return "0:00" }
        
        let minutes = duration / 60
        let seconds = duration % 60
        
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    func formatViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return String(count)
        }
    }
    
    func formatPublishedDate(_ dateString: String?) -> String {
        guard let dateString = dateString,
              let date = ISO8601DateFormatter().date(from: dateString) else {
            return "Unknown"
        }
        
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        if interval < 3600 { // Less than 1 hour
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 { // Less than 1 day
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if interval < 2592000 { // Less than 30 days
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else if interval < 31536000 { // Less than 1 year
            let months = Int(interval / 2592000)
            return "\(months) month\(months == 1 ? "" : "s") ago"
        } else {
            let years = Int(interval / 31536000)
            return "\(years) year\(years == 1 ? "" : "s") ago"
        }
    }
}









