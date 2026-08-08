import express, {type Request, type Response} from 'express';
import cors from 'cors';
import {createClient} from '@supabase/supabase-js';
import rateLimit from 'express-rate-limit';
import admin from 'firebase-admin';
import jwt, {type JwtPayload} from 'jsonwebtoken';

if (!admin.apps.length) admin.initializeApp();
if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_KEY) {
  throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_KEY');
}

const app = express();
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY,
);
const JWT_SECRET = process.env.JWT_SECRET || '';
const REQUIRE_APP_CHECK = process.env.REQUIRE_APP_CHECK !== 'false';

type AuthenticatedUser = {userId: string};
type CreatorRow = {
  id: string;
  username: string;
  display_name: string;
  avatar_url: string;
  verified: boolean;
  subscriber_count: number;
};
type VideoRow = {
  id: string;
  title: string;
  description: string;
  thumbnail_url: string;
  duration: number;
  view_count: number;
  like_count: number;
  comment_count: number;
  created_at: string;
  published_at: string | null;
  category?: string;
  tags?: string[];
  users: CreatorRow;
};

type ViewerPolicyContext = {
  userId: string | null;
  isAdult: boolean;
  region: string | null;
  hiddenVideoIds: Set<string>;
  hiddenCreatorIds: Set<string>;
  watchedVideoIds: Set<string>;
};

type OptionalAuthentication = {
  accepted: boolean;
  user: AuthenticatedUser | null;
};

const POLICY_READ_BATCH_SIZE = 100;
const MAX_USER_POLICY_SIGNALS = 500;
const PUBLICATION_STATES = new Set(['public', 'published', 'ready']);
const READY_PROCESSING_STATES = new Set(['ready', 'complete', 'completed', 'published']);
const PUBLISHABLE_MODERATION_STATES = new Set(['approved', 'cleared', 'ready', 'published']);

function normalizedString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function normalizeRegion(value: unknown): string | null {
  const region = normalizedString(value).toUpperCase();
  return /^[A-Z0-9-]{2,16}$/.test(region) ? region : null;
}

function normalizedRegionList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map(normalizeRegion)
    .filter((region): region is string => region !== null)
    .slice(0, 250);
}

function regionListContains(regions: string[], viewerRegion: string): boolean {
  const country = viewerRegion.split('-', 1)[0];
  return regions.includes(viewerRegion) || regions.includes(country);
}

async function loadViewerPolicy(user: AuthenticatedUser | null): Promise<ViewerPolicyContext> {
  const emptyContext: ViewerPolicyContext = {
    userId: null,
    isAdult: false,
    region: null,
    hiddenVideoIds: new Set(),
    hiddenCreatorIds: new Set(),
    watchedVideoIds: new Set(),
  };
  if (!user) return emptyContext;

  const userRef = admin.firestore().collection('users').doc(user.userId);
  const [profileSnapshot, feedbackSnapshot, historySnapshot] = await Promise.all([
    userRef.get(),
    userRef.collection('notInterested').limit(MAX_USER_POLICY_SIGNALS).get(),
    userRef.collection('watchHistory').limit(MAX_USER_POLICY_SIGNALS).get(),
  ]);
  const profile = profileSnapshot.data() ?? {};
  const explicitAge = Number(profile.age);
  const ageIsValid = !Number.isFinite(explicitAge) || explicitAge >= 18;
  const hiddenVideoIds = new Set<string>();
  const hiddenCreatorIds = new Set<string>();
  const watchedVideoIds = new Set<string>();

  for (const document of feedbackSnapshot.docs) {
    const signal = document.data();
    const videoId = normalizedString(signal.videoId);
    const creatorId = normalizedString(signal.channelId || signal.creatorId);
    if (videoId) hiddenVideoIds.add(videoId);
    if (creatorId) hiddenCreatorIds.add(creatorId);
  }
  for (const document of historySnapshot.docs) {
    const videoId = normalizedString(document.data().videoId) || document.id;
    if (videoId) watchedVideoIds.add(videoId);
  }

  return {
    userId: user.userId,
    isAdult: (profile.isAgeVerified === true || profile.ageVerified === true) && ageIsValid,
    region: normalizeRegion(profile.region || profile.countryCode || profile.country),
    hiddenVideoIds,
    hiddenCreatorIds,
    watchedVideoIds,
  };
}

