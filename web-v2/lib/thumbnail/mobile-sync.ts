// 🔥 MOBILE APP SYNC - CROSS-PLATFORM SYNC (WEB SIDE) 💣

import {
  doc,
  setDoc,
  getDoc,
  onSnapshot,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';
import { db } from '@/lib/firebase/config';

// Types
export interface MobileSyncState {
  projectId: string;
  userId: string;
  deviceId: string;
  deviceType: 'ios' | 'android' | 'web';
  deviceName: string;
  state: ThumbnailState;
  version: number;
  isConflict: boolean;
  lastSyncedAt: Timestamp;
}

export interface ThumbnailState {
  backgroundImage?: string;
  textLayers: TextLayer[];
  imageLayers: ImageLayer[];
  filter: FilterState;
}

export interface TextLayer {
  id: string;
  text: string;
  x: number;
  y: number;
  fontSize: number;
  fontWeight: string;
  fontStyle: string;
  fontFamily: string;
  color: string;
  strokeColor: string;
  strokeWidth: number;
  align: string;
  rotation: number;
  opacity: number;
}

export interface ImageLayer {
  id: string;
  src: string;
  x: number;
  y: number;
  width: number;
  height: number;
  rotation: number;
  opacity: number;
}

export interface FilterState {
  brightness: number;
  contrast: number;
  saturation: number;
  blur: number;
}

export interface SyncConflict {
  projectId: string;
  webVersion: ThumbnailState;
  mobileVersion: ThumbnailState;
  conflictedAt: Date;
}

// Sync to mobile
export async function syncToMobile(
  projectId: string,
  userId: string,
  state: ThumbnailState
): Promise<void> {
  try {
    const syncRef = doc(db, 'mobile-sync', projectId);

    const syncData: Partial<MobileSyncState> = {
      projectId,
      userId,
      deviceId: getDeviceId(),
      deviceType: 'web',
      deviceName: getBrowserName(),
      state,
      version: Date.now(),
      isConflict: false,
      lastSyncedAt: serverTimestamp() as Timestamp,
    };

    await setDoc(syncRef, syncData, { merge: true });

    console.log('✅ [Web] Synced to mobile:', projectId);
  } catch (error) {
    console.error('🚨 [Web] Sync to mobile failed:', error);
    throw error;
  }
}

// Listen for mobile updates
export function listenForMobileUpdates(
  projectId: string,
  onUpdate: (state: ThumbnailState) => void,
  onConflict: (conflict: SyncConflict) => void
): () => void {
  const syncRef = doc(db, 'mobile-sync', projectId);

  const unsubscribe = onSnapshot(syncRef, (snapshot) => {
    if (!snapshot.exists()) return;

    const data = snapshot.data() as MobileSyncState;

    // Ignore our own updates
    if (data.deviceId === getDeviceId()) {
      return;
    }

    // Check for conflicts
    if (data.isConflict) {
      onConflict({
        projectId: data.projectId,
        webVersion: data.state,
        mobileVersion: data.state,
        conflictedAt: new Date(),
      });
    } else {
      onUpdate(data.state);
    }
  });

  return unsubscribe;
}

// Get sync status
export async function getSyncStatus(
  projectId: string
): Promise<MobileSyncState | null> {
  try {
    const syncRef = doc(db, 'mobile-sync', projectId);
    const snapshot = await getDoc(syncRef);

    if (!snapshot.exists()) return null;

    return snapshot.data() as MobileSyncState;
  } catch (error) {
    console.error('🚨 [Web] Failed to get sync status:', error);
    return null;
  }
}

// Resolve conflict
export async function resolveConflict(
  projectId: string,
  winningVersion: 'web' | 'mobile',
  state: ThumbnailState
): Promise<void> {
  try {
    const syncRef = doc(db, 'mobile-sync', projectId);

    await setDoc(
      syncRef,
      {
        state,
        version: Date.now(),
        isConflict: false,
        lastSyncedAt: serverTimestamp(),
        resolvedBy: winningVersion,
      },
      { merge: true }
    );

    console.log('✅ [Web] Conflict resolved:', winningVersion);
  } catch (error) {
    console.error('🚨 [Web] Failed to resolve conflict:', error);
    throw error;
  }
}

// Detect conflicts
export async function detectConflict(
  projectId: string,
  localState: ThumbnailState
): Promise<SyncConflict | null> {
  try {
    const syncStatus = await getSyncStatus(projectId);

    if (!syncStatus) return null;

    // Check if versions differ
    const localVersion = JSON.stringify(localState);
    const remoteVersion = JSON.stringify(syncStatus.state);

    if (localVersion !== remoteVersion) {
      return {
        projectId,
        webVersion: localState,
        mobileVersion: syncStatus.state,
        conflictedAt: new Date(),
      };
    }

    return null;
  } catch (error) {
    console.error('🚨 [Web] Failed to detect conflict:', error);
    return null;
  }
}

// Merge states (auto-resolve)
export function mergeStates(
  webState: ThumbnailState,
  mobileState: ThumbnailState
): ThumbnailState {
  // Merge text layers (keep both, dedupe by ID)
  const textLayersMap = new Map<string, TextLayer>();
  [...webState.textLayers, ...mobileState.textLayers].forEach((layer) => {
    textLayersMap.set(layer.id, layer);
  });

  // Merge image layers (keep both, dedupe by ID)
  const imageLayersMap = new Map<string, ImageLayer>();
  [...webState.imageLayers, ...mobileState.imageLayers].forEach((layer) => {
    imageLayersMap.set(layer.id, layer);
  });

  // Use web background if available, else mobile
  const backgroundImage = webState.backgroundImage || mobileState.backgroundImage;

  // Average filter values
  const filter: FilterState = {
    brightness: (webState.filter.brightness + mobileState.filter.brightness) / 2,
    contrast: (webState.filter.contrast + mobileState.filter.contrast) / 2,
    saturation: (webState.filter.saturation + mobileState.filter.saturation) / 2,
    blur: (webState.filter.blur + mobileState.filter.blur) / 2,
  };

  return {
    backgroundImage,
    textLayers: Array.from(textLayersMap.values()),
    imageLayers: Array.from(imageLayersMap.values()),
    filter,
  };
}

// Get device ID
function getDeviceId(): string {
  let deviceId = localStorage.getItem('deviceId');

  if (!deviceId) {
    deviceId = `web_${Math.random().toString(36).substr(2, 9)}`;
    localStorage.setItem('deviceId', deviceId);
  }

  return deviceId;
}

// Get browser name
function getBrowserName(): string {
  const userAgent = navigator.userAgent;

  if (userAgent.includes('Chrome')) return 'Chrome';
  if (userAgent.includes('Firefox')) return 'Firefox';
  if (userAgent.includes('Safari')) return 'Safari';
  if (userAgent.includes('Edge')) return 'Edge';

  return 'Unknown';
}

// Sync indicator component state
export interface SyncIndicatorState {
  status: 'idle' | 'syncing' | 'synced' | 'error' | 'conflict';
  lastSyncedAt?: Date;
  error?: string;
  conflict?: SyncConflict;
}

// Get sync indicator state
export function getSyncIndicatorState(
  projectId: string,
  onStateChange: (state: SyncIndicatorState) => void
): () => void {
  let currentState: SyncIndicatorState = { status: 'idle' };

  const unsubscribe = listenForMobileUpdates(
    projectId,
    (state) => {
      currentState = {
        status: 'synced',
        lastSyncedAt: new Date(),
      };
      onStateChange(currentState);
    },
    (conflict) => {
      currentState = {
        status: 'conflict',
        conflict,
      };
      onStateChange(currentState);
    }
  );

  return unsubscribe;
}

// Auto-sync on change (debounced)
let syncTimeout: NodeJS.Timeout | null = null;

export function autoSyncOnChange(
  projectId: string,
  userId: string,
  state: ThumbnailState,
  debounceMs: number = 2000
): void {
  if (syncTimeout) {
    clearTimeout(syncTimeout);
  }

  syncTimeout = setTimeout(() => {
    syncToMobile(projectId, userId, state).catch((error) => {
      console.error('🚨 [Web] Auto-sync failed:', error);
    });
  }, debounceMs);
}

// Clear auto-sync
export function clearAutoSync(): void {
  if (syncTimeout) {
    clearTimeout(syncTimeout);
    syncTimeout = null;
  }
}
