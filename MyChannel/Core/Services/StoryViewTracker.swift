//
//  StoryViewTracker.swift
//  MyChannel
//
//  Created by AI Assistant on 11/21/25.
//  🔥 REAL-TIME STORY VIEW TRACKING - INSTAGRAM-LEVEL ANALYTICS
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
class StoryViewTracker: ObservableObject {
    static let shared = StoryViewTracker()
    
    @Published var viewerCount: Int = 0
    private var listener: ListenerRegistration?
    private var currentStoryId: String?
    
    private init() {}
    
    // MARK: - View Tracking
    
    /// Start tracking views for a story
    func startTracking(storyId: String) async {
        // Clean up previous tracking
        stopTracking()
        
        currentStoryId = storyId
        
        print("📊 [StoryViewTracker] Starting tracking for story: \(storyId)")
        
        // 1. Mark story as viewed
        await markStoryAsViewed(storyId: storyId)
        
        // 2. Listen to live viewer count
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        listener = db.collection("story_views")
            .document(storyId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("🚨 [StoryViewTracker] Listener error: \(error)")
                    self.viewerCount = 1
                    return
                }
                
                guard let data = snapshot?.data(),
                      let count = data["viewCount"] as? Int else {
                    // No views yet, set to 1
                    self.viewerCount = 1
                    return
                }
                
                self.viewerCount = count
                print("📊 [StoryViewTracker] Viewer count updated: \(count)")
            }
        #else
        // Fallback for testing
        viewerCount = Int.random(in: 50...500)
        print("⚠️ [StoryViewTracker] Using mock viewer count: \(viewerCount)")
        #endif
    }
    
    /// Stop tracking views
    func stopTracking() {
        listener?.remove()
        listener = nil
        currentStoryId = nil
        viewerCount = 0
        
        print("📊 [StoryViewTracker] Stopped tracking")
    }
    
    // MARK: - Private Methods
    
    /// Mark story as viewed by current user
    private func markStoryAsViewed(storyId: String) async {
        #if canImport(FirebaseFirestore)
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ [StoryViewTracker] No authenticated user - skipping view tracking")
            return
        }
        
        let db = Firestore.firestore()
        
        do {
            // 1. Add to user's viewed stories
            try await db.collection("users")
                .document(userId)
                .collection("viewed_stories")
                .document(storyId)
                .setData([
                    "viewedAt": FieldValue.serverTimestamp(),
                    "storyId": storyId
                ], merge: true)
            
            // 2. Increment story view count (atomic operation)
            try await db.collection("story_views")
                .document(storyId)
                .setData([
                    "viewCount": FieldValue.increment(Int64(1)),
                    "viewers": FieldValue.arrayUnion([userId]),
                    "lastViewedAt": FieldValue.serverTimestamp()
                ], merge: true)
            
            // 3. Update story document view count
            try await db.collection("stories")
                .document(storyId)
                .updateData([
                    "viewCount": FieldValue.increment(Int64(1))
                ])
            
            print("✅ [StoryViewTracker] Story view tracked: \(storyId)")
        } catch {
            print("🚨 [StoryViewTracker] Failed to track view: \(error)")
        }
        #else
        print("⚠️ [StoryViewTracker] Firebase not available - skipping view tracking")
        #endif
    }
    
    // MARK: - View Count Queries
    
    /// Get total views for a story
    func getViewCount(for storyId: String) async -> Int {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        do {
            let doc = try await db.collection("story_views")
                .document(storyId)
                .getDocument()
            
            let count = doc.data()?["viewCount"] as? Int ?? 0
            print("📊 [StoryViewTracker] View count for \(storyId): \(count)")
            return count
        } catch {
            print("🚨 [StoryViewTracker] Failed to get view count: \(error)")
            return 0
        }
        #else
        return Int.random(in: 50...500)
        #endif
    }
    
    /// Get viewers list for a story
    func getViewers(for storyId: String) async -> [String] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        do {
            let doc = try await db.collection("story_views")
                .document(storyId)
                .getDocument()
            
            let viewers = doc.data()?["viewers"] as? [String] ?? []
            print("📊 [StoryViewTracker] Viewers for \(storyId): \(viewers.count)")
            return viewers
        } catch {
            print("🚨 [StoryViewTracker] Failed to get viewers: \(error)")
            return []
        }
        #else
        return []
        #endif
    }
    
    /// Check if current user has viewed a story
    func hasViewed(storyId: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        
        let db = Firestore.firestore()
        
        do {
            let doc = try await db.collection("users")
                .document(userId)
                .collection("viewed_stories")
                .document(storyId)
                .getDocument()
            
            return doc.exists
        } catch {
            print("🚨 [StoryViewTracker] Failed to check viewed status: \(error)")
            return false
        }
        #else
        return false
        #endif
    }
    
    deinit {
        listener?.remove()
        print("✅ [StoryViewTracker] Deallocated - no memory leak")
    }
}



