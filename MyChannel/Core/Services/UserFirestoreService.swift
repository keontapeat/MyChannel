//
//  UserFirestoreService.swift
//  MyChannel
//
//  Firestore service for saving and loading complete user profiles
//  Ensures banner video and all user data persists across app restarts
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class UserFirestoreService: ObservableObject {
    static let shared = UserFirestoreService()
    private init() {}
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    /// Save complete user profile to Firestore
    func updateUser(_ user: User) async throws {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("users").document(user.id)
        
        var userData: [String: Any] = [
            "username": user.username,
            "displayName": user.displayName,
            "email": user.email,
            "subscriberCount": user.subscriberCount,
            "videoCount": user.videoCount,
            "isVerified": user.isVerified,
            "isCreator": user.isCreator,
            "followerCount": user.followerCount,
            "followingCount": user.followingCount,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        // Optional fields
        if let profileImageURL = user.profileImageURL {
            userData["profileImageURL"] = profileImageURL
            // Write legacy key for compatibility with web and older clients
            userData["avatarUrl"] = profileImageURL
        }
        if let bannerImageURL = user.bannerImageURL {
            userData["bannerImageURL"] = bannerImageURL
            userData["bannerImageUrl"] = bannerImageURL
        }
        if let bio = user.bio {
            userData["bio"] = bio
        }
        if let location = user.location {
            userData["location"] = location
        }
        if let website = user.website {
            userData["website"] = website
        }
        // Always persist so "off" sticks after reload/sign-out and back in
        userData["showWebsiteOnProfile"] = user.showWebsiteOnProfile ?? false
        userData["showOnlineStatus"] = user.showOnlineStatus ?? false
        if let totalViews = user.totalViews {
            userData["totalViews"] = totalViews
        }
        if let totalEarnings = user.totalEarnings {
            userData["totalEarnings"] = totalEarnings
        }
        
        // 🔥 BANNER VIDEO FIELDS: Critical for persistence!
        if let bannerVideoURL = user.bannerVideoURL {
            userData["bannerVideoURL"] = bannerVideoURL
        } else {
            // Explicitly set to null if no video banner
            userData["bannerVideoURL"] = NSNull()
        }
        
        if let bannerVideoMuted = user.bannerVideoMuted {
            userData["bannerVideoMuted"] = bannerVideoMuted
        }
        
        if let bannerVideoContentMode = user.bannerVideoContentMode {
            userData["bannerVideoContentMode"] = bannerVideoContentMode.rawValue
        }
        
        // Social links
        if !user.socialLinks.isEmpty {
            let linksData = user.socialLinks.map { link -> [String: Any] in
                ["id": link.id, "platform": link.platform.rawValue, "url": link.url, "displayName": link.displayName]
            }
            userData["socialLinks"] = linksData
        }
        
        // Verification meta
        if let badge = user.verificationBadge {
            userData["verificationStatus"] = badge.status.rawValue
            userData["verificationMilestone"] = badge.milestone.rawValue
            userData["verificationAutoApproved"] = badge.autoApproved
            userData["verificationAwardedBy"] = badge.awardedBy
            userData["verificationReason"] = badge.reason
            if let awardedAt = badge.awardedAt {
                userData["verificationAwardedAt"] = Timestamp(date: awardedAt)
            }
            userData["verificationProgress"] = [
                "subscriberCount": badge.progress.subscriberCount,
                "subscriberGoal": badge.progress.subscriberGoal,
                "totalViews": badge.progress.totalViews,
                "totalViewsGoal": badge.progress.totalViewsGoal,
                "videoCount": badge.progress.videoCount,
                "videoGoal": badge.progress.videoGoal,
                "accountAgeDays": badge.progress.accountAgeDays,
                "accountAgeGoal": badge.progress.accountAgeGoal
            ]
        } else {
            userData["verificationStatus"] = user.isVerified ? VerificationStatus.verified.rawValue : VerificationStatus.notEligible.rawValue
        }
        
        try await ref.setData(userData, merge: true)
        
        print("✅ User profile saved to Firestore with banner video: \(user.bannerVideoURL ?? "nil")")
        #endif
    }
    
    /// Load complete user profile from Firestore
    func fetchUser(id: String) async throws -> User? {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("users").document(id)
        let doc = try await ref.getDocument()
        
        guard doc.exists, let data = doc.data() else {
            return nil
        }
        
        // Parse banner video content mode
        var contentMode: UserBannerContentMode? = nil
        if let modeString = data["bannerVideoContentMode"] as? String {
            contentMode = UserBannerContentMode(rawValue: modeString)
        }
        
        let verificationBadge = Self.makeVerificationBadge(from: data)
        
        let user = User(
            id: id,
            username: data["username"] as? String ?? "",
            displayName: data["displayName"] as? String ?? "",
            email: data["email"] as? String ?? "",
            // Read primary key, fall back to legacy key used by web, then Google Auth photo
            profileImageURL: (data["profileImageURL"] as? String) ?? (data["profileImageUrl"] as? String) ?? (data["avatarUrl"] as? String) ?? (data["photoURL"] as? String),
            bannerImageURL: (data["bannerImageURL"] as? String) ?? (data["bannerImageUrl"] as? String),
            bio: data["bio"] as? String,
            subscriberCount: data["subscriberCount"] as? Int ?? 0,
            videoCount: data["videoCount"] as? Int ?? 0,
            isVerified: data["isVerified"] as? Bool ?? false,
            isCreator: data["isCreator"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            location: data["location"] as? String,
            website: data["website"] as? String,
            showWebsiteOnProfile: data["showWebsiteOnProfile"] as? Bool,
            showOnlineStatus: data["showOnlineStatus"] as? Bool,
            socialLinks: Self.parseSocialLinks(from: data),
            followerCount: data["followerCount"] as? Int,
            followingCount: data["followingCount"] as? Int ?? 0,
            joinDate: (data["joinDate"] as? Timestamp)?.dateValue(),
            totalViews: data["totalViews"] as? Int,
            totalEarnings: data["totalEarnings"] as? Double,
            membershipTiers: nil, // TODO: Parse membership tiers if needed
            verificationBadge: verificationBadge,
            bannerVideoURL: data["bannerVideoURL"] as? String,
            bannerVideoMuted: data["bannerVideoMuted"] as? Bool,
            bannerVideoContentMode: contentMode
        )
        
        print("✅ User profile loaded from Firestore with banner video: \(user.bannerVideoURL ?? "nil")")
        return user
        #else
        return nil
        #endif
    }
    
    /// Delete user document from Firestore
    func deleteUser(userId: String) async throws {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("users").document(userId)
        try await ref.delete()
        print("✅ User document deleted from Firestore: \(userId)")
        #endif
    }
}

#if canImport(FirebaseFirestore)
private extension UserFirestoreService {
    static func parseSocialLinks(from data: [String: Any]) -> [SocialLink] {
        guard let linksArray = data["socialLinks"] as? [[String: Any]] else { return [] }
        return linksArray.compactMap { dict -> SocialLink? in
            guard let platformRaw = dict["platform"] as? String,
                  let platform = SocialPlatform(rawValue: platformRaw),
                  let url = dict["url"] as? String,
                  !url.isEmpty else { return nil }
            let id = dict["id"] as? String ?? UUID().uuidString
            let displayName = dict["displayName"] as? String ?? platformRaw
            return SocialLink(id: id, platform: platform, url: url, displayName: displayName)
        }
    }
    
    static func makeVerificationBadge(from data: [String: Any]) -> VerificationBadge? {
        guard let statusRaw = data["verificationStatus"] as? String,
              let status = VerificationStatus(rawValue: statusRaw) else {
            return nil
        }
        
        let milestoneRaw = data["verificationMilestone"] as? String ?? VerificationMilestone.manual.rawValue
        let milestone = VerificationMilestone(rawValue: milestoneRaw) ?? .manual
        let progressData = data["verificationProgress"] as? [String: Any] ?? [:]
        
        let progress = VerificationProgressSnapshot(
            subscriberCount: progressData["subscriberCount"] as? Int ?? (data["subscriberCount"] as? Int ?? 0),
            subscriberGoal: progressData["subscriberGoal"] as? Int ?? AppConfig.Verification.subscriberMilestone,
            totalViews: progressData["totalViews"] as? Int ?? (data["totalViews"] as? Int ?? 0),
            totalViewsGoal: progressData["totalViewsGoal"] as? Int ?? AppConfig.Verification.totalViewsMilestone,
            videoCount: progressData["videoCount"] as? Int ?? (data["videoCount"] as? Int ?? 0),
            videoGoal: progressData["videoGoal"] as? Int ?? AppConfig.Verification.minimumVideoCount,
            accountAgeDays: progressData["accountAgeDays"] as? Int ?? 0,
            accountAgeGoal: progressData["accountAgeGoal"] as? Int ?? AppConfig.Verification.minimumAccountAgeDays
        )
        
        let awardedAt = (data["verificationAwardedAt"] as? Timestamp)?.dateValue()
        let awardedBy = data["verificationAwardedBy"] as? String
        let reason = data["verificationReason"] as? String
        let autoApproved = data["verificationAutoApproved"] as? Bool ?? false
        
        return VerificationBadge(
            status: status,
            milestone: milestone,
            autoApproved: autoApproved,
            awardedAt: awardedAt,
            awardedBy: awardedBy,
            reason: reason,
            progress: progress
        )
    }
}
#endif

