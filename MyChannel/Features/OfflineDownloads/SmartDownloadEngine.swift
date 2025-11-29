//
//  SmartDownloadEngine.swift
//  MyChannel
//
//  🧠🔥 SMART DOWNLOAD ENGINE - AI-POWERED AUTO-DOWNLOADS 🔥🧠
//  YouTube Premium Smart Downloads Parity
//
//  Features:
//  - ML-based content recommendation for downloads
//  - Watch pattern analysis
//  - Storage-aware downloading
//  - Time-based scheduling
//  - Content freshness management
//

import Foundation
import Combine
import CoreML

// MARK: - Smart Download Engine
@MainActor
final class SmartDownloadEngine: ObservableObject {
    static let shared = SmartDownloadEngine()
    
    // MARK: - Published State
    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var recommendedVideos: [SmartDownloadRecommendation] = []
    @Published private(set) var downloadedSmartVideos: [String] = []
    @Published private(set) var lastSmartDownloadRun: Date?
    @Published private(set) var nextScheduledRun: Date?
    @Published private(set) var storageAllocated: Int64 = 2_147_483_648 // 2GB default
    @Published private(set) var storageUsed: Int64 = 0
    
    // MARK: - Settings
    @Published var maxVideosToDownload: Int = 20
    @Published var preferredQuality: NuclearDownloadQuality = .medium
    @Published var includeSubscriptions: Bool = true
    @Published var includeRecommended: Bool = true
    @Published var includeWatchLater: Bool = true
    @Published var includeShorts: Bool = true
    @Published var downloadTimeWindow: DownloadTimeWindow = .overnight
    @Published var refreshFrequency: RefreshFrequency = .daily
    
    // MARK: - Private Properties
    private let downloadManager = NuclearDownloadManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "smart_download_settings"
    
    // Watch pattern tracking
    private var watchPatterns: [WatchPattern] = []
    private var channelAffinityScores: [String: Double] = [:]
    private var categoryPreferences: [String: Double] = [:]
    private var watchTimeByHour: [Int: Int] = [:] // Hour -> minutes watched
    
    // MARK: - Initialization
    private init() {
        loadSettings()
        loadWatchPatterns()
        
        // Observe download manager
        downloadManager.$downloads
            .sink { [weak self] downloads in
                self?.updateStorageUsed(downloads)
            }
            .store(in: &cancellables)
        
        print("🧠 [SmartDownload] Engine initialized")
    }
    
    // MARK: - Public API
    
    /// Enable smart downloads
    func enable() async {
        isEnabled = true
        saveSettings()
        
        // Schedule first run
        await scheduleNextRun()
        
        // Run initial analysis
        await analyzeWatchPatterns()
        await generateRecommendations()
        
        print("🧠 [SmartDownload] Enabled")
    }
    
    /// Disable smart downloads
    func disable() {
        isEnabled = false
        saveSettings()
        
        // Cancel scheduled runs
        nextScheduledRun = nil
        
        print("🧠 [SmartDownload] Disabled")
    }
    
    /// Manually trigger smart download check
    func runSmartDownloads() async {
        guard isEnabled else { return }
        guard downloadManager.networkStatus == .wifi else {
            print("🧠 [SmartDownload] Skipping - not on WiFi")
            return
        }
        
        print("🧠 [SmartDownload] Running smart download check...")
        
        // Analyze patterns
        await analyzeWatchPatterns()
        
        // Generate fresh recommendations
        await generateRecommendations()
        
        // Download top recommendations
        await downloadRecommendedVideos()
        
        // Clean up old smart downloads
        await cleanupOldDownloads()
        
        lastSmartDownloadRun = Date()
        await scheduleNextRun()
        
        saveSettings()
    }
    
