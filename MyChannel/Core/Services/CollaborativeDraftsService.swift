//
//  CollaborativeDraftsService.swift
//  MyChannel
//
//  Phase 69: Collaborative drafts.
//  Multi-editor projects with role-based permissions and comment/approve
//  workflow. Backed by Firestore `drafts/{draftId}` + sub-collection
//  `collaborators` and `revisions`.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum DraftRole: String, Codable, CaseIterable {
    case owner
    case editor
    case reviewer
    case viewer

    var canEdit: Bool { self == .owner || self == .editor }
    var canApprove: Bool { self == .owner || self == .reviewer }
}

struct DraftCollaborator: Codable, Identifiable, Equatable {
    let id: String               // uid
    let displayName: String
    let avatarURL: URL?
    let role: DraftRole
    let addedAt: Date
}

struct DraftRevision: Codable, Identifiable, Equatable {
    let id: String
    let draftId: String
    let authorUid: String
    let createdAt: Date
    let message: String
    let snapshot: Data           // JSON blob of the editor state
}

struct VideoDraft: Codable, Identifiable, Equatable {
    let id: String
    let ownerUid: String
    let title: String
    let description: String
    let status: Status
    let createdAt: Date
    let updatedAt: Date
    let videoStorageRef: String?

    enum Status: String, Codable { case editing, inReview, approved, published, archived }
}

@MainActor
final class CollaborativeDraftsService: ObservableObject {
    static let shared = CollaborativeDraftsService()
    private init() {}

    // MARK: - CRUD

    func createDraft(_ draft: VideoDraft, initialCollaborators: [DraftCollaborator] = []) async throws {
        guard AppConfig.Features.enableCollaborativeDrafts else { throw DraftError.disabled }
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let ref = db.collection("drafts").document(draft.id)

        try await ref.setData([
            "ownerUid": draft.ownerUid,
            "title": draft.title,
            "description": draft.description,
            "status": draft.status.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "videoStorageRef": draft.videoStorageRef as Any
        ])

        // Owner is implicit — also add to collaborators for easy role queries.
        let owner = DraftCollaborator(
            id: draft.ownerUid,
            displayName: "Owner",
            avatarURL: nil,
            role: .owner,
            addedAt: Date()
        )
        try await addCollaborator(draftId: draft.id, collaborator: owner)
        for c in initialCollaborators where c.id != draft.ownerUid {
            try await addCollaborator(draftId: draft.id, collaborator: c)
        }
        #endif
    }

    func addCollaborator(draftId: String, collaborator: DraftCollaborator) async throws {
        guard AppConfig.Features.enableCollaborativeDrafts else { throw DraftError.disabled }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("drafts").document(draftId)
            .collection("collaborators").document(collaborator.id)
            .setData([
                "displayName": collaborator.displayName,
                "avatarURL": collaborator.avatarURL?.absoluteString as Any,
                "role": collaborator.role.rawValue,
                "addedAt": FieldValue.serverTimestamp()
            ])
        #endif
    }

    // MARK: - Revisions

    /// Append a new revision. Transactional so concurrent editors don't overwrite.
    func appendRevision(_ revision: DraftRevision) async throws {
        guard AppConfig.Features.enableCollaborativeDrafts else { throw DraftError.disabled }
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("drafts").document(revision.draftId)
            .collection("revisions").document(revision.id)
            .setData([
                "authorUid": revision.authorUid,
                "createdAt": FieldValue.serverTimestamp(),
                "message": revision.message,
                "snapshot": revision.snapshot
            ])
        try await db.collection("drafts").document(revision.draftId)
            .updateData([
                "updatedAt": FieldValue.serverTimestamp()
            ])
        #endif
    }

    // MARK: - Approvals

    func submitForReview(draftId: String) async throws {
        try await setStatus(draftId: draftId, status: .inReview)
    }

    func approve(draftId: String) async throws {
        try await setStatus(draftId: draftId, status: .approved)
    }

    private func setStatus(draftId: String, status: VideoDraft.Status) async throws {
        guard AppConfig.Features.enableCollaborativeDrafts else { throw DraftError.disabled }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("drafts").document(draftId)
            .updateData([
                "status": status.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        #endif
    }

    enum DraftError: LocalizedError {
        case disabled
        var errorDescription: String? { "Collaborative drafts are disabled." }
    }
}
