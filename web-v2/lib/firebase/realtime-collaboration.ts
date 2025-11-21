// 🔥 FIREBASE REALTIME DATABASE - REAL-TIME COLLABORATION 💣

import {
  ref,
  set,
  onValue,
  onChildAdded,
  onChildChanged,
  onChildRemoved,
  push,
  remove,
  serverTimestamp,
  DataSnapshot,
} from 'firebase/database';
import { realtimeDb } from './config';

// Types
export interface CollaborationSession {
  id: string;
  projectId: string;
  ownerId: string;
  participants: CollaborationParticipant[];
  createdAt: number;
  isActive: boolean;
}

export interface CollaborationParticipant {
  userId: string;
  username: string;
  avatarUrl?: string;
  color: string; // Cursor color
  isOnline: boolean;
  lastSeen: number;
  cursor?: {
    x: number;
    y: number;
  };
}

export interface CollaborationAction {
  id: string;
  sessionId: string;
  userId: string;
  username: string;
  type: 'text-add' | 'text-edit' | 'text-delete' | 'layer-move' | 'filter-change' | 'background-change';
  timestamp: number;
  data: any;
}

// Create collaboration session
export async function createCollaborationSession(
  projectId: string,
  ownerId: string,
  ownerUsername: string
): Promise<string> {
  try {
    const sessionId = `session_${projectId}_${Date.now()}`;
    const sessionRef = ref(realtimeDb, `collaboration-sessions/${sessionId}`);

    const session: CollaborationSession = {
      id: sessionId,
      projectId,
      ownerId,
      participants: [
        {
          userId: ownerId,
          username: ownerUsername,
          color: '#FF0000',
          isOnline: true,
          lastSeen: Date.now(),
        },
      ],
      createdAt: Date.now(),
      isActive: true,
    };

    await set(sessionRef, session);

    console.log('✅ Collaboration session created:', sessionId);
    return sessionId;
  } catch (error) {
    console.error('🚨 Failed to create collaboration session:', error);
    throw error;
  }
}

// Join collaboration session
export async function joinCollaborationSession(
  sessionId: string,
  userId: string,
  username: string
): Promise<void> {
  try {
    const participantRef = ref(
      realtimeDb,
      `collaboration-sessions/${sessionId}/participants/${userId}`
    );

    const participant: CollaborationParticipant = {
      userId,
      username,
      color: getRandomColor(),
      isOnline: true,
      lastSeen: Date.now(),
    };

    await set(participantRef, participant);

    // Set up presence tracking
    setupPresenceTracking(sessionId, userId);

    console.log('✅ Joined collaboration session:', sessionId);
  } catch (error) {
    console.error('🚨 Failed to join collaboration session:', error);
    throw error;
  }
}

// Leave collaboration session
export async function leaveCollaborationSession(
  sessionId: string,
  userId: string
): Promise<void> {
  try {
    const participantRef = ref(
      realtimeDb,
      `collaboration-sessions/${sessionId}/participants/${userId}`
    );

    await remove(participantRef);

    console.log('✅ Left collaboration session:', sessionId);
  } catch (error) {
    console.error('🚨 Failed to leave collaboration session:', error);
    throw error;
  }
}

// Broadcast action to all participants
export async function broadcastAction(
  sessionId: string,
  userId: string,
  username: string,
  type: CollaborationAction['type'],
  data: any
): Promise<void> {
  try {
    const actionsRef = ref(realtimeDb, `collaboration-actions/${sessionId}`);
    const newActionRef = push(actionsRef);

    const action: CollaborationAction = {
      id: newActionRef.key!,
      sessionId,
      userId,
      username,
      type,
      timestamp: Date.now(),
      data,
    };

    await set(newActionRef, action);

    console.log('✅ Action broadcasted:', type);
  } catch (error) {
    console.error('🚨 Failed to broadcast action:', error);
    throw error;
  }
}

// Listen to collaboration actions
export function listenToCollaborationActions(
  sessionId: string,
  onAction: (action: CollaborationAction) => void
): () => void {
  const actionsRef = ref(realtimeDb, `collaboration-actions/${sessionId}`);

  const unsubscribe = onChildAdded(actionsRef, (snapshot: DataSnapshot) => {
    const action = snapshot.val() as CollaborationAction;
    onAction(action);
  });

  return unsubscribe;
}

// Update cursor position
export async function updateCursorPosition(
  sessionId: string,
  userId: string,
  x: number,
  y: number
): Promise<void> {
  try {
    const cursorRef = ref(
      realtimeDb,
      `collaboration-sessions/${sessionId}/participants/${userId}/cursor`
    );

    await set(cursorRef, { x, y });
  } catch (error) {
    // Don't throw - cursor updates are not critical
    console.error('🚨 Failed to update cursor:', error);
  }
}