    /// Record a watch event for pattern analysis
    func recordWatch(
        videoId: String,
        channelId: String,
        category: String,
        duration: TimeInterval,
        watchedDuration: TimeInterval,
        completionRate: Double
    ) {
        let pattern = WatchPattern(
            videoId: videoId,
            channelId: channelId,
            category: category,
            duration: duration,
            watchedDuration: watchedDuration,
            completionRate: completionRate,
            watchedAt: Date(),
            hourOfDay: Calendar.current.component(.hour, from: Date()),
            dayOfWeek: Calendar.current.component(.weekday, from: Date())
        )
        
        watchPatterns.append(pattern)
        
        // Keep last 500 patterns
        if watchPatterns.count > 500 {
            watchPatterns.removeFirst(watchPatterns.count - 500)
        }
        
        // Update affinity scores
        updateAffinityScores(pattern)
        
        saveWatchPatterns()
    }
    
    /// Get storage allocation percentage
    var storageUsagePercentage: Double {
        guard storageAllocated > 0 else { return 0 }
        return Double(storageUsed) / Double(storageAllocated)
    }
    
    /// Set storage allocation for smart downloads
    func setStorageAllocation(_ bytes: Int64) {
        storageAllocated = max(bytes, 536_870_912) // Minimum 512MB
        saveSettings()
    }
    
    // MARK: - Pattern Analysis
    
    private func analyzeWatchPatterns() async {
        guard !watchPatterns.isEmpty else { return }
        
        // Reset scores
        channelAffinityScores.removeAll()
        categoryPreferences.removeAll()
        watchTimeByHour.removeAll()
        
        // Analyze patterns
        for pattern in watchPatterns {
            // Channel affinity (weighted by completion rate)
            let channelScore = channelAffinityScores[pattern.channelId] ?? 0
            channelAffinityScores[pattern.channelId] = channelScore + pattern.completionRate
            
            // Category preference
            let categoryScore = categoryPreferences[pattern.category] ?? 0
            categoryPreferences[pattern.category] = categoryScore + pattern.completionRate
            
            // Watch time by hour
            let hourMinutes = watchTimeByHour[pattern.hourOfDay] ?? 0
            watchTimeByHour[pattern.hourOfDay] = hourMinutes + Int(pattern.watchedDuration / 60)
        }
        
        // Normalize scores
        let maxChannelScore = channelAffinityScores.values.max() ?? 1
        for (channel, score) in channelAffinityScores {
            channelAffinityScores[channel] = score / maxChannelScore
        }
        
        let maxCategoryScore = categoryPreferences.values.max() ?? 1
        for (category, score) in categoryPreferences {
            categoryPreferences[category] = score / maxCategoryScore
        }
        
        print("🧠 [SmartDownload] Analyzed \(watchPatterns.count) patterns")
        print("🧠 [SmartDownload] Top channels: \(topChannels(5))")
        print("🧠 [SmartDownload] Top categories: \(topCategories(3))")
    }
    
    private func topChannels(_ count: Int) -> [String] {
        return channelAffinityScores
            .sorted { $0.value > $1.value }
            .prefix(count)
            .map { $0.key }
    }
    
    private func topCategories(_ count: Int) -> [String] {
        return categoryPreferences
            .sorted { $0.value > $1.value }
            .prefix(count)
            .map { $0.key }
    }
    
    // MARK: - Recommendation Generation
    
