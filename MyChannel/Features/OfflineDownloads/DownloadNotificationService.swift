//
//  DownloadNotificationService.swift
//  MyChannel
//
//  🔔🔥 DOWNLOAD NOTIFICATION SERVICE 🔥🔔
//  Background download notifications
//
//  Features:
//  - Download progress notifications
//  - Completion notifications
//  - Error notifications
//  - Smart downloads ready notification
//  - Storage warning notifications
//

import Foundation
import UserNotifications
import Combine
import UIKit

// MARK: - Download Notification Service
@MainActor
final class DownloadNotificationService: ObservableObject {
    static let shared = DownloadNotificationService()
    
    // MARK: - Published State
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var pendingNotifications: [PendingNotification] = []
    
    // MARK: - Settings
    @Published var showProgressNotifications: Bool = true
    @Published var showCompletionNotifications: Bool = true
    @Published var showErrorNotifications: Bool = true
    @Published var showSmartDownloadNotifications: Bool = true
    @Published var showStorageWarnings: Bool = true
    @Published var groupNotifications: Bool = true
    
    // MARK: - Private Properties
    private let notificationCenter = UNUserNotificationCenter.current()
    private let downloadManager = NuclearDownloadManager.shared
    private let smartEngine = SmartDownloadEngine.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Notification identifiers
    private let progressNotificationId = "download_progress"
    private let groupId = "com.mychannel.downloads"
    
    // MARK: - Initialization
    private init() {
        checkAuthorizationStatus()
        setupObservers()
        loadSettings()
        
        print("🔔 [Notifications] Service initialized")
    }
    
    // MARK: - Authorization
    
    /// Request notification permissions
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            
            if granted {
                await registerNotificationCategories()
            }
            
