//
//  VerificationBadge.swift
//  MyChannel
//
//  Created by AI Assistant on 11/21/25.
//

import Foundation

// MARK: - Verification Status
enum VerificationStatus: String, Codable, CaseIterable {
    case notEligible
    case milestoneUnlocked
    case pendingReview
    case verified
    case revoked
}

// MARK: - Verification Milestone
enum VerificationMilestone: String, Codable, CaseIterable, Identifiable {
    case subscribers
    case totalViews
    case creatorConsistency
    case manual
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .subscribers: return "Subscriber Milestone"
        case .totalViews: return "Views Milestone"
        case .creatorConsistency: return "Creator Consistency"
        case .manual: return "Manual Review"
        }
    }
    
    var description: String {
        switch self {
        case .subscribers:
            return "Unlocks at \(NumberFormatter.localizedString(from: NSNumber(value: AppConfig.Verification.subscriberMilestone), number: .decimal)) subscribers"
        case .totalViews:
            return "Unlocks at \(NumberFormatter.localizedString(from: NSNumber(value: AppConfig.Verification.totalViewsMilestone), number: .decimal)) lifetime views"
        case .creatorConsistency:
            return "Unlocks after \(AppConfig.Verification.minimumVideoCount) published videos"
        case .manual:
            return "Owner granted verification"
        }
    }
}

// MARK: - Progress Snapshot
struct VerificationProgressSnapshot: Codable, Hashable {
    let subscriberCount: Int
    let subscriberGoal: Int
    let totalViews: Int
    let totalViewsGoal: Int
    let videoCount: Int
    let videoGoal: Int
    let accountAgeDays: Int
    let accountAgeGoal: Int
    
    func progress(for milestone: VerificationMilestone) -> Double {
        switch milestone {
        case .subscribers:
            guard subscriberGoal > 0 else { return 0 }
            return min(1.0, Double(subscriberCount) / Double(subscriberGoal))
        case .totalViews:
            guard totalViewsGoal > 0 else { return 0 }
            return min(1.0, Double(totalViews) / Double(totalViewsGoal))
        case .creatorConsistency:
            guard videoGoal > 0 else { return 0 }
            return min(1.0, Double(videoCount) / Double(videoGoal))
        case .manual:
            return 1.0
        }
    }
}

// MARK: - Verification Badge
struct VerificationBadge: Codable, Hashable {
    var status: VerificationStatus
    var milestone: VerificationMilestone
    var autoApproved: Bool
    var awardedAt: Date?
    var awardedBy: String?
    var reason: String?
    var progress: VerificationProgressSnapshot
}







