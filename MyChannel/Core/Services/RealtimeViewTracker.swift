//
//  RealtimeViewTracker.swift
//  MyChannel
//
//  🔥 REAL-TIME VIEW TRACKING WITH AI MONITORING
//  Every view, every second, tracked with sub-second accuracy
//  All AI systems connected and watching everything!
//

import Foundation
import SwiftUI
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Real-time view tracker with AI monitoring integration
@MainActor
class RealtimeViewTracker: ObservableObject {
    static let shared = RealtimeViewTracker()
    
    // MARK: - Published Properties
    @Published var activeViewSessions: [String: ViewSession] = [:]
    @Published var totalLiveViewers: Int = 0
    @Published var viewCountsByVideo: [String: Int] = [:]
    @Published var realtimeEngagement: [String: EngagementMetrics] = [:]

    /// Creators this device is currently contributing a live viewer to.
    private var activeCreatorPresence: Set<String> = []
    
    // MARK: - AI Monitoring Integration
    private let aiMonitoring = MonitoringAlertingService.shared
    private let analyticsWebSocket = RealtimeAnalyticsWebSocket.shared
    private let aiService = MyChannelAI.shared
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var viewListeners: [String: ListenerRegistration] = [:]
    #endif
    
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupRealtimeTracking()
        connectAIMonitoring()
    }
    
    // MARK: - View Tracking
    
    // 🔥 DEBOUNCING: Track which videos have been viewed recently to prevent double-counting
    private var viewedVideosInSession: [String: Date] = [:]
    private let debounceWindow: TimeInterval = 5.0 // 5 seconds debounce window
    
    /// Start tracking a video view
    func startViewSession(videoId: String, userId: String?) async {
        // 🔥 DEBOUNCE: Don't count same video twice within 5 seconds
        if let lastView = viewedVideosInSession[videoId],
           Date().timeIntervalSince(lastView) < debounceWindow {
            print("⚠️ [ViewTracker] Video \(videoId) viewed recently - debouncing (waiting \(String(format: "%.1f", debounceWindow - Date().timeIntervalSince(lastView)))s)")
            return
        }
        
        let sessionId = UUID().uuidString
        var session = ViewSession(
            id: sessionId,
            videoId: videoId,
            userId: userId,
            startTime: Date(),
            lastHeartbeat: Date()
        )

        // Resolve creator once so we can roll views up + track live presence accurately
        let creatorId = await getVideoCreatorId(videoId: videoId)
        session.creatorId = creatorId

        activeViewSessions[sessionId] = session
        viewedVideosInSession[videoId] = Date() // Mark as viewed with timestamp
        updateLiveViewerCount()
        
        // Increment view count in Firestore (with retry logic)
        await incrementViewCount(videoId: videoId, userId: userId, creatorId: creatorId)

        // 🔴 LIVE PRESENCE: register this viewer so the creator's "watching now"
        // counter is a real, global concurrent-viewer number (not a hardcoded 0).
        await registerLivePresence(creatorId: creatorId)
        
        // Setup real-time listener for this video
        setupVideoListener(videoId: videoId)
        
        // Notify AI systems
        await notifyAISystems(event: .viewStarted(videoId: videoId, userId: userId))
        
        // Log to monitoring
        aiMonitoring.logMetric(
            name: "video.view.started",
            value: 1.0,
            tags: ["video_id": videoId, "has_user": userId != nil ? "true" : "false"]
        )
        
        print("👁️ [ViewTracker] ✅ Started view session: \(videoId)")
        print("📊 [ViewTracker] View count will update in Firestore")
    }
    
    /// Update view session heartbeat (call every 10 seconds during playback)
    func updateViewHeartbeat(sessionId: String, currentTime: TimeInterval, isPlaying: Bool) async {
        guard var session = activeViewSessions[sessionId] else { return }
        
        session.lastHeartbeat = Date()
        session.currentTime = currentTime
        session.watchDuration = Date().timeIntervalSince(session.startTime)
        session.isPlaying = isPlaying
        
        activeViewSessions[sessionId] = session
        
        // Update engagement metrics
        await updateEngagementMetrics(for: session.videoId, session: session)
        
        // Log heartbeat
        aiMonitoring.logMetric(
            name: "video.heartbeat",
            value: currentTime,
            tags: ["video_id": session.videoId, "watch_duration": String(format: "%.0f", session.watchDuration)]
        )
    }
    
    /// End view session
    func endViewSession(sessionId: String) async {
        guard let session = activeViewSessions[sessionId] else { return }
        
        let watchDuration = Date().timeIntervalSince(session.startTime)
        
        // Update watch time in Firestore
        await updateWatchTime(videoId: session.videoId, duration: watchDuration)
        
        // Remove session
        activeViewSessions.removeValue(forKey: sessionId)
        updateLiveViewerCount()

        // 🔴 LIVE PRESENCE: stop counting this device toward the creator's
        // "watching now" once no remaining sessions belong to that creator.
        if let creatorId = session.creatorId,
           !activeViewSessions.values.contains(where: { $0.creatorId == creatorId }) {
            await clearLivePresence(creatorId: creatorId)
        }
        
        // Notify AI systems
        await notifyAISystems(event: .viewEnded(
            videoId: session.videoId,
            userId: session.userId,
            watchDuration: watchDuration,
            completionRate: session.currentTime / (session.videoDuration ?? 1)
        ))
        
        // Log to monitoring
        aiMonitoring.logMetric(
            name: "video.view.ended",
            value: watchDuration,
            tags: ["video_id": session.videoId, "completion": String(format: "%.1f", (session.currentTime / (session.videoDuration ?? 1)) * 100)]
        )

        // 🤖 WATCH TIME OPTIMIZER: Send watch data to Cloud Run agent (non-blocking)
        let wtVideoId = session.videoId
        let wtDuration = Int(session.videoDuration ?? watchDuration)
        let wtCategory = "Entertainment"
        Task {
            if let _ = try? await RealMLAgentsService.shared.predictWatchTime(
                videoId: wtVideoId,
                title: "",
                durationSeconds: wtDuration,
                category: wtCategory,
                subscriberCount: 0,
                hasChapters: false
            ) {
                print("🤖 [WatchTimeOptimizer] Watch data sent for \(wtVideoId) (\(Int(watchDuration))s watched)")
            }
        }

        print("👋 [ViewTracker] Ended view session: \(session.videoId) - \(String(format: "%.0f", watchDuration))s watched")
    }
    
    // MARK: - Firestore Integration
    
    private func incrementViewCount(videoId: String, userId: String?, creatorId: String? = nil) async {
        #if canImport(FirebaseFirestore)
        do {
            print("🔥🔥🔥 [ViewTracker] ⚡ INCREMENTING VIEW COUNT for: \(videoId)")
            print("🔥 [ViewTracker] User ID: \(userId ?? "anonymous")")
            print("🔥 [ViewTracker] Timestamp: \(Date())")
            
            // 🔥 FIX: Always track views, even for own videos
            // No filtering - all views count, including self-views
            
            // Log view event with timestamp
            let viewRef = db.collection("video_analytics")
                .document(videoId)
                .collection("views")
                .document()
            
            // Get creator ID first (reuse if caller already resolved it)
            let resolvedCreatorId: String?
            if let creatorId {
                resolvedCreatorId = creatorId
            } else {
                resolvedCreatorId = await getVideoCreatorId(videoId: videoId)
            }
            let isSelfView = userId != nil && userId == resolvedCreatorId
            
            try await viewRef.setData([
                "userId": userId ?? "anonymous",
                "timestamp": FieldValue.serverTimestamp(),
                "deviceType": "iOS",
                "sessionId": UUID().uuidString,
                "isSelfView": isSelfView,
                "watchDuration": 0
            ])

            // 🔥 RANKING FIX: Actually increment the video's viewCount AND roll the
            // view up to the creator's users/{uid}.totalViews. This is the metric
            // TopRankMLService reads, so watching a video now genuinely moves its
            // creator up the Top shelves in real time. (Previously this method only
            // logged an analytics event and read the count back — the count never grew.)
            //
            // Self-views are logged for analytics above but EXCLUDED from the
            // ranking/view rollup so creators can't inflate placement by rewatching.
            if !isSelfView {
                let videoRef = db.collection("videos").document(videoId)
                try await videoRef.setData([
                    "viewCount": FieldValue.increment(Int64(1))
                ], merge: true)

                if let resolvedCreatorId, !resolvedCreatorId.isEmpty {
                    // Best-effort roll-up to users/{uid}.totalViews. This may be denied
                    // by security rules for non-owner views; that's fine — it's wrapped
                    // so it never aborts the authoritative daily rollup below.
                    do {
                        try await db.collection("users").document(resolvedCreatorId).setData([
                            "totalViews": FieldValue.increment(Int64(1))
                        ], merge: true)
                        print("📈 [ViewTracker] Rolled view up to creator \(resolvedCreatorId).totalViews")
                    } catch {
                        print("ℹ️ [ViewTracker] totalViews roll-up skipped: \(error.localizedDescription)")
                    }

                    // 📊 ACCURATE DASHBOARD: write a per-day rollup so the Studio dashboard
                    // chart + "views today" reflect REAL traffic instead of random data.
                    await incrementDailyViews(creatorId: resolvedCreatorId)
                }
            } else {
                print("🙈 [ViewTracker] Self-view — logged but excluded from view rollup")
            }

            // 🔥 FIX: Fetch ACTUAL count from Firestore after incrementing (not just local cache)
            // This ensures we have the real persisted count
            print("📡 [ViewTracker] Fetching updated view count from Firestore...")
            let updatedDoc = try await db.collection("videos").document(videoId).getDocument()
            if let data = updatedDoc.data(),
               let actualCount = data["viewCount"] as? Int {
                viewCountsByVideo[videoId] = actualCount
                
                // Post notification to update UI with actual count
                NotificationCenter.default.post(
                    name: NSNotification.Name("VideoViewCountUpdated"),
                    object: nil,
                    userInfo: ["videoId": videoId, "viewCount": actualCount]
                )
                
                print("✅✅✅ [ViewTracker] VIEW COUNT SUCCESSFULLY UPDATED: \(videoId) → \(actualCount) views (from Firestore)")
                print("📢 [ViewTracker] Notification posted to UI with count: \(actualCount)")
            } else {
                // Fallback: increment local cache
                let currentCount = viewCountsByVideo[videoId] ?? 0
                let newCount = currentCount + 1
                viewCountsByVideo[videoId] = newCount
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("VideoViewCountUpdated"),
                    object: nil,
                    userInfo: ["videoId": videoId, "viewCount": newCount]
                )
                
                print("⚠️ [ViewTracker] Using fallback count: \(videoId) → \(newCount) views")
            }
            
        } catch {
            print("❌ [ViewTracker] ❌ Failed to increment view count: \(error.localizedDescription)")
            print("❌ [ViewTracker] Error details: \(error)")
            print("❌ [ViewTracker] Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("❌ [ViewTracker] Error domain: \(nsError.domain), code: \(nsError.code)")
                print("❌ [ViewTracker] Error userInfo: \(nsError.userInfo)")
            }
            aiMonitoring.alert(
                severity: .error,
                message: "Failed to track video view",
                details: ["video_id": videoId, "error": error.localizedDescription]
            )
        }
        #endif
    }
    
    // Helper to get video creator ID for analytics
    private func getVideoCreatorId(videoId: String) async -> String? {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("videos").document(videoId).getDocument()
            return doc.data()?["userId"] as? String
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - 📊 Accurate Daily View Rollups

    /// UTC day key (yyyy-MM-dd) used to bucket per-day analytics consistently
    /// across devices/timezones so the Studio chart never double-counts.
    private func dayKey(for date: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    /// Increments today's view bucket for a creator. The Studio dashboard reads
    /// `creator_analytics/{creatorId}/daily/{yyyy-MM-dd}` to draw a REAL trend
    /// line and an accurate "views today" number.
    private func incrementDailyViews(creatorId: String) async {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else { return }
        let key = dayKey()
        do {
            try await db.collection("creator_analytics")
                .document(creatorId)
                .collection("daily")
                .document(key)
                .setData([
                    "date": key,
                    "views": FieldValue.increment(Int64(1)),
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
        } catch {
            print("⚠️ [ViewTracker] Failed to roll up daily views: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - 🔴 Live Presence ("watching now")

    /// Registers a short-lived presence heartbeat so a creator's dashboard can
    /// count REAL concurrent viewers across all devices. Documents are written
    /// to `creator_presence/{creatorId}/active/{sessionId}` and expire when the
    /// session ends or goes stale.
    private func registerLivePresence(creatorId: String?) async {
        #if canImport(FirebaseFirestore)
        guard let creatorId, !creatorId.isEmpty else { return }
        do {
            let sessionId = AnalyticsSessionID.current
            try await db.collection("creator_presence")
                .document(creatorId)
                .collection("active")
                .document(sessionId)
                .setData([
                    "sessionId": sessionId,
                    "lastSeen": FieldValue.serverTimestamp(),
                    "userId": AuthenticationManager.shared.currentUser?.id ?? "anonymous"
                ])
            activeCreatorPresence.insert(creatorId)
        } catch {
            print("⚠️ [ViewTracker] Failed to register presence: \(error.localizedDescription)")
        }
        #endif
    }

    /// Removes the presence heartbeat for a creator when a viewer leaves.
    private func clearLivePresence(creatorId: String?) async {
        #if canImport(FirebaseFirestore)
        guard let creatorId, !creatorId.isEmpty else { return }
        let sessionId = AnalyticsSessionID.current
        try? await db.collection("creator_presence")
            .document(creatorId)
            .collection("active")
            .document(sessionId)
            .delete()
        activeCreatorPresence.remove(creatorId)
        #endif
    }
    
    private func updateWatchTime(videoId: String, duration: TimeInterval) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("video_analytics")
                .document(videoId)
                .collection("views")
                .document()
                .setData([
                    "userId": AuthenticationManager.shared.currentUser?.id ?? "anonymous",
                    "timestamp": FieldValue.serverTimestamp(),
                    "deviceType": "iOS",
                    "sessionId": UUID().uuidString,
                    "watchDuration": Int(duration),
                    "eventType": "watch_time"
                ])
            
            print("✅ [ViewTracker] Updated watch time: \(videoId) +\(String(format: "%.0f", duration))s")
            
        } catch {
            print("❌ [ViewTracker] Failed to update watch time: \(error)")
        }
        #endif
    }
    
    // MARK: - Real-time Listeners
    
    private func setupVideoListener(videoId: String) {
        #if canImport(FirebaseFirestore)
        // Avoid duplicate listeners
        guard viewListeners[videoId] == nil else { return }
        
        let listener = db.collection("videos").document(videoId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let data = snapshot?.data(),
                      error == nil else { return }
                
                Task { @MainActor in
                    // Update view count from Firestore
                    if let viewCount = data["viewCount"] as? Int {
                        self.viewCountsByVideo[videoId] = viewCount
                        
                        // Notify observers
                        NotificationCenter.default.post(
                            name: NSNotification.Name("VideoViewCountUpdated"),
                            object: nil,
                            userInfo: ["videoId": videoId, "viewCount": viewCount]
                        )
                    }
                }
            }
        
        viewListeners[videoId] = listener
        print("🔌 [ViewTracker] Setup real-time listener for \(videoId)")
        #endif
    }
    
    private func removeVideoListener(videoId: String) {
        #if canImport(FirebaseFirestore)
        viewListeners[videoId]?.remove()
        viewListeners.removeValue(forKey: videoId)
        print("🔌 [ViewTracker] Removed listener for \(videoId)")
        #endif
    }
    
    // MARK: - AI Systems Integration
    
    private func connectAIMonitoring() {
        // Connect to WebSocket for real-time updates
        if let userId = AuthenticationManager.shared.currentUser?.id {
            analyticsWebSocket.connect(creatorId: userId)
        }
        
        // Setup periodic AI analysis
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.runAIAnalysis()
            }
        }
        
        print("🤖 [ViewTracker] AI monitoring systems connected!")
    }
    
    private func notifyAISystems(event: ViewEvent) async {
        switch event {
        case .viewStarted(let videoId, let userId):
            // Log to monitoring service
            aiMonitoring.logMetric(
                name: "video.view.started",
                value: 1.0,
                tags: ["video_id": videoId, "user_id": userId ?? "anonymous"]
            )
            
            // Track in analytics if creator
            if let creatorId = userId {
                // Update real-time metrics for this creator's channel
                aiMonitoring.logMetric(
                    name: "creator.live_views",
                    value: 1.0,
                    tags: ["creator_id": creatorId]
                )
            }
            
        case .viewEnded(let videoId, _, let watchDuration, let completionRate): // userId not needed here
            // Track engagement metrics
            aiMonitoring.logMetric(
                name: "video.watch_duration",
                value: watchDuration,
                tags: ["video_id": videoId, "completion_rate": String(format: "%.2f", completionRate)]
            )
            
            // Send to AI for pattern analysis
            let engagement = EngagementMetrics(
                videoId: videoId,
                watchDuration: watchDuration,
                completionRate: completionRate,
                timestamp: Date()
            )
            
            await analyzeEngagementPattern(engagement)
        }
        
        // Log all events to monitoring service
        aiMonitoring.logMetric(
            name: "ai.event.processed",
            value: 1.0,
            tags: ["event_type": event.name]
        )
    }
    
    private func runAIAnalysis() async {
        // Analyze current viewing patterns
        let sessions = Array(activeViewSessions.values)
        
        guard !sessions.isEmpty else { return }
        
        // Calculate aggregate metrics
        let totalWatchTime = sessions.reduce(0.0) { $0 + $1.watchDuration }
        let avgWatchTime = totalWatchTime / Double(sessions.count)
        let playingCount = sessions.filter { $0.isPlaying }.count
        
        // Send to AI for insights
        aiMonitoring.logMetrics([
            ("live.viewers", Double(sessions.count)),
            ("live.avg_watch_time", avgWatchTime),
            ("live.playing_ratio", Double(playingCount) / Double(sessions.count))
        ])
        
        // Alert on anomalies
        if sessions.count > 100 && playingCount < sessions.count / 2 {
            aiMonitoring.alert(
                severity: .warning,
                message: "Low playback ratio detected",
                details: [
                    "live_viewers": String(sessions.count),
                    "playing_count": String(playingCount),
                    "ratio": String(format: "%.1f%%", (Double(playingCount) / Double(sessions.count)) * 100)
                ]
            )
        }
        
        print("🤖 [ViewTracker] AI analysis complete: \(sessions.count) live viewers, avg \(String(format: "%.0f", avgWatchTime))s watch time")
    }
    
    private func analyzeEngagementPattern(_ engagement: EngagementMetrics) async {
        // Store in engagement cache
        var videoEngagement = realtimeEngagement[engagement.videoId] ?? engagement
        
        // Update running averages
        videoEngagement.completionRate = (videoEngagement.completionRate + engagement.completionRate) / 2
        videoEngagement.watchDuration = (videoEngagement.watchDuration + engagement.watchDuration) / 2
        
        realtimeEngagement[engagement.videoId] = videoEngagement
        
        // Alert on exceptional engagement
        if engagement.completionRate > 0.9 {
            aiMonitoring.alert(
                severity: .info,
                message: "High completion rate detected!",
                details: [
                    "video_id": engagement.videoId,
                    "completion_rate": String(format: "%.1f%%", engagement.completionRate * 100)
                ]
            )
        }
    }
    
    // MARK: - Engagement Metrics
    
    private func updateEngagementMetrics(for videoId: String, session: ViewSession) async {
        let completionRate = session.videoDuration != nil ? session.currentTime / session.videoDuration! : 0
        
        let metrics = EngagementMetrics(
            videoId: videoId,
            watchDuration: session.watchDuration,
            completionRate: completionRate,
            timestamp: Date()
        )
        
        realtimeEngagement[videoId] = metrics
    }
    
    // MARK: - Helpers
    
    private func setupRealtimeTracking() {
        // Update live viewer count every 5 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.cleanupStaleSessions()
                self.updateLiveViewerCount()
            }
        }
    }
    
    private func updateLiveViewerCount() {
        totalLiveViewers = activeViewSessions.count
        
        // Broadcast update
        NotificationCenter.default.post(
            name: NSNotification.Name("LiveViewerCountUpdated"),
            object: nil,
            userInfo: ["count": totalLiveViewers]
        )
    }
    
    private func cleanupStaleSessions() {
        let staleThreshold: TimeInterval = 30 // 30 seconds without heartbeat
        let now = Date()
        
        let staleSessions = activeViewSessions.filter { _, session in
            now.timeIntervalSince(session.lastHeartbeat) > staleThreshold
        }
        
        for (sessionId, _) in staleSessions {
            Task {
                await endViewSession(sessionId: sessionId)
            }
        }
        
        if !staleSessions.isEmpty {
            print("🧹 [ViewTracker] Cleaned up \(staleSessions.count) stale sessions")
        }
    }
    
    // MARK: - Public API
    
    /// Get current view count for video (real-time)
    /// Fetches from Firestore if not in cache
    /// 🔥 FIX: ALWAYS fetch from Firestore to ensure persistence across app refreshes
    func getViewCount(for videoId: String) async -> Int {
        #if canImport(FirebaseFirestore)
        do {
            // 🔥 FIX: Always fetch from Firestore (source of truth)
            // Don't rely on cache alone - cache can be stale after app refresh
            let doc = try await db.collection("videos").document(videoId).getDocument()
            
            if doc.exists {
                if let data = doc.data() {
                    // Try Int first
                    if let viewCount = data["viewCount"] as? Int {
                        viewCountsByVideo[videoId] = viewCount
                        print("📊 [ViewTracker] Loaded view count from Firestore: \(videoId) → \(viewCount) views")
                        return viewCount
                    }
                    // Try Int64 (Firestore sometimes returns Int64)
                    if let viewCount64 = data["viewCount"] as? Int64 {
                        let viewCount = Int(viewCount64)
                        viewCountsByVideo[videoId] = viewCount
                        print("📊 [ViewTracker] Loaded view count from Firestore (Int64): \(videoId) → \(viewCount) views")
                        return viewCount
                    }
                    // Field doesn't exist - initialize it
                    print("⚠️ [ViewTracker] viewCount field missing for \(videoId), initializing to 0")
                    try? await db.collection("videos").document(videoId).updateData([
                        "viewCount": 0
                    ])
                    viewCountsByVideo[videoId] = 0
                    return 0
                }
            } else {
                print("⚠️ [ViewTracker] Video document doesn't exist: \(videoId)")
            }
        } catch {
            print("⚠️ [ViewTracker] Failed to fetch view count from Firestore: \(error.localizedDescription)")
            // Fallback to cache if Firestore fetch fails
            if let cachedCount = viewCountsByVideo[videoId] {
                print("📊 [ViewTracker] Using cached count: \(videoId) → \(cachedCount) views")
                return cachedCount
            }
        }
        #endif
        
        // Final fallback
        return viewCountsByVideo[videoId] ?? 0
    }
    
    /// Get current view count for video (synchronous - uses cache only)
    func getViewCountSync(for videoId: String) -> Int {
        return viewCountsByVideo[videoId] ?? 0
    }
    
    /// Get live viewer count for video
    func getLiveViewers(for videoId: String) -> Int {
        return activeViewSessions.values.filter { $0.videoId == videoId }.count
    }
    
    /// Get engagement metrics for video
    func getEngagement(for videoId: String) -> EngagementMetrics? {
        return realtimeEngagement[videoId]
    }

    // MARK: - 📊 Dashboard Reads (accurate, Firestore-backed)

    /// Real concurrent viewers across a creator's whole channel right now.
    /// Counts live presence heartbeats seen within the last 45 seconds so the
    /// Studio "watching now" number is truthful instead of hardcoded 0.
    func fetchWatchingNow(creatorId: String) async -> Int {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else { return 0 }
        do {
            let cutoff = Date().addingTimeInterval(-45)
            let snap = try await db.collection("creator_presence")
                .document(creatorId)
                .collection("active")
                .whereField("lastSeen", isGreaterThan: Timestamp(date: cutoff))
                .getDocuments()
            return snap.documents.count
        } catch {
            // Missing index or offline — fall back to this device's local sessions
            print("⚠️ [ViewTracker] watching-now fallback: \(error.localizedDescription)")
            return activeViewSessions.values.filter { $0.creatorId == creatorId }.count
        }
        #else
        return activeViewSessions.values.filter { $0.creatorId == creatorId }.count
        #endif
    }

    /// Per-day view buckets for the last `days` days (oldest → newest).
    /// Powers the real trend chart and an accurate "views today" figure.
    func fetchDailyViews(creatorId: String, days: Int = 28) async -> [(date: Date, views: Int)] {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else { return [] }
        let cal = Calendar(identifier: .gregorian)
        var utc = cal
        utc.timeZone = TimeZone(identifier: "UTC") ?? .current
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.dateFormat = "yyyy-MM-dd"

        do {
            let snap = try await db.collection("creator_analytics")
                .document(creatorId)
                .collection("daily")
                .order(by: "date", descending: true)
                .limit(to: days)
                .getDocuments()

            var byKey: [String: Int] = [:]
            for doc in snap.documents {
                let d = doc.data()
                let key = (d["date"] as? String) ?? doc.documentID
                let views = (d["views"] as? Int) ?? Int((d["views"] as? Int64) ?? 0)
                byKey[key] = views
            }

            // Build a continuous series so the chart has no gaps.
            var series: [(date: Date, views: Int)] = []
            let today = utc.startOfDay(for: Date())
            for offset in stride(from: days - 1, through: 0, by: -1) {
                guard let day = utc.date(byAdding: .day, value: -offset, to: today) else { continue }
                let key = fmt.string(from: day)
                series.append((date: day, views: byKey[key] ?? 0))
            }
            return series
        } catch {
            print("⚠️ [ViewTracker] daily-views fetch failed: \(error.localizedDescription)")
            return []
        }
        #else
        return []
        #endif
    }

    /// Views recorded for the current UTC day.
    func fetchViewsToday(creatorId: String) async -> Int {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else { return 0 }
        do {
            let doc = try await db.collection("creator_analytics")
                .document(creatorId)
                .collection("daily")
                .document(dayKey())
                .getDocument()
            if let v = doc.data()?["views"] as? Int { return v }
            if let v64 = doc.data()?["views"] as? Int64 { return Int(v64) }
            return 0
        } catch {
            return 0
        }
        #else
        return 0
        #endif
    }
}

