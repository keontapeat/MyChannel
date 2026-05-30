import Foundation
import FirebaseFirestore
import Combine

/// Phase 22 & Phase 52: Advanced Collaborative Playlists
/// Syncs playlist order, items, and live presence across multiple devices.
/// Handles collision detection for simultaneous reordering using Firestore transactions.
@MainActor
final class CollaborativePlaylistService: ObservableObject {
    static let shared = CollaborativePlaylistService()
    private let db = Firestore.firestore()
    
    @Published private(set) var activePlaylist: CollaborativePlaylist?
    @Published private(set) var activeMembers: [String] = []
    @Published var playlists: [CollaborativePlaylist] = []
    
    private var playlistListener: ListenerRegistration?
    private var presenceListener: ListenerRegistration?
    
    private init() {}
    
    func joinPlaylist(playlistId: String, userId: String) {
        // Clear previous listeners
        leavePlaylist()
        
        // 1. Listen to Playlist modifications (Add/Remove videos, Reorder)
        let docRef = db.collection("playlists").document(playlistId)
        playlistListener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data() else { return }
            
            // Reconstruct playlist model
            let title = data["title"] as? String ?? "Shared Playlist"
            let videos = data["videoIds"] as? [String] ?? []
            let items = videos.map { PlaylistVideoItem(videoId: $0, title: "Video", thumbnailURL: "", duration: 0, creatorName: "Unknown", addedBy: "Unknown", addedByName: "Unknown") }
            self.activePlaylist = CollaborativePlaylist(id: playlistId, title: title, description: "", ownerId: "owner", videoItems: items)
        }
        
        // 2. Listen to Presence (Who is currently viewing/collaborating)
        let presenceRef = db.collection("playlists").document(playlistId).collection("presence")
        presenceListener = presenceRef.addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self, let docs = querySnapshot?.documents else { return }
            self.activeMembers = docs.map { $0.documentID }
        }
        
        // 3. Mark Self as Active
        presenceRef.document(userId).setData([
            "joinedAt": FieldValue.serverTimestamp(),
            "status": "active"
        ])
    }
    
    func leavePlaylist() {
        playlistListener?.remove()
        presenceListener?.remove()
        
        if let playlist = activePlaylist, let user = AuthenticationManager.shared.currentUser {
            db.collection("playlists")
                .document(playlist.id)
                .collection("presence")
                .document(user.id)
                .delete()
        }
        
        activePlaylist = nil
        activeMembers = []
    }
    
    func addVideo(_ videoId: String) {
        guard let playlist = activePlaylist else { return }
        db.collection("playlists").document(playlist.id).updateData([
            "videoIds": FieldValue.arrayUnion([videoId])
        ])
    }
    
    // 🔥 Phase 52: Collision-safe reordering
    func reorderVideo(sourceIndex: Int, destinationIndex: Int) async {
        guard let playlist = activePlaylist else { return }
        let docRef = db.collection("playlists").document(playlist.id)
        
        do {
            _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
                let document: DocumentSnapshot
                do {
                    try document = transaction.getDocument(docRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                guard var currentVideos = document.data()?["videoIds"] as? [String] else { return nil }
                
                // Safety check
                guard sourceIndex < currentVideos.count && destinationIndex <= currentVideos.count else { return nil }
                
                // Perform local reorder
                let movedItem = currentVideos.remove(at: sourceIndex)
                let targetIndex = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex
                currentVideos.insert(movedItem, at: targetIndex)
                
                // Commit back to Firestore (this will fail and retry if someone else modified it!)
                transaction.updateData(["videoIds": currentVideos], forDocument: docRef)
                return nil
            }
            print("✅ [CollaborativePlaylist] Successfully reordered queue with collision safety.")
        } catch {
            print("⚠️ [CollaborativePlaylist] Transaction failed: \(error)")
        }
    }
    
    // MARK: - View Stubs
    func getPlaylists(for userId: String) async throws -> [CollaborativePlaylist] { return [] }
    func createPlaylist(_ playlist: CollaborativePlaylist) async throws -> CollaborativePlaylist { return playlist }
    func joinPlaylist(shareCode: String, userId: String) async throws -> CollaborativePlaylist { throw URLError(.badURL) }
    func approveSuggestion(playlistId: String, suggestionId: String) async throws {}
    func rejectSuggestion(playlistId: String, suggestionId: String) async throws {}
    func removeVideo(playlistId: String, videoItemId: String) async throws {}
    func updateCollaboratorPermission(playlistId: String, userId: String, permission: CollaboratorPermission) async throws {}
    func removeCollaborator(playlistId: String, userId: String) async throws {}
    func getActivityLog(for playlistId: String) -> [PlaylistActivityLog] { return [] }
    func leavePlaylist(playlistId: String, userId: String) async throws {}
}