            return granted
        } catch {
            print("🔔 [Notifications] Authorization error: \(error)")
            return false
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Notification Categories
    
    private func registerNotificationCategories() async {
        // Download complete actions
        let playAction = UNNotificationAction(
            identifier: "PLAY_ACTION",
            title: "Play",
            options: [.foreground]
        )
        
        let deleteAction = UNNotificationAction(
            identifier: "DELETE_ACTION",
            title: "Delete",
            options: [.destructive]
        )
        
        let downloadCompleteCategory = UNNotificationCategory(
            identifier: "DOWNLOAD_COMPLETE",
            actions: [playAction, deleteAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Download error actions
        let retryAction = UNNotificationAction(
            identifier: "RETRY_ACTION",
            title: "Retry",
            options: [.foreground]
        )
        
        let cancelAction = UNNotificationAction(
            identifier: "CANCEL_ACTION",
            title: "Cancel",
            options: [.destructive]
        )
        
        let downloadErrorCategory = UNNotificationCategory(
            identifier: "DOWNLOAD_ERROR",
            actions: [retryAction, cancelAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Smart downloads actions
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "View Downloads",
            options: [.foreground]
        )
        
        let smartDownloadsCategory = UNNotificationCategory(
            identifier: "SMART_DOWNLOADS",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Storage warning actions
        let manageAction = UNNotificationAction(
            identifier: "MANAGE_ACTION",
            title: "Manage Storage",
            options: [.foreground]
        )
        
        let storageWarningCategory = UNNotificationCategory(
            identifier: "STORAGE_WARNING",
            actions: [manageAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([
            downloadCompleteCategory,
            downloadErrorCategory,
            smartDownloadsCategory,
            storageWarningCategory
        ])
    }
    
    // MARK: - Setup Observers
    
    private func setupObservers() {
        // Observe download completions
        downloadManager.$downloads
            .removeDuplicates()
            .sink { [weak self] downloads in
                Task { @MainActor in
                    self?.handleDownloadsChanged(downloads)
                }
            }
            .store(in: &cancellables)
        
        // Observe smart downloads
        smartEngine.$downloadedSmartVideos
            .removeDuplicates()
            .sink { [weak self] videos in
                Task { @MainActor in
                    if !videos.isEmpty {
                        await self?.sendSmartDownloadsNotification(count: videos.count)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Observe storage usage
        downloadManager.$totalStorageUsed
            .sink { [weak self] used in
                Task { @MainActor in
                    self?.checkStorageWarning(used: used)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleDownloadsChanged(_ downloads: [NuclearDownload]) {
        // Check for completed downloads
        let completed = downloads.filter { $0.status == .completed }
        let failed = downloads.filter { $0.status == .failed }
        
        // Track which notifications we've sent
        for download in completed {
            if !sentNotifications.contains(download.id) {
                Task {
                    await sendCompletionNotification(for: download)
                    sentNotifications.insert(download.id)
                }
            }
        }
        
        for download in failed {
            if !sentNotifications.contains("error_\(download.id)") {
                Task {
                    await sendErrorNotification(for: download)
                    sentNotifications.insert("error_\(download.id)")
                }
            }
        }
    }
    
    private var sentNotifications = Set<String>()
    
    // MARK: - Send Notifications
    
    /// Send download completion notification
    func sendCompletionNotification(for download: NuclearDownload) async {
        guard isAuthorized && showCompletionNotifications else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.body = "\"\(download.title)\" is ready to watch offline"
        content.sound = .default
        content.categoryIdentifier = "DOWNLOAD_COMPLETE"
        content.userInfo = [
            "videoId": download.videoId,
            "downloadId": download.id
        ]
        
        if groupNotifications {
            content.threadIdentifier = groupId
        }
        
        // Add thumbnail if available
        if let thumbURL = download.localThumbnailURL {
            if let attachment = try? UNNotificationAttachment(
                identifier: download.id,
                url: thumbURL,
                options: nil
            ) {
                content.attachments = [attachment]
            }
        }
        
        let request = UNNotificationRequest(
            identifier: "complete_\(download.id)",
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
        
        // Update badge
        await updateBadgeCount()
        
        print("🔔 [Notifications] Sent completion: \(download.title)")
    }
    
    /// Send download error notification
    func sendErrorNotification(for download: NuclearDownload) async {
        guard isAuthorized && showErrorNotifications else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Download Failed"
        content.body = "Couldn't download \"\(download.title)\". Tap to retry."
        content.sound = .default
        content.categoryIdentifier = "DOWNLOAD_ERROR"
        content.userInfo = [
            "videoId": download.videoId,
            "downloadId": download.id,
            "error": download.errorMessage ?? "Unknown error"
        ]
        
        if groupNotifications {
            content.threadIdentifier = groupId
        }
        
        let request = UNNotificationRequest(
            identifier: "error_\(download.id)",
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
        
        print("🔔 [Notifications] Sent error: \(download.title)")
    }
    
    /// Send download progress notification (for long downloads)
    func sendProgressNotification(for download: NuclearDownload) async {
        guard isAuthorized && showProgressNotifications else { return }
        guard download.progress > 0.1 else { return } // Only after 10%
        
        let content = UNMutableNotificationContent()
        content.title = "Downloading..."
        content.body = "\(download.title) - \(Int(download.progress * 100))%"
        content.sound = nil // Silent for progress updates
        
        if groupNotifications {
            content.threadIdentifier = groupId
        }
        
        let request = UNNotificationRequest(
            identifier: progressNotificationId,
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
    }
    
    /// Send smart downloads notification
    func sendSmartDownloadsNotification(count: Int) async {
        guard isAuthorized && showSmartDownloadNotifications else { return }
        guard count > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Smart Downloads Ready"
        content.body = "\(count) videos downloaded for offline viewing"
        content.sound = .default
        content.categoryIdentifier = "SMART_DOWNLOADS"
        
        if groupNotifications {
            content.threadIdentifier = groupId
        }
        
        let request = UNNotificationRequest(
            identifier: "smart_downloads_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
        
        print("🔔 [Notifications] Sent smart downloads ready: \(count)")
    }
    
    /// Send storage warning notification
    func sendStorageWarningNotification(usedPercentage: Double) async {
        guard isAuthorized && showStorageWarnings else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Storage Almost Full"
        content.body = "Downloads are using \(Int(usedPercentage * 100))% of allocated storage. Tap to manage."
        content.sound = .default
        content.categoryIdentifier = "STORAGE_WARNING"
        
        if groupNotifications {
            content.threadIdentifier = groupId
        }
        
        let request = UNNotificationRequest(
            identifier: "storage_warning",
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
        
        print("🔔 [Notifications] Sent storage warning: \(Int(usedPercentage * 100))%")
    }
    
    /// Send batch completion notification
    func sendBatchCompletionNotification(count: Int, totalSize: Int64) async {
        guard isAuthorized && showCompletionNotifications else { return }
        
        let sizeString = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        
        let content = UNMutableNotificationContent()
        content.title = "Downloads Complete"
        content.body = "\(count) videos ready to watch offline (\(sizeString))"
        content.sound = .default
        content.categoryIdentifier = "DOWNLOAD_COMPLETE"
        
        if groupNotifications {
            content.threadIdentifier = groupId
        }
        
        let request = UNNotificationRequest(
            identifier: "batch_complete_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
        
        print("🔔 [Notifications] Sent batch completion: \(count) videos")
    }
    
    // MARK: - Storage Warning Check
    
    private var lastStorageWarning: Date?
    
    private func checkStorageWarning(used: Int64) {
        let limit = downloadManager.storageLimit
        guard limit > 0 else { return }
        
        let percentage = Double(used) / Double(limit)
        
        // Warn at 80% and 95%
        if percentage > 0.95 {
            // Only warn once per day
            if let lastWarning = lastStorageWarning,
               Date().timeIntervalSince(lastWarning) < 86400 {
                return
            }
            
            Task {
                await sendStorageWarningNotification(usedPercentage: percentage)
                lastStorageWarning = Date()
            }
        } else if percentage > 0.80 {
            // Only warn once per week at 80%
            if let lastWarning = lastStorageWarning,
               Date().timeIntervalSince(lastWarning) < 604800 {
                return
            }
            
            Task {
                await sendStorageWarningNotification(usedPercentage: percentage)
                lastStorageWarning = Date()
            }
        }
    }
    
    // MARK: - Badge Management
    
    private func updateBadgeCount() async {
        let pendingDownloads = downloadManager.downloads.filter {
            $0.status == .downloading || $0.status == .queued
        }.count
        
        try? await notificationCenter.setBadgeCount(pendingDownloads)
    }
    
    /// Clear all download notifications
    func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        sentNotifications.removeAll()
    }
    
    /// Clear notification for specific download
    func clearNotification(for downloadId: String) {
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [
            "complete_\(downloadId)",
            "error_\(downloadId)"
        ])
        sentNotifications.remove(downloadId)
        sentNotifications.remove("error_\(downloadId)")
    }
    
    // MARK: - Handle Notification Actions
    
    func handleNotificationAction(
        _ actionIdentifier: String,
        userInfo: [AnyHashable: Any]
    ) async {
        guard let videoId = userInfo["videoId"] as? String,
              let downloadId = userInfo["downloadId"] as? String else {
            return
        }
        
        switch actionIdentifier {
        case "PLAY_ACTION":
            // Navigate to video player
            NotificationCenter.default.post(
                name: .playOfflineVideo,
                object: nil,
                userInfo: ["videoId": videoId]
            )
            
        case "DELETE_ACTION":
            try? await downloadManager.deleteDownload(downloadId)
            
        case "RETRY_ACTION":
            // Re-queue download
            if let download = downloadManager.downloads.first(where: { $0.id == downloadId }) {
                await downloadManager.resumeDownload(download.id)
            }
            
        case "CANCEL_ACTION":
            await downloadManager.cancelDownload(downloadId)
            
        case "VIEW_ACTION", "MANAGE_ACTION":
            // Navigate to downloads view
            NotificationCenter.default.post(
                name: .navigateToDownloads,
                object: nil
            )
            
        default:
            break
        }
    }
    
    // MARK: - Persistence
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(showProgressNotifications, forKey: "notif_progress")
        defaults.set(showCompletionNotifications, forKey: "notif_completion")
        defaults.set(showErrorNotifications, forKey: "notif_error")
        defaults.set(showSmartDownloadNotifications, forKey: "notif_smart")
        defaults.set(showStorageWarnings, forKey: "notif_storage")
        defaults.set(groupNotifications, forKey: "notif_group")
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        // Default to true for all
        showProgressNotifications = defaults.object(forKey: "notif_progress") as? Bool ?? true
        showCompletionNotifications = defaults.object(forKey: "notif_completion") as? Bool ?? true
        showErrorNotifications = defaults.object(forKey: "notif_error") as? Bool ?? true
        showSmartDownloadNotifications = defaults.object(forKey: "notif_smart") as? Bool ?? true
        showStorageWarnings = defaults.object(forKey: "notif_storage") as? Bool ?? true
        groupNotifications = defaults.object(forKey: "notif_group") as? Bool ?? true
    }
}

// MARK: - Models

struct PendingNotification: Identifiable {
    let id: String
    let type: NotificationType
    let title: String
    let body: String
    let scheduledFor: Date?
    let videoId: String?
}

enum NotificationType {
    case progress
    case completion
    case error
    case smartDownloads
    case storageWarning
}

// MARK: - Notification Names

extension Notification.Name {
    static let playOfflineVideo = Notification.Name("playOfflineVideo")
    static let navigateToDownloads = Notification.Name("navigateToDownloads")
}
