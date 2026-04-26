//
//  CommunityNotesService.swift
//  MyChannel
//
//  Phase 181: Community Notes System.
//  Crowd-sourced fact notes, consensus rating, helpfulness scoring.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct CommunityNote: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String
    let authorUid: String
    let body: String
    let sources: [URL]
    let helpfulCount: Int
    let notHelpfulCount: Int
    let status: NoteStatus
    let createdAt: Date
}

enum NoteStatus: String, Codable { case pending, helpful, notHelpful, needsMore }

struct NoteRating: Codable {
    let noteId: String
    let raterUid: String
    let isHelpful: Bool
    let reason: String
}

// MARK: - Service

@MainActor
final class CommunityNotesService: ObservableObject {
    static let shared = CommunityNotesService()
    private init() {}

    @Published private(set) var notes: [CommunityNote] = []
    @Published var activeNote: CommunityNote?

    func loadNotes(videoId: String) async throws {
        guard AppConfig.Features.enableCommunityNotes else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("community_notes").whereField("videoId", isEqualTo: videoId)
            .whereField("status", isEqualTo: "helpful").getDocuments()
        notes = snap.documents.compactMap { doc in
            let d = doc.data()
            return CommunityNote(
                id: doc.documentID, videoId: d["videoId"] as? String ?? "",
                authorUid: d["authorUid"] as? String ?? "", body: d["body"] as? String ?? "",
                sources: (d["sources"] as? [String])?.compactMap(URL.init(string:)) ?? [],
                helpfulCount: d["helpfulCount"] as? Int ?? 0,
                notHelpfulCount: d["notHelpfulCount"] as? Int ?? 0,
                status: NoteStatus(rawValue: d["status"] as? String ?? "") ?? .pending,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        activeNote = notes.first
        #endif
    }

    func submitNote(videoId: String, authorUid: String, body: String, sources: [URL]) async throws -> String {
        guard AppConfig.Features.enableCommunityNotes else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("community_notes").document()
        try await ref.setData([
            "videoId": videoId, "authorUid": authorUid, "body": body,
            "sources": sources.map(\.absoluteString), "helpfulCount": 0,
            "notHelpfulCount": 0, "status": NoteStatus.pending.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func rateNote(noteId: String, raterUid: String, isHelpful: Bool) async throws {
        guard AppConfig.Features.enableCommunityNotes else { return }
        #if canImport(FirebaseFirestore)
        let field = isHelpful ? "helpfulCount" : "notHelpfulCount"
        try await Firestore.firestore().collection("community_notes").document(noteId)
            .updateData([field: FieldValue.increment(Int64(1))])
        #endif
    }
}
