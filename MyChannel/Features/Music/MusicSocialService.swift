//
//  MusicSocialService.swift
//  MyChannel
//
//  Social features for music - follow artists, share tracks, group listening
//

import Foundation
import Combine
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct FollowedArtist: Identifiable, Codable {
    let id: String
    let artistId: String
    let artistName: String
    let artistImageURL: String?
    let followedAt: Date
    var isFollowing: Bool = true
}

struct SharedTrack: Identifiable, Codable {
    let id: String
    let songId: String
    let title: String
    let artist: String
    let artworkURL: String?
    let sharedBy: String
    let sharedByName: String
    let sharedAt: Date
    var shareCount: Int
}

@MainActor
final class MusicSocialService: ObservableObject {
    static let shared = MusicSocialService()
    
    @Published private(set) var followedArtists: [FollowedArtist] = []
    @Published private(set) var sharedTracks: [SharedTrack] = []
    @Published private(set) var isLoading: Bool = false
    
    private let followedArtistsKey = "followed_artists"
    
    private init() {
        loadFollowedArtists()
    }
    
    // MARK: - Follow Artist
    
    func followArtist(artistId: String, artistName: String, artistImageURL: String?) {
        let followedArtist = FollowedArtist(
            id: UUID().uuidString,
            artistId: artistId,
            artistName: artistName,
            artistImageURL: artistImageURL,
            followedAt: Date()
        )
        
        if !followedArtists.contains(where: { $0.artistId == artistId }) {
            followedArtists.append(followedArtist)
            saveFollowedArtists()
            
            #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
            Task {
                await syncFollowToFirestore(artist: followedArtist)
            }
            #endif
        }
    }
    
    func unfollowArtist(artistId: String) {
        followedArtists.removeAll { $0.artistId == artistId }
        saveFollowedArtists()
        
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        Task {
            await syncUnfollowToFirestore(artistId: artistId)
        }
        #endif
    }
    
    func isFollowing(artistId: String) -> Bool {
        followedArtists.contains { $0.artistId == artistId }
    }
    
    // MARK: - Share Track
    
    func shareTrack(songId: String, title: String, artist: String, artworkURL: String?) {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        Task {
            do {
                let shareData: [String: Any] = [
                    "songId": songId,
                    "title": title,
                    "artist": artist,
                    "artworkURL": artworkURL ?? "",
                    "sharedBy": uid,
                    "sharedByName": Auth.auth().currentUser?.displayName ?? "Anonymous",
                    "sharedAt": FieldValue.serverTimestamp(),
                    "shareCount": 1
                ]
                
                try await db.collection("music_shares").document(songId).setData(shareData, merge: true)
            } catch {
                print("Error sharing track: \(error)")
            }
        }
        #endif
    }
    
    func loadSharedTracks() async {
        #if canImport(FirebaseFirestore)
        isLoading = true
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("music_shares")
                .order(by: "sharedAt", descending: true)
                .limit(toLast: 50)
                .getDocuments()
            
            sharedTracks = snapshot.documents.compactMap { doc in
                let data = doc.data()
                return SharedTrack(
                    id: doc.documentID,
                    songId: data["songId"] as? String ?? "",
                    title: data["title"] as? String ?? "",
                    artist: data["artist"] as? String ?? "",
                    artworkURL: data["artworkURL"] as? String,
                    sharedBy: data["sharedBy"] as? String ?? "",
                    sharedByName: data["sharedByName"] as? String ?? "",
                    sharedAt: (data["sharedAt"] as? Timestamp)?.dateValue() ?? Date(),
                    shareCount: data["shareCount"] as? Int ?? 0
                )
            }
        } catch {
            print("Error loading shared tracks: \(error)")
        }
        isLoading = false
        #endif
    }
    
    // MARK: - Group Listening (Simulated)
    
    func startGroupListening(sessionName: String) -> String {
        let sessionId = UUID().uuidString
        // In a real implementation, this would create a Firebase Realtime Database room
        // for synchronized playback across users
        return sessionId
    }
    
    func joinGroupListening(sessionId: String) -> Bool {
        // In a real implementation, this would join a Firebase Realtime Database room
        return true
    }
    
    // MARK: - Firestore Sync
    
    private func syncFollowToFirestore(artist: FollowedArtist) async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        do {
            let followData: [String: Any] = [
                "artistId": artist.artistId,
                "artistName": artist.artistName,
                "artistImageURL": artist.artistImageURL ?? "",
                "followedAt": FieldValue.serverTimestamp()
            ]
            
            try await db.collection("users").document(uid)
                .collection("followed_artists")
                .document(artist.artistId)
                .setData(followData)
        } catch {
            print("Error syncing follow to Firestore: \(error)")
        }
        #endif
    }
    
    private func syncUnfollowToFirestore(artistId: String) async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        do {
            try await db.collection("users").document(uid)
                .collection("followed_artists")
                .document(artistId)
                .delete()
        } catch {
            print("Error syncing unfollow to Firestore: \(error)")
        }
        #endif
    }
    
    // MARK: - Persistence
    
    private func saveFollowedArtists() {
        if let encoded = try? JSONEncoder().encode(followedArtists) {
            UserDefaults.standard.set(encoded, forKey: followedArtistsKey)
        }
    }
    
    private func loadFollowedArtists() {
        if let data = UserDefaults.standard.data(forKey: followedArtistsKey),
           let decoded = try? JSONDecoder().decode([FollowedArtist].self, from: data) {
            followedArtists = decoded
        }
    }
}