async function loadVideoPolicies(
  videoIds: string[],
): Promise<Map<string, admin.firestore.DocumentData>> {
  const validIds = Array.from(new Set(videoIds.filter(
    videoId => /^[A-Za-z0-9_-]{1,128}$/.test(videoId),
  )));
  const policies = new Map<string, admin.firestore.DocumentData>();
  const database = admin.firestore();

  for (let index = 0; index < validIds.length; index += POLICY_READ_BATCH_SIZE) {
    const batchIds = validIds.slice(index, index + POLICY_READ_BATCH_SIZE);
    const references = batchIds.map(videoId => database.collection('videos').doc(videoId));
    const snapshots = await database.getAll(...references);
    for (const snapshot of snapshots) {
      if (snapshot.exists) policies.set(snapshot.id, snapshot.data() ?? {});
    }
  }
  return policies;
}

function isVideoPolicyEligible(
  videoId: string,
  servingCreatorId: string,
  policy: admin.firestore.DocumentData | undefined,
  viewer: ViewerPolicyContext,
  excludeWatched: boolean,
): boolean {
  // Firestore is canonical. A stale Supabase row without a canonical document
  // cannot be served because its visibility and safety state cannot be proven.
  if (!policy) return false;

  const canonicalCreatorId = normalizedString(
    policy.creatorId || policy.userId || policy.channelId,
  );
  if (viewer.hiddenVideoIds.has(videoId)) return false;
  if (excludeWatched && viewer.watchedVideoIds.has(videoId)) return false;
  if (viewer.hiddenCreatorIds.has(servingCreatorId) ||
      (canonicalCreatorId && viewer.hiddenCreatorIds.has(canonicalCreatorId))) {
    return false;
  }

  const publicationState = normalizedString(policy.visibility || policy.status).toLowerCase();
  if (policy.isPublic === false ||
      (policy.isPublic !== true && !PUBLICATION_STATES.has(publicationState)) ||
      (publicationState && !PUBLICATION_STATES.has(publicationState))) {
    return false;
  }

  const processingState = normalizedString(policy.processingStatus).toLowerCase();
  if (processingState && !READY_PROCESSING_STATES.has(processingState)) return false;

  const moderationState = normalizedString(policy.moderationStatus).toLowerCase();
  if (moderationState && !PUBLISHABLE_MODERATION_STATES.has(moderationState)) return false;
  if (policy.ageRestricted === true && !viewer.isAdult) return false;

  const blockedRegions = normalizedRegionList(policy.blockedRegions);
  if (blockedRegions.length > 0 &&
      (!viewer.region || regionListContains(blockedRegions, viewer.region))) {
    return false;
  }
  const allowedRegions = normalizedRegionList(policy.allowedRegions);
  if (allowedRegions.length > 0 &&
      (!viewer.region || !regionListContains(allowedRegions, viewer.region))) {
    return false;
  }

  return true;
}

async function filterRecommendationCandidates(
  videos: VideoRow[],
  viewer: ViewerPolicyContext,
  excludeWatched: boolean,
): Promise<VideoRow[]> {
  const uniqueVideos = videos.filter((video, index, all) =>
    index === all.findIndex(candidate => candidate.id === video.id),
  );
  const policies = await loadVideoPolicies(uniqueVideos.map(video => video.id));
  return uniqueVideos.filter(video => isVideoPolicyEligible(
    video.id,
    normalizedString(video.users?.id),
    policies.get(video.id),
    viewer,
    excludeWatched,
  ));
}

async function optionalAuthenticatedUser(
  req: Request,
  res: Response,
): Promise<OptionalAuthentication> {
  if (!req.headers.authorization) return {accepted: true, user: null};
  const user = await authenticate(req.headers.authorization);
  if (!user) {
    res.status(401).json({error: 'Unauthorized'});
    return {accepted: false, user: null};
  }
  return {accepted: true, user};
}

