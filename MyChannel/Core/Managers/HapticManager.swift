//
//  HapticManager.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import UIKit

// MARK: - 📳 Professional Haptic Feedback Manager
class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // MARK: - Impact Feedback
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // MARK: - Notification Feedback
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    // MARK: - Selection Feedback
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    // MARK: - Custom Patterns
    func doubleImpact() {
        impact(style: .medium)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impact(style: .light)
        }
    }
    
    func successPattern() {
        notification(type: .success)
    }
    
    func errorPattern() {
        notification(type: .error)
    }
    
    func warningPattern() {
        notification(type: .warning)
    }
    
    func likePattern() {
        impact(style: .light)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.impact(style: .medium)
        }
    }
    
    func sharePattern() {
        selection()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impact(style: .light)
        }
    }
}

// MARK: - Haptic Extensions
extension HapticManager {
    /// Play haptic feedback for UI interactions
    func playForUIAction(_ action: UIAction) {
        switch action {
        case .tap:
            selection()
        case .longPress:
            impact(style: .medium)
        case .swipe:
            impact(style: .light)
        case .success:
            successPattern()
        case .error:
            errorPattern()
        case .warning:
            warningPattern()
        case .like:
            likePattern()
        case .share:
            sharePattern()
        }
    }
    
    enum UIAction {
        case tap, longPress, swipe, success, error, warning, like, share
    }
}