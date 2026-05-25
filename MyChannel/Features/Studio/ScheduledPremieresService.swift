import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct ScheduledPremiere: Identifiable, Codable {
    let id: String
    let videoId: String
    let title: String
    let thumbnailURL: String
    let scheduledAt: Date
    let creatorId: String
    let status: PremiereStatus
    let viewerCount: Int?
    let chatEnabled: Bool
    
    enum PremiereStatus: String, Codable, CaseIterable {
        case scheduled, live, completed
        
        var displayName: String {
            switch self {
            case .scheduled: return "Scheduled"
            case .live: return "Live Now"
            case .completed: return "Completed"
            }
        }
    }
}

@MainActor
final class ScheduledPremieresService: ObservableObject {
    static let shared = ScheduledPremieresService()
    private init() {}
    
    @Published var premieres: [ScheduledPremiere] = []
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?
    #endif
    
    func schedulePremiereForVideo(videoId: String, title: String, thumbnailURL: String, scheduledAt: Date, creatorId: String, chatEnabled: Bool = true) async -> String? {
        #if canImport(FirebaseFirestore)
        do {
            let ref = db.collection("scheduled_premieres").document()
            try await ref.setData([
                "videoId": videoId,
                "title": title,
                "thumbnailURL": thumbnailURL,
                "scheduledAt": Timestamp(date: scheduledAt),
                "creatorId": creatorId,
                "status": ScheduledPremiere.PremiereStatus.scheduled.rawValue,
                "chatEnabled": chatEnabled,
                "createdAt": FieldValue.serverTimestamp()
            ])
            return ref.documentID
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
    
    func listenToPremieres(creatorId: String) {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = db.collection("scheduled_premieres")
            .whereField("creatorId", isEqualTo: creatorId)
            .order(by: "scheduledAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let docs = snapshot?.documents else { return }
                self.premieres = docs.compactMap { doc in
                    let d = doc.data()
                    return ScheduledPremiere(
                        id: doc.documentID,
                        videoId: d["videoId"] as? String ?? "",
                        title: d["title"] as? String ?? "",
                        thumbnailURL: d["thumbnailURL"] as? String ?? "",
                        scheduledAt: (d["scheduledAt"] as? Timestamp)?.dateValue() ?? Date(),
                        creatorId: d["creatorId"] as? String ?? "",
                        status: ScheduledPremiere.PremiereStatus(rawValue: d["status"] as? String ?? "scheduled") ?? .scheduled,
                        viewerCount: d["viewerCount"] as? Int,
                        chatEnabled: d["chatEnabled"] as? Bool ?? true
                    )
                }
            }
        #endif
        
        // Mock fallback
        if premieres.isEmpty {
            premieres = [
                ScheduledPremiere(
                    id: "premiere1",
                    videoId: "video1",
                    title: "Upcoming Music Video Premiere",
                    thumbnailURL: "https://picsum.photos/400/225?random=1",
                    scheduledAt: Date().addingTimeInterval(3600),
                    creatorId: creatorId,
                    status: .scheduled,
                    viewerCount: nil,
                    chatEnabled: true
                )
            ]
        }
    }
    
    func updatePremiereStatus(premiereId: String, status: ScheduledPremiere.PremiereStatus, viewerCount: Int? = nil) async {
        #if canImport(FirebaseFirestore)
        do {
            var data: [String: Any] = ["status": status.rawValue]
            if let viewerCount = viewerCount { data["viewerCount"] = viewerCount }
            try await db.collection("scheduled_premieres").document(premiereId).setData(data, merge: true)
        } catch { }
        #endif
    }
    
    func stopListening() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        #endif
    }
}