    private func generateRecommendations() async {
        var recommendations: [SmartDownloadRecommendation] = []
        
        // 1. Get videos from subscribed channels
        if includeSubscriptions {
            let subscriptionVideos = await fetchSubscriptionVideos()
            for video in subscriptionVideos {
                let score = calculateRecommendationScore(video)
                recommendations.append(SmartDownloadRecommendation(
                    video: video,
                    score: score,
                    reason: .subscription,
                    channelAffinity: channelAffinityScores[video.creator.id] ?? 0
                ))
            }
        }
        
        // 2. Get recommended videos
        if includeRecommended {
            let recommendedVideos = await fetchRecommendedVideos()
            for video in recommendedVideos {
                let score = calculateRecommendationScore(video)
                recommendations.append(SmartDownloadRecommendation(
                    video: video,
                    score: score,
                    reason: .recommended,
                    channelAffinity: channelAffinityScores[video.creator.id] ?? 0
                ))
            }
        }
        
        // 3. Get Watch Later videos
        if includeWatchLater {
            let watchLaterVideos = await fetchWatchLaterVideos()
            for video in watchLaterVideos {
                let score = calculateRecommendationScore(video) * 1.5 // Boost watch later
                recommendations.append(SmartDownloadRecommendation(
                    video: video,
                    score: score,
                    reason: .watchLater,
                    channelAffinity: channelAffinityScores[video.creator.id] ?? 0
                ))
            }
        }
        
        // 4. Get Shorts if enabled
        if includeShorts {
            let shorts = await fetchRecommendedShorts()
            for short in shorts {
                let score = calculateRecommendationScore(short) * 0.8 // Slightly lower priority
                recommendations.append(SmartDownloadRecommendation(
                    video: short,
                    score: score,
                    reason: .shorts,
                    channelAffinity: channelAffinityScores[short.creator.id] ?? 0
                ))
            }
        }
        
        // Remove duplicates and already downloaded
        let existingIds = Set(downloadManager.downloads.map { $0.videoId })
        recommendations = recommendations.filter { !existingIds.contains($0.video.id) }
        
        // Remove duplicates by video ID
        var seenIds = Set<String>()
        recommendations = recommendations.filter { rec in
            if seenIds.contains(rec.video.id) { return false }
            seenIds.insert(rec.video.id)
            return true
        }
        
        // Sort by score and limit
        recommendations.sort { $0.score > $1.score }
        recommendations = Array(recommendations.prefix(maxVideosToDownload * 2))
        
        self.recommendedVideos = recommendations
        
        print("🧠 [SmartDownload] Generated \(recommendations.count) recommendations")
    }
    
    private func calculateRecommendationScore(_ video: Video) -> Double {
        var score = 0.0
        
        // Channel affinity (0-40 points)
        let channelScore = channelAffinityScores[video.creator.id] ?? 0
        score += channelScore * 40
        
        // Category preference (0-30 points)
        // Would need video category - using creator ID as proxy
        let categoryScore = categoryPreferences[video.creator.id] ?? 0.5
        score += categoryScore * 30
        
        // Recency bonus (0-15 points)
        let hoursSinceUpload = Date().timeIntervalSince(video.createdAt) / 3600
        if hoursSinceUpload < 24 {
            score += 15
        } else if hoursSinceUpload < 72 {
            score += 10
        } else if hoursSinceUpload < 168 {
            score += 5
        }
        
        // Duration preference (0-10 points)
        // Prefer videos similar to average watch duration
        let avgWatchDuration = calculateAverageWatchDuration()
        let durationDiff = abs(video.duration - avgWatchDuration)
        if durationDiff < 300 { // Within 5 minutes
            score += 10
        } else if durationDiff < 600 {
            score += 5
        }
        
        // Engagement bonus (0-5 points)
        let engagementRate = Double(video.likeCount) / max(Double(video.viewCount), 1)
        score += min(engagementRate * 100, 5)
        
        return score
    }
    
    private func calculateAverageWatchDuration() -> TimeInterval {
        guard !watchPatterns.isEmpty else { return 600 } // Default 10 min
        
        let totalDuration = watchPatterns.reduce(0.0) { $0 + $1.watchedDuration }
        return totalDuration / Double(watchPatterns.count)
    }
    
    // MARK: - Download Execution
    
    private func downloadRecommendedVideos() async {
        let availableStorage = storageAllocated - storageUsed
        var downloadedCount = 0
        var usedStorage: Int64 = 0
        
        for recommendation in recommendedVideos.prefix(maxVideosToDownload) {
            // Estimate size
            let estimatedSize = estimateVideoSize(recommendation.video, quality: preferredQuality)
            
            // Check if we have space
            if usedStorage + estimatedSize > availableStorage {
                print("🧠 [SmartDownload] Storage limit reached")
                break
            }
            
            do {
                _ = try await downloadManager.downloadVideo(
                    recommendation.video,
                    quality: preferredQuality,
                    priority: .low
                )
                
                downloadedSmartVideos.append(recommendation.video.id)
                usedStorage += estimatedSize
                downloadedCount += 1
                
                print("🧠 [SmartDownload] Queued: \(recommendation.video.title)")
            } catch {
                print("🧠 [SmartDownload] Failed to queue \(recommendation.video.title): \(error)")
            }
        }
        
        print("🧠 [SmartDownload] Queued \(downloadedCount) videos for download")
    }
    
