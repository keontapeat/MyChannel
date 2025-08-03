//
//  PremiumService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import Combine

@MainActor
class PremiumService: ObservableObject {
    static let shared = PremiumService()
    
    @Published var isPremium = false
    @Published var premiumTier: PremiumTier = .none
    @Published var subscriptionStatus: SubscriptionStatus = .inactive
    @Published var downloadedVideos: [DownloadedVideo] = []
    @Published var premiumFeatures: Set<PremiumFeature> = []
    @Published var downloadProgress: [String: Double] = [:] // videoID: progress
    
    private init() {
        loadPremiumStatus()
        setupPremiumFeatures()
        loadDownloadedVideos()
    }
    
    private func loadPremiumStatus() {
        // Load from UserDefaults or Keychain
        isPremium = UserDefaults.standard.bool(forKey: "isPremium")
        if let tierRaw = UserDefaults.standard.object(forKey: "premiumTier") as? String,
           let tier = PremiumTier(rawValue: tierRaw) {
            premiumTier = tier
        }
        
        updatePremiumFeatures()
    }
    
    private func setupPremiumFeatures() {
        // Set available features based on tier
        updatePremiumFeatures()
    }
    
    private func updatePremiumFeatures() {
        premiumFeatures = Set(premiumTier.features)
    }
    
    // MARK: - Premium Actions
    func subscribe(to tier: PremiumTier) async throws {
        // Simulate subscription process
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        premiumTier = tier
        isPremium = true
        subscriptionStatus = .active
        
        // Save to persistent storage
        UserDefaults.standard.set(true, forKey: "isPremium")
        UserDefaults.standard.set(tier.rawValue, forKey: "premiumTier")
        
        updatePremiumFeatures()
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    func cancelSubscription() async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        subscriptionStatus = .cancelled
        // Keep premium features until end of billing period
    }
    
    // MARK: - Feature Checks
    func hasFeature(_ feature: PremiumFeature) -> Bool {
        return premiumFeatures.contains(feature)
    }
    
    // MARK: - Download Management
    func downloadVideo(_ video: Video, quality: PremiumVideoQuality = .high) async throws {
        guard hasFeature(.offlineDownloads) else {
            throw PremiumError.featureNotAvailable
        }
        
        // Check if already downloaded
        if downloadedVideos.contains(where: { $0.video.id == video.id }) {
            throw PremiumError.alreadyDownloaded
        }
        
        // Check download limit based on tier
        let downloadLimit = getDownloadLimitForCurrentTier()
        if downloadedVideos.count >= downloadLimit {
            throw PremiumError.downloadLimitReached
        }
        
        // Simulate download progress
        let progressID = video.id
        downloadProgress[progressID] = 0.0
        
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            let progress = Double(i) / 10.0
            await MainActor.run {
                downloadProgress[progressID] = progress
            }
        }
        
        // Create downloaded video
        let downloadedVideo = DownloadedVideo(
            video: video,
            quality: quality,
            downloadDate: Date(),
            filePath: "downloads/\(video.id).mp4" // Simulated file path
        )
        
        await MainActor.run {
            downloadedVideos.append(downloadedVideo)
            downloadProgress[progressID] = nil
        }
        
