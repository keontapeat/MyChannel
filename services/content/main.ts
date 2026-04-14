import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import admin from 'firebase-admin';
import { Storage } from '@google-cloud/storage';
import jwt from 'jsonwebtoken';

// Initialize Firebase Admin (Application Default Credentials or service account)
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();
const storage = new Storage();
const STORIES_BUCKET = process.env.STORIES_BUCKET || 'mychannel-ingest';
const JWT_SECRET = process.env.JWT_SECRET || '';

type AuthenticatedUser = {
  userId: string;
  email: string | null;
  username: string | null;
  premiumTier: string | null;
  tokenType: 'firebase' | 'jwt';
};

type FirestoreData = Record<string, any>;

function toIsoString(value: any): string | null {
  if (!value) return null;
  if (typeof value === 'string') return value;
  if (value instanceof Date) return value.toISOString();
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (typeof value._seconds === 'number') return new Date(value._seconds * 1000).toISOString();
  return null;
}

function extractStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map(item => String(item).trim()).filter(Boolean);
}

function normalizeTagList(value: unknown): string[] {
  return Array.from(new Set(extractStringList(value).map(tag => tag.toLowerCase())));
}

function formatCreatorSummary(userId: string, userData: FirestoreData | null = null) {
  const data = userData || {};
  return {
    id: userId,
    username: data.username || '',
    displayName: data.displayName || data.name || data.username || '',
    avatarUrl: data.avatarUrl || null,
    verified: !!data.verified,
    subscriberCount: Number(data.subscriberCount || data.subscriber_count || 0)
  };
}

function formatCreatorDetail(userId: string, userData: FirestoreData | null = null) {
  const data = userData || {};
  return {
    ...formatCreatorSummary(userId, data),
    bio: data.bio || null,
    videoCount: Number(data.videoCount || data.video_count || 0),
    totalViews: Number(data.totalViews || data.total_views || 0)
  };
}

function formatVideoSummary(videoId: string, videoData: FirestoreData, userData: FirestoreData | null = null) {
  return {
    id: videoId,
    title: videoData.title || '',
    description: videoData.description || null,
    thumbnailUrl: videoData.thumbnailUrl || null,
    duration: typeof videoData.duration === 'number' ? videoData.duration : (videoData.duration ? Number(videoData.duration) : null),
    viewCount: Number(videoData.views || 0),
    likeCount: Number(videoData.likes || 0),
    commentCount: Number(videoData.comments || 0),
    publishedAt: toIsoString(videoData.publishedAt),
    createdAt: toIsoString(videoData.createdAt) || new Date().toISOString(),
    creator: formatCreatorSummary(String(videoData.ownerId || ''), userData)
  };
}

function formatVideoDetail(videoId: string, videoData: FirestoreData, userData: FirestoreData | null = null) {
  const createdAt = toIsoString(videoData.createdAt) || new Date().toISOString();
  return {
    id: videoId,
    title: videoData.title || '',
    description: videoData.description || null,
    thumbnailUrl: videoData.thumbnailUrl || null,
    videoUrl: videoData.videoUrl || null,
    duration: typeof videoData.duration === 'number' ? videoData.duration : (videoData.duration ? Number(videoData.duration) : null),
    fileSize: typeof videoData.fileSize === 'number' ? videoData.fileSize : (videoData.fileSize ? Number(videoData.fileSize) : null),
    status: videoData.status || 'ready',
    qualityVariants: Array.isArray(videoData.qualityVariants) ? videoData.qualityVariants : [],
    captions: Array.isArray(videoData.captions) ? videoData.captions : [],
    chapters: Array.isArray(videoData.chapters) ? videoData.chapters : [],
    visibility: videoData.visibility || 'public',
    isLive: !!videoData.isLive,
    isPremium: !!videoData.isPremium,
    viewCount: Number(videoData.views || 0),
    likeCount: Number(videoData.likes || 0),
    dislikeCount: Number(videoData.dislikes || 0),
    commentCount: Number(videoData.comments || 0),
    shareCount: Number(videoData.shares || 0),
    category: videoData.category || null,
    tags: extractStringList(videoData.tags),
    language: videoData.language || 'en',
    ageRestriction: Number(videoData.ageRestriction || 0),
    publishedAt: toIsoString(videoData.publishedAt),
    createdAt,
    updatedAt: toIsoString(videoData.updatedAt) || createdAt,
    creator: formatCreatorDetail(String(videoData.ownerId || ''), userData)
  };
}

async function loadUsersMap(userIds: string[]): Promise<Record<string, FirestoreData | null>> {
  const ids = Array.from(new Set(userIds.map(id => String(id || '')).filter(Boolean)));
  const usersMap: Record<string, FirestoreData | null> = {};
  if (!ids.length) return usersMap;
  const userSnaps = await Promise.all(ids.map(id => db.collection('users').doc(id).get()));
  for (const snap of userSnaps) {
    usersMap[snap.id] = snap.exists ? snap.data()! : null;
  }
  return usersMap;
}

async function loadUserDocument(userId: string): Promise<FirestoreData | null> {
  if (!userId) return null;
  const snap = await db.collection('users').doc(userId).get();
  return snap.exists ? snap.data()! : null;
}

async function ensureUserDocument(user: AuthenticatedUser, fallback: Record<string, any> = {}): Promise<FirestoreData> {
  const ref = db.collection('users').doc(user.userId);
  const snap = await ref.get();
  const now = admin.firestore.Timestamp.now();
  const username = String(fallback.username || '').trim() || user.username || (user.email ? String(user.email).split('@')[0] : '') || `user_${user.userId.slice(0, 8)}`;
  const displayName = String(fallback.displayName || '').trim() || username || user.email || `user_${user.userId.slice(0, 8)}`;
  const defaults = {
    username,
    displayName,
    name: displayName,
    email: user.email || null,
    verified: false,
    subscriberCount: 0,
    videoCount: 0,
    totalViews: 0,
    premiumTier: user.premiumTier || 'free',
    updatedAt: now
  };

  if (!snap.exists) {
    const createdData = {
      ...defaults,
      createdAt: now
    };
    await ref.set(createdData, { merge: true });
    return createdData;
  }

  const existing = snap.data() || {};
  const patch: Record<string, any> = {};
  if (!existing.username && defaults.username) patch.username = defaults.username;
  if (!existing.displayName && defaults.displayName) patch.displayName = defaults.displayName;
  if (!existing.name && defaults.name) patch.name = defaults.name;
  if (!existing.email && defaults.email) patch.email = defaults.email;
  if (existing.verified == null) patch.verified = false;
  if (existing.subscriberCount == null) patch.subscriberCount = 0;
  if (existing.videoCount == null) patch.videoCount = 0;
  if (existing.totalViews == null) patch.totalViews = 0;
  if (existing.premiumTier == null && defaults.premiumTier) patch.premiumTier = defaults.premiumTier;

  if (Object.keys(patch).length) {
    patch.updatedAt = now;
    await ref.set(patch, { merge: true });
    return { ...existing, ...patch };
  }

  return existing;
}