function normalizeVideo(value: unknown): VideoRow {
  const row = value as Omit<VideoRow, 'users'> & {users: CreatorRow | CreatorRow[]};
  return {...row, users: Array.isArray(row.users) ? row.users[0] : row.users};
}

async function authenticate(header: string | undefined): Promise<AuthenticatedUser | null> {
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice(7).trim();
  if (!token) return null;
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    return {userId: decoded.uid};
  } catch {}
  if (!JWT_SECRET) return null;
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as JwtPayload;
    const userId = String(decoded.uid || decoded.userId || decoded.sub || '').trim();
    return userId ? {userId} : null;
  } catch {
    return null;
  }
}

async function requireUser(req: Request, res: Response): Promise<AuthenticatedUser | null> {
  const user = await authenticate(req.headers.authorization);
  if (!user) res.status(401).json({error: 'Unauthorized'});
  return user;
}

function parseLimit(value: unknown, fallback: number, maximum: number): number {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? Math.min(parsed, maximum) : fallback;
}

function cleanVideoId(value: unknown): string {
  const videoId = String(value || '');
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(videoId)) throw new Error('Invalid video ID');
  return videoId;
}

function diversifyCreators(videos: VideoRow[], limit: number): VideoRow[] {
  const buckets = new Map<string, VideoRow[]>();
  for (const video of videos) {
    const creatorId = video.users?.id || `unknown:${video.id}`;
    const bucket = buckets.get(creatorId) ?? [];
    if (bucket.length < 3) bucket.push(video);
    buckets.set(creatorId, bucket);
  }

  const result: VideoRow[] = [];
  while (result.length < limit) {
    let added = false;
    for (const bucket of buckets.values()) {
      const video = bucket.shift();
      if (!video) continue;
      result.push(video);
      added = true;
      if (result.length === limit) break;
    }
    if (!added) break;
  }
  return result;
}

app.use(cors({
  origin: process.env.CORS_ORIGIN || 'https://mychannel.live',
  methods: ['GET', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Firebase-AppCheck'],
}));
app.use(express.json({limit: '16kb'}));
app.use(rateLimit({
  windowMs: 60_000,
  limit: 120,
  standardHeaders: true,
  legacyHeaders: false,
  message: {error: 'Too many requests, please try again later'},
}));
app.use('/v1/recommendations', async (req, res, next) => {
  if (!REQUIRE_APP_CHECK) return next();
  const bearer = req.headers.authorization?.startsWith('Bearer ')
    ? req.headers.authorization.slice(7).trim()
    : '';
  if (bearer && JWT_SECRET) {
    try {
      jwt.verify(bearer, JWT_SECRET);
      return next();
    } catch {}
  }
  const appCheckToken = req.header('x-firebase-appcheck');
  if (!appCheckToken) return res.status(401).json({error: 'App Check required'});
  try {
    await admin.appCheck().verifyToken(appCheckToken);
    return next();
  } catch {
    return res.status(401).json({error: 'Invalid App Check token'});
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'recommendations', timestamp: new Date().toISOString() });
});

// MARK: - Recommendation Algorithms