    private func estimateVideoSize(_ video: Video, quality: NuclearDownloadQuality) -> Int64 {
        let bytesPerSecond: Int64
        switch quality {
        case .low: bytesPerSecond = 100_000 // ~100KB/s
        case .medium: bytesPerSecond = 300_000
        case .high: bytesPerSecond = 600_000
        case .ultra: bytesPerSecond = 1_200_000
        case .max: bytesPerSecond = 2_500_000
        case .adaptive: bytesPerSecond = 250_000
        }
        
        return Int64(video.duration) * bytesPerSecond
    }
    
    // MARK: - Cleanup
    
    private func cleanupOldDownloads() async {
        // Remove smart downloads that are:
        // 1. Watched (completion > 90%)
        // 2. Older than 7 days and unwatched
        // 3. Expired
        
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        
        for download in downloadManager.downloads {
            // Skip non-smart downloads
            guard downloadedSmartVideos.contains(download.videoId) else { continue }
            
            var shouldRemove = false
            var reason = ""
            
            // Check if watched
            if download.watchProgress > 0.9 {
                shouldRemove = true
                reason = "watched"
            }
            
            // Check if old and unwatched
            if let downloadedAt = download.downloadedAt,
               downloadedAt < sevenDaysAgo,
               download.watchProgress < 0.1 {
                shouldRemove = true
                reason = "stale"
            }
            
            // Check if expired
            if download.isExpired {
                shouldRemove = true
                reason = "expired"
            }
            
            if shouldRemove {
                do {
                    try await downloadManager.deleteDownload(download.id)
                    downloadedSmartVideos.removeAll { $0 == download.videoId }
                    print("🧠 [SmartDownload] Removed \(reason) video: \(download.title)")
                } catch {
                    print("🧠 [SmartDownload] Failed to remove: \(error)")
                }
            }
        }
    }
    
    // MARK: - Scheduling
    
    private func scheduleNextRun() async {
        let calendar = Calendar.current
        var nextDate: Date
        
        switch refreshFrequency {
        case .daily:
            nextDate = calendar.date(byAdding: .day, value: 1, to: Date())!
        case .twiceDaily:
            nextDate = calendar.date(byAdding: .hour, value: 12, to: Date())!
        case .weekly:
            nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: Date())!
        }
        
