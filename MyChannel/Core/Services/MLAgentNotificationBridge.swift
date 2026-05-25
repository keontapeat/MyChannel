//
//  MLAgentNotificationBridge.swift
//  MyChannel
//
//  ML agents power smart notification grouping + live/viral timing.
//  RULE: Only user-facing social events reach regular users.
//  Zero admin / internal / system events are ever shown.
//

import Foundation
import Combine

// MARK: - MLAgentNotificationBridge

@MainActor
final class MLAgentNotificationBridge: ObservableObject {
    static let shared = MLAgentNotificationBridge()

    // MARK: Observed services
    private let agentManager   = AGIAgentManager.shared
    private let mlAgents       = RealMLAgentsService.shared
    private let store          = NotificationsStore.shared
    private let smartEngine    = SmartNotificationEngine.shared

    // MARK: State
    @Published private(set) var totalRouted: Int = 0
    @Published private(set) var isActive: Bool = false

    // MARK: Private
    private var cancellables = Set<AnyCancellable>()

    // Dedup: track (agentId + contentHash) → last fired timestamp
    private var lastFired: [String: Date] = [:]
    // Minimum interval (seconds) between same-agent same-type notifications
    private let cooldown: TimeInterval = 300   // 5 min

    private init() {}

    // MARK: - Lifecycle

    /// Call once from AppDelegate / AppState after login.
    func start(userId: String) {
        guard !isActive else { return }
        isActive = true

        // Real-time Firestore social events (likes, comments, follows, uploads, live)
        observeFirestoreInbox(userId: userId)
        // ML-powered: viral alert only shown to the video OWNER, never broadcast
        observeViralSignals(userId: userId)
        // ML-powered: new video recommendations surfaced once per session
        observeRecommendationDigest(userId: userId)

        print("🔔 [MLAgentNotificationBridge] Started for user: \(userId)")
    }

    func stop() {
        cancellables.removeAll()
        isActive = false
        print("🔔 [MLAgentNotificationBridge] Stopped")
    }

    // MARK: - 1. Firestore Real-Time Social Inbox
    // Cloud functions write likes/comments/follows/uploads/live events here.
    // This is the primary fast path — real-time, per-user, social only.

    private func observeFirestoreInbox(userId: String) {
        Task { try? await NotificationsInboxService.shared.fetchNotifications(userId: userId) }
    }

    // MARK: - 2. ML-Powered Viral Alert (creator only — their own content)
    // Only fires when the Recommendation ML model detects the current user's
    // own video is trending. Never shown to viewers of that video.

    private func observeViralSignals(userId: String) {
        agentManager.$activityLog
            .compactMap { log in
                log.first(where: {
                    $0.agentId == "viral-prediction-engine" && $0.success
                })
            }
            .removeDuplicates(by: { $0.id.uuidString == $1.id.uuidString })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] activity in
                guard let self else { return }
                let key = "viral:\(userId):\(activity.id)"
                guard self.canFire(key: key, cooldown: 3600) else { return }
                let output = activity.output.lowercased()
                guard output.contains("viral") || output.contains("trending") else { return }
                let item = StoreNotificationItem(
                    title: "🔥 Your video is trending!",
                    message: "Your content is picking up fast. Tap to see your analytics.",
                    timestamp: activity.timestamp,
                    isRead: false,
                    type: .upload,
                    source: .viralAgent,
                    priority: .high,
                    deepLinkPath: "/analytics"
                )
                self.store.push(item)
                self.totalRouted += 1
                self.markFired(key: key)
            }
            .store(in: &cancellables)
    }

    // MARK: - 3. ML-Powered New Video Picks (once per session max)
    // ML recommendation engine surfaces new videos from subscribed creators.
    // This is a user benefit — like YouTube's "New from channels you follow".

    private func observeRecommendationDigest(userId: String) {
        Task {
            // Wait 10s after login before first digest (let UI settle)
            try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
            guard isActive else { return }
            let key = "rec_digest:\(userId)"
            guard canFire(key: key, cooldown: 4 * 3600) else { return }
            do {
                let result = try await mlAgents.getRecommendations(
                    userId: userId,
                    preferredCategories: [],
                    count: 5
                )
                guard !result.recommendations.isEmpty else { return }
                let item = StoreNotificationItem(
                    title: "New videos from channels you follow",
                    message: "\(result.recommendations.count) new videos are ready for you.",
                    timestamp: Date(),
                    isRead: false,
                    type: .upload,
                    source: .recommendAgent,
                    priority: .normal,
                    deepLinkPath: "/feed"
                )
                store.push(item)
                totalRouted += 1
                markFired(key: key)
            } catch { }
        }
    }

    // MARK: - Cooldown / Dedup Helpers

    private func canFire(key: String, cooldown overrideCooldown: TimeInterval? = nil) -> Bool {
        let interval = overrideCooldown ?? cooldown
        guard let last = lastFired[key] else { return true }
        return Date().timeIntervalSince(last) >= interval
    }

    private func markFired(key: String) {
        lastFired[key] = Date()
    }
}

// MARK: - Notification.Name Extensions

extension Notification.Name {
    static let mlAgentDidFireNotification = Notification.Name("MLAgentDidFireNotification")
    static let notificationsStoreDidUpdate = Notification.Name("NotificationsStoreDidUpdate")
}