        // Save to persistent storage
        saveDownloadedVideos()
    }
    
    func deleteDownload(_ downloadedVideo: DownloadedVideo) {
        downloadedVideos.removeAll { $0.id == downloadedVideo.id }
        downloadProgress[downloadedVideo.video.id] = nil
        
        // Save to persistent storage
        saveDownloadedVideos()
    }
    
    func cancelDownload(for videoID: String) {
        downloadProgress[videoID] = nil
    }
    
    private func getDownloadLimitForCurrentTier() -> Int {
        switch premiumTier {
        case .none:
            return 0 // Free tier - no downloads
        case .basic:
            return 10 // Basic tier - 10 downloads
        case .pro:
            return 50 // Pro tier - 50 downloads
        case .ultimate:
            return 100 // Ultimate tier - 100 downloads
        }
    }
    
    private func saveDownloadedVideos() {
        // In a real app, this would save to a persistent store
        // For now we'll use UserDefaults for demo purposes
        if let data = try? JSONEncoder().encode(downloadedVideos) {
            UserDefaults.standard.set(data, forKey: "downloadedVideos")
        }
    }
    
    private func loadDownloadedVideos() {
        // Load downloaded videos from persistent storage
        if let data = UserDefaults.standard.data(forKey: "downloadedVideos"),
           let videos = try? JSONDecoder().decode([DownloadedVideo].self, from: data) {
            downloadedVideos = videos
        }
    }
    
    func getDownloadedVideos() -> [DownloadedVideo] {
        return downloadedVideos
    }
    
    func isVideoDownloaded(_ videoID: String) -> Bool {
        return downloadedVideos.contains { $0.video.id == videoID }
    }
    
    func getDownloadProgress(for videoID: String) -> Double? {
        return downloadProgress[videoID]
    }
    
    // MARK: - AI Features
    func generateSmartPlaylist(for user: User) async throws -> [Video] {
        guard hasFeature(.aiRecommendations) else {
            throw PremiumError.featureNotAvailable
        }
        
        // AI-powered playlist generation
        try await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Return AI-curated videos
        return Video.sampleVideos.shuffled().prefix(20).map { $0 }
    }
    
    func enableSpatialAudio(for video: Video) -> Bool {
        return hasFeature(.spatialAudio)
    }
}

// MARK: - Premium Models
enum PremiumTier: String, CaseIterable {
    case none = "none"
    case basic = "basic"
    case pro = "pro"
    case ultimate = "ultimate"
    
    var title: String {
        switch self {
        case .none: return "Free"
        case .basic: return "MyChannel+"
        case .pro: return "MyChannel Pro"
        case .ultimate: return "MyChannel Ultimate"
        }
    }
    
    var price: String {
        switch self {
        case .none: return "Free"
        case .basic: return "$4.99/month"
        case .pro: return "$9.99/month"
        case .ultimate: return "$14.99/month"
        }
    }
    
    var annualPrice: String {
        switch self {
        case .none: return "Free"
        case .basic: return "$49.99/year"
        case .pro: return "$99.99/year"
        case .ultimate: return "$149.99/year"
        }
    }
    
