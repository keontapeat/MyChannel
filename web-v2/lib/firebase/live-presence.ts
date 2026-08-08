import {onAuthStateChanged} from 'firebase/auth';
import {
  onDisconnect, onValue, ref, remove, serverTimestamp, set,
  type DatabaseReference,
} from 'firebase/database';
import {auth, rtdb} from './config';

function validStreamId(streamId: string): boolean {
  return /^[A-Za-z0-9_-]{1,128}$/.test(streamId);
}

export function subscribeToLiveViewerCount(
  streamId: string,
  onCount: (count: number) => void,
): () => void {
  if (!validStreamId(streamId)) return () => undefined;
  return onValue(ref(rtdb, `live_viewers/${streamId}/viewerCount`), snapshot => {
    const count = Number(snapshot.val());
    onCount(Number.isFinite(count) ? Math.max(0, Math.round(count)) : 0);
  }, () => onCount(0));
}

export function connectLiveViewerPresence(streamId: string): () => void {
  if (!validStreamId(streamId)) return () => undefined;

  let activeRef: DatabaseReference | null = null;
  let activeDisconnect: ReturnType<typeof onDisconnect> | null = null;
  let generation = 0;
  const clearPresence = () => {
    generation += 1;
    const staleRef = activeRef;
    const staleDisconnect = activeDisconnect;
    activeRef = null;
    activeDisconnect = null;
    if (staleDisconnect) void staleDisconnect.cancel().catch(() => undefined);
    if (staleRef) void remove(staleRef).catch(() => undefined);
  };
  const unsubscribeAuth = onAuthStateChanged(auth, user => {
    clearPresence();
    if (!user) return;

    const currentGeneration = generation;
    const connectionId = crypto.randomUUID();
    const presenceRef = ref(
      rtdb,
      `live_viewers/${streamId}/viewers/${user.uid}/${connectionId}`,
    );
    const disconnect = onDisconnect(presenceRef);
    activeRef = presenceRef;
    activeDisconnect = disconnect;

    void disconnect.remove()
      .then(() => {
        if (generation !== currentGeneration || activeRef !== presenceRef) return;
        return set(presenceRef, {
          joinedAt: serverTimestamp(),
          displayName: (user.displayName || 'Viewer').slice(0, 100),
        });
      })
      .catch(() => undefined);
  });

  return () => {
    unsubscribeAuth();
    void activeDisconnect?.cancel().catch(() => undefined);
    activeDisconnect = null;
    clearPresence();
  };
}