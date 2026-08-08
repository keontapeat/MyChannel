import type {Video} from '@/types';

const CONFIGURED_MEDIA_HOSTS = (process.env.NEXT_PUBLIC_MEDIA_CDN_HOSTS ?? '')
  .split(',')
  .map((host) => host.trim().toLowerCase())
  .filter((host) => /^[a-z0-9.-]+$/.test(host) && !host.startsWith('.') && !host.endsWith('.'));

const APPROVED_MEDIA_HOSTS = [
  'firebasestorage.googleapis.com',
  'storage.googleapis.com',
  'commondatastorage.googleapis.com',
  'devstreaming-cdn.apple.com',
  'ytimg.com',
  'imgur.com',
  'cloudinary.com',
  'googleusercontent.com',
  'akamaized.net',
  'cloudfront.net',
  'pluto.tv',
  'image.tmdb.org',
  'm.media-amazon.com',
  ...CONFIGURED_MEDIA_HOSTS,
] as const;

const APPROVED_EXTERNAL_HOSTS = [
  'mychannel.live',
  'youtube.com',
  'youtu.be',
  'instagram.com',
  'tiktok.com',
  'twitch.tv',
  'twitter.com',
  'x.com',
] as const;

function hostMatches(host: string, approved: readonly string[]): boolean {
  return approved.some((allowed) => host === allowed || host.endsWith(`.${allowed}`));
}

function currentOrigin(): string {
  return typeof window !== 'undefined' ? window.location.origin : 'https://mychannel.live';
}

function approvedHttpsUrl(value: unknown, approvedHosts: readonly string[]): string | null {
  if (typeof value !== 'string' || !value.trim()) return null;
  try {
    const parsed = new URL(value, currentOrigin());
    if (parsed.protocol !== 'https:') return null;
    if (parsed.origin !== currentOrigin() && !hostMatches(parsed.hostname.toLowerCase(), approvedHosts)) return null;
    return parsed.origin === currentOrigin() && value.startsWith('/')
      ? `${parsed.pathname}${parsed.search}${parsed.hash}`
      : parsed.toString();
  } catch {
    return null;
  }
}

export function safeMediaUrl(value: unknown): string | null {
  return approvedHttpsUrl(value, APPROVED_MEDIA_HOSTS);
}

export function safeImageUrl(value: unknown, fallback = '/logo.png'): string {
  return safeMediaUrl(value) ?? fallback;
}

export function safeExternalUrl(value: unknown): string | null {
  return approvedHttpsUrl(value, APPROVED_EXTERNAL_HOSTS);
}

export function safeJsonLd(value: unknown): string {
  return JSON.stringify(value)
    .replace(/</g, '\\u003c')
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029');
}

export function safeServiceBaseUrl(value: unknown): string | null {
  const url = approvedHttpsUrl(value, ['mychannel.live', 'run.app', 'cloudfunctions.net']);
  return url?.replace(/\/+$/, '') ?? null;
}

export interface RecommendationViewerPolicy {
  isAdult: boolean;
  region: string | null;
}

export type PolicyVideo = Video & {
  moderationStatus?: string;
  status?: string;
  privacyStatus?: string;
  blockedRegions?: unknown;
  allowedRegions?: unknown;
};

export function normalizeRegion(value: unknown): string | null {
  const region = typeof value === 'string' ? value.trim().toUpperCase() : '';
  return /^[A-Z]{2}(?:-[A-Z0-9]{1,3})?$/.test(region) ? region : null;
}

function regionList(value: unknown): string[] {
  return Array.isArray(value)
    ? value.map(normalizeRegion).filter((region): region is string => region !== null)
    : [];
}

function regionMatches(regions: string[], viewerRegion: string): boolean {
  return regions.includes(viewerRegion) || regions.includes(viewerRegion.split('-', 1)[0]);
}

export function isRecommendationEligible(
  candidate: PolicyVideo,
  viewer: RecommendationViewerPolicy,
): boolean {
  const visibility = String(candidate.visibility ?? candidate.privacyStatus ?? candidate.status ?? '').toLowerCase();
  if (candidate.isPublic !== true || (visibility && visibility !== 'public')) return false;

  const moderation = candidate.moderationStatus?.trim().toLowerCase();
  if (!moderation || !['approved', 'cleared', 'ready', 'published'].includes(moderation)) return false;

  const processing = candidate.processingStatus?.trim().toLowerCase();
  if (!processing || !['ready', 'complete', 'completed', 'published'].includes(processing)) return false;
  if (candidate.ageRestricted && !viewer.isAdult) return false;
  if (!safeImageUrl(candidate.thumbnailURL, '')) return false;

  const blocked = regionList(candidate.blockedRegions);
  if (blocked.length > 0 && (!viewer.region || regionMatches(blocked, viewer.region))) return false;
  const allowed = regionList(candidate.allowedRegions);
  if (allowed.length > 0 && (!viewer.region || !regionMatches(allowed, viewer.region))) return false;
  return true;
}
