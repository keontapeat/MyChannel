import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct Collaboration: Identifiable, Codable {
    let id: String
    let videoId: String
    let initiatorId: String
    let collaborators: [Collaborator]
    let title: String
    let description: String
    let type: CollaborationType
    let status: CollaborationStatus
    let permissions: CollaborationPermissions
    let revenueShare: [RevenueShare]
    let createdAt: Date
    let deadline: Date?
    
    struct Collaborator: Identifiable, Codable {
        let id: String
        let userId: String
        let displayName: String
        let role: CollaboratorRole
        let status: CollaboratorStatus
        let invitedAt: Date
        let joinedAt: Date?
        
        enum CollaboratorRole: String, Codable, CaseIterable {
            case coCreator, guest, editor, musician, voiceActor
            
            var displayName: String {
                switch self {
                case .coCreator: return "Co-creator"
                case .guest: return "Guest"
                case .editor: return "Editor"
                case .musician: return "Musician"
                case .voiceActor: return "Voice Actor"
                }
            }
        }
        
        enum CollaboratorStatus: String, Codable {
            case invited, accepted, declined, removed
        }
    }
    
    enum CollaborationType: String, Codable, CaseIterable {
        case coCreation, guestAppearance, remix, duet, reaction
        
        var displayName: String {
            switch self {
            case .coCreation: return "Co-creation"
            case .guestAppearance: return "Guest Appearance"
            case .remix: return "Remix"
            case .duet: return "Duet"
            case .reaction: return "Reaction"
            }
        }
    }
    
    enum CollaborationStatus: String, Codable {
        case pending, active, completed, cancelled
    }
    
    struct CollaborationPermissions: Codable {
        let canEdit: [String] // User IDs who can edit
        let canPublish: [String]
        let canMonetize: [String]
        let canDelete: [String]
    }
    
    struct RevenueShare: Codable {
        let userId: String
        let percentage: Double
        let type: RevenueType
        
        enum RevenueType: String, Codable {
            case ads, tips, memberships, merchandise
        }
    }
}

struct LiveCollaboration: Identifiable, Codable {
    let id: String
    let streamId: String
    let hostId: String
    let guests: [LiveGuest]
    let type: LiveCollabType
    let status: LiveCollabStatus
    let startedAt: Date?
    let endedAt: Date?
    
    struct LiveGuest: Identifiable, Codable {
        let id: String
        let userId: String
        let displayName: String
        let role: GuestRole
        let streamURL: String?
        let status: GuestStatus
        let invitedAt: Date
        let joinedAt: Date?
        
        enum GuestRole: String, Codable {
            case coHost, guest, moderator, interviewer
        }
        
        enum GuestStatus: String, Codable {
            case invited, connecting, live, disconnected, removed
        }
    }
    
    enum LiveCollabType: String, Codable {
        case interview, coStream, panel, gameSession
    }
    
    enum LiveCollabStatus: String, Codable {
        case scheduled, live, ended, cancelled
    }
}

@MainActor
final class CollaborationsService: ObservableObject {
    static let shared = CollaborationsService()
    private init() {}
    
    @Published var myCollaborations: [Collaboration] = []
    @Published var pendingInvites: [Collaboration] = []
    @Published var liveCollaborations: [LiveCollaboration] = []
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var collaborationsListener: ListenerRegistration?
    private var invitesListener: ListenerRegistration?
    #endif
    
