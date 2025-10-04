//
//  NotificationManager.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import UserNotifications

@MainActor
class NotificationManager: ObservableObject {
    @Published var inAppNotifications: [InAppNotification] = []
    @Published var hasPermission: Bool = false
    
    static let shared = NotificationManager()
    
    private init() {
        checkNotificationPermission()
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.hasPermission = granted
            }
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.hasPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - In-App Notifications
    
    func showInAppNotification(_ notification: InAppNotification) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            inAppNotifications.append(notification)
        }
        
        // Auto dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + notification.duration) {
            self.dismissInAppNotification(notification.id)
        }
    }
    
    func dismissInAppNotification(_ id: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            inAppNotifications.removeAll { $0.id == id }
        }
    }
    
    // MARK: - Convenience Methods
    
    func showSuccess(_ message: String) {
        showInAppNotification(InAppNotification(
            type: .success,
            title: "Success",
            message: message,
            duration: 2.0
        ))
    }
    
    func showError(_ message: String) {
        showInAppNotification(InAppNotification(
            type: .error,
            title: "Error",
            message: message,
            duration: 3.0
        ))
    }
    
    func showInfo(_ message: String) {
        showInAppNotification(InAppNotification(
            type: .info,
            title: "Info",
            message: message,
            duration: 2.5
        ))
    }
    
    // MARK: - Push Notifications
    
    func scheduleLocalNotification(title: String, body: String, delay: TimeInterval) {
        guard hasPermission else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - In-App Notification Model

struct InAppNotification: Identifiable, Equatable {
    let id: String = UUID().uuidString
    let type: NotificationType
    let title: String
    let message: String
    let duration: TimeInterval
    
    enum NotificationType {
        case success, error, warning, info
        
        var color: Color {
            switch self {
            case .success: return AppTheme.Colors.success
            case .error: return AppTheme.Colors.error
            case .warning: return AppTheme.Colors.warning
            case .info: return AppTheme.Colors.primary
            }
        }
        
        var iconName: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    static func == (lhs: InAppNotification, rhs: InAppNotification) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - In-App Notification View

struct InAppNotificationView: View {
    let notification: InAppNotification
    let onDismiss: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: notification.type.iconName)
                .font(.title3)
                .foregroundColor(notification.type.color)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .padding(4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(
                    color: AppTheme.Colors.textPrimary.opacity(0.1),
                    radius: 10,
                    x: 0,
                    y: 5
                )
        )
        .overlay(
            // Left accent border
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                .fill(notification.type.color)
                .frame(width: 4)
                .clipped(),
            alignment: .leading
        )
        .offset(x: dragOffset)
        .opacity(opacity)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let translationX = value.translation.width
                    if translationX > 0 {
                        dragOffset = translationX
                        opacity = max(0.3, 1.0 - translationX / 200)
                    }
                }
                .onEnded { value in
                    let translationX = value.translation.width
                    if translationX > 100 {
                        // Dismiss if dragged far enough
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = 300
                            opacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onDismiss()
                        }
                    } else {
                        // Snap back
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            dragOffset = 0
                            opacity = 1.0
                        }
                    }
                }
        )
    }
}

// MARK: - In-App Notifications Container

struct InAppNotificationsContainer: View {
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(notificationManager.inAppNotifications) { notification in
                InAppNotificationView(notification: notification) {
                    notificationManager.dismissInAppNotification(notification.id)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(!notificationManager.inAppNotifications.isEmpty)
    }
}

// MARK: - View Modifier for Notifications

struct WithNotifications: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            content
            
            InAppNotificationsContainer()
        }
    }
}

extension View {
    func withNotifications() -> some View {
        modifier(WithNotifications())
    }
}

// MARK: - HUD Style Notification

struct HUDNotificationView: View {
    let notification: InAppNotification
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: notification.type.iconName)
                .font(.system(size: 40))
                .foregroundColor(notification.type.color)
            
            VStack(spacing: 8) {
                Text(notification.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(notification.message)
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xl)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(
                    color: AppTheme.Colors.textPrimary.opacity(0.2),
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Auto dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + notification.duration) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scale = 0.8
                    opacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
}

// MARK: - Usage Examples

struct NotificationExamplesView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Notification Examples")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                Button("Show Success") {
                    notificationManager.showSuccess("Video uploaded successfully!")
                }
                .primaryButtonStyle()
                
                Button("Show Error") {
                    notificationManager.showError("Failed to upload video. Please try again.")
                }
                .secondaryButtonStyle()
                
                Button("Show Info") {
                    notificationManager.showInfo("New feature available! Check it out.")
                }
                .secondaryButtonStyle()
                
                Button("Schedule Local Notification") {
                    notificationManager.scheduleLocalNotification(
                        title: "MyChannel",
                        body: "Don't forget to check out new videos!",
                        delay: 5.0
                    )
                }
                .secondaryButtonStyle()
            }
            
            Spacer()
        }
        .padding()
        .withNotifications()
    }
}

#Preview("Notification Examples") {
    NotificationExamplesView()
}

#Preview("In-App Notification") {
    InAppNotificationView(
        notification: InAppNotification(
            type: .success,
            title: "Success",
            message: "Your video has been uploaded successfully!",
            duration: 3.0
        )
    ) {
        // Dismiss action
    }
    .padding()
}

#Preview("HUD Notification") {
    HUDNotificationView(
        notification: InAppNotification(
            type: .info,
            title: "New Feature",
            message: "Dark mode is now available in settings!",
            duration: 3.0
        )
    ) {
        // Dismiss action
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.opacity(0.3))
}