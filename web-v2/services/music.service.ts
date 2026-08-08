import {
  collection,
  getDocs,
  limit,
  orderBy,
  query,
  where,
  type DocumentData,
  type QueryDocumentSnapshot,
} from 'firebase/firestore';
import { auth, db, getAppCheckHeaders } from '@/lib/firebase/config';
import type { MusicTrack } from '@/types/music';

const PUBLISHED_TRACK_LIMIT = 30;
const QUALIFIED_PLAY_SECONDS = 30;

function optionalString(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : undefined;
}

function httpsUrl(value: unknown): string | undefined {
  const candidate = optionalString(value);
  if (!candidate || candidate.length > 2048) return undefined;

  try {
    const parsed = new URL(candidate);
    return parsed.protocol === 'https:' ? parsed.toString() : undefined;
  } catch {
    return undefined;
  }
}

function getMusicApiBaseUrl(): string {
  // This dedicated public value must point to the authenticated, idempotent
  // qualified-play service. Never fall back to an unrelated general API base.
  const safeBaseUrl = httpsUrl(process.env.NEXT_PUBLIC_MUSIC_API_BASE_URL);

  if (!safeBaseUrl) {
    throw new Error(
      'Qualified music play accounting is unavailable: configure a verified HTTPS NEXT_PUBLIC_MUSIC_API_BASE_URL',
    );
  }

  const parsed = new URL(safeBaseUrl);
  if (parsed.username || parsed.password || parsed.search || parsed.hash) {
    throw new Error('Qualified music play accounting is unavailable: unsafe music API base URL');
  }

  return safeBaseUrl.replace(/\/+$/, '');
}

function safeArtworkUrl(value: unknown): string | undefined {
  const candidate = httpsUrl(value);
  if (!candidate) return undefined;

  const parsed = new URL(candidate);
  const host = parsed.hostname.toLowerCase();
  const path = parsed.pathname.toLowerCase();
  if (host.includes('wikipedia.org') || host.includes('wikimedia.org') || path.endsWith('.svg')) {
    return undefined;
  }

  const approvedHosts = [
    'firebasestorage.googleapis.com', 'storage.googleapis.com', 'ytimg.com',
    'imgur.com', 'cloudinary.com', 'googleusercontent.com', 'akamaized.net',
    'cloudfront.net', 'pluto.tv', 'image.tmdb.org', 'm.media-amazon.com',
  ];
  const approvedHost = approvedHosts.some((allowed) => host === allowed || host.endsWith(`.${allowed}`));
  const directImage = /\.(?:jpe?g|png|webp|gif)$/.test(path);
  return approvedHost || directImage ? candidate : undefined;
}

function timestampMillis(value: unknown): number | undefined {
  if (!value || typeof value !== 'object') return undefined;
  const toMillis = (value as { toMillis?: unknown }).toMillis;
  if (typeof toMillis !== 'function') return undefined;

  try {
    const result = toMillis.call(value);
    return typeof result === 'number' && Number.isFinite(result) ? result : undefined;
  } catch {
    return undefined;
  }
}

function normalizeTrack(doc: QueryDocumentSnapshot<DocumentData>): MusicTrack | null {
  const data = doc.data();
  if (data.isPublished !== true || data.status !== 'published') return null;
  const renditions = data.renditions && typeof data.renditions === 'object'
    ? data.renditions as Record<string, unknown>
    : {};

  const audioUrl = [
    renditions.hls,
    data.hlsURL,
    data.streamURL,
    renditions.mp3,
    data.mp3URL,
  ].map(httpsUrl).find((value): value is string => Boolean(value));

  if (!audioUrl) return null;

  const duration = data.duration;
  const durationSeconds = typeof duration === 'number' &&
    Number.isFinite(duration) && duration > 0
    ? duration
    : undefined;

  return {
    id: doc.id,
    title: optionalString(data.title) ?? 'Untitled track',
    artistName: optionalString(data.artistName) ?? 'Unknown artist',
    artistId: optionalString(data.artistId),
    albumName: optionalString(data.albumName),
    genre: optionalString(data.genre),
    audioUrl,
    artworkUrl: safeArtworkUrl(data.artworkURL) ?? safeArtworkUrl(data.artworkUrl),
    isExplicit: data.isExplicit === true,
    durationSeconds,
    publishedAtMs: timestampMillis(data.uploadedAt),
  };
}

export async function getPublishedMusicTracks(): Promise<MusicTrack[]> {
  const publishedTracksQuery = query(
    collection(db, 'music_tracks'),
    where('isPublished', '==', true),
    where('status', '==', 'published'),
    orderBy('uploadedAt', 'desc'),
    limit(PUBLISHED_TRACK_LIMIT),
  );
  const snapshot = await getDocs(publishedTracksQuery);
  return snapshot.docs
    .map(normalizeTrack)
    .filter((track): track is MusicTrack => track !== null);
}

export async function submitQualifiedMusicPlay(
  trackId: string,
  sessionId: string,
): Promise<void> {
  const user = auth.currentUser;
  if (!user) return;
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(trackId)) {
    throw new Error('Invalid music track ID');
  }
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(sessionId)) {
    throw new Error('Invalid playback session ID');
  }

  const musicApiBaseUrl = getMusicApiBaseUrl();
  const [idToken, appCheckHeaders] = await Promise.all([
    user.getIdToken(),
    getAppCheckHeaders(),
  ]);
  const response = await fetch(
    `${musicApiBaseUrl}/v1/music/tracks/${encodeURIComponent(trackId)}/plays`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${idToken}`,
        'Idempotency-Key': sessionId,
        ...appCheckHeaders,
      },
      body: JSON.stringify({
        sessionId,
        qualifiedSeconds: QUALIFIED_PLAY_SECONDS,
      }),
    },
  );

  if (!response.ok) {
    throw new Error(`Qualified music play request failed (${response.status})`);
  }
}