// Listen to participant cursors
export function listenToParticipantCursors(
  sessionId: string,
  onCursorUpdate: (userId: string, cursor: { x: number; y: number }) => void
): () => void {
  const participantsRef = ref(realtimeDb, `collaboration-sessions/${sessionId}/participants`);

  const unsubscribe = onChildChanged(participantsRef, (snapshot: DataSnapshot) => {
    const participant = snapshot.val() as CollaborationParticipant;
    if (participant.cursor) {
      onCursorUpdate(participant.userId, participant.cursor);
    }
  });

  return unsubscribe;
}

// Setup presence tracking (online/offline)
function setupPresenceTracking(sessionId: string, userId: string): void {
  const participantRef = ref(
    realtimeDb,
    `collaboration-sessions/${sessionId}/participants/${userId}`
  );

  // Update last seen every 30 seconds
  const presenceInterval = setInterval(async () => {
    try {
      await set(ref(realtimeDb, `${participantRef.toString()}/lastSeen`), Date.now());
      await set(ref(realtimeDb, `${participantRef.toString()}/isOnline`), true);
    } catch (error) {
      console.error('🚨 Failed to update presence:', error);
    }
  }, 30000);

  // Cleanup on disconnect
  window.addEventListener('beforeunload', async () => {
    clearInterval(presenceInterval);
    await set(ref(realtimeDb, `${participantRef.toString()}/isOnline`), false);
  });
}

// Get random color for cursor
function getRandomColor(): string {
  const colors = [
    '#FF0000', // Red
    '#00FF00', // Green
    '#0000FF', // Blue
    '#FFFF00', // Yellow
    '#FF00FF', // Magenta
    '#00FFFF', // Cyan
    '#FF8800', // Orange
    '#8800FF', // Purple
  ];
  return colors[Math.floor(Math.random() * colors.length)];
}

// Get active participants
export function listenToActiveParticipants(
  sessionId: string,
  onParticipantsUpdate: (participants: CollaborationParticipant[]) => void
): () => void {
  const participantsRef = ref(realtimeDb, `collaboration-sessions/${sessionId}/participants`);

  const unsubscribe = onValue(participantsRef, (snapshot: DataSnapshot) => {
    const participantsData = snapshot.val();
    if (!participantsData) {
      onParticipantsUpdate([]);
      return;
    }

    const participants: CollaborationParticipant[] = Object.values(participantsData);
    
    // Filter out offline participants (not seen in last 2 minutes)
    const activeParticipants = participants.filter(
      (p) => p.isOnline && Date.now() - p.lastSeen < 120000
    );

    onParticipantsUpdate(activeParticipants);
  });

  return unsubscribe;
}

// Share session link
export function generateShareLink(sessionId: string): string {
  const baseUrl = typeof window !== 'undefined' ? window.location.origin : '';
  return `${baseUrl}/studio/thumbnail-creator?session=${sessionId}`;
}

// Lock/Unlock layer for editing
export async function lockLayer(
  sessionId: string,
  layerId: string,
  userId: string,
  username: string
): Promise<void> {
  try {
    const lockRef = ref(realtimeDb, `collaboration-locks/${sessionId}/${layerId}`);

    await set(lockRef, {
      userId,
      username,
      lockedAt: Date.now(),
    });

    console.log('✅ Layer locked:', layerId);
  } catch (error) {
    console.error('🚨 Failed to lock layer:', error);
    throw error;
  }
}

export async function unlockLayer(sessionId: string, layerId: string): Promise<void> {
  try {
    const lockRef = ref(realtimeDb, `collaboration-locks/${sessionId}/${layerId}`);
    await remove(lockRef);

    console.log('✅ Layer unlocked:', layerId);
  } catch (error) {
    console.error('🚨 Failed to unlock layer:', error);
    throw error;
  }
}

// Check if layer is locked
export function listenToLayerLocks(
  sessionId: string,
  onLockUpdate: (layerId: string, lock: { userId: string; username: string } | null) => void
): () => void {
  const locksRef = ref(realtimeDb, `collaboration-locks/${sessionId}`);

  const unsubscribeAdded = onChildAdded(locksRef, (snapshot: DataSnapshot) => {
    const layerId = snapshot.key!;
    const lock = snapshot.val();
    onLockUpdate(layerId, lock);
  });

  const unsubscribeRemoved = onChildRemoved(locksRef, (snapshot: DataSnapshot) => {
    const layerId = snapshot.key!;
    onLockUpdate(layerId, null);
  });

  return () => {
    unsubscribeAdded();
    unsubscribeRemoved();
  };
}






