//
//  AddSampleFlicks.swift
//  MyChannel
//
//  Helper script to add sample Flicks to Firestore for testing
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Add sample Flicks to Firestore "shorts" collection
/// This populates the database with demo content so users see real Flicks instead of errors
///
/// Usage (in your app):
/// ```swift
/// Task {
///     await AddSampleFlicks.addSamples()
/// }
/// ```
class AddSampleFlicks {
    
    /// Add sample Flicks to Firestore
    @MainActor
    static func addSamples() async {
        #if canImport(FirebaseFirestore)
        print("🔥 [AddSampleFlicks] Starting to add sample Flicks...")
        
        let sampleFlicks: [(title: String, description: String, tags: [String], musicTrack: (title: String, artist: String)?)] = [
            (
                title: "Epic Gaming Moment 🎮",
                description: "Insane clutch in the final round! #gaming #esports",
                tags: ["gaming", "esports", "clutch"],
                musicTrack: ("Epic Battle Music", "Game Soundtrack")
            ),
            (
                title: "Cooking Hack: Perfect Eggs 🍳",
                description: "Learn the secret to restaurant-quality scrambled eggs in 60 seconds!",
                tags: ["cooking", "foodhacks", "breakfast"],
                musicTrack: nil
            ),
            (
                title: "Mind-Blowing Magic Trick ✨",
                description: "Can you figure out how I did this? Comment below! #magic #tricks",
                tags: ["magic", "tricks", "entertainment"],
                musicTrack: ("Mystery Theme", "Magic Orchestra")
            ),
            (
                title: "Gym Motivation 💪",
                description: "No excuses! Let's get that workout in! #fitness #motivation",
                tags: ["fitness", "gym", "motivation"],
                musicTrack: ("Workout Beats", "Fitness Vibes")
            ),
            (
                title: "Travel Vlog: Bali Sunset 🌅",
                description: "The most beautiful sunset I've ever seen. Bali, Indonesia.",
                tags: ["travel", "bali", "sunset"],
                musicTrack: ("Tropical Vibes", "Travel Tunes")
            ),
            (
                title: "Funny Cat Compilation 😹",
                description: "These cats are absolutely hilarious! #cats #funny #pets",
                tags: ["cats", "funny", "pets"],
                musicTrack: nil
            ),
            (
                title: "Tech Review: iPhone 15 Pro 📱",
                description: "Is it worth the upgrade? Quick review of the new iPhone!",
                tags: ["tech", "iphone", "review"],
                musicTrack: nil
            ),
            (
                title: "Dance Challenge 💃",
                description: "Join the challenge! Tag me in your version! #dance #challenge",
                tags: ["dance", "challenge", "trending"],
                musicTrack: ("Dance Beat Drop", "DJ Mix Master")
            ),
            (
                title: "Life Hack: Organize Your Cables ⚡",
                description: "Stop the cable chaos with this simple trick!",
                tags: ["lifehack", "organization", "tech"],
                musicTrack: nil
            ),
            (
                title: "Skateboard Tricks 🛹",
                description: "Learning kickflips! Follow my skating journey!",
                tags: ["skateboarding", "sports", "tricks"],
                musicTrack: ("Skate Punk", "Rock Band")
            )
        ]
        
        let service = ShortsFirestoreService.shared
        let currentUser = AppState.shared.currentUser ?? User.defaultUser
        
        for (index, sample) in sampleFlicks.enumerated() {
            do {
                // Use placeholder video and thumbnail URLs (these are demo placeholders)
                let videoURL = "https://storage.googleapis.com/mychannel-demo/flicks/sample\(index + 1).mp4"
                let thumbnailURL = "https://storage.googleapis.com/mychannel-demo/flicks/thumb\(index + 1).jpg"
                
                let flickId = try await service.saveFlick(
                    id: nil, // Auto-generate ID
                    title: sample.title,
                    description: sample.description,
                    videoURL: videoURL,
                    thumbnailURL: thumbnailURL,
                    duration: Double.random(in: 15...60), // Random duration 15-60 seconds
                    tags: sample.tags,
                    musicTrack: sample.musicTrack,
                    userId: currentUser.id,
                    username: currentUser.username,
                    userDisplayName: currentUser.displayName,
                    userProfileImageURL: currentUser.profileImageURL ?? "",
                    userIsVerified: currentUser.isVerified
                )
                
                print("✅ [AddSampleFlicks] Added Flick: \(sample.title) (ID: \(flickId))")
                
                // Small delay to avoid rate limiting
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
            } catch {
                print("🚨 [AddSampleFlicks] Error adding '\(sample.title)': \(error.localizedDescription)")
            }
        }
        
        print("✅ [AddSampleFlicks] Finished adding \(sampleFlicks.count) sample Flicks!")
        print("📺 [AddSampleFlicks] Restart the app to see them in the Flicks feed!")
        #else
        print("⚠️ [AddSampleFlicks] Firebase not available")
        #endif
    }
    
    /// Delete all sample Flicks (cleanup)
    @MainActor
    static func deleteAllSampleFlicks() async {
        #if canImport(FirebaseFirestore)
        print("🗑️ [AddSampleFlicks] Deleting all sample Flicks...")
        
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("shorts").getDocuments()
            
            for doc in snapshot.documents {
                try await db.collection("shorts").document(doc.documentID).delete()
                print("🗑️ [AddSampleFlicks] Deleted Flick: \(doc.documentID)")
            }
            
            print("✅ [AddSampleFlicks] Deleted \(snapshot.documents.count) Flicks")
        } catch {
            print("🚨 [AddSampleFlicks] Error deleting Flicks: \(error.localizedDescription)")
        }
        #endif
    }
}

// MARK: - Usage Example

/*
 // Add samples when app launches (for testing)
 import SwiftUI
 
 struct ContentView: View {
     var body: some View {
         Button("Add Sample Flicks") {
             Task {
                 await AddSampleFlicks.addSamples()
             }
         }
     }
 }
 */





