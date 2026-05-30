import Foundation
import UserNotifications
import UIKit

/// Phase 79: Advanced Notification Engine
/// Handles local pushes and simulates UNNotificationServiceExtension logic for rich media.
@MainActor
final class RichNotificationService: ObservableObject {
    static let shared = RichNotificationService()
    
    private init() {
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("🔔 [NotificationEngine] Notifications authorized.")
            } else if let error = error {
                print("⚠️ [NotificationEngine] Failed to authorize notifications: \(error)")
            }
        }
    }
    
    /// Simulates pushing a notification with a rich media attachment (e.g. video thumbnail GIF)
    func scheduleRichNotification(title: String, body: String, mediaURL: URL?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // If a media URL is provided, try to attach it
        if let url = mediaURL {
            Task {
                do {
                    // Download the file locally to a temp directory
                    let (tempURL, _) = try await URLSession.shared.download(from: url)
                    
                    // Move it to a place with the correct extension so UNNotificationAttachment can read it
                    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let finalURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
                    
                    if FileManager.default.fileExists(atPath: finalURL.path) {
                        try FileManager.default.removeItem(at: finalURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: finalURL)
                    
                    let attachment = try UNNotificationAttachment(identifier: "richMedia", url: finalURL, options: nil)
                    content.attachments = [attachment]
                    
                    self.triggerPush(with: content)
                } catch {
                    print("⚠️ [NotificationEngine] Failed to attach rich media: \(error)")
                    // Trigger without media
                    self.triggerPush(with: content)
                }
            }
        } else {
            triggerPush(with: content)
        }
    }
    
    private func triggerPush(with content: UNNotificationContent) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ [NotificationEngine] Failed to schedule push: \(error)")
            } else {
                print("🔔 [NotificationEngine] Rich push scheduled successfully.")
            }
        }
    }
}