async function verifyAppToken(authHeader: string | undefined): Promise<AuthenticatedUser | null> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
  const token = authHeader.slice(7).trim();
  if (!token) return null;

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    return {
      userId: decoded.uid,
      email: decoded.email || null,
      username: decoded.name || (decoded.email ? decoded.email.split('@')[0] : null),
      premiumTier: null,
      tokenType: 'firebase'
    };
  } catch {}

  if (!JWT_SECRET) return null;

  try {
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    const userId = String(decoded.userId || decoded.uid || '').trim();
    if (!userId) return null;
    return {
      userId,
      email: decoded.email || null,
      username: decoded.username || null,
      premiumTier: decoded.premiumTier || null,
      tokenType: 'jwt'
    };
  } catch {
    return null;
  }
}

async function requireUser(req: any, res: any): Promise<AuthenticatedUser | null> {
  const user = await verifyAppToken(req.headers.authorization);
  if (!user) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
  return user;
}

async function updateVideoReaction(videoId: string, userId: string, kind: 'like' | 'dislike', shouldAdd: boolean): Promise<FirestoreData | null> {
  const videoRef = db.collection('videos').doc(videoId);
  return db.runTransaction(async tx => {
    const videoSnap = await tx.get(videoRef);
    if (!videoSnap.exists) return null;

    const videoData = videoSnap.data() || {};
    const likeRef = videoRef.collection('likes').doc(userId);
    const dislikeRef = videoRef.collection('dislikes').doc(userId);
    const likeSnap = await tx.get(likeRef);
    const dislikeSnap = await tx.get(dislikeRef);
    let likes = Number(videoData.likes || 0);
    let dislikes = Number(videoData.dislikes || 0);

    if (kind === 'like') {
      if (shouldAdd && !likeSnap.exists) {
        tx.set(likeRef, { userId, createdAt: admin.firestore.Timestamp.now() });
        likes += 1;
      }
      if (!shouldAdd && likeSnap.exists) {
        tx.delete(likeRef);
        likes = Math.max(0, likes - 1);
      }
      if (shouldAdd && dislikeSnap.exists) {
        tx.delete(dislikeRef);
        dislikes = Math.max(0, dislikes - 1);
      }
    } else {
      if (shouldAdd && !dislikeSnap.exists) {
        tx.set(dislikeRef, { userId, createdAt: admin.firestore.Timestamp.now() });
        dislikes += 1;
      }
      if (!shouldAdd && dislikeSnap.exists) {
        tx.delete(dislikeRef);
        dislikes = Math.max(0, dislikes - 1);
      }
      if (shouldAdd && likeSnap.exists) {
        tx.delete(likeRef);
        likes = Math.max(0, likes - 1);
      }
    }

    tx.update(videoRef, {
      likes,
      dislikes,
      updatedAt: admin.firestore.Timestamp.now()
    });

    return { ...videoData, likes, dislikes };
  });
}

function successMessage(message: string) {
  return {
    message,
    success: true,
    timestamp: new Date().toISOString()
  };
}

const app = express();

app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json({ limit: '50mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // limit each IP to 1000 requests per windowMs
  message: { error: 'Too many requests, please try again later' }
});
app.use(limiter);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'content', timestamp: new Date().toISOString() });
});

