//
//  EnhancedVideoAnalytics.swift
//  MyChannel
//
//  Enhanced video analytics with watch time heatmaps and drop-off tracking
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Video Watch Session Model (prefixed to avoid conflicts)
struct VideoWatchSession: Codable, Identifiable {
    let id: String
    let videoId: String
    let userId: String
    let startTime: Date
    var endTime: Date?
    var segments: [VideoWatchSegment]
    var totalWatchTime: TimeInterval
    var completionRate: Double // 0.0 - 1.0
    var deviceType: String
    var qualityChanges: [VideoQualityChange]
    var bufferingEvents: [VideoBufferingEvent]
    var interactionEvents: [VideoInteractionEvent]
    
    init(videoId: String, userId: String) {
        self.id = UUID().uuidString
        self.videoId = videoId
        self.userId = userId
        self.startTime = Date()
        self.segments = []
        self.totalWatchTime = 0
        self.completionRate = 0
        self.deviceType = UIDevice.current.model
        self.qualityChanges = []
        self.bufferingEvents = []
        self.interactionEvents = []
    }
}

// MARK: - Video Watch Segment (for heatmap)
struct VideoWatchSegment: Codable {
    let startPosition: TimeInterval
    let endPosition: TimeInterval
    let timestamp: Date
    var rewatched: Bool
    
    var duration: TimeInterval {
        endPosition - startPosition
    }
}

// MARK: - Video Quality Change Event
struct VideoQualityChange: Codable {
    let timestamp: Date
    let position: TimeInterval
    let fromQuality: String
    let toQuality: String
    let reason: String // "user", "auto", "network"
}

// MARK: - Video Buffering Event
struct VideoBufferingEvent: Codable {
    let timestamp: Date
    let position: TimeInterval
    let duration: TimeInterval
    let networkType: String
}

// MARK: - Video Interaction Event
struct VideoInteractionEvent: Codable {
    let timestamp: Date
    let position: TimeInterval
    let type: VideoInteractionType
    let metadata: [String: String]?
}

enum VideoInteractionType: String, Codable {
    case like
    case dislike
    case comment
    case share
    case subscribe
    case pause
    case resume
    case seek
    case fullscreen
    case miniPlayer
    case pip
    case speedChange
    case captionsToggle
}

// MARK: - Video Analytics Summary
struct VideoAnalyticsSummary: Codable {
    let videoId: String
    var totalViews: Int
    var uniqueViewers: Int
    var totalWatchTime: TimeInterval
    var averageWatchTime: TimeInterval
    var averageCompletionRate: Double
    var heatmapData: [HeatmapBucket]
    var dropOffPoints: [DropOffPoint]
    var peakConcurrentViewers: Int
    var engagementRate: Double // (likes + comments + shares) / views
    var retentionCurve: [RetentionPoint]
    var demographicBreakdown: DemographicData?
    var trafficSources: [TrafficSource]
    var deviceBreakdown: [DeviceStats]
    
    struct HeatmapBucket: Codable {
        let startPercent: Double // 0-100
        let endPercent: Double
        var viewCount: Int
        var rewatchCount: Int
        
        var intensity: Double {
            Double(viewCount + rewatchCount * 2) // Rewatches count double
        }
    }
    
    struct DropOffPoint: Codable {
        let position: TimeInterval
        let percentPosition: Double
        var dropOffCount: Int
        var dropOffRate: Double // % of viewers who left at this point
    }
    
    struct RetentionPoint: Codable {
        let percentPosition: Double // 0, 10, 20, ..., 100
        let retentionRate: Double // % of viewers still watching
    }
    
    struct DemographicData: Codable {
        var ageGroups: [String: Int]
        var genderBreakdown: [String: Int]
        var topCountries: [String: Int]
        var topCities: [String: Int]
    }
    
    struct TrafficSource: Codable {
        let source: String // "search", "suggested", "external", "direct", "playlist"
        var views: Int
        var watchTime: TimeInterval
    }
    
    struct DeviceStats: Codable {
        let deviceType: String
        var views: Int
        var averageWatchTime: TimeInterval
    }
}

// MARK: - Enhanced Video Analytics Service
@MainActor
class EnhancedVideoAnalyticsService: ObservableObject {
    static let shared = EnhancedVideoAnalyticsService()
    
    @Published var currentSession: VideoWatchSession?
    @Published var isTracking = false
    
    private var sessionStartPosition: TimeInterval = 0
    private var lastKnownPosition: TimeInterval = 0
    private var videoDuration: TimeInterval = 0
    private var positionUpdateTimer: Timer?
    
    private let batchSize = 10
    private var pendingSessions: [VideoWatchSession] = []
    
    private init() {}
    
    // MARK: - Session Management
    
    func startSession(videoId: String, userId: String, duration: TimeInterval) {
        // End any existing session
        if currentSession != nil {
            endSession()
        }
        
        videoDuration = duration
        currentSession = VideoWatchSession(videoId: videoId, userId: userId)
        sessionStartPosition = 0
        lastKnownPosition = 0
        isTracking = true
        
        // Start position tracking
        startPositionTracking()
        
        print("📊 [Analytics] Started session for video: \(videoId)")
    }
    
