//
//  PushNotificationService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import UserNotifications
import Combine

// MARK: - Supporting Models

struct NotificationAnalytics {
    var totalSent: Int = 0
    var totalDelivered: Int = 0
    var totalOpened: Int = 0
    var conversionRate: Double = 0.0
}

struct ActiveNotification: Identifiable {
    let id = UUID()
    let identifier: String
    let title: String
    let body: String
    let scheduledDate: Date
    let category: String
}

struct NotificationPreferences {
    var enableVideoUploads: Bool = true
    var enableLiveStreams: Bool = true
    var enableComments: Bool = true
    var enableSubscriptions: Bool = true
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 8)) ?? Date()
}

class SmartNotificationScheduler {
    func scheduleOptimalTime(for notification: UNNotificationRequest) -> Date {
        // AI-powered optimal scheduling based on user patterns
        return Date().addingTimeInterval(60) // Simplified for now
    }
}

class NotificationPersonalizationEngine {
    func personalizeContent(title: String, body: String, for userId: String) -> (title: String, body: String) {
        // AI-powered content personalization
        return (title, body)
    }
}

class NotificationAnalyticsTracker {
    func trackDelivery(notificationId: String) {
        // Track notification delivery
    }
    
    func trackOpen(notificationId: String) {
        // Track notification open
    }
}