    var features: [PremiumFeature] {
        switch self {
        case .none:
            return []
        case .basic:
            return [.adFree, .backgroundPlay, .offlineDownloads]
        case .pro:
            return [.adFree, .backgroundPlay, .offlineDownloads, .highQuality, .creatorTools, .prioritySupport]
        case .ultimate:
            return PremiumFeature.allCases
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .none:
            return LinearGradient(colors: [.gray], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .basic:
            return LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pro:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .ultimate:
            return LinearGradient(colors: [.purple, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    var icon: String {
        switch self {
        case .none: return "play.circle"
        case .basic: return "star.circle.fill"
        case .pro: return "crown.fill"
        case .ultimate: return "sparkles"
        }
    }
}

enum PremiumFeature: String, CaseIterable {
    case adFree = "ad_free"
    case backgroundPlay = "background_play"
    case offlineDownloads = "offline_downloads"
    case highQuality = "high_quality"
    case creatorTools = "creator_tools"
    case prioritySupport = "priority_support"
    case aiRecommendations = "ai_recommendations"
    case spatialAudio = "spatial_audio"
    case exclusiveContent = "exclusive_content"
    case earlyAccess = "early_access"
    case customization = "customization"
    case analytics = "analytics"
    
    var title: String {
        switch self {
        case .adFree: return "Ad-Free Experience"
        case .backgroundPlay: return "Background Play"
        case .offlineDownloads: return "Offline Downloads"
        case .highQuality: return "4K & HDR Quality"
        case .creatorTools: return "Creator Studio Pro"
        case .prioritySupport: return "Priority Support"
        case .aiRecommendations: return "AI Smart Playlists"
        case .spatialAudio: return "Spatial Audio"
        case .exclusiveContent: return "Exclusive Content"
        case .earlyAccess: return "Early Access"
        case .customization: return "Custom Themes"
        case .analytics: return "Advanced Analytics"
        }
    }
    
    var description: String {
        switch self {
        case .adFree: return "No interruptions, ever"
        case .backgroundPlay: return "Keep playing while using other apps"
        case .offlineDownloads: return "Download up to 100 videos"
        case .highQuality: return "Crystal clear 4K streaming"
        case .creatorTools: return "Professional content creation tools"
        case .prioritySupport: return "24/7 premium support"
        case .aiRecommendations: return "AI-curated content just for you"
        case .spatialAudio: return "Immersive 3D audio experience"
        case .exclusiveContent: return "Access premium creator content"
        case .earlyAccess: return "First access to new features"
        case .customization: return "Personalize your experience"
        case .analytics: return "Detailed viewing insights"
        }
    }
    
    var icon: String {
        switch self {
        case .adFree: return "slash.circle.fill"
        case .backgroundPlay: return "play.rectangle.on.rectangle.fill"
        case .offlineDownloads: return "arrow.down.circle.fill"
        case .highQuality: return "4k.tv.fill"
        case .creatorTools: return "camera.fill"
        case .prioritySupport: return "headphones.circle.fill"
        case .aiRecommendations: return "brain.head.profile"
        case .spatialAudio: return "spatial.audio"
        case .exclusiveContent: return "star.circle.fill"
        case .earlyAccess: return "timer"
        case .customization: return "paintpalette.fill"
        case .analytics: return "chart.line.uptrend.xyaxis.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .adFree: return .red
        case .backgroundPlay: return .blue
        case .offlineDownloads: return .green
        case .highQuality: return .orange
        case .creatorTools: return .purple
        case .prioritySupport: return .cyan
        case .aiRecommendations: return .pink
        case .spatialAudio: return .indigo
        case .exclusiveContent: return .yellow
        case .earlyAccess: return .mint
        case .customization: return .teal
        case .analytics: return .brown
        }
    }
}

enum SubscriptionStatus {
    case inactive
    case active
    case cancelled
    case expired
    case paused
}

enum PremiumVideoQuality: String, CaseIterable, Codable {
    case low = "360p"
    case medium = "720p"
    case high = "1080p"
    case ultra = "4K"
    
    var title: String { rawValue }
}

enum PremiumError: LocalizedError {
    case featureNotAvailable
    case subscriptionRequired
    case downloadLimitReached
    case alreadyDownloaded
    
    var errorDescription: String? {
        switch self {
        case .featureNotAvailable:
            return "This feature is not available in your current plan"
        case .subscriptionRequired:
            return "Premium subscription required"
        case .downloadLimitReached:
            return "Download limit reached for your tier"
        case .alreadyDownloaded:
            return "This video is already downloaded"
        }
    }
}

// MARK: - Downloaded Video Model
struct DownloadedVideo: Identifiable, Codable {
    let id: String
    let video: Video
    let quality: PremiumVideoQuality
    let downloadDate: Date
    let filePath: String? // Made optional for backward compatibility
    
    init(video: Video, quality: PremiumVideoQuality, downloadDate: Date, filePath: String? = nil) {
        self.id = UUID().uuidString
        self.video = video
        self.quality = quality
        self.downloadDate = downloadDate
        self.filePath = filePath
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        video = try container.decode(Video.self, forKey: .video)
        quality = try container.decode(PremiumVideoQuality.self, forKey: .quality)
        downloadDate = try container.decode(Date.self, forKey: .downloadDate)
        
        // Handle optional filePath for backward compatibility
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
    }
    
    var fileSize: String {
        switch quality {
        case .low: return "~50MB"
        case .medium: return "~150MB"
        case .high: return "~300MB"
        case .ultra: return "~1GB"
        }
    }
}