// Get home feed with personalized recommendations
app.get('/v1/feed/home', async (req, res) => {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    // Firestore: status == 'published', (optional) visibility == 'public'
    let query = db.collection('videos')
      .where('status', '==', 'published')
      .orderBy('views', 'desc')
      .orderBy('createdAt', 'desc');

    // Firestore supports offset; acceptable for small pages
    const snap = await query.offset(offset).limit(limit).get();
    const videoDocs = snap.docs;

    // Batch load creators
    const ownersMap = await loadUsersMap(videoDocs.map(d => String(d.get('ownerId') || '')));
    const formattedVideos = videoDocs.map(d => formatVideoSummary(d.id, d.data(), ownersMap[String(d.get('ownerId') || '')] || null));

    res.json({
      videos: formattedVideos,
      pagination: {
        page,
        limit,
        hasMore: formattedVideos.length === limit
      }
    });
  } catch (error) {
    console.error('Home feed error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get video by ID
app.get('/v1/videos/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const doc = await db.collection('videos').doc(id).get();
    if (!doc.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }
    const v = doc.data()!;
    const requester = await verifyAppToken(req.headers.authorization);
    const isOwner = requester?.userId === String(v.ownerId || '');
    if (v.status && v.status !== 'published' && !isOwner) {
      return res.status(404).json({ error: 'Video not available' });
    }
    if (v.visibility && v.visibility === 'private' && !isOwner) {
      return res.status(403).json({ error: 'Video is private' });
    }

    // Fetch creator
    const creator = v.ownerId ? await loadUserDocument(String(v.ownerId)) : null;
    const formattedVideo = formatVideoDetail(doc.id, v, creator);

    res.json({ video: formattedVideo });
  } catch (error) {
    console.error('Video fetch error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Search videos
app.get('/v1/search', async (req, res) => {
  try {
    const query = String(req.query.q || '').trim();
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    if (!query) {
      return res.status(400).json({ error: 'Search query is required' });
    }

    // Firestore naive search: match tags or title prefix if maintained
    const qLower = query.toLowerCase();
    const candidatesSnap = await db.collection('videos')
      .where('status', '==', 'published')
      .orderBy('views', 'desc')
      .limit(Math.min(Math.max(page * limit * 5, 60), 240))
      .get();
    const ownersMap = await loadUsersMap(candidatesSnap.docs.map(d => String(d.get('ownerId') || '')));
    const filteredDocs = candidatesSnap.docs.filter(d => {
      const v = d.data();
      const u = ownersMap[String(v.ownerId || '')] || {};
      const haystacks = [
        String(v.title || ''),
        String(v.description || ''),
        String(v.searchText || ''),
        ...extractStringList(v.tags),
        String(u.username || ''),
        String(u.displayName || u.name || '')
      ];
      return haystacks.some(value => value.toLowerCase().includes(qLower));
    });
    const paginatedDocs = filteredDocs.slice(offset, offset + limit);
    const formattedVideos = paginatedDocs.map(d => formatVideoSummary(d.id, d.data(), ownersMap[String(d.get('ownerId') || '')] || null));

    res.json({
      query,
      videos: formattedVideos,
      pagination: {
        page,
        limit,
        hasMore: filteredDocs.length > offset + formattedVideos.length
      }
    });
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/v1/suggest', async (req, res) => {
  try {
    const query = String(req.query.q || '').trim().toLowerCase();
    const limit = Math.min(parseInt(req.query.limit as string) || 8, 20);
    if (!query) {
      return res.json({ suggestions: [] });
    }

    const snap = await db.collection('videos')
      .where('status', '==', 'published')
      .orderBy('views', 'desc')
      .limit(100)
      .get();

    const suggestions = new Set<string>();
    for (const doc of snap.docs) {
      const data = doc.data();
      const title = String(data.title || '').trim();
      if (title && title.toLowerCase().includes(query)) {
        suggestions.add(title);
      }

      for (const tag of extractStringList(data.tags)) {
        if (tag.toLowerCase().includes(query)) {
          suggestions.add(tag);
        }
      }

      if (suggestions.size >= limit) {
        break;
      }
    }

    res.json({ suggestions: Array.from(suggestions).slice(0, limit) });
  } catch (error) {
    console.error('Suggest error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get trending videos
app.get('/v1/feed/trending', async (req, res) => {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;
    const timeframe = req.query.timeframe as string || 'week'; // day, week, month, all

    const now = admin.firestore.Timestamp.now();
    let afterTs: any = null;
    switch (timeframe) {
      case 'day':
        afterTs = admin.firestore.Timestamp.fromMillis(now.toMillis() - 24 * 60 * 60 * 1000);
        break;
      case 'week':
        afterTs = admin.firestore.Timestamp.fromMillis(now.toMillis() - 7 * 24 * 60 * 60 * 1000);
        break;
      case 'month':
        afterTs = admin.firestore.Timestamp.fromMillis(now.toMillis() - 30 * 24 * 60 * 60 * 1000);
        break;
      default:
        afterTs = null;
    }

    let q = db.collection('videos')
      .where('status', '==', 'published')
      .orderBy('views', 'desc')
      .orderBy('createdAt', 'desc');
    if (afterTs) {
      q = q.where('createdAt', '>=', afterTs);
    }
    const snap = await q.offset(offset).limit(limit).get();
    const docs = snap.docs;
    const ownersMap = await loadUsersMap(docs.map(d => String(d.get('ownerId') || '')));
    const formattedVideos = docs.map(d => formatVideoSummary(d.id, d.data(), ownersMap[String(d.get('ownerId') || '')] || null));

    res.json({
      timeframe,
      videos: formattedVideos,
      pagination: {
        page,
        limit,
        hasMore: formattedVideos.length === limit
      }
    });
  } catch (error) {
    console.error('Trending error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get videos by category
app.get('/v1/feed/category/:category', async (req, res) => {
  try {
    const { category } = req.params;
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    const snap = await db.collection('videos')
      .where('status', '==', 'published')
      .where('category', '==', category)
      .orderBy('createdAt', 'desc')
      .offset(offset)
      .limit(limit)
      .get();
    const docs = snap.docs;
    const ownersMap = await loadUsersMap(docs.map(d => String(d.get('ownerId') || '')));
    const formattedVideos = docs.map(d => formatVideoSummary(d.id, d.data(), ownersMap[String(d.get('ownerId') || '')] || null));

    res.json({
      category,
      videos: formattedVideos,
      pagination: {
        page,
        limit,
        hasMore: formattedVideos.length === limit
      }
    });
  } catch (error) {
    console.error('Category error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get related/recommended videos
app.get('/v1/videos/:id/related', async (req, res) => {
  try {
    const { id } = req.params;
    const limit = Math.min(parseInt(req.query.limit as string) || 12, 24);

    // Get the current video to find related content
    const current = await db.collection('videos').doc(id).get();
    if (!current.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }
    const cv = current.data()!;

    // Related by category or same owner
    const relSnap = await db.collection('videos')
      .where('status', '==', 'published')
      .where('category', '==', cv.category || '')
      .orderBy('views', 'desc')
      .limit(limit)
      .get();

    const docs = relSnap.docs.filter(d => d.id !== id);
    const ownersMap = await loadUsersMap(docs.map(d => String(d.get('ownerId') || '')));
    const formattedVideos = docs.map(d => formatVideoSummary(d.id, d.data(), ownersMap[String(d.get('ownerId') || '')] || null));

    res.json({ videos: formattedVideos });
  } catch (error) {
    console.error('Related videos error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/v1/creator/videos', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const creator = await ensureUserDocument(user);
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;
    const snap = await db.collection('videos')
      .where('ownerId', '==', user.userId)
      .orderBy('createdAt', 'desc')
      .offset(offset)
      .limit(limit)
      .get();

    const videos = snap.docs.map(doc => formatVideoDetail(doc.id, doc.data(), creator));
    res.json({
      videos,
      pagination: {
        page,
        limit,
        hasMore: videos.length === limit
      }
    });
  } catch (error) {
    console.error('Creator videos error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/v1/creator/videos', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const body = req.body || {};
    const title = String(body.title || '').trim();
    if (!title) {
      return res.status(400).json({ error: 'Title is required' });
    }

    const description = String(body.description || '').trim() || null;
    const category = String(body.category || '').trim() || null;
    const visibilityValue = String(body.visibility || 'public').trim().toLowerCase();
    const visibility = ['public', 'private', 'unlisted'].includes(visibilityValue) ? visibilityValue : 'public';
    const tags = normalizeTagList(body.tags).slice(0, 25);
    const language = String(body.language || 'en').trim() || 'en';
    const videoUrl = String(body.videoUrl || '').trim() || null;
    const thumbnailUrl = String(body.thumbnailUrl || '').trim() || null;
    const now = admin.firestore.Timestamp.now();
    const creator = await ensureUserDocument(user, body);
    const status = videoUrl ? 'published' : 'draft';
    const videoRef = db.collection('videos').doc();
    const payload = {
      ownerId: user.userId,
      title,
      description,
      thumbnailUrl,
      videoUrl,
      duration: typeof body.duration === 'number' ? body.duration : (body.duration ? Number(body.duration) : null),
      fileSize: typeof body.fileSize === 'number' ? body.fileSize : (body.fileSize ? Number(body.fileSize) : null),
      status,
      qualityVariants: Array.isArray(body.qualityVariants) ? body.qualityVariants : [],
      captions: Array.isArray(body.captions) ? body.captions : [],
      chapters: Array.isArray(body.chapters) ? body.chapters : [],
      visibility,
      isLive: false,
      isPremium: !!body.isPremium,
      views: 0,
      likes: 0,
      dislikes: 0,
      comments: 0,
      shares: 0,
      category,
      tags,
      searchText: [title, description || '', category || '', language, ...tags].join(' ').trim().toLowerCase(),
      language,
      ageRestriction: typeof body.ageRestriction === 'number' ? body.ageRestriction : Number(body.ageRestriction || 0),
      publishedAt: videoUrl ? now : null,
      createdAt: now,
      updatedAt: now
    };

    await videoRef.set(payload);
    if (status === 'published') {
      await db.collection('users').doc(user.userId).set({
        videoCount: admin.firestore.FieldValue.increment(1),
        updatedAt: now
      }, { merge: true });
    }

    const updatedCreator = {
      ...creator,
      videoCount: Number(creator.videoCount || 0) + (status === 'published' ? 1 : 0)
    };

    res.status(201).json({
      video: formatVideoDetail(videoRef.id, payload, updatedCreator)
    });
  } catch (error) {
    console.error('Create video error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/v1/videos/:id/like', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const updated = await updateVideoReaction(req.params.id, user.userId, 'like', true);
    if (!updated) {
      return res.status(404).json({ error: 'Video not found' });
    }

    res.json({
      ...successMessage('Video liked'),
      likeCount: Number(updated.likes || 0),
      dislikeCount: Number(updated.dislikes || 0)
    });
  } catch (error) {
    console.error('Like video error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.delete('/v1/videos/:id/like', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const updated = await updateVideoReaction(req.params.id, user.userId, 'like', false);
    if (!updated) {
      return res.status(404).json({ error: 'Video not found' });
    }

    res.json({
      ...successMessage('Video like removed'),
      likeCount: Number(updated.likes || 0),
      dislikeCount: Number(updated.dislikes || 0)
    });
  } catch (error) {
    console.error('Unlike video error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/v1/videos/:id/dislike', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const updated = await updateVideoReaction(req.params.id, user.userId, 'dislike', true);
    if (!updated) {
      return res.status(404).json({ error: 'Video not found' });
    }

    res.json({
      ...successMessage('Video disliked'),
      likeCount: Number(updated.likes || 0),
      dislikeCount: Number(updated.dislikes || 0)
    });
  } catch (error) {
    console.error('Dislike video error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.delete('/v1/videos/:id/dislike', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const updated = await updateVideoReaction(req.params.id, user.userId, 'dislike', false);
    if (!updated) {
      return res.status(404).json({ error: 'Video not found' });
    }

    res.json({
      ...successMessage('Video dislike removed'),
      likeCount: Number(updated.likes || 0),
      dislikeCount: Number(updated.dislikes || 0)
    });
  } catch (error) {
    console.error('Remove dislike error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ── Stories ───────────────────────────────────────────────────────────────────

// Helper: verify Firebase ID token and return uid
async function verifyToken(authHeader: string | undefined): Promise<string | null> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
  try {
    const decoded = await admin.auth().verifyIdToken(authHeader.slice(7));
    return decoded.uid;
  } catch {
    return null;
  }
}

// GET /v1/stories/following — fetch active stories from followed creators
app.get('/v1/stories/following', async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit as string) || 24, 50);
    const now = admin.firestore.Timestamp.now();

    const snap = await db.collection('stories')
      .where('expiresAt', '>', now)
      .orderBy('expiresAt', 'desc')
      .limit(limit)
      .get();

    const stories = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    res.json({ stories });
  } catch (error) {
    console.error('Stories fetch error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/stories/signed-url — get a GCS signed URL for story media upload
app.post('/v1/stories/signed-url', async (req, res) => {
  try {
    const uid = await verifyToken(req.headers.authorization);
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const { filename, contentType } = req.body || {};
    if (!filename) return res.status(400).json({ error: 'filename required' });

    const objectName = `stories/${uid}/${filename}`;
    const file = storage.bucket(STORIES_BUCKET).file(objectName);

    const [url] = await file.getSignedUrl({
      action: 'write',
      version: 'v4',
      expires: Date.now() + 15 * 60 * 1000,
    });
    const [getUrl] = await file.getSignedUrl({
      action: 'read',
      version: 'v4',
      expires: Date.now() + 25 * 60 * 60 * 1000,
    });

    return res.json({
      url,
      method: 'PUT',
      bucket: STORIES_BUCKET,
      object: objectName,
      getUrl,
    });
  } catch (e: any) {
    console.error('Stories signed-url error:', e);
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

// POST /v1/stories/finalize — set content-type metadata, return public URL
app.post('/v1/stories/finalize', async (req, res) => {
  try {
    const uid = await verifyToken(req.headers.authorization);
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const { object, bucket, contentType } = req.body || {};
    const bkt = String(bucket || STORIES_BUCKET);
    const obj = String(object || '').trim();
    if (!obj) return res.status(400).json({ error: 'object required' });

    const file = storage.bucket(bkt).file(obj);
    if (contentType) {
      try { await file.setMetadata({ contentType: String(contentType) }); } catch {}
    }

    const [publicUrl] = await file.getSignedUrl({
      action: 'read',
      version: 'v4',
      expires: Date.now() + 25 * 60 * 60 * 1000,
    });

    return res.json({ url: publicUrl, publicUrl, bucket: bkt, object: obj, contentType: contentType || null });
  } catch (e: any) {
    console.error('Stories finalize error:', e);
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

// POST /v1/stories — create a story record in Firestore
app.post('/v1/stories', async (req, res) => {
  try {
    const uid = await verifyToken(req.headers.authorization);
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const {
      mediaUrl, mediaType, duration, caption, text,
      backgroundColor, textColor, music, stickers, audience
    } = req.body || {};

    if (!mediaUrl || !mediaType) {
      return res.status(400).json({ error: 'mediaUrl and mediaType are required' });
    }

    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000);

    const storyData: Record<string, any> = {
      creatorId: uid,
      mediaURL: mediaUrl,
      mediaType,
      duration: duration || 15,
      caption: caption || null,
      text: text || null,
      backgroundColor: backgroundColor || null,
      textColor: textColor || null,
      music: music || null,
      stickers: stickers || [],
      audience: audience || 'public',
      viewCount: 0,
      isLive: false,
      createdAt: now,
      expiresAt,
    };

    const docRef = await db.collection('stories').add(storyData);

    const story = {
      id: docRef.id,
      creatorId: uid,
      mediaURL: mediaUrl,
      mediaType,
      duration: duration || 15,
      caption: caption || null,
      text: text || null,
      backgroundColor: backgroundColor || null,
      textColor: textColor || null,
      music: music || null,
      stickers: stickers || [],
      polls: [],
      links: [],
      content: [],
      audience: audience || 'public',
      viewCount: 0,
      isViewed: false,
      isLive: false,
      thumbnail: null,
      createdAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    };

    return res.status(201).json({ story });
  } catch (e: any) {
    console.error('Create story error:', e);
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Comments API
// ─────────────────────────────────────────────────────────────────────────────

async function formatComment(commentId: string, commentData: FirestoreData, userData: FirestoreData | null = null) {
  return {
    id: commentId,
    text: commentData.text || '',
    videoId: commentData.videoId || null,
    userId: commentData.userId || null,
    user: userData ? {
      id: userData.id || commentData.userId,
      username: userData.username || '',
      displayName: userData.displayName || userData.name || userData.username || '',
      avatarUrl: userData.avatarUrl || null,
      verified: !!userData.verified
    } : null,
    likeCount: Number(commentData.likeCount || 0),
    replyCount: Number(commentData.replyCount || 0),
    createdAt: toIsoString(commentData.createdAt),
    updatedAt: toIsoString(commentData.updatedAt) || toIsoString(commentData.createdAt)
  };
}

// GET /v1/videos/:id/comments - list comments for a video
app.get('/v1/videos/:id/comments', async (req, res) => {
  try {
    const { id } = req.params;
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    const snap = await db.collection('videos').doc(id).collection('comments')
      .orderBy('createdAt', 'desc')
      .offset(offset)
      .limit(limit)
      .get();

    const userIds = snap.docs.map(doc => String(doc.get('userId') || ''));
    const usersMap = await loadUsersMap(userIds);

    const comments = snap.docs.map(doc => formatComment(doc.id, doc.data(), usersMap[String(doc.get('userId') || '')] || null));

    res.json({
      comments,
      pagination: {
        page,
        limit,
        hasMore: comments.length === limit
      }
    });
  } catch (error) {
    console.error('List comments error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/videos/:id/comments - create a comment
app.post('/v1/videos/:id/comments', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const { text } = req.body || {};

    if (!text || typeof text !== 'string' || !text.trim()) {
      return res.status(400).json({ error: 'Comment text is required' });
    }

    const now = admin.firestore.Timestamp.now();
    const commentRef = db.collection('videos').doc(id).collection('comments').doc();
    const commentData = {
      text: text.trim(),
      videoId: id,
      userId: user.userId,
      likeCount: 0,
      replyCount: 0,
      createdAt: now,
      updatedAt: now
    };

    await commentRef.set(commentData);

    await db.runTransaction(async tx => {
      const videoRef = db.collection('videos').doc(id);
      const videoSnap = await tx.get(videoRef);
      if (videoSnap.exists) {
        tx.update(videoRef, {
          comments: admin.firestore.FieldValue.increment(1),
          updatedAt: now
        });
      }
    });

    const userData = await loadUserDocument(user.userId);
    res.status(201).json({
      comment: formatComment(commentRef.id, commentData, userData)
    });
  } catch (error) {
    console.error('Create comment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/comments/:id - delete a comment (owner only)
app.delete('/v1/comments/:id', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const commentRef = db.collectionGroup('comments').where('id', '==', id).limit(1);
    const snap = await commentRef.get();

    if (snap.empty) {
      return res.status(404).json({ error: 'Comment not found' });
    }

    const comment = snap.docs[0];
    const commentData = comment.data();

    if (String(commentData.userId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const videoId = commentData.videoId;
    await comment.ref.delete();

    if (videoId) {
      await db.collection('videos').doc(videoId).update({
        comments: admin.firestore.FieldValue.increment(-1),
        updatedAt: admin.firestore.Timestamp.now()
      });
    }

    res.json(successMessage('Comment deleted'));
  } catch (error) {
    console.error('Delete comment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/comments/:id/like - like a comment
app.post('/v1/comments/:id/like', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const commentRef = db.collectionGroup('comments').where('id', '==', id).limit(1);
    const snap = await commentRef.get();

    if (snap.empty) {
      return res.status(404).json({ error: 'Comment not found' });
    }

    const comment = snap.docs[0];
    const likeRef = comment.ref.collection('likes').doc(user.userId);
    const likeSnap = await likeRef.get();

    if (likeSnap.exists) {
      return res.json({ message: 'Already liked', likeCount: Number(comment.data().likeCount || 0) });
    }

    await db.runTransaction(async tx => {
      const updatedSnap = await tx.get(comment.ref);
      const data = updatedSnap.data() || {};
      const likeCount = Number(data.likeCount || 0);

      tx.set(likeRef, { userId: user.userId, createdAt: admin.firestore.Timestamp.now() });
      tx.update(comment.ref, {
        likeCount: likeCount + 1,
        updatedAt: admin.firestore.Timestamp.now()
      });
    });

    const updatedSnap = await comment.ref.get();
    res.json({
      ...successMessage('Comment liked'),
      likeCount: Number(updatedSnap.data()?.likeCount || 0)
    });
  } catch (error) {
    console.error('Like comment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/comments/:id/like - unlike a comment
app.delete('/v1/comments/:id/like', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const commentRef = db.collectionGroup('comments').where('id', '==', id).limit(1);
    const snap = await commentRef.get();

    if (snap.empty) {
      return res.status(404).json({ error: 'Comment not found' });
    }

    const comment = snap.docs[0];
    const likeRef = comment.ref.collection('likes').doc(user.userId);
    const likeSnap = await likeRef.get();

    if (!likeSnap.exists) {
      return res.json({ message: 'Not liked', likeCount: Number(comment.data().likeCount || 0) });
    }

    await db.runTransaction(async tx => {
      const updatedSnap = await tx.get(comment.ref);
      const data = updatedSnap.data() || {};
      const likeCount = Number(data.likeCount || 0);

      tx.delete(likeRef);
      tx.update(comment.ref, {
        likeCount: Math.max(0, likeCount - 1),
        updatedAt: admin.firestore.Timestamp.now()
      });
    });

    const updatedSnap = await comment.ref.get();
    res.json({
      ...successMessage('Comment like removed'),
      likeCount: Number(updatedSnap.data()?.likeCount || 0)
    });
  } catch (error) {
    console.error('Unlike comment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/comments/:id/replies - create a reply to a comment
app.post('/v1/comments/:id/replies', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const { text } = req.body || {};

    if (!text || typeof text !== 'string' || !text.trim()) {
      return res.status(400).json({ error: 'Reply text is required' });
    }

    const commentRef = db.collectionGroup('comments').where('id', '==', id).limit(1);
    const commentSnap = await commentRef.get();

    if (commentSnap.empty) {
      return res.status(404).json({ error: 'Parent comment not found' });
    }

    const parentComment = commentSnap.docs[0];
    const now = admin.firestore.Timestamp.now();
    const replyRef = parentComment.ref.collection('replies').doc();
    const replyData = {
      text: text.trim(),
      userId: user.userId,
      likeCount: 0,
      createdAt: now,
      updatedAt: now
    };

    await replyRef.set(replyData);

    await db.runTransaction(async tx => {
      const updatedSnap = await tx.get(parentComment.ref);
      const data = updatedSnap.data() || {};
      const replyCount = Number(data.replyCount || 0);
      tx.update(parentComment.ref, {
        replyCount: replyCount + 1,
        updatedAt: now
      });
    });

    const userData = await loadUserDocument(user.userId);
    res.status(201).json({
      reply: formatComment(replyRef.id, replyData, userData)
    });
  } catch (error) {
    console.error('Create reply error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/comments/:id/replies - list replies to a comment
app.get('/v1/comments/:id/replies', async (req, res) => {
  try {
    const { id } = req.params;
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    const commentRef = db.collectionGroup('comments').where('id', '==', id).limit(1);
    const commentSnap = await commentRef.get();

    if (commentSnap.empty) {
      return res.status(404).json({ error: 'Comment not found' });
    }

    const parentComment = commentSnap.docs[0];
    const repliesSnap = await parentComment.ref.collection('replies')
      .orderBy('createdAt', 'desc')
      .offset(offset)
      .limit(limit)
      .get();

    const userIds = repliesSnap.docs.map(doc => String(doc.get('userId') || ''));
    const usersMap = await loadUsersMap(userIds);

    const replies = repliesSnap.docs.map(doc => formatComment(doc.id, doc.data(), usersMap[String(doc.get('userId') || '')] || null));

    res.json({
      replies,
      pagination: {
        page,
        limit,
        hasMore: replies.length === limit
      }
    });
  } catch (error) {
    console.error('List replies error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Playlists API
// ─────────────────────────────────────────────────────────────────────────────

async function formatPlaylist(playlistId: string, playlistData: FirestoreData, userData: FirestoreData | null = null, includeVideos = false) {
  const base = {
    id: playlistId,
    title: playlistData.title || '',
    description: playlistData.description || null,
    thumbnailUrl: playlistData.thumbnailUrl || null,
    userId: playlistData.userId || null,
    isPublic: !!playlistData.isPublic,
    videoCount: Number(playlistData.videoCount || 0),
    createdAt: toIsoString(playlistData.createdAt),
    updatedAt: toIsoString(playlistData.updatedAt) || toIsoString(playlistData.createdAt)
  };

  if (userData) {
    (base as any).user = {
      id: userData.id || playlistData.userId,
      username: userData.username || '',
      displayName: userData.displayName || userData.name || userData.username || '',
      avatarUrl: userData.avatarUrl || null,
      verified: !!userData.verified
    };
  }

  return base;
}

// GET /v1/playlists - list user's playlists
app.get('/v1/playlists', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    const snap = await db.collection('playlists')
      .where('userId', '==', user.userId)
      .orderBy('updatedAt', 'desc')
      .offset(offset)
      .limit(limit)
      .get();

    const playlists = snap.docs.map(doc => formatPlaylist(doc.id, doc.data()));

    res.json({
      playlists,
      pagination: {
        page,
        limit,
        hasMore: playlists.length === limit
      }
    });
  } catch (error) {
    console.error('List playlists error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/playlists - create a playlist
app.post('/v1/playlists', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { title, description, isPublic } = req.body || {};

    if (!title || typeof title !== 'string' || !title.trim()) {
      return res.status(400).json({ error: 'Playlist title is required' });
    }

    const now = admin.firestore.Timestamp.now();
    const playlistRef = db.collection('playlists').doc();
    const playlistData = {
      title: title.trim(),
      description: description?.trim() || null,
      thumbnailUrl: null,
      userId: user.userId,
      isPublic: !!isPublic,
      videoCount: 0,
      createdAt: now,
      updatedAt: now
    };

    await playlistRef.set(playlistData);

    const userData = await loadUserDocument(user.userId);
    res.status(201).json({
      playlist: formatPlaylist(playlistRef.id, playlistData, userData)
    });
  } catch (error) {
    console.error('Create playlist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/playlists/:id - get a specific playlist with videos
app.get('/v1/playlists/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const requester = await verifyAppToken(req.headers.authorization);
    const playlistSnap = await db.collection('playlists').doc(id).get();

    if (!playlistSnap.exists) {
      return res.status(404).json({ error: 'Playlist not found' });
    }

    const playlistData = playlistSnap.data()!;
    const isOwner = requester?.userId === String(playlistData.userId || '');

    if (!playlistData.isPublic && !isOwner) {
      return res.status(403).json({ error: 'Playlist is private' });
    }

    const userData = await loadUserDocument(String(playlistData.userId || ''));

    const videosSnap = await db.collection('playlists').doc(id).collection('videos')
      .orderBy('addedAt', 'asc')
      .limit(200)
      .get();

    const videoIds = videosSnap.docs.map(doc => String(doc.get('videoId') || ''));
    const videosMap: Record<string, FirestoreData> = {};

    if (videoIds.length) {
      const videoSnaps = await Promise.all(videoIds.map(vid => db.collection('videos').doc(vid).get()));
      for (const snap of videoSnaps) {
        if (snap.exists) {
          videosMap[snap.id] = snap.data()!;
        }
      }
    }

    const videos = videosSnap.docs.map(doc => {
      const videoData = videosMap[String(doc.get('videoId') || '')];
      return videoData ? formatVideoSummary(doc.get('videoId') as string, videoData, userData) : null;
    }).filter(Boolean);

    res.json({
      playlist: formatPlaylist(id, playlistData, userData),
      videos
    });
  } catch (error) {
    console.error('Get playlist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/playlists/:id - update playlist metadata
app.put('/v1/playlists/:id', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const { title, description, isPublic } = req.body || {};

    const playlistRef = db.collection('playlists').doc(id);
    const snap = await playlistRef.get();

    if (!snap.exists) {
      return res.status(404).json({ error: 'Playlist not found' });
    }

    if (String(snap.data()!.userId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const patch: Record<string, any> = { updatedAt: admin.firestore.Timestamp.now() };
    if (title !== undefined) patch.title = title.trim();
    if (description !== undefined) patch.description = description?.trim() || null;
    if (isPublic !== undefined) patch.isPublic = !!isPublic;

    await playlistRef.set(patch, { merge: true });

    const updatedSnap = await playlistRef.get();
    const userData = await loadUserDocument(user.userId);

    res.json({
      playlist: formatPlaylist(id, updatedSnap.data()!, userData)
    });
  } catch (error) {
    console.error('Update playlist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/playlists/:id - delete a playlist
app.delete('/v1/playlists/:id', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const playlistRef = db.collection('playlists').doc(id);
    const snap = await playlistRef.get();

    if (!snap.exists) {
      return res.status(404).json({ error: 'Playlist not found' });
    }

    if (String(snap.data()!.userId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    await playlistRef.delete();

    res.json(successMessage('Playlist deleted'));
  } catch (error) {
    console.error('Delete playlist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/playlists/:id/videos - add a video to a playlist
app.post('/v1/playlists/:id/videos', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const { videoId } = req.body || {};

    if (!videoId) {
      return res.status(400).json({ error: 'videoId is required' });
    }

    const playlistRef = db.collection('playlists').doc(id);
    const playlistSnap = await playlistRef.get();

    if (!playlistSnap.exists) {
      return res.status(404).json({ error: 'Playlist not found' });
    }

    if (String(playlistSnap.data()!.userId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const playlistVideoRef = playlistRef.collection('videos').doc(videoId);
    const existing = await playlistVideoRef.get();

    if (existing.exists) {
      return res.json({ message: 'Video already in playlist' });
    }

    const now = admin.firestore.Timestamp.now();
    await playlistVideoRef.set({
      videoId,
      addedAt: now
    });

    await playlistRef.update({
      videoCount: admin.firestore.FieldValue.increment(1),
      updatedAt: now
    });

    res.status(201).json(successMessage('Video added to playlist'));
  } catch (error) {
    console.error('Add video to playlist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/playlists/:id/videos/:videoId - remove a video from a playlist
app.delete('/v1/playlists/:id/videos/:videoId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id, videoId } = req.params;

    const playlistRef = db.collection('playlists').doc(id);
    const playlistSnap = await playlistRef.get();

    if (!playlistSnap.exists) {
      return res.status(404).json({ error: 'Playlist not found' });
    }

    if (String(playlistSnap.data()!.userId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const playlistVideoRef = playlistRef.collection('videos').doc(videoId);
    const existing = await playlistVideoRef.get();

    if (!existing.exists) {
      return res.status(404).json({ error: 'Video not in playlist' });
    }

    await playlistVideoRef.delete();

    await playlistRef.update({
      videoCount: admin.firestore.FieldValue.increment(-1),
      updatedAt: admin.firestore.Timestamp.now()
    });

    res.json(successMessage('Video removed from playlist'));
  } catch (error) {
    console.error('Remove video from playlist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/playlists/:id/reorder - reorder videos in a playlist
app.put('/v1/playlists/:id/reorder', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const { videoIds } = req.body || {};

    if (!Array.isArray(videoIds) || videoIds.length === 0) {
      return res.status(400).json({ error: 'videoIds array is required' });
    }

    const playlistRef = db.collection('playlists').doc(id);
    const playlistSnap = await playlistRef.get();

    if (!playlistSnap.exists) {
      return res.status(404).json({ error: 'Playlist not found' });
    }

    if (String(playlistSnap.data()!.userId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const videosSnap = await playlistRef.collection('videos').get();
    const currentVideos = videosSnap.docs;
    const currentMap = new Map<string, FirestoreData>(currentVideos.map(doc => [doc.id, doc.data() as FirestoreData]));

    const now = admin.firestore.Timestamp.now();
    const batch = db.batch();

    videoIds.forEach((videoId: string, index: number) => {
      const videoRef = playlistRef.collection('videos').doc(videoId);
      const existing = currentMap.get(videoId);

      if (existing) {
        batch.set(videoRef, {
          videoId,
          addedAt: existing.addedAt || now,
          order: index,
          updatedAt: now
        }, { merge: true });
      }
    });

    await batch.commit();
    await playlistRef.update({ updatedAt: now });

    res.json(successMessage('Playlist reordered'));
  } catch (error) {
    console.error('Reorder playlist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Subscriptions API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/users/:userId/subscribe - subscribe to a user
app.post('/v1/users/:userId/subscribe', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId: targetUserId } = req.params;

    if (targetUserId === user.userId) {
      return res.status(400).json({ error: 'Cannot subscribe to yourself' });
    }

    const targetUserRef = db.collection('users').doc(targetUserId);
    const targetUserSnap = await targetUserRef.get();

    if (!targetUserSnap.exists) {
      return res.status(404).json({ error: 'User not found' });
    }

    const subscriptionRef = db.collection('users').doc(user.userId).collection('subscriptions').doc(targetUserId);
    const existing = await subscriptionRef.get();

    if (existing.exists) {
      return res.json({ message: 'Already subscribed' });
    }

    const now = admin.firestore.Timestamp.now();
    await subscriptionRef.set({
      targetUserId,
      subscribedAt: now
    });

    await db.runTransaction(async tx => {
      const subscriberRef = db.collection('users').doc(targetUserId).collection('subscribers').doc(user.userId);
      tx.set(subscriberRef, { userId: user.userId, subscribedAt: now });

      const targetSnap = await tx.get(targetUserRef);
      const data = targetSnap.data() || {};
      const currentCount = Number(data.subscriberCount || data.subscriber_count || 0);
      tx.update(targetUserRef, {
        subscriberCount: currentCount + 1,
        updatedAt: now
      });
    });

    res.status(201).json(successMessage('Subscribed'));
  } catch (error) {
    console.error('Subscribe error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/users/:userId/subscribe - unsubscribe from a user
app.delete('/v1/users/:userId/subscribe', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId: targetUserId } = req.params;

    const subscriptionRef = db.collection('users').doc(user.userId).collection('subscriptions').doc(targetUserId);
    const existing = await subscriptionRef.get();

    if (!existing.exists) {
      return res.json({ message: 'Not subscribed' });
    }

    const targetUserRef = db.collection('users').doc(targetUserId);
    const now = admin.firestore.Timestamp.now();

    await subscriptionRef.delete();

    await db.runTransaction(async tx => {
      const subscriberRef = db.collection('users').doc(targetUserId).collection('subscribers').doc(user.userId);
      tx.delete(subscriberRef);

      const targetSnap = await tx.get(targetUserRef);
      const data = targetSnap.data() || {};
      const currentCount = Number(data.subscriberCount || data.subscriber_count || 0);
      tx.update(targetUserRef, {
        subscriberCount: Math.max(0, currentCount - 1),
        updatedAt: now
      });
    });

    res.json(successMessage('Unsubscribed'));
  } catch (error) {
    console.error('Unsubscribe error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/subscriptions - list user's subscriptions
app.get('/v1/subscriptions', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    const snap = await db.collection('users').doc(user.userId).collection('subscriptions')
      .orderBy('subscribedAt', 'desc')
      .offset(offset)
      .limit(limit)
      .get();

    const targetUserIds = snap.docs.map(doc => String(doc.get('targetUserId') || ''));
    const usersMap = await loadUsersMap(targetUserIds);

    const subscriptions = snap.docs.map(doc => {
      const targetUserId = String(doc.get('targetUserId') || '');
      const userData = usersMap[targetUserId] || null;
      return userData ? formatCreatorSummary(targetUserId, userData) : null;
    }).filter(Boolean);

    res.json({
      subscriptions,
      pagination: {
        page,
        limit,
        hasMore: subscriptions.length === limit
      }
    });
  } catch (error) {
    console.error('List subscriptions error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/users/:userId/subscribers - list a user's subscribers
app.get('/v1/users/:userId/subscribers', async (req, res) => {
  try {
    const { userId } = req.params;
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    const snap = await db.collection('users').doc(userId).collection('subscribers')
      .orderBy('subscribedAt', 'desc')
      .offset(offset)
      .limit(limit)
      .get();

    const subscriberIds = snap.docs.map(doc => String(doc.get('userId') || ''));
    const usersMap = await loadUsersMap(subscriberIds);

    const subscribers = snap.docs.map(doc => {
      const subscriberId = String(doc.get('userId') || '');
      const userData = usersMap[subscriberId] || null;
      return userData ? formatCreatorSummary(subscriberId, userData) : null;
    }).filter(Boolean);

    res.json({
      subscribers,
      pagination: {
        page,
        limit,
        hasMore: subscribers.length === limit
      }
    });
  } catch (error) {
    console.error('List subscribers error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Watch History API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/history - add a video to watch history
app.post('/v1/history', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId, duration, position } = req.body || {};

    if (!videoId) {
      return res.status(400).json({ error: 'videoId is required' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const historyRef = db.collection('users').doc(user.userId).collection('history').doc(videoId);

    await historyRef.set({
      videoId,
      watchedAt: now,
      duration: typeof duration === 'number' ? duration : null,
      position: typeof position === 'number' ? position : null,
      updatedAt: now
    }, { merge: true });

    const userData = await loadUserDocument(user.userId);
    const videoData = videoSnap.data()!;
    res.status(201).json({
      historyItem: {
        videoId,
        video: formatVideoSummary(videoId, videoData, userData),
        watchedAt: now.toDate().toISOString(),
        duration,
        position
      }
    });
  } catch (error) {
    console.error('Add to history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/history - list watch history
app.get('/v1/history', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    const snap = await db.collection('users').doc(user.userId).collection('history')
      .orderBy('watchedAt', 'desc')
      .offset(offset)
      .limit(limit)
      .get();

    const videoIds = snap.docs.map(doc => String(doc.get('videoId') || ''));
    const videosMap: Record<string, FirestoreData> = {};

    if (videoIds.length) {
      const videoSnaps = await Promise.all(videoIds.map(vid => db.collection('videos').doc(vid).get()));
      for (const snap of videoSnaps) {
        if (snap.exists) {
          videosMap[snap.id] = snap.data()!;
        }
      }
    }

    const userData = await loadUserDocument(user.userId);
    const historyItems = snap.docs.map(doc => {
      const data = doc.data();
      const videoId = String(data.videoId || '');
      const videoData = videosMap[videoId];
      if (!videoData) return null;

      return {
        videoId,
        video: formatVideoSummary(videoId, videoData, userData),
        watchedAt: toIsoString(data.watchedAt),
        duration: typeof data.duration === 'number' ? data.duration : null,
        position: typeof data.position === 'number' ? data.position : null
      };
    }).filter(Boolean);

    res.json({
      history: historyItems,
      pagination: {
        page,
        limit,
        hasMore: historyItems.length === limit
      }
    });
  } catch (error) {
    console.error('List history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/history - clear all watch history
app.delete('/v1/history', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const snap = await db.collection('users').doc(user.userId).collection('history').get();
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();

    res.json(successMessage('Watch history cleared'));
  } catch (error) {
    console.error('Clear history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/history/:videoId - remove a specific video from history
app.delete('/v1/history/:videoId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const historyRef = db.collection('users').doc(user.userId).collection('history').doc(videoId);
    const snap = await historyRef.get();

    if (!snap.exists) {
      return res.status(404).json({ error: 'History item not found' });
    }

    await historyRef.delete();

    res.json(successMessage('Removed from history'));
  } catch (error) {
    console.error('Remove from history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`📺 Content service listening on port ${port}`);
});


