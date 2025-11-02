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
        
        let user = User(
            id: id,
            username: data["username"] as? String ?? "",
            displayName: data["displayName"] as? String ?? "",
            email: data["email"] as? String ?? "",
            // Read primary key, fall back to legacy key used by web
            profileImageURL: (data["profileImageURL"] as? String) ?? (data["avatarUrl"] as? String),
            bannerImageURL: data["bannerImageURL"] as? String,
            bio: data["bio"] as? String,
            subscriberCount: data["subscriberCount"] as? Int ?? 0,
            videoCount: data["videoCount"] as? Int ?? 0,
            isVerified: data["isVerified"] as? Bool ?? false,
            isCreator: data["isCreator"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            location: data["location"] as? String,
            website: data["website"] as? String,
            socialLinks: [], // TODO: Parse social links if needed
            followerCount: data["followerCount"] as? Int,
            followingCount: data["followingCount"] as? Int ?? 0,
            joinDate: (data["joinDate"] as? Timestamp)?.dateValue(),
            totalViews: data["totalViews"] as? Int,
            totalEarnings: data["totalEarnings"] as? Double,
            membershipTiers: nil, // TODO: Parse membership tiers if needed
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
}

