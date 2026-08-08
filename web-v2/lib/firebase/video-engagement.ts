import {
  addDoc, collection, doc, serverTimestamp, type WriteBatch,
} from 'firebase/firestore';
import { auth, db } from './config';
import {safeServiceBaseUrl} from '@/lib/video-detail-security';

export type VideoEngagementType =
  | 'view'
  | 'like'
  | 'unlike'
  | 'dislike'
  | 'undislike'
  | 'comment'
  | 'comment_like'
  | 'comment_unlike'
  | 'comment_heart'
  | 'comment_unheart'
  | 'share'
  | 'watch_time';

interface VideoEngagementOptions {
  sessionId?: string;
  watchTime?: number;
  completionRate?: number;
}

function buildEngagementData(
  type: VideoEngagementType,
  options: VideoEngagementOptions,
) {
  const user = auth.currentUser;
  if (!user) throw new Error('Authentication required to record engagement');

  const sessionId = options.sessionId ?? crypto.randomUUID();
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(sessionId)) throw new Error('Invalid session ID');

  return {
    userId: user.uid,
    type,
    sessionId,
    createdAt: serverTimestamp(),
    ...(options.watchTime !== undefined && {
      watchTime: Math.max(1, Math.min(86400, Math.round(options.watchTime))),
    }),
    ...(options.completionRate !== undefined && {
      completionRate: Math.max(0, Math.min(1, options.completionRate)),
    }),
  };
}

export function appendVideoEngagement(
  batch: WriteBatch,
  videoId: string,
  type: VideoEngagementType,
  options: VideoEngagementOptions = {},
): void {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(videoId)) throw new Error('Invalid video ID');
  const eventRef = doc(collection(db, 'videos', videoId, 'events'));
  batch.set(eventRef, buildEngagementData(type, options));
}

export async function recordVideoEngagement(
  videoId: string,
  type: VideoEngagementType,
  options: VideoEngagementOptions = {},
): Promise<void> {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(videoId)) throw new Error('Invalid video ID');
  await addDoc(
    collection(db, 'videos', videoId, 'events'),
    buildEngagementData(type, options),
  );
}

export async function recordSessionWatchTime(
  videoId: string,
  sessionId: string,
  watchTime: number,
  completionRate: number | undefined,
  authorizationHeaders: Record<string, string>,
  qualifiedView = false,
): Promise<void> {
  const response = flushWatchTimeKeepalive(
    videoId,
    sessionId,
    watchTime,
    completionRate,
    authorizationHeaders,
    false,
    qualifiedView,
  );
  if (!response) throw new Error('Playback engagement unavailable');
  const result = await response;
  if (!result.ok) throw new Error('Playback engagement rejected');
}

export function flushWatchTimeKeepalive(
  videoId: string,
  sessionId: string,
  watchTime: number,
  completionRate: number | undefined,
  authorizationHeaders: Record<string, string>,
  keepalive = true,
  qualifiedView = false,
): Promise<Response> | null {
  const baseURL = safeServiceBaseUrl(process.env.NEXT_PUBLIC_CONTENT_API_URL);
  if (!baseURL || !/^[A-Za-z0-9_-]{1,128}$/.test(videoId) ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(sessionId)) return null;
  const normalizedWatchTime = Math.max(1, Math.min(86_400, Math.round(watchTime)));
  const normalizedCompletion = completionRate === undefined
    ? undefined
    : Math.max(0, Math.min(1, completionRate));
  return fetch(
    `${baseURL}/v1/videos/${encodeURIComponent(videoId)}/engagement/watch-time`,
    {
      method: 'POST',
      keepalive,
      headers: {...authorizationHeaders, 'Content-Type': 'application/json'},
      body: JSON.stringify({
        sessionId,
        watchTime: normalizedWatchTime,
        ...(qualifiedView && {qualifiedView: true}),
        ...(normalizedCompletion !== undefined && {completionRate: normalizedCompletion}),
      }),
    },
  );
}
