//
//  EnhancedContentModeration.swift
//  MyChannel
//
//  🛡️ REAL CONTENT MODERATION - 100% ACTIVE
//  Profanity filter, spam detection, hate speech detection
//

import Foundation
import SwiftUI

@MainActor
final class EnhancedContentModeration: ObservableObject {
    static let shared = EnhancedContentModeration()
    private init() {}
    
    // MARK: - Real Content Scanning
    
    /// Scan text for violations (profanity, hate speech, spam)
    func scanText(_ text: String) -> EnhancedModerationResult {
        var violations: [String] = []
        var confidence: Double = 0.0
        let lowercaseText = text.lowercased()
        
        // 1. Profanity Detection
        let profanityWords = [
            "fuck", "shit", "bitch", "asshole", "cunt", "dick", "pussy",
            "motherfucker", "bastard", "damn", "hell", "piss"
        ]
        
        for word in profanityWords {
            if lowercaseText.contains(word) {
                violations.append("Profanity: '\(word)'")
                confidence = max(confidence, 0.7)
            }
        }
        
        // 2. Hate Speech Detection
        let hateSpeechWords = [
            "nigger", "faggot", "retard", "tranny", "dyke",
            "chink", "gook", "spic", "wetback", "kike"
        ]
        
        for word in hateSpeechWords {
            if lowercaseText.contains(word) {
                violations.append("Hate speech: '\(word)'")
                confidence = 0.95 // High confidence
            }
        }
        
        // 3. Violent Threats Detection
        let violentPhrases = [
            "kill yourself", "kys", "die", "shoot you", "stab you",
            "blow up", "terrorist", "bomb", "murder"
        ]
        
        for phrase in violentPhrases {
            if lowercaseText.contains(phrase) {
                violations.append("Violent threat: '\(phrase)'")
                confidence = 0.9
            }
        }
        
        // 4. Spam Detection
        if detectSpam(lowercaseText) {
            violations.append("Spam detected")
            confidence = max(confidence, 0.6)
        }
        
        // 5. Explicit Content
        let explicitWords = ["porn", "xxx", "sex", "nude", "nsfw", "onlyfans"]
        for word in explicitWords {
            if lowercaseText.contains(word) {
                violations.append("Explicit content: '\(word)'")
                confidence = max(confidence, 0.8)
            }
        }
        
        let requiresAction = !violations.isEmpty && confidence > 0.7
        
        return EnhancedModerationResult(
            isClean: violations.isEmpty,
            violations: violations,
            confidence: confidence,
            requiresAction: requiresAction,
            requiresHumanReview: confidence > 0.85
        )
    }
    
    /// Detect spam patterns
    private func detectSpam(_ text: String) -> Bool {
        var spamScore = 0
        
        // URLs
        if text.contains("http://") || text.contains("https://") || text.contains("www.") {
            spamScore += 2
        }
        
        // Promotional language
        let promoWords = ["click here", "buy now", "limited offer", "act now", "free money", "get rich"]
        for word in promoWords {
            if text.contains(word) {
                spamScore += 1
            }
        }
        
        // Repeated characters
        if text.contains(where: { char in
            String(text.filter { $0 == char }).count > 5
        }) {
            spamScore += 1
        }
        
        // All caps (if > 70% uppercase)
        let uppercaseCount = text.filter { $0.isUppercase && $0.isLetter }.count
        let letterCount = text.filter { $0.isLetter }.count
        if letterCount > 0 && Double(uppercaseCount) / Double(letterCount) > 0.7 {
            spamScore += 1
        }
        
        // Excessive emojis
        let emojiCount = text.unicodeScalars.filter { $0.properties.isEmoji }.count
        if emojiCount > 10 {
            spamScore += 1
        }
        
        return spamScore >= 3
    }
    
    /// Moderate video before upload
    func moderateVideoBeforeUpload(title: String, description: String, tags: [String]) -> EnhancedModerationResult {
        // Scan title
        let titleResult = scanText(title)
        if !titleResult.isClean {
            return titleResult
        }
        
        // Scan description
        let descResult = scanText(description)
        if !descResult.isClean {
            return descResult
        }
        
        // Scan tags
        for tag in tags {
            let tagResult = scanText(tag)
            if !tagResult.isClean {
                return tagResult
            }
        }
        
        return EnhancedModerationResult(
            isClean: true,
            violations: [],
            confidence: 0.1,
            requiresAction: false,
            requiresHumanReview: false
        )
    }
    
    /// Moderate comment before posting
    func moderateComment(_ text: String) -> EnhancedModerationResult {
        return scanText(text)
    }
}

// MARK: - Enhanced Models (Unique Names)

struct EnhancedModerationResult {
    let isClean: Bool
    let violations: [String]
    let confidence: Double
    let requiresAction: Bool
    let requiresHumanReview: Bool
}

