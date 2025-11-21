//
//  MyChannelPlusStatsService.swift
//  MyChannel
//
//  Created by AI Assistant
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
final class MyChannelPlusStatsService: ObservableObject {
    static let shared = MyChannelPlusStatsService()
    
    @Published var isTrackingEnabled = true
    
    private init() {}
    
    // MARK: - Track Ad-Free Watch Time
    
    /// Call this when user watches a video without ads (because they're Plus member)
    /// - Parameters:
    ///   - videoId: The video being watched
    ///   - durationSeconds: How many seconds they watched
    func trackAdFreeWatchTime(videoId: String, durationSeconds: Double) async {
        guard isTrackingEnabled else { return }
        guard await isUserPlusMember() else { return }
        
        let hours = durationSeconds / 3600.0
        
        #if canImport(FirebaseFirestore)
        guard let userId = getCurrentUserId() else { return }
        
        let db = Firestore.firestore()
        let ref = db.collection("premium_stats").document(userId)
        
        do {
            try await ref.setData([
                "adFreeHours": FieldValue.increment(Int64(ceil(hours))),
                "lastAdFreeWatch": FieldValue.serverTimestamp(),
                "totalAdsSaved": FieldValue.increment(Int64(estimateAdsSaved(durationSeconds: durationSeconds)))
            ], merge: true)
            
            print("✅ [Plus Stats] Tracked ad-free watch time: +\(hours) hrs")
        } catch {
            print("🚨 [Plus Stats] Error tracking ad-free time: \(error)")
        }
        #endif
    }
    
    // MARK: - Track Background Play
    
    /// Call this when user plays video in background (Plus feature)
    /// - Parameter durationSeconds: How long they played in background
    func trackBackgroundPlay(durationSeconds: Double) async {
        guard isTrackingEnabled else { return }
        guard await isUserPlusMember() else { return }
        
        let hours = durationSeconds / 3600.0
        
        #if canImport(FirebaseFirestore)
        guard let userId = getCurrentUserId() else { return }
        
        let db = Firestore.firestore()
        let ref = db.collection("premium_stats").document(userId)
        
        do {
            try await ref.setData([
                "backgroundPlayHours": FieldValue.increment(Int64(ceil(hours))),
                "lastBackgroundPlay": FieldValue.serverTimestamp()
            ], merge: true)
            
            print("✅ [Plus Stats] Tracked background play: +\(hours) hrs")
        } catch {
            print("🚨 [Plus Stats] Error tracking background play: \(error)")
        }
        #endif
    }
    
    // MARK: - Track Video Download
    
    /// Call this when user downloads a video for offline viewing (Plus feature)
    /// - Parameter videoId: The video being downloaded
    func trackVideoDownload(videoId: String) async {
        guard isTrackingEnabled else { return }
        guard await isUserPlusMember() else { return }
        
        #if canImport(FirebaseFirestore)
        guard let userId = getCurrentUserId() else { return }
        
        let db = Firestore.firestore()
        let ref = db.collection("premium_stats").document(userId)
        
        do {
            try await ref.setData([
                "videosDownloaded": FieldValue.increment(Int64(1)),
                "lastDownload": FieldValue.serverTimestamp(),
                "downloadedVideoIds": FieldValue.arrayUnion([videoId])
            ], merge: true)
            
            print("✅ [Plus Stats] Tracked video download")
        } catch {
            print("🚨 [Plus Stats] Error tracking download: \(error)")
        }
        #endif
    }
    
    // MARK: - Track Live Stream Watch
    
    /// Call this when Plus member watches a live stream
    /// - Parameter streamId: The live stream being watched
    func trackLiveStreamWatch(streamId: String) async {
        guard isTrackingEnabled else { return }
        guard await isUserPlusMember() else { return }
        
        #if canImport(FirebaseFirestore)
        guard let userId = getCurrentUserId() else { return }
        
        let db = Firestore.firestore()
        let ref = db.collection("premium_stats").document(userId)
        
        do {
            try await ref.setData([
                "liveStreamsWatched": FieldValue.increment(Int64(1)),
                "lastLiveStreamWatch": FieldValue.serverTimestamp()
            ], merge: true)
            
            print("✅ [Plus Stats] Tracked live stream watch")
        } catch {
            print("🚨 [Plus Stats] Error tracking live stream: \(error)")
        }
        #endif
    }
    
