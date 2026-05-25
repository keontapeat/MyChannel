// 🔥 iOS TEAM WORKSPACE SERVICE - COLLABORATIVE CREATION 💣

import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class TeamWorkspaceService: ObservableObject {
    static let shared = TeamWorkspaceService()
    
    @Published var userWorkspaces: [TeamWorkspace] = []
    @Published var currentWorkspace: TeamWorkspace?
    @Published var pendingInvites: [WorkspaceInvite] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var workspaceListener: ListenerRegistration?
    
    private init() {}
    
    // MARK: - Models
    
    struct TeamWorkspace: Codable, Identifiable {
        let id: String
        var name: String
        var description: String
        let ownerId: String
        var members: [TeamMember]
        var projects: [String]
        var settings: WorkspaceSettings
        let createdAt: Date
        var updatedAt: Date
    }
    
    struct TeamMember: Codable, Identifiable {
        var id: String { userId }
        let userId: String
        let username: String
        let displayName: String
        var profileImageURL: String?
        var role: MemberRole
        var permissions: [Permission]
        let joinedAt: Date
        var lastActiveAt: Date?
    }
    
    enum MemberRole: String, Codable {
        case owner
        case admin
        case editor
        case viewer
    }
    
    enum Permission: String, Codable {
        case createProjects = "create_projects"
        case editProjects = "edit_projects"
        case deleteProjects = "delete_projects"
        case inviteMembers = "invite_members"
        case removeMembers = "remove_members"
        case changeSettings = "change_settings"
        case exportProjects = "export_projects"
        case viewAnalytics = "view_analytics"
    }
    
    struct WorkspaceSettings: Codable {
        var isPublic: Bool
        var allowGuestViewing: Bool
        var requireApprovalForJoin: Bool
        var defaultMemberRole: MemberRole
        var maxMembers: Int
        var allowedDomains: [String]?
    }
    
    struct WorkspaceInvite: Codable, Identifiable {
        let id: String
        let workspaceId: String
        let workspaceName: String
        let invitedBy: String
        let invitedByName: String
        let invitedEmail: String
        let role: MemberRole
        var status: InviteStatus
        let expiresAt: Date
        let createdAt: Date
    }
    
    enum InviteStatus: String, Codable {
        case pending
        case accepted
        case declined
        case expired
    }
    
    // MARK: - Create Workspace
    
    func createWorkspace(
        name: String,
        description: String,
        ownerId: String,
        ownerData: (username: String, displayName: String, profileImageURL: String?)
    ) async throws -> TeamWorkspace {
        isLoading = true
        defer { isLoading = false }
        
        let workspaceId = "workspace_\(Int(Date().timeIntervalSince1970))"
        let workspaceRef = db.collection("team-workspaces").document(workspaceId)
        
        let workspace = TeamWorkspace(
            id: workspaceId,
            name: name,
            description: description,
            ownerId: ownerId,
            members: [
                TeamMember(
                    userId: ownerId,
                    username: ownerData.username,
                    displayName: ownerData.displayName,
                    profileImageURL: ownerData.profileImageURL,
                    role: .owner,
                    permissions: Permission.allCases,
                    joinedAt: Date()
                )
            ],
            projects: [],
            settings: WorkspaceSettings(
                isPublic: false,
                allowGuestViewing: false,
                requireApprovalForJoin: true,
                defaultMemberRole: .editor,
                maxMembers: 50
            ),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        try workspaceRef.setData(from: workspace)
        
        print("✅ [iOS] Created workspace:", workspaceId)
        return workspace
    }
    
    // MARK: - Get Workspaces
    
    func getUserWorkspaces(userId: String) async throws -> [TeamWorkspace] {
        isLoading = true
        defer { isLoading = false }
        
        let snapshot = try await db.collection("team-workspaces")
            .whereField("members", arrayContains: ["userId": userId])
            .getDocuments()
        
        let workspaces = try snapshot.documents.compactMap { doc in
            try doc.data(as: TeamWorkspace.self)
        }
        
        userWorkspaces = workspaces
        return workspaces
    }
    
    // MARK: - Invite Member
    
    func inviteMember(
        workspaceId: String,
        invitedEmail: String,
        role: MemberRole,
        invitedBy: String,
        invitedByName: String
    ) async throws -> WorkspaceInvite {
        let workspace = try await getWorkspace(workspaceId: workspaceId)
        
        let inviteId = "invite_\(Int(Date().timeIntervalSince1970))"
        let inviteRef = db.collection("workspace-invites").document(inviteId)
        
        let invite = WorkspaceInvite(
            id: inviteId,
            workspaceId: workspaceId,
            workspaceName: workspace.name,
            invitedBy: invitedBy,
            invitedByName: invitedByName,
            invitedEmail: invitedEmail,
            role: role,
            status: .pending,
            expiresAt: Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days
            createdAt: Date()
        )
        
        try inviteRef.setData(from: invite)
        
        print("✅ [iOS] Invited member:", invitedEmail)
        return invite
    }
    
    // MARK: - Accept Invite
    
    func acceptInvite(
        inviteId: String,
        userId: String,
        userData: (username: String, displayName: String, profileImageURL: String?)
    ) async throws {
        let inviteRef = db.collection("workspace-invites").document(inviteId)
        let inviteDoc = try await inviteRef.getDocument()
        
        guard let invite = try? inviteDoc.data(as: WorkspaceInvite.self) else {
            throw WorkspaceError.inviteNotFound
        }
        
        // Check if expired
        if invite.expiresAt < Date() {
            throw WorkspaceError.inviteExpired
        }
        
        // Add member to workspace
        let workspaceRef = db.collection("team-workspaces").document(invite.workspaceId)
        
        let newMember = TeamMember(
            userId: userId,
            username: userData.username,
            displayName: userData.displayName,
            profileImageURL: userData.profileImageURL,
            role: invite.role,
            permissions: getPermissions(for: invite.role),
            joinedAt: Date()
        )
        
        try await workspaceRef.updateData([
            "members": FieldValue.arrayUnion([try Firestore.Encoder().encode(newMember)]),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        // Update invite status
        try await inviteRef.updateData(["status": InviteStatus.accepted.rawValue])
        
        print("✅ [iOS] Accepted invite:", inviteId)
    }
    
    // MARK: - Remove Member
    
    func removeMember(
        workspaceId: String,
        userId: String,
        removedBy: String
    ) async throws {
        let workspace = try await getWorkspace(workspaceId: workspaceId)
        
        // Check permissions
        guard let remover = workspace.members.first(where: { $0.userId == removedBy }),
              remover.permissions.contains(.removeMembers) else {
            throw WorkspaceError.permissionDenied
        }
        
        // Can't remove owner
        if userId == workspace.ownerId {
            throw WorkspaceError.cannotRemoveOwner
        }
        
        // Remove member
        guard let memberToRemove = workspace.members.first(where: { $0.userId == userId }) else {
            throw WorkspaceError.memberNotFound
        }
        
        let workspaceRef = db.collection("team-workspaces").document(workspaceId)
        
        try await workspaceRef.updateData([
            "members": FieldValue.arrayRemove([try Firestore.Encoder().encode(memberToRemove)]),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ [iOS] Removed member:", userId)
    }
    
    // MARK: - Update Member Role
    
    func updateMemberRole(
        workspaceId: String,
        userId: String,
        newRole: MemberRole,
        updatedBy: String
    ) async throws {
        var workspace = try await getWorkspace(workspaceId: workspaceId)
        
        // Only owner can change roles
        guard let updater = workspace.members.first(where: { $0.userId == updatedBy }),
              updater.role == .owner else {
            throw WorkspaceError.permissionDenied
        }
        
        // Can't change owner role
        if userId == workspace.ownerId {
            throw WorkspaceError.cannotChangeOwnerRole
        }
        
        // Update member
        if let index = workspace.members.firstIndex(where: { $0.userId == userId }) {
            workspace.members[index].role = newRole
            workspace.members[index].permissions = getPermissions(for: newRole)
        }
        
        let workspaceRef = db.collection("team-workspaces").document(workspaceId)
        
        try await workspaceRef.updateData([
            "members": try Firestore.Encoder().encode(workspace.members),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ [iOS] Updated member role:", userId, newRole)
    }
    
    // MARK: - Add/Remove Projects
    
    func addProject(workspaceId: String, projectId: String) async throws {
        let workspaceRef = db.collection("team-workspaces").document(workspaceId)
        
        try await workspaceRef.updateData([
            "projects": FieldValue.arrayUnion([projectId]),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ [iOS] Added project to workspace:", projectId)
    }
    
    func removeProject(workspaceId: String, projectId: String) async throws {
        let workspaceRef = db.collection("team-workspaces").document(workspaceId)
        
        try await workspaceRef.updateData([
            "projects": FieldValue.arrayRemove([projectId]),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ [iOS] Removed project from workspace:", projectId)
    }
    
    // MARK: - Helpers
    
    private func getWorkspace(workspaceId: String) async throws -> TeamWorkspace {
        let workspaceRef = db.collection("team-workspaces").document(workspaceId)
        let doc = try await workspaceRef.getDocument()
        
        guard let workspace = try? doc.data(as: TeamWorkspace.self) else {
            throw WorkspaceError.workspaceNotFound
        }
        
        return workspace
    }
    
    private func getPermissions(for role: MemberRole) -> [Permission] {
        switch role {
        case .owner:
            return Permission.allCases
        case .admin:
            return [.createProjects, .editProjects, .deleteProjects, .inviteMembers, .removeMembers, .exportProjects, .viewAnalytics]
        case .editor:
            return [.createProjects, .editProjects, .exportProjects]
        case .viewer:
            return []
        }
    }
    
    // MARK: - Errors
    
    enum WorkspaceError: LocalizedError {
        case workspaceNotFound
        case inviteNotFound
        case inviteExpired
        case permissionDenied
        case cannotRemoveOwner
        case cannotChangeOwnerRole
        case memberNotFound
        
        var errorDescription: String? {
            switch self {
            case .workspaceNotFound: return "Workspace not found"
            case .inviteNotFound: return "Invite not found"
            case .inviteExpired: return "Invite has expired"
            case .permissionDenied: return "Permission denied"
            case .cannotRemoveOwner: return "Cannot remove workspace owner"
            case .cannotChangeOwnerRole: return "Cannot change owner role"
            case .memberNotFound: return "Member not found"
            }
        }
    }
    
    deinit {
        workspaceListener?.remove()
        cancellables.removeAll()
    }
}

// MARK: - Permission Extension

extension TeamWorkspaceService.Permission: CaseIterable {}