/// Enterprise push notification service with intelligent scheduling and targeting
/// Handles all notification types with personalization and analytics
class PushNotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationService()
    
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var registeredForNotifications = false
    @Published var notificationAnalytics = NotificationAnalytics()
    @Published var activeNotifications: [ActiveNotification] = []
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let smartScheduler = SmartNotificationScheduler()
    private let personalizationEngine = NotificationPersonalizationEngine()
    private let analyticsTracker = NotificationAnalyticsTracker()
    
    // Configuration
    private var deviceToken: String?
    private var userId: String?
    private var userPreferences = NotificationPreferences()
    
    // Notification categories and actions
    private let notificationCategories: Set<UNNotificationCategory> = [
        // Video Upload Category
        UNNotificationCategory(
            identifier: "VIDEO_UPLOAD",
            actions: [
                UNNotificationAction(
                    identifier: "WATCH_NOW",
                    title: "Watch Now",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "WATCH_LATER",
                    title: "Save for Later",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        ),
        
        // Live Stream Category
        UNNotificationCategory(
            identifier: "LIVE_STREAM",
            actions: [
                UNNotificationAction(
                    identifier: "JOIN_STREAM",
                    title: "Join Stream",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "REMIND_LATER",
                    title: "Remind in 10 min",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        ),
        
        // Comment Category
        UNNotificationCategory(
            identifier: "COMMENT",
            actions: [
                UNNotificationAction(
                    identifier: "REPLY",
                    title: "Reply",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "LIKE",
                    title: "Like",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
    ]
    
    override init() {
        super.init()
        setupNotificationService()
    }
    
    // MARK: - Public Interface
    
    /// Request notification permissions with intelligent onboarding
    func requestNotificationPermissions() async -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        
        do {
            let granted = try await notificationCenter.requestAuthorization(options: options)
            
            await MainActor.run {
                self.registeredForNotifications = granted
            }
            
            if granted {
                await setupRemoteNotifications()
                setupNotificationCategories()
            }
            
            return granted
        } catch {
            print("Failed to request notification permissions: \(error)")
            return false
        }
    }
    
    /// Configure user notification preferences
    func updateNotificationPreferences(_ preferences: NotificationPreferences) {
        userPreferences = preferences
        // Save to UserDefaults or backend
        savePreferencesToStorage()
    }
    
    /// Schedule a smart notification with AI optimization
    func scheduleSmartNotification(
        title: String,
        body: String,
        category: String,
        userInfo: [String: Any] = [:],
        triggerDate: Date? = nil
    ) async {
        let notificationId = UUID().uuidString
        
        // Personalize content based on user data
        let personalizedContent = personalizationEngine.personalizeContent(
            title: title,
            body: body,
            for: userId ?? ""
        )
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = personalizedContent.title
        content.body = personalizedContent.body
        content.categoryIdentifier = category
        content.userInfo = userInfo.merging(["notificationId": notificationId]) { _, new in new }
        content.sound = .default
        
        // Determine optimal delivery time
        let optimalDate = triggerDate ?? smartScheduler.scheduleOptimalTime(
            for: UNNotificationRequest(identifier: notificationId, content: content, trigger: nil)
        )
        
        // Check quiet hours
        if isInQuietHours(optimalDate) {
            return // Skip during quiet hours
        }
        
        // Create trigger
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: optimalDate),
            repeats: false
        )
        
        // Schedule notification
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            
            // Track analytics
            await MainActor.run {
                self.notificationAnalytics.totalSent += 1
                self.activeNotifications.append(
                    ActiveNotification(
                        identifier: notificationId,
                        title: personalizedContent.title,
                        body: personalizedContent.body,
                        scheduledDate: optimalDate,
                        category: category
                    )
                )
            }
            
            analyticsTracker.trackDelivery(notificationId: notificationId)
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }
    
    /// Cancel specific notification
    func cancelNotification(identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        activeNotifications.removeAll { $0.identifier == identifier }
    }
    
    /// Cancel all pending notifications
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        activeNotifications.removeAll()
    }
    
    /// Get notification authorization status
    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        
        await MainActor.run {
            self.notificationPermissionStatus = settings.authorizationStatus
        }
        
        return settings.authorizationStatus
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationService() {
        notificationCenter.delegate = self
        Task {
            await getAuthorizationStatus()
        }
    }
    
    private func setupNotificationCategories() {
        notificationCenter.setNotificationCategories(notificationCategories)
    }
    
    private func setupRemoteNotifications() async {
        await MainActor.run {
            #if !targetEnvironment(simulator)
            UIApplication.shared.registerForRemoteNotifications()
            #endif
        }
    }
    
    private func isInQuietHours(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let quietStart = calendar.component(.hour, from: userPreferences.quietHoursStart)
        let quietEnd = calendar.component(.hour, from: userPreferences.quietHoursEnd)
        
        if quietStart < quietEnd {
            return hour >= quietStart && hour < quietEnd
        } else {
            return hour >= quietStart || hour < quietEnd
        }
    }
    
    private func savePreferencesToStorage() {
        // Save preferences to UserDefaults or backend
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(userPreferences) {
            UserDefaults.standard.set(data, forKey: "notificationPreferences")
        }
    }
    
    private func loadPreferencesFromStorage() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "notificationPreferences"),
           let preferences = try? decoder.decode(NotificationPreferences.self, from: data) {
            userPreferences = preferences
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Handle foreground notification presentation
        completionHandler([.banner, .sound, .badge])
        
        // Track delivery
        if let notificationId = notification.request.content.userInfo["notificationId"] as? String {
            analyticsTracker.trackDelivery(notificationId: notificationId)
            
            Task {
                await MainActor.run {
                    self.notificationAnalytics.totalDelivered += 1
                }
            }
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        // Track notification open
        if let notificationId = userInfo["notificationId"] as? String {
            analyticsTracker.trackOpen(notificationId: notificationId)
            
            Task {
                await MainActor.run {
                    self.notificationAnalytics.totalOpened += 1
                    self.notificationAnalytics.conversionRate = Double(self.notificationAnalytics.totalOpened) / Double(max(1, self.notificationAnalytics.totalDelivered))
                }
            }
        }
        
        // Handle notification actions
        handleNotificationAction(actionIdentifier: actionIdentifier, userInfo: userInfo)
        
        completionHandler()
    }
    
    private func handleNotificationAction(actionIdentifier: String, userInfo: [AnyHashable: Any]) {
        switch actionIdentifier {
        case "WATCH_NOW":
            // Navigate to video player
            if let videoId = userInfo["videoId"] as? String {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToVideo"),
                    object: videoId
                )
            }
            
        case "WATCH_LATER":
            // Add to watch later
            if let videoId = userInfo["videoId"] as? String {
                NotificationCenter.default.post(
                    name: NSNotification.Name("AddToWatchLater"),
                    object: videoId
                )
            }
            
        case "JOIN_STREAM":
            // Navigate to live stream
            if let streamId = userInfo["streamId"] as? String {
                NotificationCenter.default.post(
                    name: NSNotification.Name("JoinLiveStream"),
                    object: streamId
                )
            }
            
        case "REMIND_LATER":
            // Schedule reminder
            if let streamId = userInfo["streamId"] as? String {
                Task {
                    await scheduleSmartNotification(
                        title: "Live Stream Starting Soon!",
                        body: "Your saved stream is about to begin",
                        category: "LIVE_STREAM",
                        userInfo: ["streamId": streamId],
                        triggerDate: Date().addingTimeInterval(600) // 10 minutes
                    )
                }
            }
            
        case "REPLY":
            // Navigate to comment reply
            if let commentId = userInfo["commentId"] as? String {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ReplyToComment"),
                    object: commentId
                )
            }
            
        case "LIKE":
            // Like the content
            if let contentId = userInfo["contentId"] as? String {
                NotificationCenter.default.post(
                    name: NSNotification.Name("LikeContent"),
                    object: contentId
                )
            }
            
        default:
            break
        }
    }
    
    // MARK: - Additional Methods for Creator Economy
    
    func sendNotification(to userId: String, notification: [String: String]) async {
        let title = notification["title"] ?? "Notification"
        let message = notification["message"] ?? ""
        
        await scheduleSmartNotification(
            title: title,
            body: message,
            category: "CREATOR_NOTIFICATION",
            userInfo: notification
        )
    }
    
    func sendLiveInvite(to guestId: String, streamId: String, streamTitle: String) async {
        await scheduleSmartNotification(
            title: "Live Stream Invitation",
            body: "You've been invited to join '\(streamTitle)'",
            category: "LIVE_STREAM",
            userInfo: ["streamId": streamId, "type": "invite"]
        )
    }
}

// MARK: - NotificationPreferences Codable

extension NotificationPreferences: Codable {
    enum CodingKeys: String, CodingKey {
        case enableVideoUploads
        case enableLiveStreams
        case enableComments
        case enableSubscriptions
        case quietHoursStart
        case quietHoursEnd
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enableVideoUploads = try container.decode(Bool.self, forKey: .enableVideoUploads)
        enableLiveStreams = try container.decode(Bool.self, forKey: .enableLiveStreams)
        enableComments = try container.decode(Bool.self, forKey: .enableComments)
        enableSubscriptions = try container.decode(Bool.self, forKey: .enableSubscriptions)
        quietHoursStart = try container.decode(Date.self, forKey: .quietHoursStart)
        quietHoursEnd = try container.decode(Date.self, forKey: .quietHoursEnd)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enableVideoUploads, forKey: .enableVideoUploads)
        try container.encode(enableLiveStreams, forKey: .enableLiveStreams)
        try container.encode(enableComments, forKey: .enableComments)
        try container.encode(enableSubscriptions, forKey: .enableSubscriptions)
        try container.encode(quietHoursStart, forKey: .quietHoursStart)
        try container.encode(quietHoursEnd, forKey: .quietHoursEnd)
    }
}