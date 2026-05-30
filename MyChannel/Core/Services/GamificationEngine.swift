import Foundation
import FirebaseFirestore
import Combine

/// Phase 37: Gamification & GamificationBadges Engine
/// Manages live synced achievements and badges during video playback.
@MainActor
final class GamificationEngine: ObservableObject {
    static let shared = GamificationEngine()
    private let db = Firestore.firestore()
    
    @Published var unlockedGamificationBadges: [GamificationBadge] = []
    @Published var newlyUnlockedGamificationBadge: GamificationBadge? // For popup UI
    
    private var listener: ListenerRegistration?
    
    private init() {}
    
    func startListening(userId: String) {
        listener?.remove()
        
        let docRef = db.collection("users").document(userId).collection("achievements")
        listener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let docs = snapshot?.documents else { return }
            
            let fetchedGamificationBadges = docs.compactMap { doc -> GamificationBadge? in
                let data = doc.data()
                guard let id = data["id"] as? String,
                      let title = data["title"] as? String,
                      let icon = data["icon"] as? String else { return nil }
                return GamificationBadge(id: id, title: title, icon: icon)
            }
            
            // Check for new badges
            if !self.unlockedGamificationBadges.isEmpty && fetchedGamificationBadges.count > self.unlockedGamificationBadges.count {
                // We assume the newest one was just added
                self.newlyUnlockedGamificationBadge = fetchedGamificationBadges.last
                
                // Clear popup after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if self.newlyUnlockedGamificationBadge?.id == fetchedGamificationBadges.last?.id {
                        self.newlyUnlockedGamificationBadge = nil
                    }
                }
            }
            
            self.unlockedGamificationBadges = fetchedGamificationBadges
        }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    /// Trigger an achievement check based on an action (e.g., watched 10 videos)
    func triggerAction(_ action: GamificationAction, userId: String) {
        // Mock increment logic
        // In a real FAANG app, a Cloud Function handles the actual unlocking to prevent client spoofing.
        print("🏆 [GamificationEngine] Action triggered: \(action.rawValue)")
    }
}

enum GamificationAction: String {
    case videoWatched
    case commentPosted
    case likedVideo
    case sharedVideo
}

struct GamificationBadge: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let icon: String // SF Symbol name
}
