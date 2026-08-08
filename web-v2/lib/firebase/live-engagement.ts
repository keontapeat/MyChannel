import {onAuthStateChanged} from 'firebase/auth';
import {
  collection, doc, onSnapshot, serverTimestamp, writeBatch,
} from 'firebase/firestore';
import {auth, db} from './config';

function validStreamId(streamId: string): boolean {
  return /^[A-Za-z0-9_-]{1,128}$/.test(streamId);
}

export function subscribeToLiveLike(
  streamId: string,
  onLiked: (liked: boolean) => void,
): () => void {
  if (!validStreamId(streamId)) return () => undefined;
  let unsubscribeMarker: (() => void) | null = null;
  const unsubscribeAuth = onAuthStateChanged(auth, user => {
    unsubscribeMarker?.();
    unsubscribeMarker = null;
    if (!user) {
      onLiked(false);
      return;
    }
    const marker = doc(db, 'users', user.uid, 'liveStreamLikes', streamId);
    unsubscribeMarker = onSnapshot(marker, snapshot => {
      onLiked(snapshot.get('liked') === true);
    }, () => onLiked(false));
  });
  return () => {
    unsubscribeMarker?.();
    unsubscribeAuth();
  };
}

async function recordLiveEngagement(
  streamId: string,
  type: 'like' | 'unlike' | 'share',
): Promise<void> {
  const user = auth.currentUser;
  if (!user) throw new Error('Sign in to interact with this stream');
  if (!validStreamId(streamId)) throw new Error('Invalid stream');

  const batch = writeBatch(db);
  const eventRef = doc(collection(db, 'live_streams', streamId, 'engagement_events'));
  batch.set(eventRef, {
    userId: user.uid,
    type,
    sessionId: crypto.randomUUID(),
    createdAt: serverTimestamp(),
  });

  if (type === 'like' || type === 'unlike') {
    const marker = doc(db, 'users', user.uid, 'liveStreamLikes', streamId);
    batch.set(marker, {liked: type === 'like', updatedAt: serverTimestamp()});
  }
  await batch.commit();
}

export function setLiveLike(streamId: string, liked: boolean): Promise<void> {
  return recordLiveEngagement(streamId, liked ? 'like' : 'unlike');
}

export function recordLiveShare(streamId: string): Promise<void> {
  return recordLiveEngagement(streamId, 'share');
}