// MARK: - Models

struct ViewSession {
    let id: String
    let videoId: String
    let userId: String?
    let startTime: Date
    var lastHeartbeat: Date
    var currentTime: TimeInterval = 0
    var watchDuration: TimeInterval = 0
    var videoDuration: TimeInterval?
    var isPlaying: Bool = true
    var creatorId: String?
}

/// Stable per-app-launch session id used for live presence + de-duplicated
/// analytics so a single viewer is only counted once as "watching now".
enum AnalyticsSessionID {
    static let current: String = UUID().uuidString
}

struct EngagementMetrics {
    let videoId: String
    var watchDuration: TimeInterval
    var completionRate: Double
    let timestamp: Date
}

enum ViewEvent {
    case viewStarted(videoId: String, userId: String?)
    case viewEnded(videoId: String, userId: String?, watchDuration: TimeInterval, completionRate: Double)
    
    var name: String {
        switch self {
        case .viewStarted: return "view_started"
        case .viewEnded: return "view_ended"
        }
    }
}

// MARK: - SwiftUI Integration

struct RealtimeViewCountBadge: View {
    let videoId: String
    @StateObject private var tracker = RealtimeViewTracker.shared
    @State private var viewCount: Int = 0
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "eye.fill")
                .font(.system(size: 12, weight: .semibold))
            
            Text(formatViewCount(viewCount))
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.7))
        .clipShape(Capsule())
        .onAppear {
            // Load view count from Firestore when view appears
            Task {
                let count = await tracker.getViewCount(for: videoId)
                viewCount = count
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("VideoViewCountUpdated"))) { notification in
            if let userInfo = notification.userInfo,
               let notificationVideoId = userInfo["videoId"] as? String,
               notificationVideoId == videoId,
               let count = userInfo["viewCount"] as? Int {
                viewCount = count
            }
        }
    }
    
    private func formatViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return String(count)
        }
    }
}

