import {auth, getAppCheckHeaders} from '@/lib/firebase/config';
import {db} from '@/lib/firebase/config';
import {doc, getDoc} from 'firebase/firestore';
import {safeMediaUrl, safeServiceBaseUrl} from '@/lib/video-detail-security';

export type PlaybackDenialReason =
  | 'authentication_required'
  | 'app_check_required'
  | 'invalid_video_id'
  | 'video_not_found'
  | 'visibility_denied'
  | 'invalid_visibility_policy'
  | 'processing_not_ready'
  | 'invalid_processing_policy'
  | 'moderation_not_approved'
  | 'invalid_moderation_policy'
  | 'age_verification_required'
  | 'invalid_age_policy'
  | 'region_denied'
  | 'invalid_region_policy'
  | 'entitlement_required'
  | 'invalid_entitlement_policy'
  | 'manifest_unavailable'
  | 'manifest_expired'
  | 'invalid_policy'
  | 'service_unavailable';

export interface PlaybackSession {
  sessionId: string;
  videoId: string;
  canPlay: boolean;
  denialReason: PlaybackDenialReason | string | null;
  playbackManifestUrl: string | null;
  expiresAt: string | null;
  ads: {enabled: boolean; personalized: boolean};
  capabilities: {
    hls: boolean;
    dash: boolean;
    captions: boolean;
    offlineDownload: boolean;
    pictureInPicture: boolean;
    casting: boolean;
  };
}

const DENIED: PlaybackSession = {
  sessionId: '',
  videoId: '',
  canPlay: false,
  denialReason: 'service_unavailable',
  playbackManifestUrl: null,
  expiresAt: null,
  ads: {enabled: false, personalized: false},
  capabilities: {
    hls: false, dash: false, captions: false,
    offlineDownload: false, pictureInPicture: false, casting: false,
  },
};

function denied(videoId: string, reason: PlaybackSession['denialReason']): PlaybackSession {
  return {...DENIED, videoId, denialReason: reason};
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export async function requestPlaybackSession(videoId: string): Promise<PlaybackSession> {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(videoId)) return denied(videoId, 'invalid_policy');
  const baseURL = safeServiceBaseUrl(process.env.NEXT_PUBLIC_CONTENT_API_URL);

  // If content API is not configured, fall back to direct Firestore video URL.
  // This enables playback before the content delivery service is deployed.
  if (!baseURL) {
    return fallbackPlaybackSession(videoId);
  }

  await auth.authStateReady();
  const user = auth.currentUser;
  if (!user) return denied(videoId, 'authentication_required');

  const headers: Record<string, string> = await getAppCheckHeaders();
  headers.Authorization = `Bearer ${await user.getIdToken()}`;
  headers['Content-Type'] = 'application/json';

  let response: Response;
  try {
    response = await fetch(
      `${baseURL}/v1/videos/${encodeURIComponent(videoId)}/playback-session`,
      {method: 'POST', headers, signal: AbortSignal.timeout(8_000)},
    );
  } catch {
    return denied(videoId, 'service_unavailable');
  }

  const body: unknown = await response.json().catch(() => null);
  if (!isObject(body) || body.version !== '1.0' || body.videoId !== videoId ||
      typeof body.sessionId !== 'string' || !isObject(body.policy) ||
      !isObject(body.ads) || !isObject(body.capabilities)) {
    return denied(videoId, 'invalid_policy');
  }

  const canPlay = body.canPlay === true;
  const manifest = canPlay ? safeMediaUrl(body.playbackManifestUrl) : null;
  const isHlsManifest = manifest !== null && (() => {
    try { return new URL(manifest).pathname.toLowerCase().endsWith('.m3u8'); }
    catch { return false; }
  })();
  const expiresAt = typeof body.expiresAt === 'string' ? body.expiresAt : null;
  if (canPlay && (!manifest || !isHlsManifest || body.capabilities.hls !== true ||
      (expiresAt !== null && (!Number.isFinite(Date.parse(expiresAt)) ||
        Date.parse(expiresAt) <= Date.now())))) {
    const reason = manifest && isHlsManifest ? 'manifest_expired' : 'manifest_unavailable';
    return denied(videoId, reason);
  }

  return {
    sessionId: body.sessionId,
    videoId,
    canPlay,
    denialReason: typeof body.denialReason === 'string' ? body.denialReason : null,
    playbackManifestUrl: manifest,
    expiresAt,
    ads: {
      enabled: body.ads.enabled === true,
      personalized: body.ads.personalized === true,
    },
    capabilities: {
      hls: body.capabilities.hls === true,
      dash: body.capabilities.dash === true,
      captions: body.capabilities.captions === true,
      offlineDownload: body.capabilities.offlineDownload === true,
      pictureInPicture: body.capabilities.pictureInPicture === true,
      casting: body.capabilities.casting === true,
    },
  };
}

/**
 * Fallback: reads the video's HLS/MP4 URL directly from Firestore when the
 * content delivery service (NEXT_PUBLIC_CONTENT_API_URL) is not deployed.
 * This allows video playback during early-stage development.
 */
async function fallbackPlaybackSession(videoId: string): Promise<PlaybackSession> {
  await auth.authStateReady();
  // Note: unlike the full content API, the fallback allows anonymous playback
  // for public videos. Auth is still preferred for tracking/personalization.

  try {
    const videoDoc = await getDoc(doc(db, 'videos', videoId));
    if (!videoDoc.exists()) return denied(videoId, 'video_not_found');

    const data = videoDoc.data();
    // Try multiple URL fields that might contain the playback URL
    const hlsUrl = data.hlsUrl || data.hlsURL || data.videoHlsUrl || null;
    const mp4Url = data.videoUrl || data.videoURL || data.mp4Url || data.downloadUrl || null;
    const storageUrl = data.storageUrl || data.firebaseStorageUrl || null;

    const playbackUrl = hlsUrl || mp4Url || storageUrl;

    if (!playbackUrl) {
      // Video exists but has no playback URL — still processing or upload incomplete
      const status = (data.processingStatus || '').toLowerCase();
      if (status && !['ready', 'completed', 'complete', 'published'].includes(status)) {
        return denied(videoId, 'processing_not_ready');
      }
      return denied(videoId, 'manifest_unavailable');
    }

    const isHls = typeof playbackUrl === 'string' && (
      playbackUrl.includes('.m3u8') || playbackUrl.includes('m3u8')
    );

    return {
      sessionId: `fallback_${videoId}_${Date.now()}`,
      videoId,
      canPlay: true,
      denialReason: null,
      playbackManifestUrl: playbackUrl,
      expiresAt: null, // No expiry for direct URLs
      ads: { enabled: false, personalized: false },
      capabilities: {
        hls: isHls,
        dash: false,
        captions: !!data.captionsUrl,
        offlineDownload: false,
        pictureInPicture: true,
        casting: true,
      },
    };
  } catch {
    return denied(videoId, 'service_unavailable');
  }
}

export function playbackDenialMessage(reason: string | null): string {
  switch (reason) {
    case 'authentication_required': return 'Sign in to watch this video';
    case 'app_check_required': return 'Device verification is required';
    case 'age_verification_required': return 'Age verification is required';
    case 'region_denied': return 'This video is not available in your region';
    case 'entitlement_required': return 'A channel membership is required';
    case 'processing_not_ready': return 'This video is still processing';
    case 'moderation_not_approved': return 'This video is under review';
    case 'visibility_denied': return 'This video is unavailable';
    case 'manifest_expired': return 'Playback authorization expired. Reload to retry.';
    default: return 'Video unavailable';
  }
}