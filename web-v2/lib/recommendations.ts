import {auth, getAppCheckHeaders} from '@/lib/firebase/config';
import {
  isRecommendationEligible,
  safeImageUrl,
  safeServiceBaseUrl,
  type PolicyVideo,
  type RecommendationViewerPolicy,
} from '@/lib/video-detail-security';
import type {Video} from '@/types';

type RecommendationPayload = {
  id?: unknown;
  title?: unknown;
  description?: unknown;
  thumbnailUrl?: unknown;
  duration?: unknown;
  viewCount?: unknown;
  likeCount?: unknown;
  commentCount?: unknown;
  publishedAt?: unknown;
  createdAt?: unknown;
  isPublic?: unknown;
  visibility?: unknown;
  moderationStatus?: unknown;
  processingStatus?: unknown;
  ageRestricted?: unknown;
  blockedRegions?: unknown;
  allowedRegions?: unknown;
  creator?: {
    id?: unknown;
    username?: unknown;
    displayName?: unknown;
    avatarUrl?: unknown;
    verified?: unknown;
    subscriberCount?: unknown;
  };
};

function text(value: unknown, fallback = ''): string {
  return typeof value === 'string' ? value : fallback;
}

function count(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : 0;
}

function date(value: unknown): Date {
  const parsed = new Date(text(value));
  return Number.isNaN(parsed.getTime()) ? new Date(0) : parsed;
}

function mapRecommendation(item: RecommendationPayload): PolicyVideo | null {
  const id = text(item.id);
  const creatorId = text(item.creator?.id);
  const title = text(item.title);
  const thumbnailURL = safeImageUrl(item.thumbnailUrl, '');
  if (!id || !creatorId || !title || !thumbnailURL) return null;

  const visibility = text(item.visibility).toLowerCase();
  const processingStatus = text(item.processingStatus).toLowerCase();
  const video: PolicyVideo = {
    id,
    title,
    description: text(item.description),
    videoURL: '',
    thumbnailURL,
    duration: count(item.duration),
    viewCount: count(item.viewCount),
    likeCount: count(item.likeCount),
    dislikeCount: 0,
    commentCount: count(item.commentCount),
    shareCount: 0,
    createdAt: date(item.publishedAt ?? item.createdAt),
    updatedAt: date(item.createdAt),
    creatorId,
    creator: {
      id: creatorId,
      username: text(item.creator?.username, 'creator'),
      displayName: text(item.creator?.displayName, 'Creator'),
      email: '',
      profileImageURL: safeImageUrl(item.creator?.avatarUrl),
      bannerImageURL: '',
      subscriberCount: count(item.creator?.subscriberCount),
      videoCount: 0,
      createdAt: new Date(0),
      isVerified: item.creator?.verified === true,
      isAdmin: false,
    },
    category: {id: '', name: '', slug: ''},
    tags: [],
    isPublic: item.isPublic === true,
    visibility: visibility === 'public' ? 'public' : undefined,
    processingStatus: processingStatus === 'ready' ? 'ready' : undefined,
    moderationStatus: text(item.moderationStatus),
    blockedRegions: item.blockedRegions,
    allowedRegions: item.allowedRegions,
    ageRestricted: item.ageRestricted === true,
    madeForKids: false,
    commentsEnabled: true,
    likesEnabled: true,
    downloadsEnabled: false,
  };
  return video;
}

export async function fetchSimilarRecommendations(
  videoId: string,
  limit = 24,
  viewerPolicy: RecommendationViewerPolicy = {isAdult: false, region: null},
): Promise<Video[]> {
  const baseURL = safeServiceBaseUrl(process.env.NEXT_PUBLIC_RECOMMENDATIONS_API_URL);
  if (!baseURL || !/^[A-Za-z0-9_-]{1,128}$/.test(videoId)) return [];

  const headers: Record<string, string> = await getAppCheckHeaders();
  const user = auth.currentUser;
  if (user) headers.Authorization = `Bearer ${await user.getIdToken()}`;

  const response = await fetch(
    `${baseURL}/v1/recommendations/similar/${encodeURIComponent(videoId)}?limit=${Math.min(24, Math.max(1, limit))}`,
    {headers, signal: AbortSignal.timeout(8_000)},
  );
  if (!response.ok) throw new Error('Recommendation service unavailable.');

  const payload = await response.json() as {videos?: RecommendationPayload[]};
  return (Array.isArray(payload.videos) ? payload.videos : [])
    .map(mapRecommendation)
    .filter((video): video is PolicyVideo => video !== null && video.id !== videoId)
    .filter((video) => isRecommendationEligible(video, viewerPolicy));
}
