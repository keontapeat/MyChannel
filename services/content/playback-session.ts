export const PLAYBACK_SESSION_VERSION = '1.0' as const;

export type PlaybackDenialReason =
  | 'authentication_required'
  | 'app_check_required'
  | 'invalid_video_id'
  | 'video_not_found'
  | 'invalid_visibility_policy'
  | 'visibility_denied'
  | 'invalid_processing_policy'
  | 'processing_not_ready'
  | 'invalid_moderation_policy'
  | 'moderation_not_approved'
  | 'invalid_age_policy'
  | 'age_verification_required'
  | 'invalid_region_policy'
  | 'region_denied'
  | 'invalid_entitlement_policy'
  | 'entitlement_required'
  | 'manifest_unavailable'
  | 'manifest_expired'
  | 'internal_error';

export type PlaybackPolicyState =
  | 'allowed'
  | 'owner_allowed'
  | 'ready'
  | 'approved'
  | 'not_required'
  | 'verified'
  | 'unrestricted'
  | 'granted'
  | 'denied'
  | 'invalid';

export interface PlaybackPolicyStatus {
  state: PlaybackPolicyState;
  value: string | boolean | null;
}

export interface PlaybackPolicyStatuses {
  visibility: PlaybackPolicyStatus;
  processing: PlaybackPolicyStatus;
  moderation: PlaybackPolicyStatus;
  age: PlaybackPolicyStatus;
  region: PlaybackPolicyStatus;
  entitlement: PlaybackPolicyStatus;
}

export interface PlaybackSessionResponseV1 {
  version: typeof PLAYBACK_SESSION_VERSION;
  sessionId: string;
  videoId: string;
  canPlay: boolean;
  denialReason: PlaybackDenialReason | null;
  playbackManifestUrl: string | null;
  expiresAt: string | null;
  policy: PlaybackPolicyStatuses;
  ads: { enabled: boolean; personalized: boolean };
  capabilities: {
    hls: boolean;
    dash: boolean;
    captions: boolean;
    offlineDownload: boolean;
    pictureInPicture: boolean;
    casting: boolean;
  };
}

type Data = Record<string, unknown>;

export interface PlaybackAuthorizationInput {
  sessionId: string;
  videoId: string;
  viewerId: string;
  video: Data;
  viewer: Data | null;
}

const INVALID_POLICY: PlaybackPolicyStatuses = {
  visibility: { state: 'invalid', value: null },
  processing: { state: 'invalid', value: null },
  moderation: { state: 'invalid', value: null },
  age: { state: 'invalid', value: null },
  region: { state: 'invalid', value: null },
  entitlement: { state: 'invalid', value: null }
};

function baseResponse(
  sessionId: string,
  videoId: string,
  denialReason: PlaybackDenialReason,
): PlaybackSessionResponseV1 {
  return {
    version: PLAYBACK_SESSION_VERSION,
    sessionId,
    videoId,
    canPlay: false,
    denialReason,
    playbackManifestUrl: null,
    expiresAt: null,
    policy: {
      visibility: { ...INVALID_POLICY.visibility },
      processing: { ...INVALID_POLICY.processing },
      moderation: { ...INVALID_POLICY.moderation },
      age: { ...INVALID_POLICY.age },
      region: { ...INVALID_POLICY.region },
      entitlement: { ...INVALID_POLICY.entitlement }
    },
    ads: { enabled: false, personalized: false },
    capabilities: {
      hls: false,
      dash: false,
      captions: false,
      offlineDownload: false,
      pictureInPicture: false,
      casting: false
    }
  };
}

export function createDeniedPlaybackSession(
  sessionId: string,
  videoId: string,
  denialReason: PlaybackDenialReason,
): PlaybackSessionResponseV1 {
  return baseResponse(sessionId, videoId, denialReason);
}

function normalizedString(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim().toLowerCase() : null;
}

function normalizeRegion(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const region = value.trim().replace(/_/g, '-').toUpperCase();
  return /^[A-Z]{2}(?:-[A-Z0-9]{1,3})?$/.test(region) ? region : null;
}

function regionList(value: unknown): string[] | null {
  if (!Array.isArray(value)) return null;
  const regions = value.map(normalizeRegion);
  return regions.every((region): region is string => region !== null)
    ? Array.from(new Set(regions))
    : null;
}

function regionMatches(regions: string[], viewerRegion: string): boolean {
  const country = viewerRegion.split('-', 1)[0];
  return regions.includes(viewerRegion) || regions.includes(country);
}

