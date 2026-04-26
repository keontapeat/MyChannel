//
//  MultiHostLiveService.swift
//  MyChannel
//
//  Phase 173: Multi-Host Live Rooms.
//  Up to 8 co-hosts, layout switching, audience participation queue.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct LiveRoom: Codable, Identifiable, Equatable {
    let id: String
    let hostUid: String
    let title: String
    let coHosts: [CoHost]
    let layout: RoomLayout
    let maxCoHosts: Int
    let isOpen: Bool
    let createdAt: Date
}

struct CoHost: Codable, Identifiable, Equatable {
    let id: String
    let uid: String
    let displayName: String
    let isMuted: Bool
    let isVideoOn: Bool
    let joinedAt: Date
}

enum RoomLayout: String, Codable, CaseIterable {
    case grid, spotlight, sidebar, split, pip
}

struct ParticipationRequest: Codable, Identifiable {
    let id: String
    let roomId: String
    let uid: String
    let displayName: String
    let requestedAt: Date
}

// MARK: - Service

@MainActor
final class MultiHostLiveService: ObservableObject {
    static let shared = MultiHostLiveService()
    private init() {}

    @Published private(set) var room: LiveRoom?
    @Published private(set) var participationQueue: [ParticipationRequest] = []
    @Published var currentLayout: RoomLayout = .grid

    func createRoom(hostUid: String, title: String, maxCoHosts: Int = 8) async throws -> String {
        guard AppConfig.Features.enableMultiHostLive else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("live_rooms").document()
        try await ref.setData([
            "hostUid": hostUid, "title": title, "coHosts": [],
            "layout": RoomLayout.grid.rawValue, "maxCoHosts": maxCoHosts,
            "isOpen": true, "createdAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func inviteCoHost(roomId: String, uid: String, displayName: String) async throws {
        guard AppConfig.Features.enableMultiHostLive else { return }
        #if canImport(FirebaseFirestore)
        let coHost: [String: Any] = [
            "id": UUID().uuidString, "uid": uid, "displayName": displayName,
            "isMuted": false, "isVideoOn": true, "joinedAt": Timestamp(date: Date())
        ]
        try await Firestore.firestore().collection("live_rooms").document(roomId)
            .updateData(["coHosts": FieldValue.arrayUnion([coHost])])
        #endif
    }

    func switchLayout(_ layout: RoomLayout, roomId: String) async throws {
        guard AppConfig.Features.enableMultiHostLive else { return }
        currentLayout = layout
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("live_rooms").document(roomId)
            .updateData(["layout": layout.rawValue])
        #endif
    }

    func requestToJoin(roomId: String, uid: String, displayName: String) async throws {
        guard AppConfig.Features.enableMultiHostLive else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("participation_requests").document().setData([
            "roomId": roomId, "uid": uid, "displayName": displayName,
            "requestedAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    func approveRequest(requestId: String, roomId: String) async throws {
        guard AppConfig.Features.enableMultiHostLive else { return }
        #if canImport(FirebaseFirestore)
        let doc = try await Firestore.firestore().collection("participation_requests").document(requestId).getDocument()
        if let d = doc.data() {
            try await inviteCoHost(roomId: roomId, uid: d["uid"] as? String ?? "", displayName: d["displayName"] as? String ?? "")
            try await Firestore.firestore().collection("participation_requests").document(requestId).delete()
        }
        #endif
    }
}