    func updatePosition(_ position: TimeInterval) {
        guard var session = currentSession else { return }
        
        // Detect if this is a seek (jump of more than 2 seconds)
        let isSeek = abs(position - lastKnownPosition) > 2
        
        if isSeek {
            // Close current segment
            if lastKnownPosition > sessionStartPosition {
                let segment = VideoWatchSegment(
                    startPosition: sessionStartPosition,
                    endPosition: lastKnownPosition,
                    timestamp: Date(),
                    rewatched: position < lastKnownPosition
                )
                session.segments.append(segment)
            }
            
            // Log seek event
            let seekEvent = VideoInteractionEvent(
                timestamp: Date(),
                position: position,
                type: .seek,
                metadata: ["from": "\(lastKnownPosition)", "to": "\(position)"]
            )
            session.interactionEvents.append(seekEvent)
            
            // Start new segment
            sessionStartPosition = position
        }
        
        lastKnownPosition = position
        
        // Update completion rate
        if videoDuration > 0 {
            session.completionRate = position / videoDuration
        }
        
        // Calculate total watch time from segments
        session.totalWatchTime = session.segments.reduce(0) { $0 + $1.duration }
        session.totalWatchTime += max(0, position - sessionStartPosition)
        
        currentSession = session
    }
    
    func endSession() {
        guard var session = currentSession else { return }
        
        // Close final segment
        if lastKnownPosition > sessionStartPosition {
            let segment = VideoWatchSegment(
                startPosition: sessionStartPosition,
                endPosition: lastKnownPosition,
                timestamp: Date(),
                rewatched: false
            )
            session.segments.append(segment)
        }
        
        session.endTime = Date()
        
        // Stop tracking
        stopPositionTracking()
        isTracking = false
        
        // Queue for upload
        pendingSessions.append(session)
        
        // Upload if batch is full
        if pendingSessions.count >= batchSize {
            Task {
                await uploadPendingSessions()
            }
        }
        
        print("📊 [Analytics] Ended session - Watch time: \(session.totalWatchTime)s, Completion: \(Int(session.completionRate * 100))%")
        
        currentSession = nil
    }
    
    // MARK: - Event Tracking
    
    func trackInteraction(_ type: VideoInteractionType, metadata: [String: String]? = nil) {
        guard var session = currentSession else { return }
        
        let event = VideoInteractionEvent(
            timestamp: Date(),
            position: lastKnownPosition,
            type: type,
            metadata: metadata
        )
        session.interactionEvents.append(event)
        currentSession = session
        
        // Also log to Firebase Analytics
        Task {
            await AnalyticsService.shared.trackEvent(
                "video_interaction",
                parameters: [
                    "video_id": session.videoId,
                    "interaction_type": type.rawValue,
                    "position": lastKnownPosition
                ]
            )
        }
    }
    
    func trackBuffering(duration: TimeInterval, networkType: String) {
        guard var session = currentSession else { return }
        
        let event = VideoBufferingEvent(
            timestamp: Date(),
            position: lastKnownPosition,
            duration: duration,
            networkType: networkType
        )
        session.bufferingEvents.append(event)
        currentSession = session
    }
    
    func trackQualityChange(from: String, to: String, reason: String) {
        guard var session = currentSession else { return }
        
        let change = VideoQualityChange(
            timestamp: Date(),
            position: lastKnownPosition,
            fromQuality: from,
            toQuality: to,
            reason: reason
        )
        session.qualityChanges.append(change)
        currentSession = session
    }
    
    // MARK: - Heatmap Generation
    