// Simple content-based filtering
async function getContentBasedRecommendations(userId: string, limit: number = 10) {
  try {
    // Get user's watch history and liked videos
    const { data: userHistory } = await supabase
      .from('watch_history')
      .select(`
        video_id,
        videos!inner(
          id, category, tags, creator:user_id
        )
      `)
      .eq('user_id', userId)
      .order('last_watched_at', { ascending: false })
      .limit(50);

    if (!userHistory || userHistory.length === 0) {
      return getPopularVideos(limit);
    }

    // Extract user preferences
    const categoryPreferences = new Map<string, number>();
    const tagPreferences = new Map<string, number>();
    const creatorPreferences = new Map<string, number>();

    userHistory.forEach(item => {
      const relation = item.videos;
      const video = Array.isArray(relation) ? relation[0] : relation;
      if (!video) return;

      if (video.category) {
        categoryPreferences.set(
          video.category,
          (categoryPreferences.get(video.category) || 0) + 1,
        );
      }

      if (Array.isArray(video.tags)) {
        video.tags.forEach((tag: string) => {
          tagPreferences.set(tag, (tagPreferences.get(tag) || 0) + 1);
        });
      }

      if (video.creator) {
        creatorPreferences.set(
          video.creator,
          (creatorPreferences.get(video.creator) || 0) + 1,
        );
      }
    });

    // Get top preferences
    const topCategories = Array.from(categoryPreferences.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(entry => entry[0]);

    const topTags = Array.from(tagPreferences.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(entry => entry[0]);

    const topCreators = Array.from(creatorPreferences.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(entry => entry[0]);

    // Find similar videos
    const watchedVideoIds = userHistory.map(item => item.video_id);
    
    let query = supabase
      .from('videos')
      .select(`
        id, title, description, thumbnail_url, duration, view_count, 
        like_count, comment_count, created_at, published_at, category, tags,
        users!inner(
          id, username, display_name, avatar_url, verified, subscriber_count
        )
      `)
      .eq('status', 'ready')
      .eq('visibility', 'public')
      .not('id', 'in', `(${watchedVideoIds.join(',')})`) // Exclude watched videos
      .order('view_count', { ascending: false })
      .limit(limit * 3); // Get more to filter and rank

    const {data: candidateVideos, error: candidateError} = await query;
    if (candidateError) throw candidateError;

    const normalizedCandidates = (candidateVideos ?? []).map(normalizeVideo);

    // Score videos based on user preferences
    const scoredVideos = normalizedCandidates.map(video => {
      let score = 0;
      
      // Category match
      if (video.category && topCategories.includes(video.category)) {
        score += 10;
      }
      
      // Tag matches
      if (video.tags && Array.isArray(video.tags)) {
        const tagMatches = video.tags.filter(tag => topTags.includes(tag)).length;
        score += tagMatches * 2;
      }
      
      // Creator match
      if (topCreators.includes(video.users.id)) {
        score += 15;
      }
      
      // Popularity boost
      score += Math.log10(video.view_count + 1);
      
      // Recency boost
      const publishedAt = new Date(video.published_at || video.created_at);
      const daysSincePublished = (Date.now() - publishedAt.getTime()) / (1000 * 60 * 60 * 24);
      if (daysSincePublished < 7) {
        score += 5;
      } else if (daysSincePublished < 30) {
        score += 2;
      }

      return { ...video, score };
    });

    // Sort by score and return top results
    return scoredVideos
      .sort((a, b) => b.score - a.score)
      .slice(0, limit)
      .map(({ score, ...video }) => video);

  } catch (error) {
    console.error('Content-based recommendation error:', error);
    return getPopularVideos(limit);
  }
}

// Collaborative filtering (simplified user-based)
async function getCollaborativeRecommendations(userId: string, limit: number = 10) {
  try {
    // Get users with similar viewing patterns
    const { data: userHistory } = await supabase
      .from('watch_history')
      .select('video_id')
      .eq('user_id', userId)
      .limit(100);

    if (!userHistory || userHistory.length === 0) {
      return getPopularVideos(limit);
    }

    const userVideoIds = userHistory.map(item => item.video_id);

    // Find users who watched similar videos
    const { data: similarUsers } = await supabase
      .from('watch_history')
      .select('user_id, video_id')
      .in('video_id', userVideoIds)
      .neq('user_id', userId);

    if (!similarUsers || similarUsers.length === 0) {
      return getPopularVideos(limit);
    }

    // Calculate user similarity scores
    const userSimilarity = new Map<string, number>();
    
    similarUsers.forEach(item => {
      const similarUserId = item.user_id;
      userSimilarity.set(
        similarUserId, 
        (userSimilarity.get(similarUserId) || 0) + 1
      );
    });

    // Get top similar users
    const topSimilarUsers = Array.from(userSimilarity.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 20)
      .map(entry => entry[0]);

    // Get videos watched by similar users that current user hasn't watched
    const { data: recommendations } = await supabase
      .from('watch_history')
      .select(`
        video_id,
        videos!inner(
          id, title, description, thumbnail_url, duration, view_count, 
          like_count, comment_count, created_at, published_at,
          users!inner(
            id, username, display_name, avatar_url, verified, subscriber_count
          )
        )
      `)
      .in('user_id', topSimilarUsers)
      .not('video_id', 'in', `(${userVideoIds.join(',')})`)
      .eq('videos.status', 'ready')
      .eq('videos.visibility', 'public')
      .order('videos.view_count', { ascending: false })
      .limit(limit);

    return (recommendations ?? [])
      .map(item => Array.isArray(item.videos) ? item.videos[0] : item.videos)
      .filter(Boolean)
      .map(normalizeVideo);

  } catch (error) {
    console.error('Collaborative filtering error:', error);
    return getPopularVideos(limit);
  }
}

// Get popular videos as fallback
async function getPopularVideos(limit: number = 10): Promise<VideoRow[]> {
  const {data: videos, error} = await supabase
    .from('videos')
    .select(`
      id, title, description, thumbnail_url, duration, view_count, 
      like_count, comment_count, created_at, published_at,
      users!inner(
        id, username, display_name, avatar_url, verified, subscriber_count
      )
    `)
    .eq('status', 'ready')
    .eq('visibility', 'public')
    .order('view_count', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return (videos ?? []).map(normalizeVideo);
}

// Get trending videos with time decay
async function getTrendingVideos(
  limit: number = 10,
  timeframe: 'day' | 'week' | 'month' = 'week',
): Promise<VideoRow[]> {
  let timeFilter = '';
  const now = new Date();
  
  switch (timeframe) {
    case 'day':
      timeFilter = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
      break;
    case 'week':
      timeFilter = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
      break;
    case 'month':
      timeFilter = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();
      break;
    default:
      timeFilter = '';
  }

  let query = supabase
    .from('videos')
    .select(`
      id, title, description, thumbnail_url, duration, view_count, 
      like_count, comment_count, created_at, published_at,
      users!inner(
        id, username, display_name, avatar_url, verified, subscriber_count
      )
    `)
    .eq('status', 'ready')
    .eq('visibility', 'public');

  if (timeFilter) {
    query = query.gte('published_at', timeFilter);
  }

  const {data: videos, error} = await query
    .order('view_count', { ascending: false })
    .order('like_count', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return (videos ?? []).map(normalizeVideo);
}

// MARK: - API Endpoints

function formatVideos(videos: VideoRow[]) {
  return videos.map(video => ({
    id: video.id,
    title: video.title,
    description: video.description,
    thumbnailUrl: video.thumbnail_url,
    duration: video.duration,
    viewCount: video.view_count,
    likeCount: video.like_count,
    commentCount: video.comment_count,
    publishedAt: video.published_at,
    createdAt: video.created_at,
    creator: {
      id: video.users.id,
      username: video.users.username,
      displayName: video.users.display_name,
      avatarUrl: video.users.avatar_url,
      verified: video.users.verified,
      subscriberCount: video.users.subscriber_count,
    },
  }));
}

// Get personalized recommendations for authenticated user
app.get('/v1/recommendations/personal', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;
    const userId = user.userId;
    const limit = parseLimit(req.query.limit, 20, 50);
    const candidateLimit = limit * 3;
    const algorithm = String(req.query.algorithm || 'hybrid');
    if (!['content', 'collaborative', 'hybrid'].includes(algorithm)) {
      return res.status(400).json({error: 'Invalid algorithm'});
    }

    let recommendations: VideoRow[] = [];
    switch (algorithm) {
      case 'content':
        recommendations = await getContentBasedRecommendations(userId, candidateLimit);
        break;
      case 'collaborative':
        recommendations = await getCollaborativeRecommendations(userId, candidateLimit);
        break;
      case 'hybrid':
      default: {
        const contentRecs = await getContentBasedRecommendations(
          userId,
          Math.ceil(candidateLimit * 0.7),
        );
        const collaborativeRecs = await getCollaborativeRecommendations(
          userId,
          Math.ceil(candidateLimit * 0.3),
        );
        recommendations = [...contentRecs, ...collaborativeRecs];
        break;
      }
    }

    const viewer = await loadViewerPolicy(user);
    recommendations = diversifyCreators(
      await filterRecommendationCandidates(recommendations, viewer, true),
      limit,
    );

    res.json({
      videos: formatVideos(recommendations),
      algorithm,
      userId,
    });
  } catch (error) {
    console.error('Personal recommendations error:', error);
    res.status(500).json({error: 'Failed to get recommendations'});
  }
});

// Get trending videos
app.get('/v1/recommendations/trending', async (req, res) => {
  try {
    const authentication = await optionalAuthenticatedUser(req, res);
    if (!authentication.accepted) return;
    const limit = parseLimit(req.query.limit, 20, 50);
    const timeframe = String(req.query.timeframe || 'week');
    if (!['day', 'week', 'month'].includes(timeframe)) {
      return res.status(400).json({error: 'Invalid timeframe'});
    }

    const viewer = await loadViewerPolicy(authentication.user);
    const candidates = await getTrendingVideos(
      limit * 3,
      timeframe as 'day' | 'week' | 'month',
    );
    const videos = diversifyCreators(
      await filterRecommendationCandidates(candidates, viewer, false),
      limit,
    );

    res.json({
      videos: formatVideos(videos),
      timeframe,
      algorithm: 'trending',
    });
  } catch (error) {
    console.error('Trending recommendations error:', error);
    res.status(500).json({error: 'Failed to get trending videos'});
  }
});

// Get similar videos for a specific video
app.get('/v1/recommendations/similar/:videoId', async (req, res) => {
  try {
    const authentication = await optionalAuthenticatedUser(req, res);
    if (!authentication.accepted) return;
    const videoId = cleanVideoId(req.params.videoId);
    const limit = parseLimit(req.query.limit, 12, 24);
    const viewer = await loadViewerPolicy(authentication.user);

    const {data: currentVideo, error: currentVideoError} = await supabase
      .from('videos')
      .select('category, tags, user_id')
      .eq('id', videoId)
      .single();

    if (currentVideoError || !currentVideo) {
      return res.status(404).json({error: 'Video not found'});
    }

    const category = String(currentVideo.category || '');
    const creatorId = String(currentVideo.user_id || '');
    if (!/^[A-Za-z0-9 _-]{1,64}$/.test(category) ||
        !/^[A-Za-z0-9_-]{1,128}$/.test(creatorId)) {
      return res.status(422).json({error: 'Video recommendation metadata is invalid'});
    }

    const currentPolicy = await loadVideoPolicies([videoId]);
    if (!isVideoPolicyEligible(
      videoId,
      creatorId,
      currentPolicy.get(videoId),
      viewer,
      false,
    )) {
      return res.status(404).json({error: 'Video not found'});
    }

    const {data: similarVideos, error: similarError} = await supabase
      .from('videos')
      .select(`
        id, title, description, thumbnail_url, duration, view_count,
        like_count, comment_count, created_at, published_at,
        users!inner(
          id, username, display_name, avatar_url, verified, subscriber_count
        )
      `)
      .eq('status', 'ready')
      .eq('visibility', 'public')
      .neq('id', videoId)
      .or(`category.eq.${category},user_id.eq.${creatorId}`)
      .order('view_count', {ascending: false})
      .limit(limit * 3);

    if (similarError) throw similarError;
    const candidates = (similarVideos ?? []).map(normalizeVideo);
    const recommendations = diversifyCreators(
      await filterRecommendationCandidates(
        candidates,
        viewer,
        authentication.user !== null,
      ),
      limit,
    );

    res.json({
      videos: formatVideos(recommendations),
      baseVideoId: videoId,
      algorithm: 'similar',
    });
  } catch (error) {
    console.error('Similar videos error:', error);
    res.status(500).json({error: 'Failed to get similar videos'});
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`🤖 Recommendations service listening on port ${port}`);
});











