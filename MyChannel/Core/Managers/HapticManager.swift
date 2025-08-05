//
//  HapticManager.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import UIKit

// MARK: - Haptic Feedback Manager
/// A singleton class to manage haptic feedback throughout the app.
/// This provides a simple interface to trigger different feedback types,
/// enhancing the user's tactile experience.
final class HapticManager {
    
    /// The shared singleton instance of the `HapticManager`.
    static let shared = HapticManager()
    
    // Private feedback generators for different haptic styles.
    // Initializing them once and reusing them is more efficient.
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpactGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    /// Private initializer to ensure the singleton pattern.
    private init() {
        // Prepare generators to reduce latency for the first haptic feedback.
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
        softImpactGenerator.prepare()
        rigidImpactGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    /// Triggers an impact feedback with a specific style.
    /// - Parameter style: The intensity of the impact feedback.
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            lightImpactGenerator.impactOccurred()
        case .medium:
            mediumImpactGenerator.impactOccurred()
        case .heavy:
            heavyImpactGenerator.impactOccurred()
        case .soft:
            softImpactGenerator.impactOccurred()
        case .rigid:
            rigidImpactGenerator.impactOccurred()
        @unknown default:
            // Fallback to medium for any future unknown styles.
            mediumImpactGenerator.impactOccurred()
        }
    }
    
    /// Triggers a notification feedback.
    /// - Parameter type: The type of the notification feedback (e.g., success, warning, error).
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
    }
}