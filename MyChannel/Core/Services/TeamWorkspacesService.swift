//
//  TeamWorkspacesService.swift
//  MyChannel
//
//  Phase 106: Team Workspaces.
//  Org accounts, role-based access control, approval chains, audit trails.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct TeamWorkspace: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let ownerUid: String
    let iconURL: URL?
    let memberCount: Int
    let createdAt: Date
}

struct WorkspaceMember: Codable, Identifiable, Equatable {
    let id: String
    let workspaceId: String
    let uid: String
    let displayName: String
    let role: WorkspaceRole
    let joinedAt: Date
}

enum WorkspaceRole: String, Codable, CaseIterable {
    case owner, admin, editor, reviewer, viewer
}

struct ApprovalRequest: Codable, Identifiable {
    let id: String
    let workspaceId: String
    let videoId: String
    let requestedByUid: String
    let status: ApprovalStatus
    let reviewedByUid: String?
    let note: String?
    let createdAt: Date
}

enum ApprovalStatus: String, Codable { case pending, approved, rejected }

struct AuditEntry: Codable, Identifiable {
    let id: String
    let workspaceId: String
    let actorUid: String
    let action: String
    let resourceId: String
    let timestamp: Date
}

// MARK: - Service

@MainActor
final class TeamWorkspacesService: ObservableObject {
    static let shared = TeamWorkspacesService()
    private init() {}

    @Published private(set) var workspaces: [TeamWorkspace] = []
    @Published private(set) var members: [WorkspaceMember] = []
    @Published private(set) var pendingApprovals: [ApprovalRequest] = []

    func loadWorkspaces(uid: String) async throws {
        guard AppConfig.Features.enableTeamWorkspaces else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("workspaces")
            .whereField("memberUids", arrayContains: uid)
            .getDocuments()
        workspaces = snap.documents.compactMap { doc in
            let d = doc.data()
            return TeamWorkspace(
                id: doc.documentID,
                name: d["name"] as? String ?? "",
                ownerUid: d["ownerUid"] as? String ?? "",
                iconURL: (d["iconURL"] as? String).flatMap(URL.init(string:)),
                memberCount: (d["memberUids"] as? [String])?.count ?? 0,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func createWorkspace(name: String, ownerUid: String) async throws -> String {
        guard AppConfig.Features.enableTeamWorkspaces else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("workspaces").document()
        try await ref.setData([
            "name": name,
            "ownerUid": ownerUid,
            "memberUids": [ownerUid],
            "createdAt": FieldValue.serverTimestamp()
        ])
        try await Firestore.firestore()
            .collection("workspace_members").document()
            .setData([
                "workspaceId": ref.documentID,
                "uid": ownerUid,
                "role": WorkspaceRole.owner.rawValue,
                "joinedAt": FieldValue.serverTimestamp()
            ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func inviteMember(workspaceId: String, uid: String, role: WorkspaceRole) async throws {
        guard AppConfig.Features.enableTeamWorkspaces else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("workspace_members").document()
            .setData([
                "workspaceId": workspaceId,
                "uid": uid,
                "role": role.rawValue,
                "joinedAt": FieldValue.serverTimestamp()
            ])
        try await Firestore.firestore()
            .collection("workspaces").document(workspaceId)
            .updateData(["memberUids": FieldValue.arrayUnion([uid])])
        try await logAudit(workspaceId: workspaceId, actorUid: "", action: "invite_member", resourceId: uid)
        #endif
    }

    func updateRole(memberId: String, newRole: WorkspaceRole) async throws {
        guard AppConfig.Features.enableTeamWorkspaces else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("workspace_members").document(memberId)
            .updateData(["role": newRole.rawValue])
        #endif
    }

    func submitForApproval(workspaceId: String, videoId: String, requestedByUid: String) async throws {
        guard AppConfig.Features.enableTeamWorkspaces else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("approval_requests").document()
            .setData([
                "workspaceId": workspaceId,
                "videoId": videoId,
                "requestedByUid": requestedByUid,
                "status": ApprovalStatus.pending.rawValue,
                "createdAt": FieldValue.serverTimestamp()
            ])
        #endif
    }

    func approveContent(requestId: String, reviewerUid: String, approved: Bool, note: String?) async throws {
        guard AppConfig.Features.enableTeamWorkspaces else { return }
        #if canImport(FirebaseFirestore)
        var update: [String: Any] = [
            "status": approved ? ApprovalStatus.approved.rawValue : ApprovalStatus.rejected.rawValue,
            "reviewedByUid": reviewerUid
        ]
        if let note { update["note"] = note }
        try await Firestore.firestore()
            .collection("approval_requests").document(requestId)
            .updateData(update)
        #endif
    }

    private func logAudit(workspaceId: String, actorUid: String, action: String, resourceId: String) async throws {
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("workspace_audit_log").document()
            .setData([
                "workspaceId": workspaceId,
                "actorUid": actorUid,
                "action": action,
                "resourceId": resourceId,
                "timestamp": FieldValue.serverTimestamp()
            ])
        #endif
    }
}