    func generateHeatmap(for videoId: String, bucketCount: Int = 100) async -> [VideoAnalyticsSummary.HeatmapBucket] {
        var buckets: [VideoAnalyticsSummary.HeatmapBucket] = []
        let bucketSize = 100.0 / Double(bucketCount)
        
        for i in 0..<bucketCount {
            let startPercent = Double(i) * bucketSize
            let endPercent = startPercent + bucketSize
            buckets.append(VideoAnalyticsSummary.HeatmapBucket(
                startPercent: startPercent,
                endPercent: endPercent,
                viewCount: 0,
                rewatchCount: 0
            ))
        }
        
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("watch-sessions")
                .whereField("videoId", isEqualTo: videoId)
                .getDocuments()
            
            for doc in snapshot.documents {
                if let segmentsData = doc.data()["segments"] as? [[String: Any]] {
                    for segmentData in segmentsData {
                        guard let startPos = segmentData["startPosition"] as? Double,
                              let endPos = segmentData["endPosition"] as? Double,
                              let duration = doc.data()["videoDuration"] as? Double,
                              duration > 0 else { continue }
                        
                        let startPercent = (startPos / duration) * 100
                        let endPercent = (endPos / duration) * 100
                        let rewatched = segmentData["rewatched"] as? Bool ?? false
                        
                        // Increment buckets that this segment covers
                        for i in 0..<buckets.count {
                            if buckets[i].startPercent < endPercent && buckets[i].endPercent > startPercent {
                                buckets[i].viewCount += 1
                                if rewatched {
                                    buckets[i].rewatchCount += 1
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            print("🚨 [Analytics] Error generating heatmap: \(error)")
        }
        #endif
        
        return buckets
    }
    
    // MARK: - Drop-off Analysis
    
    func analyzeDropOffPoints(for videoId: String) async -> [VideoAnalyticsSummary.DropOffPoint] {
        var dropOffPoints: [VideoAnalyticsSummary.DropOffPoint] = []
        
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("watch-sessions")
                .whereField("videoId", isEqualTo: videoId)
                .getDocuments()
            
            var endPositions: [Double] = []
            var totalSessions = 0
            
            for doc in snapshot.documents {
                totalSessions += 1
                if let segments = doc.data()["segments"] as? [[String: Any]],
                   let lastSegment = segments.last,
                   let endPos = lastSegment["endPosition"] as? Double,
                   let duration = doc.data()["videoDuration"] as? Double,
                   duration > 0 {
                    let percentPos = (endPos / duration) * 100
                    endPositions.append(percentPos)
                }
            }
            
            // Group by 5% buckets and find significant drop-offs
            var bucketCounts: [Int: Int] = [:]
            for pos in endPositions {
                let bucket = Int(pos / 5) * 5
                bucketCounts[bucket, default: 0] += 1
            }
            
            // Calculate drop-off rates
            var viewersRemaining = totalSessions
            for bucket in stride(from: 0, through: 95, by: 5) {
                let dropOffs = bucketCounts[bucket] ?? 0
                let dropOffRate = totalSessions > 0 ? Double(dropOffs) / Double(totalSessions) : 0
                
                if dropOffRate > 0.05 { // Only include significant drop-offs (>5%)
                    dropOffPoints.append(VideoAnalyticsSummary.DropOffPoint(
                        position: Double(bucket),
                        percentPosition: Double(bucket),
                        dropOffCount: dropOffs,
                        dropOffRate: dropOffRate
                    ))
                }
                
                viewersRemaining -= dropOffs
            }
        } catch {
            print("🚨 [Analytics] Error analyzing drop-offs: \(error)")
        }
        #endif
        
        return dropOffPoints
    }
    
    // MARK: - Retention Curve
    
    func generateRetentionCurve(for videoId: String) async -> [VideoAnalyticsSummary.RetentionPoint] {
        var retentionPoints: [VideoAnalyticsSummary.RetentionPoint] = []
        
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("watch-sessions")
                .whereField("videoId", isEqualTo: videoId)
                .getDocuments()
            
            let totalSessions = snapshot.documents.count
            guard totalSessions > 0 else { return retentionPoints }
            
            // Count how many viewers reached each 10% milestone
            for milestone in stride(from: 0, through: 100, by: 10) {
                var viewersReached = 0
                
                for doc in snapshot.documents {
                    if let completionRate = doc.data()["completionRate"] as? Double {
                        if completionRate * 100 >= Double(milestone) {
                            viewersReached += 1
                        }
                    }
                }
                
                retentionPoints.append(VideoAnalyticsSummary.RetentionPoint(
                    percentPosition: Double(milestone),
                    retentionRate: Double(viewersReached) / Double(totalSessions)
                ))
            }
        } catch {
            print("🚨 [Analytics] Error generating retention curve: \(error)")
        }
        #endif
        
        return retentionPoints
    }
    
    // MARK: - Private Helpers
    
    private func startPositionTracking() {
        positionUpdateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            // Position updates come from the video player
            // This timer is for periodic session saves
            Task { @MainActor in
                self?.saveSessionProgress()
            }
        }
    }
    
    private func stopPositionTracking() {
        positionUpdateTimer?.invalidate()
        positionUpdateTimer = nil
    }
    
    private func saveSessionProgress() {
        // Save current session state to local storage
        // This ensures data isn't lost if app crashes
        guard let session = currentSession else { return }
        
        do {
            let data = try JSONEncoder().encode(session)
            UserDefaults.standard.set(data, forKey: "currentVideoWatchSession")
        } catch {
            print("🚨 [Analytics] Error saving session: \(error)")
        }
    }
    
    private func uploadPendingSessions() async {
        guard !pendingSessions.isEmpty else { return }
        
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let batch = db.batch()
        
        for session in pendingSessions {
            do {
                let data = try JSONEncoder().encode(session)
                if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let docRef = db.collection("watch-sessions").document(session.id)
                    batch.setData(dict, forDocument: docRef)
                }
            } catch {
                print("🚨 [Analytics] Error encoding session: \(error)")
            }
        }
        
        do {
            try await batch.commit()
            print("📊 [Analytics] Uploaded \(pendingSessions.count) sessions")
            pendingSessions.removeAll()
        } catch {
            print("🚨 [Analytics] Error uploading sessions: \(error)")
        }
        #endif
    }
}

// MARK: - Preview
#if DEBUG
extension EnhancedVideoAnalyticsService {
    static var preview: EnhancedVideoAnalyticsService {
        let service = EnhancedVideoAnalyticsService.shared
        // Add mock data for previews
        return service
    }
}
#endif