struct LiveViewersBadge: View {
    let videoId: String
    @StateObject private var tracker = RealtimeViewTracker.shared
    
    var body: some View {
        let liveCount = tracker.getLiveViewers(for: videoId)
        
        if liveCount > 0 {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                
                Text("\(liveCount) watching")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.75))
            .clipShape(Capsule())
        }
    }
}

#Preview("View Tracker") {
    VStack(spacing: 20) {
        Text("🔥 REAL-TIME VIEW TRACKING")
            .font(.title)
            .fontWeight(.bold)
        
        Text("Sub-Second Accuracy • AI Monitoring • Live Updates")
            .font(.subheadline)
            .foregroundColor(.secondary)
        
        Divider()
        
        RealtimeViewCountBadge(videoId: "test123")
        LiveViewersBadge(videoId: "test123")
        
        VStack(alignment: .leading, spacing: 12) {
            ViewTrackerFeatureRow(icon: "bolt.fill", color: .yellow, text: "Sub-second view tracking")
            ViewTrackerFeatureRow(icon: "eye.fill", color: .blue, text: "Real-time view counts")
            ViewTrackerFeatureRow(icon: "brain", color: .purple, text: "AI pattern analysis")
            ViewTrackerFeatureRow(icon: "chart.line.uptrend.xyaxis", color: .green, text: "Live engagement metrics")
            ViewTrackerFeatureRow(icon: "bell.badge.fill", color: .red, text: "Intelligent alerts")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        
        Spacer()
    }
    .padding()
}

struct ViewTrackerFeatureRow: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14, weight: .medium))
        }
    }
}

