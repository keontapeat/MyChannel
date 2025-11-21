// 🔥 TEAM WORKSPACES - COLLABORATIVE THUMBNAIL CREATION 💣
// Works on both Web and iOS

import {
  collection,
  doc,
  setDoc,
  getDoc,
  getDocs,
  query,
  where,
  updateDoc,
  deleteDoc,
  arrayUnion,
  arrayRemove,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';
import { db } from '@/lib/firebase/config';

// Types
export interface TeamWorkspace {
  id: string;
  name: string;
  description: string;
  ownerId: string;
  members: TeamMember[];
  projects: string[]; // Project IDs
  settings: WorkspaceSettings;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface TeamMember {
  userId: string;
  username: string;
  displayName: string;
  profileImageURL?: string;
  role: MemberRole;
  permissions: Permission[];
  joinedAt: Timestamp;
  lastActiveAt?: Timestamp;
}

export type MemberRole = 'owner' | 'admin' | 'editor' | 'viewer';

export type Permission =
  | 'create_projects'
  | 'edit_projects'
  | 'delete_projects'
  | 'invite_members'
  | 'remove_members'
  | 'change_settings'
  | 'export_projects'
  | 'view_analytics';

export interface WorkspaceSettings {
  isPublic: boolean;
  allowGuestViewing: boolean;
  requireApprovalForJoin: boolean;
  defaultMemberRole: MemberRole;
  maxMembers: number;
  allowedDomains?: string[];
}

export interface WorkspaceInvite {
  id: string;
  workspaceId: string;
  workspaceName: string;
  invitedBy: string;
  invitedByName: string;
  invitedEmail: string;
  role: MemberRole;
  status: 'pending' | 'accepted' | 'declined' | 'expired';
  expiresAt: Timestamp;
  createdAt: Timestamp;
}

// Create workspace
export async function createWorkspace(
  name: string,
  description: string,
  ownerId: string,
  ownerData: { username: string; displayName: string; profileImageURL?: string }
): Promise<TeamWorkspace> {
  try {
    const workspaceId = `workspace_${Date.now()}`;
    const workspaceRef = doc(db, 'team-workspaces', workspaceId);

    const workspace: TeamWorkspace = {
      id: workspaceId,
      name,
      description,
      ownerId,
      members: [
        {
          userId: ownerId,
          username: ownerData.username,
          displayName: ownerData.displayName,
          profileImageURL: ownerData.profileImageURL,
          role: 'owner',
          permissions: getAllPermissions(),
          joinedAt: serverTimestamp() as Timestamp,
        },
      ],
      projects: [],
      settings: {
        isPublic: false,
        allowGuestViewing: false,
        requireApprovalForJoin: true,
        defaultMemberRole: 'editor',
        maxMembers: 50,
      },
      createdAt: serverTimestamp() as Timestamp,
      updatedAt: serverTimestamp() as Timestamp,
    };

    await setDoc(workspaceRef, workspace);

    console.log('✅ Created workspace:', workspaceId);
    return workspace;
  } catch (error) {
    console.error('🚨 Failed to create workspace:', error);
    throw error;
  }
}

// Get workspace
export async function getWorkspace(workspaceId: string): Promise<TeamWorkspace | null> {
  try {
    const workspaceRef = doc(db, 'team-workspaces', workspaceId);
    const snapshot = await getDoc(workspaceRef);

    if (!snapshot.exists()) return null;

    return snapshot.data() as TeamWorkspace;
  } catch (error) {
    console.error('🚨 Failed to get workspace:', error);
    return null;
  }
}

// Get user's workspaces
export async function getUserWorkspaces(userId: string): Promise<TeamWorkspace[]> {
  try {
    const workspacesRef = collection(db, 'team-workspaces');
    const q = query(
      workspacesRef,
      where('members', 'array-contains', { userId })
    );

    const snapshot = await getDocs(q);
    return snapshot.docs.map((doc) => doc.data() as TeamWorkspace);
  } catch (error) {
    console.error('🚨 Failed to get user workspaces:', error);
    return [];
  }
}

// Invite member
export async function inviteMember(
  workspaceId: string,
  invitedEmail: string,
  role: MemberRole,
  invitedBy: string,
  invitedByName: string
): Promise<WorkspaceInvite> {
  try {
    const workspace = await getWorkspace(workspaceId);
    if (!workspace) throw new Error('Workspace not found');

    const inviteId = `invite_${Date.now()}`;
    const inviteRef = doc(db, 'workspace-invites', inviteId);

    const invite: WorkspaceInvite = {
      id: inviteId,
      workspaceId,
      workspaceName: workspace.name,
      invitedBy,
      invitedByName,
      invitedEmail,
      role,
      status: 'pending',
      expiresAt: Timestamp.fromDate(
        new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
      ), // 7 days
      createdAt: serverTimestamp() as Timestamp,
    };

    await setDoc(inviteRef, invite);

    // TODO: Send email notification

    console.log('✅ Invited member:', invitedEmail);
    return invite;
  } catch (error) {
    console.error('🚨 Failed to invite member:', error);
    throw error;
  }
}

// Accept invite
export async function acceptInvite(
  inviteId: string,
  userId: string,
  userData: { username: string; displayName: string; profileImageURL?: string }
): Promise<void> {
  try {
    const inviteRef = doc(db, 'workspace-invites', inviteId);
    const inviteSnap = await getDoc(inviteRef);

    if (!inviteSnap.exists()) throw new Error('Invite not found');

    const invite = inviteSnap.data() as WorkspaceInvite;

    // Check if expired
    if (invite.expiresAt.toDate() < new Date()) {
      throw new Error('Invite expired');
    }

    // Add member to workspace
    const workspaceRef = doc(db, 'team-workspaces', invite.workspaceId);

    const newMember: TeamMember = {
      userId,
      username: userData.username,
      displayName: userData.displayName,
      profileImageURL: userData.profileImageURL,
      role: invite.role,
      permissions: getPermissionsForRole(invite.role),
      joinedAt: serverTimestamp() as Timestamp,
    };

    await updateDoc(workspaceRef, {
      members: arrayUnion(newMember),
      updatedAt: serverTimestamp(),
    });

    // Update invite status
    await updateDoc(inviteRef, {
      status: 'accepted',
    });

    console.log('✅ Accepted invite:', inviteId);
  } catch (error) {
    console.error('🚨 Failed to accept invite:', error);
    throw error;
  }
}

// Remove member
export async function removeMember(
  workspaceId: string,
  userId: string,
  removedBy: string
): Promise<void> {
  try {
    const workspace = await getWorkspace(workspaceId);
    if (!workspace) throw new Error('Workspace not found');

    // Check permissions
    const remover = workspace.members.find((m) => m.userId === removedBy);
    if (!remover || !remover.permissions.includes('remove_members')) {
      throw new Error('Permission denied');
    }

    // Can't remove owner
    if (userId === workspace.ownerId) {
      throw new Error('Cannot remove workspace owner');
    }

    // Remove member
    const memberToRemove = workspace.members.find((m) => m.userId === userId);
    if (!memberToRemove) throw new Error('Member not found');

    const workspaceRef = doc(db, 'team-workspaces', workspaceId);

    await updateDoc(workspaceRef, {
      members: arrayRemove(memberToRemove),
      updatedAt: serverTimestamp(),
    });

    console.log('✅ Removed member:', userId);
  } catch (error) {
    console.error('🚨 Failed to remove member:', error);
    throw error;
  }
}

// Update member role
export async function updateMemberRole(
  workspaceId: string,
  userId: string,
  newRole: MemberRole,
  updatedBy: string
): Promise<void> {
  try {
    const workspace = await getWorkspace(workspaceId);
    if (!workspace) throw new Error('Workspace not found');

    // Check permissions
    const updater = workspace.members.find((m) => m.userId === updatedBy);
    if (!updater || updater.role !== 'owner') {
      throw new Error('Only owner can change roles');
    }

    // Can't change owner role
    if (userId === workspace.ownerId) {
      throw new Error('Cannot change owner role');
    }

    // Update member
    const updatedMembers = workspace.members.map((member) =>
      member.userId === userId
        ? { ...member, role: newRole, permissions: getPermissionsForRole(newRole) }
        : member
    );

    const workspaceRef = doc(db, 'team-workspaces', workspaceId);

    await updateDoc(workspaceRef, {
      members: updatedMembers,
      updatedAt: serverTimestamp(),
    });

    console.log('✅ Updated member role:', userId, newRole);
  } catch (error) {
    console.error('🚨 Failed to update member role:', error);
    throw error;
  }
}

// Add project to workspace
export async function addProjectToWorkspace(
  workspaceId: string,
  projectId: string
): Promise<void> {
  try {
    const workspaceRef = doc(db, 'team-workspaces', workspaceId);

    await updateDoc(workspaceRef, {
      projects: arrayUnion(projectId),
      updatedAt: serverTimestamp(),
    });

    console.log('✅ Added project to workspace:', projectId);
  } catch (error) {
    console.error('🚨 Failed to add project to workspace:', error);
    throw error;
  }
}

// Remove project from workspace
export async function removeProjectFromWorkspace(
  workspaceId: string,
  projectId: string
): Promise<void> {
  try {
    const workspaceRef = doc(db, 'team-workspaces', workspaceId);

    await updateDoc(workspaceRef, {
      projects: arrayRemove(projectId),
      updatedAt: serverTimestamp(),
    });

    console.log('✅ Removed project from workspace:', projectId);
  } catch (error) {
    console.error('🚨 Failed to remove project from workspace:', error);
    throw error;
  }
}

// Update workspace settings
export async function updateWorkspaceSettings(
  workspaceId: string,
  settings: Partial<WorkspaceSettings>,
  updatedBy: string
): Promise<void> {
  try {
    const workspace = await getWorkspace(workspaceId);
    if (!workspace) throw new Error('Workspace not found');

    // Check permissions
    const updater = workspace.members.find((m) => m.userId === updatedBy);
    if (!updater || !updater.permissions.includes('change_settings')) {
      throw new Error('Permission denied');
    }

    const workspaceRef = doc(db, 'team-workspaces', workspaceId);

    await updateDoc(workspaceRef, {
      settings: { ...workspace.settings, ...settings },
      updatedAt: serverTimestamp(),
    });

    console.log('✅ Updated workspace settings:', workspaceId);
  } catch (error) {
    console.error('🚨 Failed to update workspace settings:', error);
    throw error;
  }
}

// Delete workspace
export async function deleteWorkspace(
  workspaceId: string,
  deletedBy: string
): Promise<void> {
  try {
    const workspace = await getWorkspace(workspaceId);
    if (!workspace) throw new Error('Workspace not found');

    // Only owner can delete
    if (deletedBy !== workspace.ownerId) {
      throw new Error('Only owner can delete workspace');
    }

    const workspaceRef = doc(db, 'team-workspaces', workspaceId);
    await deleteDoc(workspaceRef);

    console.log('✅ Deleted workspace:', workspaceId);
  } catch (error) {
    console.error('🚨 Failed to delete workspace:', error);
    throw error;
  }
}

// Helper: Get all permissions
function getAllPermissions(): Permission[] {
  return [
    'create_projects',
    'edit_projects',
    'delete_projects',
    'invite_members',
    'remove_members',
    'change_settings',
    'export_projects',
    'view_analytics',
  ];
}

// Helper: Get permissions for role
function getPermissionsForRole(role: MemberRole): Permission[] {
  switch (role) {
    case 'owner':
      return getAllPermissions();
    case 'admin':
      return [
        'create_projects',
        'edit_projects',
        'delete_projects',
        'invite_members',
        'remove_members',
        'export_projects',
        'view_analytics',
      ];
    case 'editor':
      return ['create_projects', 'edit_projects', 'export_projects'];
    case 'viewer':
      return [];
  }
}

// Check if user has permission
export function hasPermission(
  workspace: TeamWorkspace,
  userId: string,
  permission: Permission
): boolean {
  const member = workspace.members.find((m) => m.userId === userId);
  if (!member) return false;

  return member.permissions.includes(permission);
}

// Get workspace analytics
export async function getWorkspaceAnalytics(
  workspaceId: string
): Promise<WorkspaceAnalytics> {
  try {
    const workspace = await getWorkspace(workspaceId);
    if (!workspace) throw new Error('Workspace not found');

    // Get all projects
    const projectsRef = collection(db, 'thumbnail-projects');
    const q = query(projectsRef, where('workspaceId', '==', workspaceId));
    const snapshot = await getDocs(q);

    const projects = snapshot.docs.map((doc) => doc.data());

    return {
      totalProjects: projects.length,
      totalMembers: workspace.members.length,
      activeMembers: workspace.members.filter(
        (m) =>
          m.lastActiveAt &&
          m.lastActiveAt.toDate() > new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
      ).length,
      projectsThisWeek: projects.filter(
        (p: any) =>
          p.createdAt &&
          p.createdAt.toDate() > new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
      ).length,
      projectsThisMonth: projects.filter(
        (p: any) =>
          p.createdAt &&
          p.createdAt.toDate() > new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
      ).length,
    };
  } catch (error) {
    console.error('🚨 Failed to get workspace analytics:', error);
    throw error;
  }
}

export interface WorkspaceAnalytics {
  totalProjects: number;
  totalMembers: number;
  activeMembers: number;
  projectsThisWeek: number;
  projectsThisMonth: number;
}






