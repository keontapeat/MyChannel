//
//  PushNotificationService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import Foundation
import UserNotifications
import Combine
import SwiftUI
import UIKit

// MARK: - Push Notification Service
@MainActor
class PushNotificationService: ObservableObject {
    static let shared = PushNotificationService()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var deviceToken: String?
    @Published var hasPermission: Bool = false
    
    private let networkService = NetworkService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - Setup
    private func setupNotifications() {
        checkAuthorizationStatus()
        
        // Listen for authorization changes
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkAuthorizationStatus()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Permission Management
    func requestPermission() async -> Bool {
        guard AppConfig.Features.enablePushNotifications else {
            print("📱 Push notifications are disabled in app config")
            return false
        }
        
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound, .provisional, .criticalAlert]
            )
            
            await MainActor.run {
                hasPermission = granted
                authorizationStatus = granted ? .authorized : .denied
            }
            
            if granted {
                // Register for remote notifications
                await UIApplication.shared.registerForRemoteNotifications()
                
                // Track analytics
                await AnalyticsService.shared.trackEvent("notification_permission_granted")
                
                print("📱 Push notification permission granted")
            } else {
                await AnalyticsService.shared.trackEvent("notification_permission_denied")
                print("📱 Push notification permission denied")
            }
            
            return granted
            
        } catch {
            print("📱 Failed to request notification permission: \(error)")
            await AnalyticsService.shared.trackError(error, context: "push_notification_permission")
            return false
        }
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
                self?.hasPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Device Token Management
    func setDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token
        
        // Send token to backend
        Task {
            await registerDeviceToken(token)
        }
        
        print("📱 Device token registered: \(token.prefix(20))...")
    }
    
    func handleRegistrationError(_ error: Error) {
        print("📱 Failed to register for remote notifications: \(error)")
        Task {
            await AnalyticsService.shared.trackError(error, context: "push_notification_registration")
        }
    }
    
    private func registerDeviceToken(_ token: String) async {
        guard !AppConfig.Features.enableMockData else {
            print("📱 Mock mode: Device token registration skipped")
            return
        }
        
        do {
            var request = DeviceTokenRegistrationRequest(
                deviceToken: token,
                platform: "ios",
                appVersion: AppConfig.appVersion,
                environment: AppConfig.environment.rawValue
            )
            
            // Create a custom request with userId
            let requestWithUserId = DeviceTokenRegistrationRequestWithUser(
                deviceToken: token,
                platform: "ios",
                appVersion: AppConfig.appVersion,
                environment: AppConfig.environment.rawValue,
                userId: AuthService.shared.currentUser?.id
            )
            
            let _: APIResponse<EmptyResponse> = try await networkService.post(
                endpoint: .registerDeviceToken,
                body: requestWithUserId,
                responseType: APIResponse<EmptyResponse>.self
            )
            
            print("📱 Device token successfully registered with backend")
            
        } catch {
            print("📱 Failed to register device token with backend: \(error)")
        }
    }
    
    // MARK: - Local Notifications
    func scheduleLocalNotification(
        title: String,
        body: String,
        delay: TimeInterval,
        identifier: String? = nil,
        category: String? = nil,
        userInfo: [String: Any] = [:]
    ) async {
        guard hasPermission else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
        if let category = category {
            content.categoryIdentifier = category
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier ?? UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📱 Local notification scheduled: \(title)")
        } catch {
            print("📱 Failed to schedule local notification: \(error)")
        }
    }
    
    // MARK: - Notification Categories
    func setupNotificationCategories() {
        let likeAction = UNNotificationAction(
            identifier: "LIKE_ACTION",
            title: "❤️ Like",
            options: [.foreground]
        )
        
        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_ACTION",
            title: "💬 Reply",
            options: [.foreground],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Write a comment..."
        )
        
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "👀 View",
            options: [.foreground]
        )
        
        // Video interaction category
        let videoCategory = UNNotificationCategory(
            identifier: AppConfig.Notifications.likeCategory,
            actions: [likeAction, replyAction, viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Comment category
        let commentCategory = UNNotificationCategory(
            identifier: AppConfig.Notifications.commentCategory,
            actions: [replyAction, viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Follow category
        let followCategory = UNNotificationCategory(
            identifier: AppConfig.Notifications.followCategory,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            videoCategory,
            commentCategory,
            followCategory
        ])
        
        print("📱 Notification categories configured")
    }
    
    // MARK: - Handle Notification Response
    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        // Track analytics
        await AnalyticsService.shared.trackEvent("notification_action", parameters: [
            "action": actionIdentifier,
            "category": response.notification.request.content.categoryIdentifier
        ])
        
        switch actionIdentifier {
        case "LIKE_ACTION":
            await handleLikeAction(userInfo: userInfo)
        case "REPLY_ACTION":
            if let textResponse = response as? UNTextInputNotificationResponse {
                await handleReplyAction(userInfo: userInfo, text: textResponse.userText)
            }
        case "VIEW_ACTION":
            await handleViewAction(userInfo: userInfo)
        case UNNotificationDefaultActionIdentifier:
            await handleDefaultAction(userInfo: userInfo)
        default:
            break
        }
    }
    
    private func handleLikeAction(userInfo: [AnyHashable: Any]) async {
        guard let videoId = userInfo["video_id"] as? String else { return }
        
        do {
            try await VideoService.shared.likeVideo(videoId)
            
            // Show success notification
            await scheduleLocalNotification(
                title: "❤️ Liked!",
                body: "Video liked successfully",
                delay: 0.1
            )
        } catch {
            print("Failed to like video from notification: \(error)")
        }
    }
    
    private func handleReplyAction(userInfo: [AnyHashable: Any], text: String) async {
        guard let videoId = userInfo["video_id"] as? String else { return }
        
        // In a real app, you'd post the comment
        print("📱 Reply to video \(videoId): \(text)")
        
        await scheduleLocalNotification(
            title: "💬 Comment Posted",
            body: "Your comment has been posted",
            delay: 0.1
        )
    }
    
    private func handleViewAction(userInfo: [AnyHashable: Any]) async {
        // Navigate to the appropriate screen
        if let videoId = userInfo["video_id"] as? String {
            await navigateToVideo(videoId)
        } else if let userId = userInfo["user_id"] as? String {
            await navigateToProfile(userId)
        }
    }
    
    private func handleDefaultAction(userInfo: [AnyHashable: Any]) async {
        // Handle tap on notification body
        await handleViewAction(userInfo: userInfo)
    }
    
    // MARK: - Navigation Helpers
    private func navigateToVideo(_ videoId: String) async {
        // Post notification to navigate to video
        NotificationCenter.default.post(
            name: .navigateToVideo,
            object: nil,
            userInfo: ["videoId": videoId]
        )
    }
    
    private func navigateToProfile(_ userId: String) async {
        // Post notification to navigate to profile
        NotificationCenter.default.post(
            name: .navigateToProfile,
            object: nil,
            userInfo: ["userId": userId]
        )
    }
    
    // MARK: - Convenience Methods
    func sendVideoLikeNotification(videoTitle: String, userName: String) async {
        await scheduleLocalNotification(
            title: "❤️ New Like",
            body: "\(userName) liked your video '\(videoTitle)'",
            delay: 0.1,
            category: AppConfig.Notifications.likeCategory,
            userInfo: ["type": "like", "user_name": userName]
        )
    }
    
    func sendCommentNotification(videoTitle: String, userName: String, comment: String) async {
        await scheduleLocalNotification(
            title: "💬 New Comment",
            body: "\(userName) commented: \(comment)",
            delay: 0.1,
            category: AppConfig.Notifications.commentCategory,
            userInfo: ["type": "comment", "user_name": userName]
        )
    }
    
    func sendFollowNotification(userName: String) async {
        await scheduleLocalNotification(
            title: "👥 New Follower",
            body: "\(userName) started following you",
            delay: 0.1,
            category: AppConfig.Notifications.followCategory,
            userInfo: ["type": "follow", "user_name": userName]
        )
    }
    
    // MARK: - Badge Management
    func setBadgeCount(_ count: Int) {
        UIApplication.shared.applicationIconBadgeNumber = count
    }
    
    func clearBadge() {
        setBadgeCount(0)
    }
    
    // MARK: - Cleanup
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        clearBadge()
    }
}

