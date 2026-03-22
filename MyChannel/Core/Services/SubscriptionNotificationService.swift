//
//  SubscriptionNotificationService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import UserNotifications

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

// 🔔 Enterprise Subscription Notification Service
// Smart notification system with ML-powered personalization
@MainActor
class SubscriptionNotificationService: ObservableObject {
    static let shared = SubscriptionNotificationService()
    
    @Published var notificationPermission: UNAuthorizationStatus = .notDetermined
    @Published var isConfigured = false
    
    // ML Services
    private let notificationMLURL = "https://notification-ml-fkri6ifojq-uc.a.run.app"
    private let engagementPredictorURL = "https://engagement-predictor-fkri6ifojq-uc.a.run.app"
    
    private init() {
        checkNotificationPermission()
    }
    
    // MARK: - Configuration
    
    func configure() async {
        await requestNotificationPermission()
        setupNotificationCategories()
        isConfigured = true
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.notificationPermission = settings.authorizationStatus
            }
        }
    }
    
    private func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound, .provisional]
            )
            
            notificationPermission = granted ? .authorized : .denied
            
            if granted {
                await UIApplication.shared.registerForRemoteNotifications()
            }
            
        } catch {
            ErrorReportingManager.shared.reportError(
                error,
                context: "NotificationPermission",
                severity: .warning
            )
        }
    }
    
    private func setupNotificationCategories() {
        let videoUploadCategory = UNNotificationCategory(
            identifier: "VIDEO_UPLOAD",
            actions: [
                UNNotificationAction(
                    identifier: "WATCH_NOW",
                    title: "Watch Now",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "SAVE_FOR_LATER",
                    title: "Save for Later",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let liveStreamCategory = UNNotificationCategory(
            identifier: "LIVE_STREAM",
            actions: [
                UNNotificationAction(
                    identifier: "JOIN_STREAM",
                    title: "Join Stream",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "REMIND_LATER",
                    title: "Remind Me Later",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            videoUploadCategory,
            liveStreamCategory
        ])
    }
    
    // MARK: - Smart Notifications
    
    func sendVideoUploadNotification(
        video: Video,
        subscriberIds: [String]
    ) async {
        guard isConfigured else { return }
        
        // Get ML-powered notification optimization
        let optimizedNotifications = await optimizeNotifications(
            video: video,
            subscriberIds: subscriberIds
        )
        
        for notification in optimizedNotifications {
            await scheduleNotification(notification)
        }
    }
    
    private func optimizeNotifications(
        video: Video,
        subscriberIds: [String]
    ) async -> [OptimizedNotification] {
        do {
            let request = NotificationOptimizationRequest(
                videoId: video.id,
                creatorId: video.creator.id,
                videoMetadata: VideoMetadata(
                    title: video.title,
                    duration: video.duration,
                    category: video.category.rawValue,
                    tags: video.tags
                ),
                subscriberIds: subscriberIds
            )
            
            let response = try await performMLRequest(
                url: notificationMLURL + "/optimize",
                request: request,
                responseType: NotificationOptimizationResponse.self
            )
            
            return response.optimizedNotifications.map { mlNotification in
                OptimizedNotification(
                    userId: mlNotification.userId,
                    title: mlNotification.title,
                    body: mlNotification.body,
                    scheduledTime: Date(timeIntervalSince1970: mlNotification.scheduledTime),
                    priority: NotificationPriority(rawValue: mlNotification.priority) ?? .normal,
                    category: mlNotification.category,
                    metadata: mlNotification.metadata
                )
            }
            
        } catch {
            // Fallback to standard notifications
            return subscriberIds.map { userId in
                OptimizedNotification(
                    userId: userId,
                    title: "\(video.creator.displayName) uploaded a new video",
                    body: video.title,
                    scheduledTime: Date(),
                    priority: .normal,
                    category: "VIDEO_UPLOAD",
                    metadata: ["video_id": video.id]
                )
            }
        }
    }
    
    private func scheduleNotification(_ notification: OptimizedNotification) async {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.categoryIdentifier = notification.category
        content.userInfo = notification.metadata
        
        // Set badge count
        content.badge = await getUnreadNotificationCount(userId: notification.userId) as NSNumber
        
        // Schedule notification
        let timeInterval = max(1, notification.scheduledTime.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "subscription_\(notification.userId)_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            
            // Track notification sent
            EnhancedAnalyticsManager.shared.logEvent("subscription_notification_sent", parameters: [
                "user_id": notification.userId,
                "priority": notification.priority.rawValue,
                "category": notification.category,
                "scheduled_delay": timeInterval
            ])
            
        } catch {
            ErrorReportingManager.shared.reportError(
                error,
                context: "NotificationScheduling",
                severity: .warning,
                metadata: [
                    "user_id": notification.userId,
                    "category": notification.category
                ]
            )
        }
    }
    
    // MARK: - Notification Analytics
    
    func trackNotificationInteraction(
        notificationId: String,
        action: String,
        userId: String
    ) {
        EnhancedAnalyticsManager.shared.logEvent("notification_interaction", parameters: [
            "notification_id": notificationId,
            "action": action,
            "user_id": userId,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    private func getUnreadNotificationCount(userId: String) async -> Int {
        // Get unread notification count from Firestore
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("notifications")
                .whereField("read", isEqualTo: false)
                .getDocuments()
            
            return snapshot.documents.count
        } catch {
            return 0
        }
        #else
        return 0
        #endif
    }
    
    // MARK: - Helper Methods
    
    private func performMLRequest<T: Codable, R: Codable>(
        url: String,
        request: T,
        responseType: R.Type
    ) async throws -> R {
        guard let requestURL = URL(string: url) else {
            throw NotificationError.invalidURL
        }
        
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NotificationError.serverError
        }
        
        return try JSONDecoder().decode(responseType, from: data)
    }
}

// MARK: - Supporting Types

struct OptimizedNotification {
    let userId: String
    let title: String
    let body: String
    let scheduledTime: Date
    let priority: NotificationPriority
    let category: String
    let metadata: [String: Any]
}

enum NotificationPriority: String, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
}

struct VideoMetadata: Codable {
    let title: String
    let duration: TimeInterval
    let category: String
    let tags: [String]
}

// MARK: - ML Request/Response Types

struct NotificationOptimizationRequest: Codable {
    let videoId: String
    let creatorId: String
    let videoMetadata: VideoMetadata
    let subscriberIds: [String]
}

struct NotificationOptimizationResponse: Codable {
    let optimizedNotifications: [MLOptimizedNotification]
}

struct MLOptimizedNotification: Codable {
    let userId: String
    let title: String
    let body: String
    let scheduledTime: TimeInterval
    let priority: String
    let category: String
    let metadata: [String: String]
}

enum NotificationError: LocalizedError {
    case invalidURL
    case serverError
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid notification service URL"
        case .serverError:
            return "Notification server error"
        case .permissionDenied:
            return "Notification permission denied"
        }
    }
}