function isRecord(value: unknown): value is Data {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function ageRestriction(video: Data): boolean | null {
  const hasBoolean = typeof video.ageRestricted === 'boolean';
  const hasNumber = typeof video.ageRestriction === 'number' &&
    Number.isFinite(video.ageRestriction) && video.ageRestriction >= 0;
  if (!hasBoolean && !hasNumber) return null;

  const booleanRestriction = hasBoolean ? video.ageRestricted as boolean : null;
  const numericRestriction = hasNumber ? (video.ageRestriction as number) >= 18 : null;
  if (booleanRestriction !== null && numericRestriction !== null &&
      booleanRestriction !== numericRestriction) return null;
  return booleanRestriction ?? numericRestriction;
}

function viewerIsAgeVerified(viewer: Data | null): boolean {
  if (!viewer || (viewer.isAgeVerified !== true && viewer.ageVerified !== true)) return false;
  if (viewer.age === undefined) return true;
  return typeof viewer.age === 'number' && Number.isFinite(viewer.age) && viewer.age >= 18;
}

function isAllowedManifestOrigin(url: URL): boolean {
  const host = url.hostname.toLowerCase();
  if (host === 'storage.googleapis.com' || host.endsWith('.storage.googleapis.com') ||
      host === 'firebasestorage.googleapis.com') return true;

  const configuredCdn = process.env.CDN_BASE_URL;
  if (!configuredCdn) return false;
  try {
    const cdnUrl = new URL(configuredCdn);
    return cdnUrl.protocol === 'https:' && cdnUrl.hostname.toLowerCase() === host;
  } catch {
    return false;
  }
}

function validatedManifest(video: Data): URL | null {
  const candidates = [
    video.hlsURL,
    video.playbackManifestUrl,
    video.manifestUrl,
    video.dashURL,
    video.videoURL,
    video.videoUrl
  ];
  for (const candidate of candidates) {
    if (typeof candidate !== 'string' || !candidate.trim()) continue;
    try {
      const url = new URL(candidate.trim());
      const path = url.pathname.toLowerCase();
      if (url.protocol === 'https:' && !url.username && !url.password &&
          isAllowedManifestOrigin(url) &&
          (path.endsWith('.m3u8') || path.endsWith('.mpd'))) return url;
    } catch {}
  }
  return null;
}

function manifestExpiry(url: URL, explicitValue: unknown): string | null {
  if (typeof explicitValue === 'string') {
    const explicitDate = new Date(explicitValue);
    if (Number.isFinite(explicitDate.getTime())) return explicitDate.toISOString();
  }
  const expires = url.searchParams.get('Expires');
  if (expires && /^\d+$/.test(expires)) {
    const date = new Date(Number(expires) * 1000);
    if (Number.isFinite(date.getTime())) return date.toISOString();
  }
  const signedAt = url.searchParams.get('X-Goog-Date');
  const duration = url.searchParams.get('X-Goog-Expires');
  if (signedAt && /^\d{8}T\d{6}Z$/.test(signedAt) && duration && /^\d+$/.test(duration)) {
    const date = new Date(`${signedAt.slice(0, 4)}-${signedAt.slice(4, 6)}-${signedAt.slice(6, 8)}T${signedAt.slice(9, 11)}:${signedAt.slice(11, 13)}:${signedAt.slice(13, 15)}Z`);
    date.setUTCSeconds(date.getUTCSeconds() + Number(duration));
    if (Number.isFinite(date.getTime())) return date.toISOString();
  }
  return null;
}

function firstDenial(policy: PlaybackPolicyStatuses): PlaybackDenialReason | null {
  if (policy.visibility.state === 'invalid') return 'invalid_visibility_policy';
  if (policy.visibility.state === 'denied') return 'visibility_denied';
  if (policy.processing.state === 'invalid') return 'invalid_processing_policy';
  if (policy.processing.state === 'denied') return 'processing_not_ready';
  if (policy.moderation.state === 'invalid') return 'invalid_moderation_policy';
  if (policy.moderation.state === 'denied') return 'moderation_not_approved';
  if (policy.age.state === 'invalid') return 'invalid_age_policy';
  if (policy.age.state === 'denied') return 'age_verification_required';
  if (policy.region.state === 'invalid') return 'invalid_region_policy';
  if (policy.region.state === 'denied') return 'region_denied';
  if (policy.entitlement.state === 'invalid') return 'invalid_entitlement_policy';
  if (policy.entitlement.state === 'denied') return 'entitlement_required';
  return null;
}

export function authorizePlaybackSession(
  input: PlaybackAuthorizationInput,
): PlaybackSessionResponseV1 {
  const { sessionId, videoId, viewerId, video, viewer } = input;
  const response = baseResponse(sessionId, videoId, 'manifest_unavailable');
  const canonicalOwnerIds = [video.ownerId, video.creatorId, video.userId]
    .filter((value): value is string => typeof value === 'string' && !!value.trim())
    .map(value => value.trim());
  const uniqueOwnerIds = Array.from(new Set(canonicalOwnerIds));
  const fallbackChannelOwner = uniqueOwnerIds.length === 0 &&
    typeof video.channelId === 'string' && video.channelId.trim()
    ? video.channelId.trim()
    : null;
  const ownerId = uniqueOwnerIds.length === 1 ? uniqueOwnerIds[0] : fallbackChannelOwner;
  const isOwner = ownerId === viewerId;

  const visibility = normalizedString(video.visibility);
  const isPublicValid = video.isPublic === undefined || typeof video.isPublic === 'boolean';
  if (visibility && isPublicValid) {
    const contradictory = (visibility === 'public' && video.isPublic === false) ||
      (visibility === 'private' && video.isPublic === true);
    if (contradictory) {
      response.policy.visibility = { state: 'invalid', value: visibility };
    } else if (visibility === 'public') {
      response.policy.visibility = { state: 'allowed', value: visibility };
    } else if (visibility === 'private' && isOwner) {
      response.policy.visibility = { state: 'owner_allowed', value: visibility };
    } else {
      response.policy.visibility = { state: 'denied', value: visibility };
    }
  }

  const processing = normalizedString(video.processingStatus);
  if (processing) {
    response.policy.processing = {
      state: processing === 'ready' ? 'ready' : 'denied',
      value: processing
    };
  }

  const moderation = normalizedString(video.moderationStatus);
  if (moderation) {
    response.policy.moderation = {
      state: moderation === 'approved' ? 'approved' : 'denied',
      value: moderation
    };
  }

  const restricted = ageRestriction(video);
  if (restricted !== null) {
    response.policy.age = restricted
      ? { state: viewerIsAgeVerified(viewer) ? 'verified' : 'denied', value: true }
      : { state: 'not_required', value: false };
  }

  const allowedRegions = regionList(video.allowedRegions);
  const blockedRegions = regionList(video.blockedRegions);
  if (allowedRegions !== null && blockedRegions !== null) {
    if (allowedRegions.length === 0 && blockedRegions.length === 0) {
      response.policy.region = { state: 'unrestricted', value: null };
    } else {
      const viewerRegion = normalizeRegion(viewer?.region || viewer?.countryCode || viewer?.country);
      const allowed = !!viewerRegion &&
        !regionMatches(blockedRegions, viewerRegion) &&
        (allowedRegions.length === 0 || regionMatches(allowedRegions, viewerRegion));
      response.policy.region = {
        state: allowed ? 'allowed' : 'denied',
        value: viewerRegion
      };
    }
  }

  if (typeof video.isPremium === 'boolean') {
    if (!video.isPremium) {
      response.policy.entitlement = { state: 'not_required', value: false };
    } else if (isOwner) {
      response.policy.entitlement = { state: 'owner_allowed', value: true };
    } else {
      const channelId = typeof video.channelId === 'string' && video.channelId.trim()
        ? video.channelId.trim()
        : ownerId;
      const entitlementKey = channelId ? `channel:${channelId}` : null;
      if (!entitlementKey) {
        response.policy.entitlement = { state: 'invalid', value: true };
      } else if (viewer?.entitlements === undefined) {
        response.policy.entitlement = { state: 'denied', value: entitlementKey };
      } else if (!isRecord(viewer.entitlements)) {
        response.policy.entitlement = { state: 'invalid', value: entitlementKey };
      } else {
        response.policy.entitlement = {
          state: viewer.entitlements[entitlementKey] === true ? 'granted' : 'denied',
          value: entitlementKey
        };
      }
    }
  }

  const denialReason = firstDenial(response.policy);
  if (denialReason) {
    response.denialReason = denialReason;
    return response;
  }

  const manifest = validatedManifest(video);
  if (!manifest) return response;

  const isHls = manifest.pathname.toLowerCase().endsWith('.m3u8');
  const isDash = manifest.pathname.toLowerCase().endsWith('.mpd');
  const expiresAt = manifestExpiry(manifest, video.playbackExpiresAt);
  if (expiresAt && Date.parse(expiresAt) <= Date.now()) {
    response.denialReason = 'manifest_expired';
    return response;
  }

  response.canPlay = true;
  response.denialReason = null;
  response.playbackManifestUrl = manifest.toString();
  response.expiresAt = expiresAt;
  response.ads = {
    enabled: video.adsEnabled === true && normalizedString(video.monetizationStatus) === 'approved',
    personalized: false
  };
  response.capabilities = {
    hls: isHls,
    dash: isDash,
    captions: video.hasCaptions === true ||
      (Array.isArray(video.captions) && video.captions.length > 0),
    offlineDownload: video.offlineDownloadEnabled === true && video.downloadDisabled !== true,
    pictureInPicture: video.pictureInPictureEnabled === true,
    casting: video.castingEnabled === true
  };
  return response;
}