// MARK: - Supporting Models
struct DeviceTokenRegistrationRequest: Codable {
    let deviceToken: String
    let platform: String
    let appVersion: String
    let environment: String
    
    init(deviceToken: String, platform: String, appVersion: String, environment: String) {
        self.deviceToken = deviceToken
        self.platform = platform
        self.appVersion = appVersion
        self.environment = environment
    }
}

struct DeviceTokenRegistrationRequestWithUser: Codable {
    let deviceToken: String
    let platform: String
    let appVersion: String
    let environment: String
    let userId: String?
    
    init(deviceToken: String, platform: String, appVersion: String, environment: String, userId: String?) {
        self.deviceToken = deviceToken
        self.platform = platform
        self.appVersion = appVersion
        self.environment = environment
        self.userId = userId
    }
}

// MARK: - API Extensions
extension APIEndpoint {
    static let registerDeviceToken = APIEndpoint.custom("/notifications/device-token")
}

// MARK: - Notification Names
extension Notification.Name {
    static let navigateToVideo = Notification.Name("navigateToVideo")
    static let navigateToProfile = Notification.Name("navigateToProfile")
}

#Preview("Push Notification Service Status") {
    VStack(spacing: 20) {
        Text("Push Notifications")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Permission:")
                    .fontWeight(.medium)
                Spacer()
                Text(PushNotificationService.shared.hasPermission ? "Granted" : "Not Granted")
                    .foregroundColor(PushNotificationService.shared.hasPermission ? .green : .red)
            }
            
            HStack {
                Text("Status:")
                    .fontWeight(.medium)
                Spacer()
                Text(statusText(PushNotificationService.shared.authorizationStatus))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let token = PushNotificationService.shared.deviceToken {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Device Token:")
                        .fontWeight(.medium)
                    Text("\(token.prefix(20))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Configuration:")
                    .fontWeight(.medium)
                
                Text("Enabled: \(AppConfig.Features.enablePushNotifications ? "Yes" : "No")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Categories: Like, Comment, Follow")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        Button("Request Permission") {
            Task {
                _ = await PushNotificationService.shared.requestPermission()
            }
        }
        .primaryButtonStyle()
        .disabled(PushNotificationService.shared.hasPermission)
        
        Spacer()
    }
    .padding()
}

private func statusText(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "Not Determined"
    case .denied: return "Denied"
    case .authorized: return "Authorized"
    case .provisional: return "Provisional"
    case .ephemeral: return "Ephemeral"
    @unknown default: return "Unknown"
    }
}