        // Adjust to preferred time window
        switch downloadTimeWindow {
        case .overnight:
            nextDate = calendar.date(bySettingHour: 3, minute: 0, second: 0, of: nextDate)!
        case .morning:
            nextDate = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: nextDate)!
        case .evening:
            nextDate = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: nextDate)!
        case .anytime:
            break // Keep as is
        }
        
        nextScheduledRun = nextDate
    }
    
    // MARK: - Data Fetching (Placeholders)
    
    private func fetchSubscriptionVideos() async -> [Video] {
        // TODO: Integrate with subscription service
        return []
    }
    
    private func fetchRecommendedVideos() async -> [Video] {
        // TODO: Integrate with recommendation service
        return []
    }
    
    private func fetchWatchLaterVideos() async -> [Video] {
        // TODO: Integrate with playlist service
        return []
    }
    
    private func fetchRecommendedShorts() async -> [Video] {
        // TODO: Integrate with shorts service
        return []
    }
    
    // MARK: - Affinity Updates
    
    private func updateAffinityScores(_ pattern: WatchPattern) {
        // Exponential moving average for channel affinity
        let alpha = 0.1 // Learning rate
        let currentScore = channelAffinityScores[pattern.channelId] ?? 0.5
        let newScore = (1 - alpha) * currentScore + alpha * pattern.completionRate
        channelAffinityScores[pattern.channelId] = newScore
        
        // Update category preference
        let currentCatScore = categoryPreferences[pattern.category] ?? 0.5
        let newCatScore = (1 - alpha) * currentCatScore + alpha * pattern.completionRate
        categoryPreferences[pattern.category] = newCatScore
    }
    
    private func updateStorageUsed(_ downloads: [NuclearDownload]) {
        storageUsed = downloads
            .filter { downloadedSmartVideos.contains($0.videoId) }
            .reduce(0) { $0 + $1.totalBytes }
    }
    
    // MARK: - Persistence
    
    private func saveSettings() {
        let settings = SmartDownloadSettings(
            isEnabled: isEnabled,
            maxVideosToDownload: maxVideosToDownload,
            preferredQuality: preferredQuality,
            includeSubscriptions: includeSubscriptions,
            includeRecommended: includeRecommended,
            includeWatchLater: includeWatchLater,
            includeShorts: includeShorts,
            downloadTimeWindow: downloadTimeWindow,
            refreshFrequency: refreshFrequency,
            storageAllocated: storageAllocated,
            lastSmartDownloadRun: lastSmartDownloadRun,
            downloadedSmartVideos: downloadedSmartVideos
        )
        
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }
    
    private func loadSettings() {
        guard let data = userDefaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(SmartDownloadSettings.self, from: data) else {
            return
        }
        
        isEnabled = settings.isEnabled
        maxVideosToDownload = settings.maxVideosToDownload
        preferredQuality = settings.preferredQuality
        includeSubscriptions = settings.includeSubscriptions
        includeRecommended = settings.includeRecommended
        includeWatchLater = settings.includeWatchLater
        includeShorts = settings.includeShorts
        downloadTimeWindow = settings.downloadTimeWindow
        refreshFrequency = settings.refreshFrequency
        storageAllocated = settings.storageAllocated
        lastSmartDownloadRun = settings.lastSmartDownloadRun
        downloadedSmartVideos = settings.downloadedSmartVideos
    }
    
    private func saveWatchPatterns() {
        if let data = try? JSONEncoder().encode(watchPatterns) {
            userDefaults.set(data, forKey: "smart_download_patterns")
        }
    }
    
    private func loadWatchPatterns() {
        guard let data = userDefaults.data(forKey: "smart_download_patterns"),
              let patterns = try? JSONDecoder().decode([WatchPattern].self, from: data) else {
            return
        }
        watchPatterns = patterns
    }
}

// MARK: - Models

struct SmartDownloadRecommendation: Identifiable {
    var id: String { video.id }
    let video: Video
    let score: Double
    let reason: RecommendationReason
    let channelAffinity: Double
}

enum RecommendationReason: String, Codable {
    case subscription = "From your subscriptions"
    case recommended = "Recommended for you"
    case watchLater = "In your Watch Later"
    case shorts = "Popular Short"
    case trending = "Trending"
}

struct WatchPattern: Codable {
    let videoId: String
    let channelId: String
    let category: String
    let duration: TimeInterval
    let watchedDuration: TimeInterval
    let completionRate: Double
    let watchedAt: Date
    let hourOfDay: Int
    let dayOfWeek: Int
}

enum DownloadTimeWindow: String, Codable, CaseIterable {
    case overnight = "Overnight (2-6 AM)"
    case morning = "Morning (6-9 AM)"
    case evening = "Evening (9 PM-12 AM)"
    case anytime = "Anytime"
}

enum RefreshFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case twiceDaily = "Twice Daily"
    case weekly = "Weekly"
}

struct SmartDownloadSettings: Codable {
    let isEnabled: Bool
    let maxVideosToDownload: Int
    let preferredQuality: NuclearDownloadQuality
    let includeSubscriptions: Bool
    let includeRecommended: Bool
    let includeWatchLater: Bool
    let includeShorts: Bool
    let downloadTimeWindow: DownloadTimeWindow
    let refreshFrequency: RefreshFrequency
    let storageAllocated: Int64
    let lastSmartDownloadRun: Date?
    let downloadedSmartVideos: [String]
}
