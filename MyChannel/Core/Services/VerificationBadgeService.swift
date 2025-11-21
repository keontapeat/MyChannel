//
//  VerificationBadgeService.swift
//  MyChannel
//
//  Created by AI Assistant on 11/21/25.
//

import Foundation

@MainActor
final class VerificationBadgeService: ObservableObject {
    static let shared = VerificationBadgeService()
    private init() {}
    
    struct Eligibility {
        let milestone: VerificationMilestone
        let progress: VerificationProgressSnapshot
        var percentComplete: Double {
            milestone == .manual ? 1.0 : progress.progress(for: milestone)
        }
    }
    
    func eligibility(for user: User) -> Eligibility? {
        guard user.verificationStatus != .revoked else { return nil }
        if let milestone = unlockedMilestone(for: user) {
            return Eligibility(milestone: milestone, progress: progressSnapshot(for: user))
        }
        return nil
    }
    
    func unlockedMilestone(for user: User) -> VerificationMilestone? {
        if user.subscriberCount >= AppConfig.Verification.subscriberMilestone {
            return .subscribers
        }
        
        if let totalViews = user.totalViews,
           totalViews >= AppConfig.Verification.totalViewsMilestone {
            return .totalViews
        }
        
        if user.videoCount >= AppConfig.Verification.minimumVideoCount,
           accountAgeDays(for: user) >= AppConfig.Verification.minimumAccountAgeDays {
            return .creatorConsistency
        }
        return nil
    }
    
    func grantBlueCheck(
        to user: User,
        adminId: String?,
        reason: String? = nil
    ) async throws -> User {
        let milestone = unlockedMilestone(for: user) ?? .manual
        let badge = VerificationBadge(
            status: .verified,
            milestone: milestone,
            autoApproved: adminId == nil,
            awardedAt: Date(),
            awardedBy: adminId ?? OwnerProfile.owner.id,
            reason: reason ?? milestone.description,
            progress: progressSnapshot(for: user)
        )
        
        let updatedUser = user.replacingVerification(isVerified: true, badge: badge)
        try await UserFirestoreService.shared.updateUser(updatedUser)
        if AuthenticationManager.shared.currentUser?.id == user.id {
            AuthenticationManager.shared.currentUser = updatedUser
        }
        NotificationManager.shared.showSuccess("\(user.displayName) is now verified")
        return updatedUser
    }
    
    func revokeBlueCheck(
        for user: User,
        adminId: String,
        reason: String? = nil
    ) async throws -> User {
        let progress = progressSnapshot(for: user)
        let badge = VerificationBadge(
            status: .revoked,
            milestone: user.verificationBadge?.milestone ?? .manual,
            autoApproved: false,
            awardedAt: user.verificationBadge?.awardedAt,
            awardedBy: adminId,
            reason: reason ?? "Badge revoked",
            progress: progress
        )
        
        let updatedUser = user.replacingVerification(isVerified: false, badge: badge)
        try await UserFirestoreService.shared.updateUser(updatedUser)
        if AuthenticationManager.shared.currentUser?.id == user.id {
            AuthenticationManager.shared.currentUser = updatedUser
        }
        NotificationManager.shared.showWarning("\(user.displayName)'s verification was revoked")
        return updatedUser
    }
    
    func progressSnapshot(for user: User) -> VerificationProgressSnapshot {
        VerificationProgressSnapshot(
            subscriberCount: user.subscriberCount,
            subscriberGoal: AppConfig.Verification.subscriberMilestone,
            totalViews: user.totalViews ?? 0,
            totalViewsGoal: AppConfig.Verification.totalViewsMilestone,
            videoCount: user.videoCount,
            videoGoal: AppConfig.Verification.minimumVideoCount,
            accountAgeDays: accountAgeDays(for: user),
            accountAgeGoal: AppConfig.Verification.minimumAccountAgeDays
        )
    }
    
    private func accountAgeDays(for user: User) -> Int {
        let days = Calendar.current.dateComponents([.day], from: user.createdAt, to: Date()).day ?? 0
        return max(0, days)
    }
}