    // MARK: - Track VS Match Participation
    
    /// Call this when Plus member participates in VS match (Plus members get benefits)
    /// - Parameter matchId: The match they participated in
    func trackVSMatchParticipation(matchId: String) async {
        guard isTrackingEnabled else { return }
        guard await isUserPlusMember() else { return }
        
        #if canImport(FirebaseFirestore)
        guard let userId = getCurrentUserId() else { return }
        
        let db = Firestore.firestore()
        let ref = db.collection("premium_stats").document(userId)
        
        do {
            try await ref.setData([
                "vsMatchesParticipated": FieldValue.increment(Int64(1)),
                "lastVSMatch": FieldValue.serverTimestamp()
            ], merge: true)
            
            print("✅ [Plus Stats] Tracked VS match participation")
        } catch {
            print("🚨 [Plus Stats] Error tracking VS match: \(error)")
        }
        #endif
    }
    
    // MARK: - Track Exclusive Content
    
    /// Call this when Plus member watches Plus-exclusive content
    /// - Parameters:
    ///   - contentId: The exclusive content being watched
    ///   - durationSeconds: How long they watched
    func trackExclusiveContent(contentId: String, durationSeconds: Double) async {
        guard isTrackingEnabled else { return }
        guard await isUserPlusMember() else { return }
        
        let hours = durationSeconds / 3600.0
        
        #if canImport(FirebaseFirestore)
        guard let userId = getCurrentUserId() else { return }
        
        let db = Firestore.firestore()
        let ref = db.collection("premium_stats").document(userId)
        
        do {
            try await ref.setData([
                "exclusiveContentHours": FieldValue.increment(Int64(ceil(hours))),
                "lastExclusiveWatch": FieldValue.serverTimestamp()
            ], merge: true)
            
            print("✅ [Plus Stats] Tracked exclusive content: +\(hours) hrs")
        } catch {
            print("🚨 [Plus Stats] Error tracking exclusive content: \(error)")
        }
        #endif
    }
    
    // MARK: - Get Stats
    
    func getStats() async -> PremiumStats? {
        #if canImport(FirebaseFirestore)
        guard let userId = getCurrentUserId() else { return nil }
        
        let db = Firestore.firestore()
        
        do {
            let doc = try await db.collection("premium_stats").document(userId).getDocument()
            guard let data = doc.data() else { return nil }
            
            return PremiumStats(
                adFreeHours: data["adFreeHours"] as? Int ?? 0,
                backgroundPlayHours: data["backgroundPlayHours"] as? Int ?? 0,
                videosDownloaded: data["videosDownloaded"] as? Int ?? 0,
                liveStreamsWatched: data["liveStreamsWatched"] as? Int ?? 0,
                vsMatchesParticipated: data["vsMatchesParticipated"] as? Int ?? 0,
                exclusiveContentHours: data["exclusiveContentHours"] as? Int ?? 0
            )
        } catch {
            print("🚨 [Plus Stats] Error getting stats: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }
    
    // MARK: - Helper Methods
    
    private func isUserPlusMember() async -> Bool {
        // Check if user has active Plus subscription
        #if canImport(FirebaseFirestore)
        guard let userId = getCurrentUserId() else { return false }
        
        let db = Firestore.firestore()
        
        do {
            let doc = try await db.collection("subscriptions")
                .whereField("userId", isEqualTo: userId)
                .whereField("status", isEqualTo: "active")
                .whereField("plan", isEqualTo: "plus")
                .limit(to: 1)
                .getDocuments()
                .documents
                .first
            
            return doc != nil
        } catch {
            print("🚨 [Plus Stats] Error checking Plus membership: \(error)")
            return false
        }
        #else
        return false
        #endif
    }
    
    private func getCurrentUserId() -> String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }
    
    private func estimateAdsSaved(durationSeconds: Double) -> Int {
        // Estimate: 1 ad per 5 minutes of video
        let minutes = durationSeconds / 60.0
        return Int(ceil(minutes / 5.0))
    }
}