    func createCollaboration(
        videoId: String,
        collaboratorIds: [String],
        title: String,
        description: String,
        type: Collaboration.CollaborationType,
        revenueShares: [Collaboration.RevenueShare],
        deadline: Date?
    ) async -> String? {
        guard let initiatorId = AppState.shared.currentUser?.id else { return nil }
        
        let collaborators = collaboratorIds.enumerated().map { index, userId in
            Collaboration.Collaborator(
                id: UUID().uuidString,
                userId: userId,
                displayName: "Collaborator \(index + 1)", // Would fetch actual name
                role: .coCreator,
                status: .invited,
                invitedAt: Date(),
                joinedAt: nil
            )
        }
        
        #if canImport(FirebaseFirestore)
        do {
            let ref = db.collection("collaborations").document()
            try await ref.setData([
                "videoId": videoId,
                "initiatorId": initiatorId,
                "collaborators": collaborators.map { collab in
                    [
                        "id": collab.id,
                        "userId": collab.userId,
                        "displayName": collab.displayName,
                        "role": collab.role.rawValue,
                        "status": collab.status.rawValue,
                        "invitedAt": Timestamp(date: collab.invitedAt)
                    ]
                },
                "title": title,
                "description": description,
                "type": type.rawValue,
                "status": Collaboration.CollaborationStatus.pending.rawValue,
                "permissions": [
                    "canEdit": [initiatorId] + collaboratorIds,
                    "canPublish": [initiatorId],
                    "canMonetize": [initiatorId],
                    "canDelete": [initiatorId]
                ],
                "revenueShare": revenueShares.map { share in
                    [
                        "userId": share.userId,
                        "percentage": share.percentage,
                        "type": share.type.rawValue
                    ]
                },
                "createdAt": FieldValue.serverTimestamp(),
                "deadline": deadline != nil ? Timestamp(date: deadline!) : nil
            ])
            
            // Send invitations
            for collaborator in collaborators {
                await sendCollaborationInvite(
                    collaborationId: ref.documentID,
                    toUserId: collaborator.userId,
                    fromUserId: initiatorId,
                    title: title
                )
            }
            
            return ref.documentID
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
    
    func respondToInvite(collaborationId: String, userId: String, accept: Bool) async -> Bool {
        #if canImport(FirebaseFirestore)
        do {
            // Update collaborator status
            let collabRef = db.collection("collaborations").document(collaborationId)
            let doc = try await collabRef.getDocument()
            
            guard var data = doc.data() else { return false }
            var collaborators = data["collaborators"] as? [[String: Any]] ?? []
            
            for i in 0..<collaborators.count {
                if collaborators[i]["userId"] as? String == userId {
                    collaborators[i]["status"] = accept ? Collaboration.Collaborator.CollaboratorStatus.accepted.rawValue : Collaboration.Collaborator.CollaboratorStatus.declined.rawValue
                    collaborators[i]["joinedAt"] = Timestamp(date: Date())
                    break
                }
            }
            
            try await collabRef.setData([
                "collaborators": collaborators
            ], merge: true)
            
            // If accepted, grant permissions
            if accept {
                await grantCollaborationPermissions(collaborationId: collaborationId, userId: userId)
            }
            
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
    
    func startLiveCollaboration(
        streamId: String,
        guestIds: [String],
        type: LiveCollaboration.LiveCollabType
    ) async -> String? {
        guard let hostId = AppState.shared.currentUser?.id else { return nil }
        
        let guests = guestIds.map { userId in
            LiveCollaboration.LiveGuest(
                id: UUID().uuidString,
                userId: userId,
                displayName: "Guest", // Would fetch actual name
                role: .guest,
                streamURL: nil,
                status: .invited,
                invitedAt: Date(),
                joinedAt: nil
            )
        }
        
        #if canImport(FirebaseFirestore)
        do {
            let ref = db.collection("live_collaborations").document()
            try await ref.setData([
                "streamId": streamId,
                "hostId": hostId,
                "guests": guests.map { guest in
                    [
                        "id": guest.id,
                        "userId": guest.userId,
                        "displayName": guest.displayName,
                        "role": guest.role.rawValue,
                        "status": guest.status.rawValue,
                        "invitedAt": Timestamp(date: guest.invitedAt)
                    ]
                },
                "type": type.rawValue,
                "status": LiveCollaboration.LiveCollabStatus.scheduled.rawValue,
                "createdAt": FieldValue.serverTimestamp()
            ])
            
            // Send live invite notifications
            for guest in guests {
                await sendLiveCollaborationInvite(
                    collaborationId: ref.documentID,
                    toUserId: guest.userId,
                    streamId: streamId,
                    hostId: hostId
                )
            }
            
            return ref.documentID
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
    
    func joinLiveCollaboration(collaborationId: String, userId: String, streamURL: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        do {
            let collabRef = db.collection("live_collaborations").document(collaborationId)
            let doc = try await collabRef.getDocument()
            
            guard var data = doc.data() else { return false }
            var guests = data["guests"] as? [[String: Any]] ?? []
            
            for i in 0..<guests.count {
                if guests[i]["userId"] as? String == userId {
                    guests[i]["status"] = LiveCollaboration.LiveGuest.GuestStatus.live.rawValue
                    guests[i]["streamURL"] = streamURL
                    guests[i]["joinedAt"] = Timestamp(date: Date())
                    break
                }
            }
            
            try await collabRef.setData([
                "guests": guests,
                "status": LiveCollaboration.LiveCollabStatus.live.rawValue,
                "startedAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
    
    func listenToMyCollaborations(userId: String) {
        #if canImport(FirebaseFirestore)
        collaborationsListener?.remove()
        collaborationsListener = db.collection("collaborations")
            .whereFilter(Filter.orFilter([
                Filter.whereField("initiatorId", isEqualTo: userId),
                Filter.whereField("collaborators", arrayContains: ["userId": userId])
            ]))
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                // Handle snapshot updates
                self?.handleCollaborationsSnapshot(snapshot)
            }
        #endif
    }
    
    func listenToPendingInvites(userId: String) {
        #if canImport(FirebaseFirestore)
        invitesListener?.remove()
        invitesListener = db.collection("collaborations")
            .whereField("collaborators", arrayContains: ["userId": userId, "status": "invited"])
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                // Handle invites snapshot
                self?.handleInvitesSnapshot(snapshot)
            }
        #endif
    }
    
    private func sendCollaborationInvite(collaborationId: String, toUserId: String, fromUserId: String, title: String) async {
        // Send push notification and in-app notification
        await PushNotificationService.shared.scheduleSmartNotification(
            title: "Collaboration Invite",
            body: "You've been invited to collaborate on '\(title)'",
            category: "COLLABORATION",
            userInfo: [
                "collaborationId": collaborationId,
                "type": "collaboration_invite"
            ]
        )
    }
    
    private func sendLiveCollaborationInvite(collaborationId: String, toUserId: String, streamId: String, hostId: String) async {
        await PushNotificationService.shared.scheduleSmartNotification(
            title: "Live Collaboration Invite",
            body: "You've been invited to join a live stream",
            category: "LIVE_STREAM",
            userInfo: [
                "collaborationId": collaborationId,
                "streamId": streamId,
                "type": "live_collaboration_invite"
            ]
        )
    }
    
    private func grantCollaborationPermissions(collaborationId: String, userId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            // Grant edit permissions to video
            let collabDoc = try await db.collection("collaborations").document(collaborationId).getDocument()
            if let data = collabDoc.data(), let videoId = data["videoId"] as? String {
                try await db.collection("videos").document(videoId).setData([
                    "collaborators": FieldValue.arrayUnion([userId]),
                    "permissions": [
                        "editors": FieldValue.arrayUnion([userId])
                    ]
                ], merge: true)
            }
        } catch { }
        #endif
    }
    
    #if canImport(FirebaseFirestore)
    private func handleCollaborationsSnapshot(_ snapshot: QuerySnapshot?) {
        // Handle collaborations updates
        guard let docs = snapshot?.documents else { return }
        // Parse and update myCollaborations
    }
    
    private func handleInvitesSnapshot(_ snapshot: QuerySnapshot?) {
        // Handle pending invites updates
        guard let docs = snapshot?.documents else { return }
        // Parse and update pendingInvites
    }
    #endif
    
    func stopListening() {
        #if canImport(FirebaseFirestore)
        collaborationsListener?.remove()
        invitesListener?.remove()
        #endif
    }
}
