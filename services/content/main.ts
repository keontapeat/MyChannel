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

      await notifySubscribers(user.userId, creator.username || creator.displayName || 'A creator', videoRef.id, payload.title);
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

// POST /v1/comments/:id/report - report a comment for moderation
app.post('/v1/comments/:id/report', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const { reason } = req.body || {};

    if (!reason || typeof reason !== 'string') {
      return res.status(400).json({ error: 'reason is required' });
    }

    const commentRef = db.collectionGroup('comments').where('id', '==', id).limit(1);
    const commentSnap = await commentRef.get();

    if (commentSnap.empty) {
      return res.status(404).json({ error: 'Comment not found' });
    }

    const comment = commentSnap.docs[0];
    const reportRef = comment.ref.collection('reports').doc(user.userId);
    const existing = await reportRef.get();

    if (existing.exists) {
      return res.json({ message: 'Already reported' });
    }

    const now = admin.firestore.Timestamp.now();
    await reportRef.set({
      userId: user.userId,
      reason: reason.trim(),
      createdAt: now
    });

    await comment.ref.update({
      reportCount: admin.firestore.FieldValue.increment(1),
      updatedAt: now
    });

    res.status(201).json({ message: 'Comment reported' });
  } catch (error) {
    console.error('Report comment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/comments/:id/hide - hide a comment (moderation action)
app.post('/v1/comments/:id/hide', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const { reason } = req.body || {};

    const commentRef = db.collectionGroup('comments').where('id', '==', id).limit(1);
    const commentSnap = await commentRef.get();

    if (commentSnap.empty) {
      return res.status(404).json({ error: 'Comment not found' });
    }

    const comment = commentSnap.docs[0];
    const commentData = comment.data();

    if (String(commentData.userId || '') === user.userId) {
      return res.status(403).json({ error: 'Cannot hide your own comment' });
    }

    const now = admin.firestore.Timestamp.now();
    await comment.ref.update({
      hidden: true,
      hiddenBy: user.userId,
      hiddenReason: reason || null,
      hiddenAt: now,
      updatedAt: now
    });

    res.json({ message: 'Comment hidden' });
  } catch (error) {
    console.error('Hide comment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/comments/:id/unhide - unhide a comment (moderation action)
app.post('/v1/comments/:id/unhide', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;

    const commentRef = db.collectionGroup('comments').where('id', '==', id).limit(1);
    const commentSnap = await commentRef.get();

    if (commentSnap.empty) {
      return res.status(404).json({ error: 'Comment not found' });
    }

    const now = admin.firestore.Timestamp.now();
    await commentRef.update({
      hidden: false,
      hiddenBy: null,
      hiddenReason: null,
      hiddenAt: null,
      updatedAt: now
    });

    res.json({ message: 'Comment unhidden' });
  } catch (error) {
    console.error('Unhide comment error:', error);
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

// POST /v1/playlists/:id/generate-thumbnail - auto-generate playlist thumbnail from first video
app.post('/v1/playlists/:id/generate-thumbnail', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;

    const playlistRef = db.collection('playlists').doc(id);
    const playlistSnap = await playlistRef.get();

    if (!playlistSnap.exists) {
      return res.status(404).json({ error: 'Playlist not found' });
    }

    if (String(playlistSnap.data()!.userId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const videosSnap = await playlistRef.collection('videos')
      .orderBy('order', 'asc')
      .limit(1)
      .get();

    if (videosSnap.empty) {
      return res.status(400).json({ error: 'Playlist is empty' });
    }

    const firstVideoId = String(videosSnap.docs[0].get('videoId') || '');
    const videoSnap = await db.collection('videos').doc(firstVideoId).get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'First video not found' });
    }

    const videoData = videoSnap.data()!;
    const thumbnailUrl = videoData.thumbnailUrl || null;

    if (!thumbnailUrl) {
      return res.status(400).json({ error: 'First video has no thumbnail' });
    }

    await playlistRef.update({
      thumbnailUrl,
      thumbnailGeneratedAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now()
    });

    res.json({
      thumbnailUrl,
      message: 'Thumbnail generated from first video'
    });
  } catch (error) {
    console.error('Generate thumbnail error:', error);
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

// POST /v1/history - add to watch history
app.post('/v1/history', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId, duration, position } = req.body || {};

    if (!videoId) {
      return res.status(400).json({ error: 'videoId is required' });
    }

    const videoSnap = await db.collection('videos').doc(videoId).get();
    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const historyRef = db.collection('users').doc(user.userId).collection('history').doc(videoId);

    await historyRef.set({
      videoId,
      watchedAt: now,
      duration: typeof duration === 'number' ? duration : null,
      position: typeof position === 'number' ? position : null
    }, { merge: true });

    res.json(successMessage('Added to history'));
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

// POST /v1/activity/track - track user activity (watch time, engagement)
app.post('/v1/activity/track', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId, action, duration, timestamp, sessionId } = req.body || {};

    if (!videoId || !action) {
      return res.status(400).json({ error: 'videoId and action are required' });
    }

    const videoSnap = await db.collection('videos').doc(videoId).get();
    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const ts = timestamp ? admin.firestore.Timestamp.fromDate(new Date(timestamp)) : now;
    const sid = sessionId || `session_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;

    const activityRef = db.collection('users').doc(user.userId).collection('activity').doc();
    await activityRef.set({
      videoId,
      action,
      duration: typeof duration === 'number' ? duration : null,
      timestamp: ts,
      sessionId: sid,
      userId: user.userId,
      createdAt: now
    });

    res.json({ activityId: activityRef.id, sessionId: sid });
  } catch (error) {
    console.error('Track activity error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/activity/summary - get user activity summary
app.get('/v1/activity/summary', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const days = parseInt(req.query.days as string) || 7;
    const now = admin.firestore.Timestamp.now();
    const startDate = admin.firestore.Timestamp.fromDate(new Date(Date.now() - days * 24 * 60 * 60 * 1000));

    const activitySnap = await db.collection('users').doc(user.userId).collection('activity')
      .where('timestamp', '>=', startDate)
      .orderBy('timestamp', 'desc')
      .limit(500)
      .get();

    const totalWatchTime = activitySnap.docs.reduce((sum, doc) => {
      const duration = doc.get('duration');
      return sum + (typeof duration === 'number' ? duration : 0);
    }, 0);

    const videosWatched = new Set(activitySnap.docs.map(doc => String(doc.get('videoId') || '')));

    const actionCounts: Record<string, number> = {};
    activitySnap.docs.forEach(doc => {
      const action = String(doc.get('action') || 'unknown');
      actionCounts[action] = (actionCounts[action] || 0) + 1;
    });

    const dailyActivity: Record<string, { watchTime: number; videos: number }> = {};
    for (let i = 0; i < days; i++) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      const dateStr = date.toISOString().split('T')[0];
      dailyActivity[dateStr] = { watchTime: 0, videos: 0 };
    }

    activitySnap.docs.forEach(doc => {
      const timestamp = doc.get('timestamp') as admin.firestore.Timestamp;
      if (timestamp) {
        const dateStr = timestamp.toDate().toISOString().split('T')[0];
        if (dailyActivity[dateStr]) {
          const duration = doc.get('duration');
          dailyActivity[dateStr].watchTime += typeof duration === 'number' ? duration : 0;
          dailyActivity[dateStr].videos += 1;
        }
      }
    });

    res.json({
      totalWatchTime,
      totalVideosWatched: videosWatched.size,
      totalActions: activitySnap.size,
      actionCounts,
      dailyActivity,
      period: `${days} days`
    });
  } catch (error) {
    console.error('Activity summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Notifications API
// ─────────────────────────────────────────────────────────────────────────────

async function formatNotification(notificationId: string, notificationData: FirestoreData) {
  return {
    id: notificationId,
    type: notificationData.type || 'general',
    title: notificationData.title || '',
    body: notificationData.body || '',
    data: notificationData.data || null,
    read: !!notificationData.read,
    createdAt: toIsoString(notificationData.createdAt),
    readAt: toIsoString(notificationData.readAt) || null
  };
}

async function notifySubscribers(creatorId: string, creatorName: string, videoId: string, videoTitle: string) {
  try {
    const subscribersSnap = await db.collection('users').doc(creatorId).collection('subscribers')
      .limit(500)
      .get();

    const now = admin.firestore.Timestamp.now();
    const batch = db.batch();

    subscribersSnap.docs.forEach(doc => {
      const subscriberId = doc.id;
      const notificationRef = db.collection('users').doc(subscriberId).collection('notifications').doc();
      batch.set(notificationRef, {
        type: 'new_video',
        title: `${creatorName} uploaded a new video`,
        body: videoTitle,
        data: { creatorId, videoId, creatorName, videoTitle },
        read: false,
        createdAt: now,
        readAt: null
      });
    });

    await batch.commit();
  } catch (error) {
    console.error('Notify subscribers error:', error);
  }
}

// GET /v1/notifications - list user's notifications
app.get('/v1/notifications', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;
    const unreadOnly = req.query.unreadOnly === 'true';

    let query = db.collection('users').doc(user.userId).collection('notifications')
      .orderBy('createdAt', 'desc');

    if (unreadOnly) {
      query = query.where('read', '==', false);
    }

    const snap = await query.offset(offset).limit(limit).get();

    const notifications = snap.docs.map(doc => formatNotification(doc.id, doc.data()));

    res.json({
      notifications,
      pagination: {
        page,
        limit,
        hasMore: notifications.length === limit
      }
    });
  } catch (error) {
    console.error('List notifications error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/notifications - create a notification (internal/system use)
app.post('/v1/notifications', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { type, title, body, data, targetUserId } = req.body || {};

    if (!title || typeof title !== 'string') {
      return res.status(400).json({ error: 'title is required' });
    }

    const now = admin.firestore.Timestamp.now();
    const notificationRef = db.collection('users').doc(user.userId).collection('notifications').doc();
    const notificationData = {
      type: type || 'general',
      title,
      body: body || null,
      data: data || null,
      read: false,
      createdAt: now,
      readAt: null
    };

    await notificationRef.set(notificationData);

    res.status(201).json({
      notification: formatNotification(notificationRef.id, notificationData)
    });
  } catch (error) {
    console.error('Create notification error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/notifications/:id/read - mark notification as read
app.put('/v1/notifications/:id/read', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const notificationRef = db.collection('users').doc(user.userId).collection('notifications').doc(id);
    const snap = await notificationRef.get();

    if (!snap.exists) {
      return res.status(404).json({ error: 'Notification not found' });
    }

    await notificationRef.update({
      read: true,
      readAt: admin.firestore.Timestamp.now()
    });

    const updatedSnap = await notificationRef.get();
    res.json({
      notification: formatNotification(id, updatedSnap.data()!)
    });
  } catch (error) {
    console.error('Mark notification read error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/notifications/:id - delete a notification
app.delete('/v1/notifications/:id', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const notificationRef = db.collection('users').doc(user.userId).collection('notifications').doc(id);
    const snap = await notificationRef.get();

    if (!snap.exists) {
      return res.status(404).json({ error: 'Notification not found' });
    }

    await notificationRef.delete();

    res.json(successMessage('Notification deleted'));
  } catch (error) {
    console.error('Delete notification error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/notifications/read-all - mark all notifications as read
app.put('/v1/notifications/read-all', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const snap = await db.collection('users').doc(user.userId).collection('notifications')
      .where('read', '==', false)
      .limit(100)
      .get();

    const batch = db.batch();
    const now = admin.firestore.Timestamp.now();

    snap.docs.forEach(doc => {
      batch.update(doc.ref, {
        read: true,
        readAt: now
      });
    });

    await batch.commit();

    res.json({
      ...successMessage('All notifications marked as read'),
      count: snap.size
    });
  } catch (error) {
    console.error('Mark all read error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/notifications/unread-count - get unread notification count
app.get('/v1/notifications/unread-count', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const snap = await db.collection('users').doc(user.userId).collection('notifications')
      .where('read', '==', false)
      .count()
      .get();

    res.json({
      unreadCount: snap.data().count
    });
  } catch (error) {
    console.error('Get unread count error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/notifications/preferences - get user's notification preferences
app.get('/v1/notifications/preferences', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const snap = await db.collection('users').doc(user.userId).collection('settings').doc('notifications').get();

    const defaultPreferences = {
      newVideos: true,
      comments: true,
      replies: true,
      likes: false,
      subscriptions: true,
      mentions: true,
      emailNotifications: false,
      pushNotifications: true
    };

    const preferences = snap.exists ? snap.data()! : defaultPreferences;

    res.json({ preferences });
  } catch (error) {
    console.error('Get notification preferences error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/notifications/preferences - update user's notification preferences
app.put('/v1/notifications/preferences', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { newVideos, comments, replies, likes, subscriptions, mentions, emailNotifications, pushNotifications } = req.body || {};

    const patch: Record<string, any> = {
      updatedAt: admin.firestore.Timestamp.now()
    };

    if (newVideos !== undefined) patch.newVideos = !!newVideos;
    if (comments !== undefined) patch.comments = !!comments;
    if (replies !== undefined) patch.replies = !!replies;
    if (likes !== undefined) patch.likes = !!likes;
    if (subscriptions !== undefined) patch.subscriptions = !!subscriptions;
    if (mentions !== undefined) patch.mentions = !!mentions;
    if (emailNotifications !== undefined) patch.emailNotifications = !!emailNotifications;
    if (pushNotifications !== undefined) patch.pushNotifications = !!pushNotifications;

    await db.collection('users').doc(user.userId).collection('settings').doc('notifications').set(patch, { merge: true });

    const updatedSnap = await db.collection('users').doc(user.userId).collection('settings').doc('notifications').get();
    res.json({
      preferences: updatedSnap.exists ? updatedSnap.data()! : patch
    });
  } catch (error) {
    console.error('Update notification preferences error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Social Share API
// ─────────────────────────────────────────────────────────────────────────────

// GET /v1/videos/:id/share - get share link and embed code
app.get('/v1/videos/:id/share', async (req, res) => {
  try {
    const { id } = req.params;

    const videoSnap = await db.collection('videos').doc(id).get();
    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;
    const baseUrl = process.env.BASE_URL || 'https://mychannel.live';
    const shareUrl = `${baseUrl}/v/${id}`;
    const embedUrl = `${baseUrl}/embed/${id}`;

    const embedCode = `<iframe width="560" height="315" src="${embedUrl}" title="${videoData.title || 'Video'}" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>`;

    const compactEmbed = `<iframe src="${embedUrl}" width="100%" height="100%" frameborder="0" allowfullscreen></iframe>`;

    res.json({
      shareUrl,
      embedUrl,
      embedCode,
      compactEmbed,
      videoId: id,
      title: videoData.title || ''
    });
  } catch (error) {
    console.error('Get share error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/videos/:id/share/custom - generate custom embed with options
app.post('/v1/videos/:id/share/custom', async (req, res) => {
  try {
    const { id } = req.params;
    const { width, height, autoplay, controls, loop, muted } = req.body || {};

    const videoSnap = await db.collection('videos').doc(id).get();
    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;
    const baseUrl = process.env.BASE_URL || 'https://mychannel.live';
    const embedUrl = `${baseUrl}/embed/${id}`;

    const w = width || '100%';
    const h = height || '100%';
    const autoplayAttr = autoplay ? 'autoplay' : '';
    const controlsAttr = controls !== false ? 'controls' : '';
    const loopAttr = loop ? 'loop' : '';
    const mutedAttr = muted ? 'muted' : '';

    const embedCode = `<iframe src="${embedUrl}?autoplay=${autoplay ? 1 : 0}&loop=${loop ? 1 : 0}&muted=${muted ? 1 : 0}" width="${w}" height="${h}" frameborder="0" ${autoplayAttr} ${controlsAttr} ${loopAttr} ${mutedAttr} allowfullscreen></iframe>`;

    res.json({
      embedCode,
      embedUrl,
      videoId: id,
      title: videoData.title || '',
      options: { width: w, height: h, autoplay, controls, loop, muted }
    });
  } catch (error) {
    console.error('Custom share error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Advanced Analytics API
// ─────────────────────────────────────────────────────────────────────────────

// GET /v1/videos/:id/analytics - get detailed video analytics
app.get('/v1/videos/:id/analytics', async (req, res) => {
  try {
    const user = await verifyAppToken(req.headers.authorization);
    const { id } = req.params;

    const videoSnap = await db.collection('videos').doc(id).get();
    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (user && String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const videoId = id;
    const now = admin.firestore.Timestamp.now();
    const sevenDaysAgo = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 7 * 24 * 60 * 60 * 1000));

    const viewsSnap = await db.collection('events').where('videoId', '==', videoId).get();
    const totalViews = viewsSnap.size;

    const recentViewsSnap = await db.collection('events')
      .where('videoId', '==', videoId)
      .where('timestamp', '>=', sevenDaysAgo)
      .get();

    const dailyViews: Record<string, number> = {};
    for (let i = 0; i < 7; i++) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      const dateStr = date.toISOString().split('T')[0];
      dailyViews[dateStr] = 0;
    }

    recentViewsSnap.docs.forEach(doc => {
      const timestamp = doc.get('timestamp') as admin.firestore.Timestamp;
      if (timestamp) {
        const dateStr = timestamp.toDate().toISOString().split('T')[0];
        if (dailyViews.hasOwnProperty(dateStr)) {
          dailyViews[dateStr]++;
        }
      }
    });

    const likesSnap = await db.collection('videos').doc(videoId).collection('likes').get();
    const totalLikes = likesSnap.size;

    const dislikesSnap = await db.collection('videos').doc(videoId).collection('dislikes').get();
    const totalDislikes = dislikesSnap.size;

    const commentsSnap = await db.collection('videos').doc(videoId).collection('comments').get();
    const totalComments = commentsSnap.size;

    const sharesSnap = await db.collection('videos').doc(videoId).collection('shares').get();
    const totalShares = sharesSnap.size;

    res.json({
      videoId,
      totalViews,
      totalLikes,
      totalDislikes,
      totalComments,
      totalShares,
      engagementRate: totalViews > 0 ? ((totalLikes + totalComments + totalShares) / totalViews * 100).toFixed(2) : '0',
      dailyViews,
      period: '7 days',
      updatedAt: now.toDate().toISOString()
    });
  } catch (error) {
    console.error('Get video analytics error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/analytics/demographics - get video demographics (stubbed for now)
app.get('/v1/analytics/demographics', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.query;

    if (!videoId) {
      return res.status(400).json({ error: 'videoId is required' });
    }

    const videoSnap = await db.collection('videos').doc(String(videoId)).get();
    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    res.json({
      videoId,
      ageGroups: [
        { range: '13-17', percentage: 15 },
        { range: '18-24', percentage: 35 },
        { range: '25-34', percentage: 25 },
        { range: '35-44', percentage: 15 },
        { range: '45+', percentage: 10 }
      ],
      gender: [
        { gender: 'male', percentage: 55 },
        { gender: 'female', percentage: 45 }
      ],
      topCountries: [
        { country: 'US', percentage: 40 },
        { country: 'UK', percentage: 15 },
        { country: 'CA', percentage: 10 },
        { country: 'AU', percentage: 8 },
        { country: 'Other', percentage: 27 }
      ]
    });
  } catch (error) {
    console.error('Get demographics error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Recommendations Engine
// ─────────────────────────────────────────────────────────────────────────────

// GET /v1/recommendations - get personalized video recommendations
app.get('/v1/recommendations', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const excludeWatched = req.query.excludeWatched !== 'false';

    const historySnap = await db.collection('users').doc(user.userId).collection('history')
      .orderBy('watchedAt', 'desc')
      .limit(50)
      .get();

    const watchedVideoIds = new Set(historySnap.docs.map(doc => String(doc.get('videoId') || '')));
    const watchedVideosData: FirestoreData[] = [];

    for (const doc of historySnap.docs) {
      const videoId = String(doc.get('videoId') || '');
      const videoSnap = await db.collection('videos').doc(videoId).get();
      if (videoSnap.exists) {
        watchedVideosData.push(videoSnap.data()!);
      }
    }

    const categories = new Set<string>();
    const tags = new Set<string>();
    const creators = new Set<string>();

    watchedVideosData.forEach(video => {
      if (video.category) categories.add(video.category);
      if (Array.isArray(video.tags)) {
        video.tags.forEach(tag => tags.add(tag));
      }
      if (video.ownerId) creators.add(video.ownerId);
    });

    const recommendedVideos: FirestoreData[] = [];
    const recommendedVideoIds = new Set<string>();

    const videosSnap = await db.collection('videos')
      .where('status', '==', 'published')
      .orderBy('views', 'desc')
      .limit(200)
      .get();

    for (const doc of videosSnap.docs) {
      const video = doc.data()!;
      const videoId = doc.id;

      if (excludeWatched && watchedVideoIds.has(videoId)) continue;
      if (String(video.ownerId || '') === user.userId) continue;
      if (recommendedVideoIds.has(videoId)) continue;

      let score = 0;

      if (video.category && categories.has(video.category)) score += 3;
      if (Array.isArray(video.tags)) {
        video.tags.forEach(tag => {
          if (tags.has(tag)) score += 2;
        });
      }
      if (video.ownerId && creators.has(video.ownerId)) score += 4;
      score += Math.log10(Number(video.views || 1)) * 0.5;

      if (score > 0) {
        recommendedVideos.push({ ...video, _score: score });
        recommendedVideoIds.add(videoId);
      }
    }

    recommendedVideos.sort((a, b) => (b._score || 0) - (a._score || 0));

    const userIds = recommendedVideos.slice(0, limit).map(v => String(v.ownerId || ''));
    const usersMap = await loadUsersMap(userIds);

    const recommendations = recommendedVideos.slice(0, limit).map(video => {
      const userData = usersMap[String(video.ownerId || '')] || null;
      return formatVideoSummary('', video, userData);
    });

    res.json({
      recommendations,
      algorithm: 'collaborative_filtering',
      basedOn: {
        categoriesWatched: Array.from(categories),
        tagsWatched: Array.from(tags).slice(0, 10),
        creatorsWatched: Array.from(creators).slice(0, 5),
        videosWatched: watchedVideoIds.size
      }
    });
  } catch (error) {
    console.error('Get recommendations error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:id/related - get related videos for a specific video
app.get('/v1/videos/:id/related', async (req, res) => {
  try {
    const { id } = req.params;
    const limit = Math.min(parseInt(req.query.limit as string) || 10, 30);

    const videoSnap = await db.collection('videos').doc(id).get();
    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;
    const category = videoData.category || '';
    const tags = Array.isArray(videoData.tags) ? videoData.tags : [];
    const ownerId = videoData.ownerId || '';

    const relatedVideos: FirestoreData[] = [];
    const relatedVideoIds = new Set<string>();

    const videosSnap = await db.collection('videos')
      .where('status', '==', 'published')
      .orderBy('views', 'desc')
      .limit(100)
      .get();

    for (const doc of videosSnap.docs) {
      const video = doc.data()!;
      const videoId = doc.id;

      if (videoId === id) continue;
      if (String(video.ownerId || '') === ownerId) continue;
      if (relatedVideoIds.has(videoId)) continue;

      let score = 0;

      if (video.category === category) score += 3;
      if (Array.isArray(video.tags)) {
        const commonTags = video.tags.filter(tag => tags.includes(tag));
        score += commonTags.length * 2;
      }
      score += Math.log10(Number(video.views || 1)) * 0.3;

      if (score > 0) {
        relatedVideos.push({ ...video, _score: score });
        relatedVideoIds.add(videoId);
      }
    }

    relatedVideos.sort((a, b) => (b._score || 0) - (a._score || 0));

    const userIds = relatedVideos.slice(0, limit).map(v => String(v.ownerId || ''));
    const usersMap = await loadUsersMap(userIds);

    const related = relatedVideos.slice(0, limit).map(video => {
      const userData = usersMap[String(video.ownerId || '')] || null;
      return formatVideoSummary('', video, userData);
    });

    res.json({
      related,
      videoId: id,
      algorithm: 'content_based'
    });
  } catch (error) {
    console.error('Get related videos error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/discover/trending - get trending videos
app.get('/v1/discover/trending', async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const category = req.query.category as string || null;
    const period = (req.query.period as string) || 'week';

    const now = admin.firestore.Timestamp.now();
    let startDate: admin.firestore.Timestamp;

    if (period === 'day') {
      startDate = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 24 * 60 * 60 * 1000));
    } else if (period === 'week') {
      startDate = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 7 * 24 * 60 * 60 * 1000));
    } else if (period === 'month') {
      startDate = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000));
    } else {
      startDate = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 7 * 24 * 60 * 60 * 1000));
    }

    let query = db.collection('videos')
      .where('status', '==', 'published')
      .where('publishedAt', '>=', startDate)
      .orderBy('views', 'desc');

    if (category) {
      query = query.where('category', '==', category);
    }

    const snap = await query.limit(limit * 2).get();

    const userIds = snap.docs.map(doc => String(doc.get('ownerId') || ''));
    const usersMap = await loadUsersMap(userIds);

    const trending = snap.docs.slice(0, limit).map(doc => {
      const data = doc.data();
      const userData = usersMap[String(data.ownerId || '')] || null;
      return formatVideoSummary(doc.id, data, userData);
    });

    res.json({
      trending,
      category: category || 'all',
      period,
      count: trending.length
    });
  } catch (error) {
    console.error('Get trending error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/discover/feed - get personalized discovery feed
app.get('/v1/discover/feed', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);

    const subscriptionsSnap = await db.collection('users').doc(user.userId).collection('subscriptions')
      .limit(50)
      .get();

    const subscribedCreatorIds = new Set(subscriptionsSnap.docs.map(doc => String(doc.get('creatorId') || '')));

    const videosSnap = await db.collection('videos')
      .where('status', '==', 'published')
      .orderBy('publishedAt', 'desc')
      .limit(200)
      .get();

    const feedVideos: FirestoreData[] = [];

    for (const doc of videosSnap.docs) {
      const video = doc.data();
      const videoId = doc.id;
      const ownerId = String(video.ownerId || '');

      if (ownerId === user.userId) continue;

      let score = 0;

      if (subscribedCreatorIds.has(ownerId)) score += 5;

      const likesSnap = await db.collection('videos').doc(videoId).collection('likes').doc(user.userId).get();
      if (likesSnap.exists) score += 2;

      score += Math.log10(Number(video.views || 1)) * 0.3;

      if (score > 0) {
        feedVideos.push({ ...video, _score: score });
      }
    }

    feedVideos.sort((a, b) => (b._score || 0) - (a._score || 0));

    const userIds = feedVideos.slice(0, limit).map(v => String(v.ownerId || ''));
    const usersMap = await loadUsersMap(userIds);

    const feed = feedVideos.slice(0, limit).map(video => {
      const userData = usersMap[String(video.ownerId || '')] || null;
      return formatVideoSummary('', video, userData);
    });

    res.json({
      feed,
      algorithm: 'personalized',
      subscriptionsCount: subscribedCreatorIds.size
    });
  } catch (error) {
    console.error('Get feed error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Chapters API
// ─────────────────────────────────────────────────────────────────────────────

// GET /v1/videos/:id/chapters - list video chapters
app.get('/v1/videos/:id/chapters', async (req, res) => {
  try {
    const { id } = req.params;

    const videoSnap = await db.collection('videos').doc(id).get();
    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;
    const chapters = Array.isArray(videoData.chapters) ? videoData.chapters : [];

    res.json({
      videoId: id,
      chapters: chapters.map((chapter: any, index: number) => ({
        index,
        title: chapter.title || '',
        timestamp: typeof chapter.timestamp === 'number' ? chapter.timestamp : (chapter.timestamp ? Number(chapter.timestamp) : 0),
        thumbnail: chapter.thumbnail || null
      }))
    });
  } catch (error) {
    console.error('Get chapters error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/videos/:id/chapters - set/update video chapters
app.put('/v1/videos/:id/chapters', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const { chapters } = req.body || {};

    if (!Array.isArray(chapters)) {
      return res.status(400).json({ error: 'chapters array is required' });
    }

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const validatedChapters = chapters.map((chapter: any) => ({
      title: chapter.title || '',
      timestamp: typeof chapter.timestamp === 'number' ? chapter.timestamp : (chapter.timestamp ? Number(chapter.timestamp) : 0),
      thumbnail: chapter.thumbnail || null
    })).sort((a, b) => a.timestamp - b.timestamp);

    await videoRef.update({
      chapters: validatedChapters,
      updatedAt: admin.firestore.Timestamp.now()
    });

    res.json({
      videoId: id,
      chapters: validatedChapters.map((chapter: any, index: number) => ({
        index,
        title: chapter.title,
        timestamp: chapter.timestamp,
        thumbnail: chapter.thumbnail
      }))
    });
  } catch (error) {
    console.error('Update chapters error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/videos/:id/chapters - delete all chapters
app.delete('/v1/videos/:id/chapters', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    await videoRef.update({
      chapters: [],
      updatedAt: admin.firestore.Timestamp.now()
    });

    res.json({ message: 'All chapters deleted' });
  } catch (error) {
    console.error('Delete chapters error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Captions/Subtitles API
// ─────────────────────────────────────────────────────────────────────────────

// GET /v1/videos/:id/captions - list video captions
app.get('/v1/videos/:id/captions', async (req, res) => {
  try {
    const { id } = req.params;

    const videoSnap = await db.collection('videos').doc(id).get();
    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const captionsSnap = await db.collection('videos').doc(id).collection('captions').get();

    const captions = captionsSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        language: data.language || 'en',
        label: data.label || data.language || 'English',
        source: data.source || 'manual',
        url: data.url || null,
        isAutoGenerated: !!data.isAutoGenerated,
        createdAt: toIsoString(data.createdAt)
      };
    });

    res.json({
      videoId: id,
      captions
    });
  } catch (error) {
    console.error('Get captions error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/videos/:id/captions - upload a caption file
app.post('/v1/videos/:id/captions', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const { language, label, url, isAutoGenerated } = req.body || {};

    if (!language || typeof language !== 'string') {
      return res.status(400).json({ error: 'language is required' });
    }

    if (!url || typeof url !== 'string') {
      return res.status(400).json({ error: 'url is required' });
    }

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const captionRef = db.collection('videos').doc(id).collection('captions').doc();

    await captionRef.set({
      language: language.trim().toLowerCase(),
      label: label || language,
      url: url.trim(),
      source: 'manual',
      isAutoGenerated: !!isAutoGenerated,
      createdAt: now,
      createdBy: user.userId
    });

    const captionSnap = await captionRef.get();

    res.status(201).json({
      caption: {
        id: captionRef.id,
        language: captionSnap.data()!.language,
        label: captionSnap.data()!.label,
        source: captionSnap.data()!.source,
        url: captionSnap.data()!.url,
        isAutoGenerated: captionSnap.data()!.isAutoGenerated,
        createdAt: toIsoString(captionSnap.data()!.createdAt)
      }
    });
  } catch (error) {
    console.error('Upload caption error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/videos/:id/captions/:captionId - update a caption
app.put('/v1/videos/:id/captions/:captionId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id, captionId } = req.params;
    const { label, url } = req.body || {};

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const captionRef = db.collection('videos').doc(id).collection('captions').doc(captionId);
    const captionSnap = await captionRef.get();

    if (!captionSnap.exists) {
      return res.status(404).json({ error: 'Caption not found' });
    }

    const patch: Record<string, any> = {
      updatedAt: admin.firestore.Timestamp.now()
    };

    if (label) patch.label = label;
    if (url) patch.url = url;

    await captionRef.update(patch);

    const updatedSnap = await captionRef.get();

    res.json({
      caption: {
        id: captionRef.id,
        language: updatedSnap.data()!.language,
        label: updatedSnap.data()!.label,
        source: updatedSnap.data()!.source,
        url: updatedSnap.data()!.url,
        isAutoGenerated: updatedSnap.data()!.isAutoGenerated,
        createdAt: toIsoString(updatedSnap.data()!.createdAt)
      }
    });
  } catch (error) {
    console.error('Update caption error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/videos/:id/captions/:captionId - delete a caption
app.delete('/v1/videos/:id/captions/:captionId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id, captionId } = req.params;

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const captionRef = db.collection('videos').doc(id).collection('captions').doc(captionId);
    const captionSnap = await captionRef.get();

    if (!captionSnap.exists) {
      return res.status(404).json({ error: 'Caption not found' });
    }

    await captionRef.delete();

    res.json({ message: 'Caption deleted' });
  } catch (error) {
    console.error('Delete caption error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Channel Customization API
// ─────────────────────────────────────────────────────────────────────────────

// GET /v1/users/:userId/channel - get channel customization
app.get('/v1/users/:userId/channel', async (req, res) => {
  try {
    const { userId } = req.params;

    const userSnap = await db.collection('users').doc(userId).get();
    if (!userSnap.exists) {
      return res.status(404).json({ error: 'User not found' });
    }

    const userData = userSnap.data()!;

    res.json({
      userId,
      channel: {
        bannerUrl: userData.bannerUrl || null,
        avatarUrl: userData.avatarUrl || null,
        description: userData.description || '',
        keywords: Array.isArray(userData.keywords) ? userData.keywords : [],
        customUrl: userData.customUrl || null,
        country: userData.country || null
      }
    });
  } catch (error) {
    console.error('Get channel error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/users/:userId/channel - update channel customization
app.put('/v1/users/:userId/channel', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { bannerUrl, avatarUrl, description, keywords, customUrl, country } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const patch: Record<string, any> = {
      updatedAt: admin.firestore.Timestamp.now()
    };

    if (bannerUrl) patch.bannerUrl = bannerUrl;
    if (avatarUrl) patch.avatarUrl = avatarUrl;
    if (description !== undefined) patch.description = description;
    if (Array.isArray(keywords)) patch.keywords = keywords;
    if (customUrl) patch.customUrl = customUrl;
    if (country) patch.country = country;

    await db.collection('users').doc(userId).set(patch, { merge: true });

    const updatedSnap = await db.collection('users').doc(userId).get();
    const updatedData = updatedSnap.data()!;

    res.json({
      userId,
      channel: {
        bannerUrl: updatedData.bannerUrl || null,
        avatarUrl: updatedData.avatarUrl || null,
        description: updatedData.description || '',
        keywords: Array.isArray(updatedData.keywords) ? updatedData.keywords : [],
        customUrl: updatedData.customUrl || null,
        country: updatedData.country || null
      }
    });
  } catch (error) {
    console.error('Update channel error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Community Posts API
// ─────────────────────────────────────────────────────────────────────────────

// GET /v1/users/:userId/community - list community posts
app.get('/v1/users/:userId/community', async (req, res) => {
  try {
    const { userId } = req.params;
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    const postsSnap = await db.collection('users').doc(userId).collection('community')
      .orderBy('createdAt', 'desc')
      .offset(offset)
      .limit(limit)
      .get();

    const posts = postsSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        content: data.content || '',
        imageUrl: data.imageUrl || null,
        videoId: data.videoId || null,
        likes: Number(data.likeCount || 0),
        comments: Number(data.commentCount || 0),
        createdAt: toIsoString(data.createdAt),
        updatedAt: toIsoString(data.updatedAt)
      };
    });

    res.json({
      userId,
      posts,
      pagination: {
        page,
        limit,
        hasMore: posts.length === limit
      }
    });
  } catch (error) {
    console.error('List community posts error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/users/:userId/community - create a community post
app.post('/v1/users/:userId/community', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { content, imageUrl, videoId } = req.body || {};

    if (!content || typeof content !== 'string') {
      return res.status(400).json({ error: 'content is required' });
    }

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const postRef = db.collection('users').doc(userId).collection('community').doc();

    await postRef.set({
      content: content.trim(),
      imageUrl: imageUrl || null,
      videoId: videoId || null,
      likeCount: 0,
      commentCount: 0,
      createdAt: now,
      updatedAt: now,
      createdBy: user.userId
    });

    const postSnap = await postRef.get();

    res.status(201).json({
      post: {
        id: postRef.id,
        content: postSnap.data()!.content,
        imageUrl: postSnap.data()!.imageUrl,
        videoId: postSnap.data()!.videoId,
        likes: 0,
        comments: 0,
        createdAt: toIsoString(postSnap.data()!.createdAt)
      }
    });
  } catch (error) {
    console.error('Create community post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/users/:userId/community/:postId - update a community post
app.put('/v1/users/:userId/community/:postId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId, postId } = req.params;
    const { content, imageUrl, videoId } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const postRef = db.collection('users').doc(userId).collection('community').doc(postId);
    const postSnap = await postRef.get();

    if (!postSnap.exists) {
      return res.status(404).json({ error: 'Post not found' });
    }

    const patch: Record<string, any> = {
      updatedAt: admin.firestore.Timestamp.now()
    };

    if (content) patch.content = content.trim();
    if (imageUrl) patch.imageUrl = imageUrl;
    if (videoId) patch.videoId = videoId;

    await postRef.update(patch);

    const updatedSnap = await postRef.get();

    res.json({
      post: {
        id: postRef.id,
        content: updatedSnap.data()!.content,
        imageUrl: updatedSnap.data()!.imageUrl,
        videoId: updatedSnap.data()!.videoId,
        likes: Number(updatedSnap.data()!.likeCount || 0),
        comments: Number(updatedSnap.data()!.commentCount || 0),
        createdAt: toIsoString(updatedSnap.data()!.createdAt),
        updatedAt: toIsoString(updatedSnap.data()!.updatedAt)
      }
    });
  } catch (error) {
    console.error('Update community post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/users/:userId/community/:postId - delete a community post
app.delete('/v1/users/:userId/community/:postId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId, postId } = req.params;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const postRef = db.collection('users').doc(userId).collection('community').doc(postId);
    const postSnap = await postRef.get();

    if (!postSnap.exists) {
      return res.status(404).json({ error: 'Post not found' });
    }

    await postRef.delete();

    res.json({ message: 'Post deleted' });
  } catch (error) {
    console.error('Delete community post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Scheduling API
// ─────────────────────────────────────────────────────────────────────────────

// GET /v1/videos/scheduled - list scheduled videos for the current user
app.get('/v1/videos/scheduled', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    const snap = await db.collection('videos')
      .where('ownerId', '==', user.userId)
      .where('status', '==', 'scheduled')
      .orderBy('scheduledAt', 'asc')
      .offset(offset)
      .limit(limit)
      .get();

    const videos = snap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        title: data.title || '',
        thumbnailUrl: data.thumbnailUrl || null,
        scheduledAt: toIsoString(data.scheduledAt),
        createdAt: toIsoString(data.createdAt)
      };
    });

    res.json({
      videos,
      pagination: {
        page,
        limit,
        hasMore: videos.length === limit
      }
    });
  } catch (error) {
    console.error('List scheduled videos error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/videos/:id/schedule - schedule a video for future publication
app.put('/v1/videos/:id/schedule', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const { scheduledAt } = req.body || {};

    if (!scheduledAt) {
      return res.status(400).json({ error: 'scheduledAt is required' });
    }

    const scheduledDate = new Date(scheduledAt);
    if (isNaN(scheduledDate.getTime()) || scheduledDate < new Date()) {
      return res.status(400).json({ error: 'scheduledAt must be a valid future date' });
    }

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const scheduledTimestamp = admin.firestore.Timestamp.fromDate(scheduledDate);

    await videoRef.update({
      status: 'scheduled',
      scheduledAt: scheduledTimestamp,
      updatedAt: now
    });

    res.json({
      videoId: id,
      scheduledAt: scheduledTimestamp.toDate().toISOString(),
      status: 'scheduled'
    });
  } catch (error) {
    console.error('Schedule video error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/videos/:id/schedule/update - update scheduled time
app.put('/v1/videos/:id/schedule/update', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const { scheduledAt } = req.body || {};

    if (!scheduledAt) {
      return res.status(400).json({ error: 'scheduledAt is required' });
    }

    const scheduledDate = new Date(scheduledAt);
    if (isNaN(scheduledDate.getTime()) || scheduledDate < new Date()) {
      return res.status(400).json({ error: 'scheduledAt must be a valid future date' });
    }

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (videoData.status !== 'scheduled') {
      return res.status(400).json({ error: 'Video is not scheduled' });
    }

    const now = admin.firestore.Timestamp.now();
    const scheduledTimestamp = admin.firestore.Timestamp.fromDate(scheduledDate);

    await videoRef.update({
      scheduledAt: scheduledTimestamp,
      updatedAt: now
    });

    res.json({
      videoId: id,
      scheduledAt: scheduledTimestamp.toDate().toISOString(),
      status: 'scheduled'
    });
  } catch (error) {
    console.error('Update schedule error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/videos/:id/schedule/cancel - cancel scheduled publication
app.put('/v1/videos/:id/schedule/cancel', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (videoData.status !== 'scheduled') {
      return res.status(400).json({ error: 'Video is not scheduled' });
    }

    const now = admin.firestore.Timestamp.now();

    await videoRef.update({
      status: 'draft',
      scheduledAt: null,
      updatedAt: now
    });

    res.json({
      videoId: id,
      status: 'draft',
      message: 'Scheduled publication cancelled'
    });
  } catch (error) {
    console.error('Cancel schedule error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Premiere API
// ─────────────────────────────────────────────────────────────────────────────

// PUT /v1/videos/:id/premiere - set video as premiere
app.put('/v1/videos/:id/premiere', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const { premiereAt } = req.body || {};

    if (!premiereAt) {
      return res.status(400).json({ error: 'premiereAt is required' });
    }

    const premiereDate = new Date(premiereAt);
    if (isNaN(premiereDate.getTime()) || premiereDate < new Date()) {
      return res.status(400).json({ error: 'premiereAt must be a valid future date' });
    }

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const premiereTimestamp = admin.firestore.Timestamp.fromDate(premiereDate);

    await videoRef.update({
      status: 'premiere',
      premiereAt: premiereTimestamp,
      scheduledAt: premiereTimestamp,
      isPremiere: true,
      premiereLiveChatEnabled: true,
      updatedAt: now
    });

    res.json({
      videoId: id,
      premiereAt: premiereTimestamp.toDate().toISOString(),
      status: 'premiere'
    });
  } catch (error) {
    console.error('Set premiere error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:id/premiere - get premiere info
app.get('/v1/videos/:id/premiere', async (req, res) => {
  try {
    const { id } = req.params;

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (videoData.status !== 'premiere') {
      return res.status(400).json({ error: 'Video is not a premiere' });
    }

    const premiereAt = videoData.premiereAt || videoData.scheduledAt;
    const now = admin.firestore.Timestamp.now();
    const premiereDate = premiereAt ? premiereAt.toDate() : null;

    let countdownSeconds = 0;
    let status = 'upcoming';

    if (premiereDate) {
      const diffMs = premiereDate.getTime() - now.toDate().getTime();
      countdownSeconds = Math.max(0, Math.floor(diffMs / 1000));

      if (diffMs <= 0 && diffMs > -3600000) {
        status = 'live';
      } else if (diffMs <= -3600000) {
        status = 'ended';
      }
    }

    res.json({
      videoId: id,
      premiereAt: premiereAt ? toIsoString(premiereAt) : null,
      countdownSeconds,
      status,
      liveChatEnabled: !!videoData.premiereLiveChatEnabled
    });
  } catch (error) {
    console.error('Get premiere error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Download API
// ─────────────────────────────────────────────────────────────────────────────

// GET /v1/videos/:id/download - get download URLs for a video
app.get('/v1/videos/:id/download', async (req, res) => {
  try {
    const { id } = req.params;

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (videoData.status !== 'published') {
      return res.status(400).json({ error: 'Video must be published to download' });
    }

    const qualityVariants = Array.isArray(videoData.qualityVariants) ? videoData.qualityVariants : [];
    const baseUrl = process.env.BASE_URL || 'https://mychannel.live';

    const downloadOptions = [
      {
        quality: 'original',
        label: 'Original Quality',
        url: videoData.videoUrl || null,
        size: typeof videoData.fileSize === 'number' ? videoData.fileSize : (videoData.fileSize ? Number(videoData.fileSize) : null),
        mimeType: videoData.mimeType || 'video/mp4'
      }
    ];

    if (qualityVariants.length > 0) {
      qualityVariants.forEach((variant: any) => {
        downloadOptions.push({
          quality: variant.quality || 'unknown',
          label: variant.label || variant.quality || 'Unknown',
          url: variant.url || null,
          size: typeof variant.size === 'number' ? variant.size : (variant.size ? Number(variant.size) : null),
          mimeType: variant.mimeType || 'video/mp4'
        });
      });
    }

    res.json({
      videoId: id,
      title: videoData.title || '',
      downloadOptions,
      downloadEnabled: !videoData.downloadDisabled
    });
  } catch (error) {
    console.error('Get download error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/videos/:id/download/disable - disable downloads for a video
app.put('/v1/videos/:id/download/disable', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    await videoRef.update({
      downloadDisabled: true,
      updatedAt: admin.firestore.Timestamp.now()
    });

    res.json({
      videoId: id,
      downloadEnabled: false
    });
  } catch (error) {
    console.error('Disable download error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/videos/:id/download/enable - enable downloads for a video
app.put('/v1/videos/:id/download/enable', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    await videoRef.update({
      downloadDisabled: false,
      updatedAt: admin.firestore.Timestamp.now()
    });

    res.json({
      videoId: id,
      downloadEnabled: true
    });
  } catch (error) {
    console.error('Enable download error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// FCM Push Notifications API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/fcm/register - register FCM token for push notifications
app.post('/v1/fcm/register', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { token, platform } = req.body || {};

    if (!token || typeof token !== 'string') {
      return res.status(400).json({ error: 'token is required' });
    }

    const now = admin.firestore.Timestamp.now();
    const tokenRef = db.collection('users').doc(user.userId).collection('fcmTokens').doc(token);

    await tokenRef.set({
      token,
      platform: platform || 'unknown',
      active: true,
      registeredAt: now,
      updatedAt: now
    }, { merge: true });

    res.json({ message: 'FCM token registered' });
  } catch (error) {
    console.error('Register FCM token error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/fcm/unregister - unregister FCM token
app.delete('/v1/fcm/unregister', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { token } = req.body || {};

    if (!token || typeof token !== 'string') {
      return res.status(400).json({ error: 'token is required' });
    }

    const tokenRef = db.collection('users').doc(user.userId).collection('fcmTokens').doc(token);
    await tokenRef.delete();

    res.json({ message: 'FCM token unregistered' });
  } catch (error) {
    console.error('Unregister FCM token error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/fcm/send - send push notification (admin/internal use)
app.post('/v1/fcm/send', async (req, res) => {
  try {
    const { userId, title, body, data } = req.body || {};

    if (!userId || !title) {
      return res.status(400).json({ error: 'userId and title are required' });
    }

    const tokensSnap = await db.collection('users').doc(userId).collection('fcmTokens')
      .where('active', '==', true)
      .get();

    if (tokensSnap.empty) {
      return res.json({ message: 'No active FCM tokens found', sent: 0 });
    }

    const tokens = tokensSnap.docs.map(doc => doc.get('token'));
    const message = {
      notification: {
        title,
        body: body || ''
      },
      data: data || {},
      tokens
    };

    try {
      const response = await admin.messaging().sendMulticast(message);
      res.json({
        successCount: response.successCount,
        failureCount: response.failureCount,
        sent: tokens.length
      });
    } catch (error: any) {
      console.error('FCM send error:', error);
      res.status(500).json({ error: 'Failed to send push notification' });
    }
  } catch (error) {
    console.error('Send FCM error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/fcm/broadcast - broadcast notification to subscribers
app.post('/v1/fcm/broadcast', async (req, res) => {
  try {
    const { creatorId, title, body, data } = req.body || {};

    if (!creatorId || !title) {
      return res.status(400).json({ error: 'creatorId and title are required' });
    }

    const subscribersSnap = await db.collection('users').doc(creatorId).collection('subscribers')
      .limit(500)
      .get();

    if (subscribersSnap.empty) {
      return res.json({ message: 'No subscribers found', sent: 0 });
    }

    const subscriberIds = subscribersSnap.docs.map(doc => doc.id);
    const tokens: string[] = [];

    for (const subscriberId of subscriberIds) {
      const tokensSnap = await db.collection('users').doc(subscriberId).collection('fcmTokens')
        .where('active', '==', true)
        .get();
      
      tokensSnap.docs.forEach(doc => {
        const token = doc.get('token');
        if (token) tokens.push(token);
      });
    }

    if (tokens.length === 0) {
      return res.json({ message: 'No active FCM tokens found', sent: 0 });
    }

    const message = {
      notification: {
        title,
        body: body || ''
      },
      data: data || {},
      tokens
    };

    try {
      const response = await admin.messaging().sendMulticast(message);
      res.json({
        successCount: response.successCount,
        failureCount: response.failureCount,
        sent: tokens.length,
        subscriberCount: subscriberIds.length
      });
    } catch (error: any) {
      console.error('FCM broadcast error:', error);
      res.status(500).json({ error: 'Failed to broadcast push notification' });
    }
  } catch (error) {
    console.error('Broadcast FCM error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// User Profile Settings API
// ─────────────────────────────────────────────────────────────────────────────

// GET /v1/users/:userId/settings - get user settings
app.get('/v1/users/:userId/settings', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const settingsSnap = await db.collection('users').doc(userId).collection('settings').doc('profile').get();
    const privacySnap = await db.collection('users').doc(userId).collection('settings').doc('privacy').get();
    const preferencesSnap = await db.collection('users').doc(userId).collection('settings').doc('preferences').get();

    const settingsData = settingsSnap.exists ? settingsSnap.data()! : {};
    const privacyData = privacySnap.exists ? privacySnap.data()! : {};
    const preferencesData = preferencesSnap.exists ? preferencesSnap.data()! : {};

    res.json({
      userId,
      settings: {
        profile: {
          displayName: settingsData.displayName || null,
          bio: settingsData.bio || null,
          location: settingsData.location || null,
          website: settingsData.website || null
        },
        privacy: {
          profileVisibility: privacyData.profileVisibility || 'public',
          activityVisibility: privacyData.activityVisibility || 'public',
          allowMessages: privacyData.allowMessages !== false,
          showSubscriberCount: privacyData.showSubscriberCount !== false
        },
        preferences: {
          language: preferencesData.language || 'en',
          theme: preferencesData.theme || 'auto',
          autoplay: preferencesData.autoplay !== false,
          defaultQuality: preferencesData.defaultQuality || 'auto',
          showAnnotations: preferencesData.showAnnotations !== false
        }
      }
    });
  } catch (error) {
    console.error('Get settings error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/users/:userId/settings/profile - update profile settings
app.put('/v1/users/:userId/settings/profile', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { displayName, bio, location, website } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const patch: Record<string, any> = {
      updatedAt: admin.firestore.Timestamp.now()
    };

    if (displayName !== undefined) patch.displayName = displayName;
    if (bio !== undefined) patch.bio = bio;
    if (location !== undefined) patch.location = location;
    if (website !== undefined) patch.website = website;

    await db.collection('users').doc(userId).collection('settings').doc('profile').set(patch, { merge: true });

    res.json({ message: 'Profile settings updated' });
  } catch (error) {
    console.error('Update profile settings error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/users/:userId/settings/privacy - update privacy settings
app.put('/v1/users/:userId/settings/privacy', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { profileVisibility, activityVisibility, allowMessages, showSubscriberCount } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const patch: Record<string, any> = {
      updatedAt: admin.firestore.Timestamp.now()
    };

    if (profileVisibility) patch.profileVisibility = profileVisibility;
    if (activityVisibility) patch.activityVisibility = activityVisibility;
    if (allowMessages !== undefined) patch.allowMessages = !!allowMessages;
    if (showSubscriberCount !== undefined) patch.showSubscriberCount = !!showSubscriberCount;

    await db.collection('users').doc(userId).collection('settings').doc('privacy').set(patch, { merge: true });

    res.json({ message: 'Privacy settings updated' });
  } catch (error) {
    console.error('Update privacy settings error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/users/:userId/settings/preferences - update preferences
app.put('/v1/users/:userId/settings/preferences', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { language, theme, autoplay, defaultQuality, showAnnotations } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const patch: Record<string, any> = {
      updatedAt: admin.firestore.Timestamp.now()
    };

    if (language) patch.language = language;
    if (theme) patch.theme = theme;
    if (autoplay !== undefined) patch.autoplay = !!autoplay;
    if (defaultQuality) patch.defaultQuality = defaultQuality;
    if (showAnnotations !== undefined) patch.showAnnotations = !!showAnnotations;

    await db.collection('users').doc(userId).collection('settings').doc('preferences').set(patch, { merge: true });

    res.json({ message: 'Preferences updated' });
  } catch (error) {
    console.error('Update preferences error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Monetization Basics API
// ─────────────────────────────────────────────────────────────────────────────

// GET /v1/users/:userId/monetization - get monetization settings
app.get('/v1/users/:userId/monetization', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const monetizationSnap = await db.collection('users').doc(userId).collection('settings').doc('monetization').get();
    const monetizationData = monetizationSnap.exists ? monetizationSnap.data()! : {};

    res.json({
      userId,
      monetization: {
        adsEnabled: monetizationData.adsEnabled || false,
        midRollAds: monetizationData.midRollAds || false,
        adFrequency: monetizationData.adFrequency || 'medium',
        sponsorshipDisclosureEnabled: monetizationData.sponsorshipDisclosureEnabled !== false,
        sponsorshipText: monetizationData.sponsorshipText || '',
        monetizationPartner: monetizationData.monetizationPartner || null,
        partnerId: monetizationData.partnerId || null
      }
    });
  } catch (error) {
    console.error('Get monetization error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/users/:userId/monetization - update monetization settings
app.put('/v1/users/:userId/monetization', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { adsEnabled, midRollAds, adFrequency, sponsorshipDisclosureEnabled, sponsorshipText } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const patch: Record<string, any> = {
      updatedAt: admin.firestore.Timestamp.now()
    };

    if (adsEnabled !== undefined) patch.adsEnabled = !!adsEnabled;
    if (midRollAds !== undefined) patch.midRollAds = !!midRollAds;
    if (adFrequency) patch.adFrequency = adFrequency;
    if (sponsorshipDisclosureEnabled !== undefined) patch.sponsorshipDisclosureEnabled = !!sponsorshipDisclosureEnabled;
    if (sponsorshipText !== undefined) patch.sponsorshipText = sponsorshipText;

    await db.collection('users').doc(userId).collection('settings').doc('monetization').set(patch, { merge: true });

    res.json({ message: 'Monetization settings updated' });
  } catch (error) {
    console.error('Update monetization error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/videos/:id/sponsorship - add sponsorship disclosure to a video
app.post('/v1/videos/:id/sponsorship', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const { sponsorName, sponsorshipType, startTime, endTime } = req.body || {};

    if (!sponsorName || typeof sponsorName !== 'string') {
      return res.status(400).json({ error: 'sponsorName is required' });
    }

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const sponsorshipRef = db.collection('videos').doc(id).collection('sponsorships').doc();

    await sponsorshipRef.set({
      sponsorName: sponsorName.trim(),
      sponsorshipType: sponsorshipType || 'paid',
      startTime: typeof startTime === 'number' ? startTime : null,
      endTime: typeof endTime === 'number' ? endTime : null,
      createdAt: now,
      createdBy: user.userId
    });

    await videoRef.update({
      hasSponsorship: true,
      updatedAt: now
    });

    const sponsorshipSnap = await sponsorshipRef.get();

    res.status(201).json({
      sponsorship: {
        id: sponsorshipRef.id,
        sponsorName: sponsorshipSnap.data()!.sponsorName,
        sponsorshipType: sponsorshipSnap.data()!.sponsorshipType,
        startTime: sponsorshipSnap.data()!.startTime,
        endTime: sponsorshipSnap.data()!.endTime,
        createdAt: toIsoString(sponsorshipSnap.data()!.createdAt)
      }
    });
  } catch (error) {
    console.error('Add sponsorship error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Metadata API
// ─────────────────────────────────────────────────────────────────────────────

// PUT /v1/videos/:id/metadata - update video metadata (tags, category, language, license)
app.put('/v1/videos/:id/metadata', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const { tags, category, language, license, recordingDate, location } = req.body || {};

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const patch: Record<string, any> = {
      updatedAt: admin.firestore.Timestamp.now()
    };

    if (Array.isArray(tags)) {
      patch.tags = tags.filter(tag => typeof tag === 'string' && tag.trim().length > 0);
    }
    if (category) patch.category = category;
    if (language) patch.language = language;
    if (license) patch.license = license;
    if (recordingDate) patch.recordingDate = recordingDate;
    if (location) patch.location = location;

    await videoRef.update(patch);

    const updatedSnap = await videoRef.get();

    res.json({
      videoId: id,
      metadata: {
        tags: updatedSnap.data()!.tags || [],
        category: updatedSnap.data()!.category || null,
        language: updatedSnap.data()!.language || null,
        license: updatedSnap.data()!.license || null,
        recordingDate: updatedSnap.data()!.recordingDate || null,
        location: updatedSnap.data()!.location || null
      }
    });
  } catch (error) {
    console.error('Update metadata error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:id/metadata - get video metadata
app.get('/v1/videos/:id/metadata', async (req, res) => {
  try {
    const { id } = req.params;

    const videoSnap = await db.collection('videos').doc(id).get();
    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    res.json({
      videoId: id,
      metadata: {
        tags: Array.isArray(videoData.tags) ? videoData.tags : [],
        category: videoData.category || null,
        language: videoData.language || null,
        license: videoData.license || null,
        recordingDate: videoData.recordingDate || null,
        location: videoData.location || null
      }
    });
  } catch (error) {
    console.error('Get metadata error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Bulk Operations API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/bulk/delete - delete multiple videos at once
app.post('/v1/videos/bulk/delete', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoIds } = req.body || {};

    if (!Array.isArray(videoIds) || videoIds.length === 0) {
      return res.status(400).json({ error: 'videoIds array is required' });
    }

    if (videoIds.length > 50) {
      return res.status(400).json({ error: 'Cannot delete more than 50 videos at once' });
    }

    const batch = db.batch();
    let deletedCount = 0;
    let notOwnedCount = 0;

    for (const videoId of videoIds) {
      const videoRef = db.collection('videos').doc(videoId);
      const videoSnap = await videoRef.get();

      if (!videoSnap.exists) continue;

      const videoData = videoSnap.data()!;

      if (String(videoData.ownerId || '') === user.userId) {
        batch.delete(videoRef);
        deletedCount++;
      } else {
        notOwnedCount++;
      }
    }

    if (deletedCount > 0) {
      await batch.commit();
    }

    res.json({
      deleted: deletedCount,
      notOwned: notOwnedCount,
      total: videoIds.length
    });
  } catch (error) {
    console.error('Bulk delete error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/videos/bulk/privacy - change privacy of multiple videos at once
app.post('/v1/videos/bulk/privacy', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoIds, privacy } = req.body || {};

    if (!Array.isArray(videoIds) || videoIds.length === 0) {
      return res.status(400).json({ error: 'videoIds array is required' });
    }

    if (!privacy || typeof privacy !== 'string') {
      return res.status(400).json({ error: 'privacy is required (public, private, unlisted)' });
    }

    if (!['public', 'private', 'unlisted'].includes(privacy)) {
      return res.status(400).json({ error: 'privacy must be public, private, or unlisted' });
    }

    if (videoIds.length > 50) {
      return res.status(400).json({ error: 'Cannot update more than 50 videos at once' });
    }

    const batch = db.batch();
    let updatedCount = 0;
    let notOwnedCount = 0;

    for (const videoId of videoIds) {
      const videoRef = db.collection('videos').doc(videoId);
      const videoSnap = await videoRef.get();

      if (!videoSnap.exists) continue;

      const videoData = videoSnap.data()!;

      if (String(videoData.ownerId || '') === user.userId) {
        batch.update(videoRef, {
          privacy,
          updatedAt: admin.firestore.Timestamp.now()
        });
        updatedCount++;
      } else {
        notOwnedCount++;
      }
    }

    if (updatedCount > 0) {
      await batch.commit();
    }

    res.json({
      updated: updatedCount,
      notOwned: notOwnedCount,
      total: videoIds.length,
      privacy
    });
  } catch (error) {
    console.error('Bulk privacy error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Engagement Metrics API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/:id/impression - record video impression (for CTR calculation)
app.post('/v1/videos/:id/impression', async (req, res) => {
  try {
    const { id } = req.params;
    const { source } = req.body || {};

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const impressionRef = db.collection('videos').doc(id).collection('impressions').doc(now.toDate().toISOString());

    await impressionRef.set({
      source: source || 'unknown',
      timestamp: now
    });

    await videoRef.update({
      impressionCount: admin.firestore.FieldValue.increment(1),
      updatedAt: now
    });

    res.json({ ok: true });
  } catch (error) {
    console.error('Record impression error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:id/engagement - get engagement metrics (CTR, retention)
app.get('/v1/videos/:id/engagement', async (req, res) => {
  try {
    const { id } = req.params;
    const days = parseInt(req.query.days as string) || 7;

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;
    const since = admin.firestore.Timestamp.fromDate(new Date(Date.now() - days * 24 * 60 * 60 * 1000));

    const impressionsSnap = await videoRef.collection('impressions')
      .where('timestamp', '>=', since)
      .get();

    const retentionSnap = await videoRef.collection('retention')
      .where('timestamp', '>=', since)
      .orderBy('timestamp', 'desc')
      .limit(100)
      .get();

    const totalImpressions = impressionsSnap.size;
    const totalViews = Number(videoData.views || 0);
    const ctr = totalImpressions > 0 ? (totalViews / totalImpressions) * 100 : 0;

    const retentionData = retentionSnap.docs.map(doc => {
      const data = doc.data();
      return {
        timestamp: toIsoString(data.timestamp),
        watchTime: typeof data.watchTime === 'number' ? data.watchTime : 0,
        videoPosition: typeof data.videoPosition === 'number' ? data.videoPosition : 0
      };
    });

    const avgWatchTime = retentionData.length > 0 
      ? retentionData.reduce((sum, r) => sum + r.watchTime, 0) / retentionData.length 
      : 0;

    const avgRetentionPercent = retentionData.length > 0 
      ? retentionData.reduce((sum, r) => sum + (r.videoPosition || 0), 0) / retentionData.length 
      : 0;

    res.json({
      videoId: id,
      period: `${days} days`,
      metrics: {
        impressions: totalImpressions,
        views: totalViews,
        ctr: Math.round(ctr * 100) / 100,
        avgWatchTime: Math.round(avgWatchTime),
        avgRetentionPercent: Math.round(avgRetentionPercent * 100) / 100,
        likeRate: totalViews > 0 ? (Number(videoData.likeCount || 0) / totalViews) * 100 : 0,
        commentRate: totalViews > 0 ? (Number(videoData.commentCount || 0) / totalViews) * 100 : 0
      },
      retentionData: retentionData.slice(0, 20)
    });
  } catch (error) {
    console.error('Get engagement error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/videos/:id/retention - record retention data
app.post('/v1/videos/:id/retention', async (req, res) => {
  try {
    const { id } = req.params;
    const { watchTime, videoPosition } = req.body || {};

    if (typeof watchTime !== 'number' || typeof videoPosition !== 'number') {
      return res.status(400).json({ error: 'watchTime and videoPosition are required' });
    }

    const videoRef = db.collection('videos').doc(id);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const retentionRef = videoRef.collection('retention').doc(now.toDate().toISOString());

    await retentionRef.set({
      watchTime,
      videoPosition,
      timestamp: now
    });

    res.json({ ok: true });
  } catch (error) {
    console.error('Record retention error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Creator Dashboard Analytics API
// ─────────────────────────────────────────────────────────────────────────────

// GET /v1/users/:userId/analytics/dashboard - get creator dashboard analytics
app.get('/v1/users/:userId/analytics/dashboard', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const days = parseInt(req.query.days as string) || 30;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const since = admin.firestore.Timestamp.fromDate(new Date(Date.now() - days * 24 * 60 * 60 * 1000));

    const videosSnap = await db.collection('videos')
      .where('ownerId', '==', userId)
      .where('status', '==', 'published')
      .where('createdAt', '>=', since)
      .get();

    const subscribersSnap = await db.collection('users').doc(userId).collection('subscribers').get();
    const currentSubscribers = subscribersSnap.size;

    const videos = videosSnap.docs.map(doc => doc.data());
    const totalViews = videos.reduce((sum, v) => sum + (Number(v.views) || 0), 0);
    const totalLikes = videos.reduce((sum, v) => sum + (Number(v.likeCount) || 0), 0);
    const totalComments = videos.reduce((sum, v) => sum + (Number(v.commentCount) || 0), 0);

    const subscriberHistorySnap = await db.collection('users').doc(userId).collection('analytics')
      .doc('subscriberHistory')
      .get();

    const subscriberHistoryData = subscriberHistorySnap.exists ? subscriberHistorySnap.data()! : {};
    const subscriberGrowth = Array.isArray(subscriberHistoryData.history) 
      ? subscriberHistoryData.history.filter((h: any) => h.date >= since.toDate().toISOString())
      : [];

    const dailyViews: Record<string, number> = {};
    videos.forEach(v => {
      const date = v.createdAt ? v.createdAt.toDate().toISOString().split('T')[0] : new Date().toISOString().split('T')[0];
      dailyViews[date] = (dailyViews[date] || 0) + (Number(v.views) || 0);
    });

    res.json({
      userId,
      period: `${days} days`,
      summary: {
        totalVideos: videos.length,
        totalViews,
        totalLikes,
        totalComments,
        currentSubscribers,
        avgViewsPerVideo: videos.length > 0 ? Math.round(totalViews / videos.length) : 0,
        avgLikeRate: totalViews > 0 ? Math.round((totalLikes / totalViews) * 100) / 100 : 0
      },
      subscriberGrowth: subscriberGrowth.slice(0, 30),
      dailyViews: Object.entries(dailyViews).slice(0, 30).map(([date, views]) => ({ date, views }))
    });
  } catch (error) {
    console.error('Get dashboard analytics error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/users/:userId/analytics/subscribers - record subscriber count for analytics
app.post('/v1/users/:userId/analytics/subscribers', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { count } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (typeof count !== 'number') {
      return res.status(400).json({ error: 'count is required' });
    }

    const now = admin.firestore.Timestamp.now();
    const date = now.toDate().toISOString().split('T')[0];

    const historyRef = db.collection('users').doc(userId).collection('analytics').doc('subscriberHistory');
    const historySnap = await historyRef.get();

    let history = [];
    if (historySnap.exists) {
      const data = historySnap.data()!;
      history = Array.isArray(data.history) ? data.history : [];
    }

    history.push({ date, count, timestamp: now.toDate().toISOString() });
    history = history.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
    history = history.slice(0, 365);

    await historyRef.set({ history, updatedAt: now });

    res.json({ ok: true });
  } catch (error) {
    console.error('Record subscriber analytics error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Content Management API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/bulk/edit - bulk edit video metadata
app.post('/v1/videos/bulk/edit', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoIds, title, description, category, tags, language } = req.body || {};

    if (!Array.isArray(videoIds) || videoIds.length === 0) {
      return res.status(400).json({ error: 'videoIds array is required' });
    }

    if (videoIds.length > 50) {
      return res.status(400).json({ error: 'Cannot edit more than 50 videos at once' });
    }

    const batch = db.batch();
    let editedCount = 0;
    let notOwnedCount = 0;

    for (const videoId of videoIds) {
      const videoRef = db.collection('videos').doc(videoId);
      const videoSnap = await videoRef.get();

      if (!videoSnap.exists) continue;

      const videoData = videoSnap.data()!;

      if (String(videoData.ownerId || '') === user.userId) {
        const patch: Record<string, any> = {
          updatedAt: admin.firestore.Timestamp.now()
        };

        if (title) patch.title = title;
        if (description) patch.description = description;
        if (category) patch.category = category;
        if (Array.isArray(tags)) patch.tags = tags;
        if (language) patch.language = language;

        batch.update(videoRef, patch);
        editedCount++;
      } else {
        notOwnedCount++;
      }
    }

    if (editedCount > 0) {
      await batch.commit();
    }

    res.json({
      edited: editedCount,
      notOwned: notOwnedCount,
      total: videoIds.length
    });
  } catch (error) {
    console.error('Bulk edit error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/videos/bulk/publish - bulk publish videos
app.post('/v1/videos/bulk/publish', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoIds } = req.body || {};

    if (!Array.isArray(videoIds) || videoIds.length === 0) {
      return res.status(400).json({ error: 'videoIds array is required' });
    }

    if (videoIds.length > 50) {
      return res.status(400).json({ error: 'Cannot publish more than 50 videos at once' });
    }

    const batch = db.batch();
    let publishedCount = 0;
    let notOwnedCount = 0;
    const now = admin.firestore.Timestamp.now();

    for (const videoId of videoIds) {
      const videoRef = db.collection('videos').doc(videoId);
      const videoSnap = await videoRef.get();

      if (!videoSnap.exists) continue;

      const videoData = videoSnap.data()!;

      if (String(videoData.ownerId || '') === user.userId) {
        batch.update(videoRef, {
          status: 'published',
          publishedAt: now,
          updatedAt: now
        });
        publishedCount++;
      } else {
        notOwnedCount++;
      }
    }

    if (publishedCount > 0) {
      await batch.commit();
    }

    res.json({
      published: publishedCount,
      notOwned: notOwnedCount,
      total: videoIds.length
    });
  } catch (error) {
    console.error('Bulk publish error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/videos/bulk/unpublish - bulk unpublish videos
app.post('/v1/videos/bulk/unpublish', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoIds } = req.body || {};

    if (!Array.isArray(videoIds) || videoIds.length === 0) {
      return res.status(400).json({ error: 'videoIds array is required' });
    }

    if (videoIds.length > 50) {
      return res.status(400).json({ error: 'Cannot unpublish more than 50 videos at once' });
    }

    const batch = db.batch();
    let unpublishedCount = 0;
    let notOwnedCount = 0;
    const now = admin.firestore.Timestamp.now();

    for (const videoId of videoIds) {
      const videoRef = db.collection('videos').doc(videoId);
      const videoSnap = await videoRef.get();

      if (!videoSnap.exists) continue;

      const videoData = videoSnap.data()!;

      if (String(videoData.ownerId || '') === user.userId) {
        batch.update(videoRef, {
          status: 'draft',
          updatedAt: now
        });
        unpublishedCount++;
      } else {
        notOwnedCount++;
      }
    }

    if (unpublishedCount > 0) {
      await batch.commit();
    }

    res.json({
      unpublished: unpublishedCount,
      notOwned: notOwnedCount,
      total: videoIds.length
    });
  } catch (error) {
    console.error('Bulk unpublish error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Watch Later API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/users/:userId/watch-later - add video to watch later
app.post('/v1/users/:userId/watch-later', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { videoId } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (!videoId) {
      return res.status(400).json({ error: 'videoId is required' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const watchLaterRef = db.collection('users').doc(userId).collection('watchLater').doc(videoId);

    await watchLaterRef.set({
      videoId,
      addedAt: now,
      updatedAt: now
    }, { merge: true });

    res.status(201).json({ message: 'Added to watch later' });
  } catch (error) {
    console.error('Add to watch later error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/users/:userId/watch-later/:videoId - remove video from watch later
app.delete('/v1/users/:userId/watch-later/:videoId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId, videoId } = req.params;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const watchLaterRef = db.collection('users').doc(userId).collection('watchLater').doc(videoId);
    await watchLaterRef.delete();

    res.json({ message: 'Removed from watch later' });
  } catch (error) {
    console.error('Remove from watch later error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/users/:userId/watch-later - list watch later videos
app.get('/v1/users/:userId/watch-later', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const watchLaterSnap = await db.collection('users').doc(userId).collection('watchLater')
      .orderBy('addedAt', 'desc')
      .offset(offset)
      .limit(limit)
      .get();

    const videoIds = watchLaterSnap.docs.map(doc => doc.get('videoId'));
    const videosMap: Record<string, FirestoreData> = {};
    const userIds = new Set<string>();

    for (const vid of videoIds) {
      const videoSnap = await db.collection('videos').doc(vid).get();
      if (videoSnap.exists) {
        const videoData = videoSnap.data()!;
        videosMap[vid] = videoData;
        if (videoData.ownerId) userIds.add(String(videoData.ownerId));
      }
    }

    const usersMap = await loadUsersMap(Array.from(userIds));

    const videos = watchLaterSnap.docs.map(doc => {
      const videoId = doc.get('videoId');
      const videoData = videosMap[videoId] || null;
      const userData = videoData ? usersMap[String(videoData.ownerId || '')] || null : null;
      return {
        videoId,
        addedAt: toIsoString(doc.get('addedAt')),
        video: videoData ? formatVideoSummary('', videoData, userData) : null
      };
    });

    res.json({
      userId,
      videos,
      pagination: {
        page,
        limit,
        hasMore: videos.length === limit
      }
    });
  } catch (error) {
    console.error('List watch later error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Favorites API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/users/:userId/favorites - add video to favorites
app.post('/v1/users/:userId/favorites', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { videoId } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (!videoId) {
      return res.status(400).json({ error: 'videoId is required' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const favoritesRef = db.collection('users').doc(userId).collection('favorites').doc(videoId);

    await favoritesRef.set({
      videoId,
      addedAt: now,
      updatedAt: now
    }, { merge: true });

    res.status(201).json({ message: 'Added to favorites' });
  } catch (error) {
    console.error('Add to favorites error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/users/:userId/favorites/:videoId - remove video from favorites
app.delete('/v1/users/:userId/favorites/:videoId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId, videoId } = req.params;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const favoritesRef = db.collection('users').doc(userId).collection('favorites').doc(videoId);
    await favoritesRef.delete();

    res.json({ message: 'Removed from favorites' });
  } catch (error) {
    console.error('Remove from favorites error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/users/:userId/favorites - list favorite videos
app.get('/v1/users/:userId/favorites', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const favoritesSnap = await db.collection('users').doc(userId).collection('favorites')
      .orderBy('addedAt', 'desc')
      .offset(offset)
      .limit(limit)
      .get();

    const videoIds = favoritesSnap.docs.map(doc => doc.get('videoId'));
    const videosMap: Record<string, FirestoreData> = {};
    const userIds = new Set<string>();

    for (const vid of videoIds) {
      const videoSnap = await db.collection('videos').doc(vid).get();
      if (videoSnap.exists) {
        const videoData = videoSnap.data()!;
        videosMap[vid] = videoData;
        if (videoData.ownerId) userIds.add(String(videoData.ownerId));
      }
    }

    const usersMap = await loadUsersMap(Array.from(userIds));

    const videos = favoritesSnap.docs.map(doc => {
      const videoId = doc.get('videoId');
      const videoData = videosMap[videoId] || null;
      const userData = videoData ? usersMap[String(videoData.ownerId || '')] || null : null;
      return {
        videoId,
        addedAt: toIsoString(doc.get('addedAt')),
        video: videoData ? formatVideoSummary('', videoData, userData) : null
      };
    });

    res.json({
      userId,
      videos,
      pagination: {
        page,
        limit,
        hasMore: videos.length === limit
      }
    });
  } catch (error) {
    console.error('List favorites error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Continue Watching API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/users/:userId/continue-watching - update watch progress
app.post('/v1/users/:userId/continue-watching', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { videoId, position, duration } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (!videoId) {
      return res.status(400).json({ error: 'videoId is required' });
    }

    if (typeof position !== 'number') {
      return res.status(400).json({ error: 'position is required' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const continueWatchingRef = db.collection('users').doc(userId).collection('continueWatching').doc(videoId);

    await continueWatchingRef.set({
      videoId,
      position,
      duration: typeof duration === 'number' ? duration : null,
      lastWatchedAt: now,
      updatedAt: now
    }, { merge: true });

    res.json({ ok: true });
  } catch (error) {
    console.error('Update continue watching error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/users/:userId/continue-watching - list continue watching videos
app.get('/v1/users/:userId/continue-watching', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const continueWatchingSnap = await db.collection('users').doc(userId).collection('continueWatching')
      .orderBy('lastWatchedAt', 'desc')
      .limit(limit)
      .get();

    const videoIds = continueWatchingSnap.docs.map(doc => doc.get('videoId'));
    const videosMap: Record<string, FirestoreData> = {};
    const userIds = new Set<string>();
    const progressMap: Record<string, { position: number; duration: number | null }> = {};

    for (const doc of continueWatchingSnap.docs) {
      const videoId = doc.get('videoId');
      progressMap[videoId] = {
        position: typeof doc.get('position') === 'number' ? doc.get('position') : 0,
        duration: typeof doc.get('duration') === 'number' ? doc.get('duration') : null
      };

      const videoSnap = await db.collection('videos').doc(videoId).get();
      if (videoSnap.exists) {
        const videoData = videoSnap.data()!;
        videosMap[videoId] = videoData;
        if (videoData.ownerId) userIds.add(String(videoData.ownerId));
      }
    }

    const usersMap = await loadUsersMap(Array.from(userIds));

    const videos = continueWatchingSnap.docs.map(doc => {
      const videoId = doc.get('videoId');
      const videoData = videosMap[videoId] || null;
      const userData = videoData ? usersMap[String(videoData.ownerId || '')] || null : null;
      const progress = progressMap[videoId] || { position: 0, duration: null };
      const progressPercent = progress.duration && progress.duration > 0 ? Math.round((progress.position / progress.duration) * 100) : 0;

      return {
        videoId,
        position: progress.position,
        duration: progress.duration,
        progressPercent,
        lastWatchedAt: toIsoString(doc.get('lastWatchedAt')),
        video: videoData ? formatVideoSummary('', videoData, userData) : null
      };
    });

    res.json({
      userId,
      videos
    });
  } catch (error) {
    console.error('List continue watching error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Add to Playlist from Video Detail API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/:videoId/add-to-playlist - add video to playlist (convenience endpoint)
app.post('/v1/videos/:videoId/add-to-playlist', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { playlistId } = req.body || {};

    if (!playlistId) {
      return res.status(400).json({ error: 'playlistId is required' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const playlistRef = db.collection('playlists').doc(playlistId);
    const playlistSnap = await playlistRef.get();

    if (!playlistSnap.exists) {
      return res.status(404).json({ error: 'Playlist not found' });
    }

    const playlistData = playlistSnap.data()!;

    if (String(playlistData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const playlistVideoRef = db.collection('playlists').doc(playlistId).collection('videos').doc(videoId);

    await playlistVideoRef.set({
      videoId,
      addedAt: now,
      order: Date.now()
    }, { merge: true });

    await playlistRef.update({
      videoCount: admin.firestore.FieldValue.increment(1),
      updatedAt: now
    });

    res.status(201).json({ message: 'Added to playlist' });
  } catch (error) {
    console.error('Add to playlist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Highlights/Clips API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/:videoId/highlights - create a video highlight/clip
app.post('/v1/videos/:videoId/highlights', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { title, startTime, endTime, description } = req.body || {};

    if (!title || typeof title !== 'string') {
      return res.status(400).json({ error: 'title is required' });
    }

    if (typeof startTime !== 'number' || typeof endTime !== 'number') {
      return res.status(400).json({ error: 'startTime and endTime are required' });
    }

    if (startTime >= endTime) {
      return res.status(400).json({ error: 'startTime must be less than endTime' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const highlightRef = db.collection('videos').doc(videoId).collection('highlights').doc();

    await highlightRef.set({
      title: title.trim(),
      description: description || '',
      startTime,
      endTime,
      createdAt: now,
      createdBy: user.userId
    });

    await videoRef.update({
      hasHighlights: true,
      updatedAt: now
    });

    const highlightSnap = await highlightRef.get();

    res.status(201).json({
      highlight: {
        id: highlightRef.id,
        title: highlightSnap.data()!.title,
        description: highlightSnap.data()!.description,
        startTime: highlightSnap.data()!.startTime,
        endTime: highlightSnap.data()!.endTime,
        createdAt: toIsoString(highlightSnap.data()!.createdAt)
      }
    });
  } catch (error) {
    console.error('Create highlight error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/highlights - list video highlights
app.get('/v1/videos/:videoId/highlights', async (req, res) => {
  try {
    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const highlightsSnap = await videoRef.collection('highlights')
      .orderBy('createdAt', 'desc')
      .get();

    const highlights = highlightsSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        title: data.title,
        description: data.description,
        startTime: data.startTime,
        endTime: data.endTime,
        createdAt: toIsoString(data.createdAt)
      };
    });

    res.json({
      videoId,
      highlights
    });
  } catch (error) {
    console.error('List highlights error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/videos/:videoId/highlights/:highlightId - delete a highlight
app.delete('/v1/videos/:videoId/highlights/:highlightId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId, highlightId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const highlightRef = videoRef.collection('highlights').doc(highlightId);
    await highlightRef.delete();

    const remainingSnap = await videoRef.collection('highlights').limit(1).get();
    if (remainingSnap.empty) {
      await videoRef.update({ hasHighlights: false });
    }

    res.json({ message: 'Highlight deleted' });
  } catch (error) {
    console.error('Delete highlight error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Trimming/Editing API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/:videoId/trim - create a trimmed version of a video
app.post('/v1/videos/:videoId/trim', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { title, startTime, endTime, description } = req.body || {};

    if (!title || typeof title !== 'string') {
      return res.status(400).json({ error: 'title is required' });
    }

    if (typeof startTime !== 'number' || typeof endTime !== 'number') {
      return res.status(400).json({ error: 'startTime and endTime are required' });
    }

    if (startTime >= endTime) {
      return res.status(400).json({ error: 'startTime must be less than endTime' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const trimmedVideoId = `trimmed_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
    const trimmedVideoRef = db.collection('videos').doc(trimmedVideoId);

    await trimmedVideoRef.set({
      id: trimmedVideoId,
      title: title.trim(),
      description: description || videoData.description || '',
      ownerId: user.userId,
      sourceVideoId: videoId,
      trimStartTime: startTime,
      trimEndTime: endTime,
      status: 'processing',
      privacy: 'private',
      thumbnailUrl: videoData.thumbnailUrl || null,
      duration: endTime - startTime,
      createdAt: now,
      updatedAt: now
    });

    await videoRef.update({
      hasTrimmedVersions: true,
      updatedAt: now
    });

    res.status(201).json({
      videoId: trimmedVideoId,
      title: title.trim(),
      startTime,
      endTime,
      status: 'processing'
    });
  } catch (error) {
    console.error('Trim video error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/edits - list video edits/trimmed versions
app.get('/v1/videos/:videoId/edits', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const editsSnap = await db.collection('videos')
      .where('sourceVideoId', '==', videoId)
      .where('ownerId', '==', user.userId)
      .orderBy('createdAt', 'desc')
      .get();

    const edits = editsSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        title: data.title,
        trimStartTime: data.trimStartTime,
        trimEndTime: data.trimEndTime,
        status: data.status,
        createdAt: toIsoString(data.createdAt)
      };
    });

    res.json({
      sourceVideoId: videoId,
      edits
    });
  } catch (error) {
    console.error('List edits error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/videos/:videoId/edits/:editId - delete a trimmed version
app.delete('/v1/videos/:videoId/edits/:editId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId, editId } = req.params;

    const sourceVideoRef = db.collection('videos').doc(videoId);
    const sourceSnap = await sourceVideoRef.get();

    if (!sourceSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const sourceData = sourceSnap.data()!;

    if (String(sourceData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const editRef = db.collection('videos').doc(editId);
    const editSnap = await editRef.get();

    if (!editSnap.exists) {
      return res.status(404).json({ error: 'Edit not found' });
    }

    const editData = editSnap.data()!;

    if (String(editData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    await editRef.delete();

    const remainingEditsSnap = await db.collection('videos')
      .where('sourceVideoId', '==', videoId)
      .limit(1)
      .get();

    if (remainingEditsSnap.empty) {
      await sourceVideoRef.update({ hasTrimmedVersions: false });
    }

    res.json({ message: 'Edit deleted' });
  } catch (error) {
    console.error('Delete edit error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Reactions API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/:videoId/reactions - add or remove emoji reaction
app.post('/v1/videos/:videoId/reactions', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { emoji, action } = req.body || {};

    if (!emoji || typeof emoji !== 'string') {
      return res.status(400).json({ error: 'emoji is required' });
    }

    if (action !== 'add' && action !== 'remove') {
      return res.status(400).json({ error: 'action must be add or remove' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const reactionRef = db.collection('videos').doc(videoId).collection('reactions').doc(`${user.userId}_${emoji}`);

    if (action === 'add') {
      await reactionRef.set({
        userId: user.userId,
        emoji: emoji.trim(),
        reactedAt: now
      });

      await videoRef.update({
        reactionCount: admin.firestore.FieldValue.increment(1),
        updatedAt: now
      });

      res.json({ action: 'added', emoji: emoji.trim() });
    } else {
      await reactionRef.delete();

      await videoRef.update({
        reactionCount: admin.firestore.FieldValue.increment(-1),
        updatedAt: now
      });

      res.json({ action: 'removed', emoji: emoji.trim() });
    }
  } catch (error) {
    console.error('Reaction error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/reactions - list video reactions
app.get('/v1/videos/:videoId/reactions', async (req, res) => {
  try {
    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const reactionsSnap = await videoRef.collection('reactions').get();

    const emojiCounts: Record<string, number> = {};
    const userReactions: Record<string, string> = {};

    reactionsSnap.docs.forEach(doc => {
      const data = doc.data();
      const emoji = data.emoji;
      emojiCounts[emoji] = (emojiCounts[emoji] || 0) + 1;
      userReactions[data.userId] = emoji;
    });

    const sortedReactions = Object.entries(emojiCounts)
      .map(([emoji, count]) => ({ emoji, count }))
      .sort((a, b) => b.count - a.count);

    res.json({
      videoId,
      totalReactions: reactionsSnap.size,
      reactions: sortedReactions,
      userReactions
    });
  } catch (error) {
    console.error('List reactions error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Sharing Stats API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/:videoId/share - track video share
app.post('/v1/videos/:videoId/share', async (req, res) => {
  try {
    const { videoId } = req.params;
    const { platform, userId } = req.body || {};

    if (!platform || typeof platform !== 'string') {
      return res.status(400).json({ error: 'platform is required' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const shareRef = db.collection('videos').doc(videoId).collection('shares').doc();

    await shareRef.set({
      platform: platform.trim(),
      userId: userId || null,
      sharedAt: now
    });

    await videoRef.update({
      shareCount: admin.firestore.FieldValue.increment(1),
      updatedAt: now
    });

    res.json({ ok: true });
  } catch (error) {
    console.error('Track share error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/sharing-stats - get video sharing stats and viral metrics
app.get('/v1/videos/:videoId/sharing-stats', async (req, res) => {
  try {
    const { videoId } = req.params;
    const days = parseInt(req.query.days as string) || 7;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;
    const since = admin.firestore.Timestamp.fromDate(new Date(Date.now() - days * 24 * 60 * 60 * 1000));

    const sharesSnap = await videoRef.collection('shares')
      .where('sharedAt', '>=', since)
      .get();

    const platformCounts: Record<string, number> = {};
    sharesSnap.docs.forEach(doc => {
      const platform = doc.get('platform');
      platformCounts[platform] = (platformCounts[platform] || 0) + 1;
    });

    const sortedPlatforms = Object.entries(platformCounts)
      .map(([platform, count]) => ({ platform, count }))
      .sort((a, b) => b.count - a.count);

    const totalShares = sharesSnap.size;
    const totalViews = Number(videoData.views || 0);
    const shareRate = totalViews > 0 ? (totalShares / totalViews) * 100 : 0;
    const viralScore = totalShares > 0 ? Math.log(totalShares + 1) * (shareRate / 100) * 100 : 0;

    res.json({
      videoId,
      period: `${days} days`,
      stats: {
        totalShares,
        totalViews,
        shareRate: Math.round(shareRate * 100) / 100,
        viralScore: Math.round(viralScore * 100) / 100,
        platformBreakdown: sortedPlatforms
      }
    });
  } catch (error) {
    console.error('Get sharing stats error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Transcoding Status API
// ─────────────────────────────────────────────────────────────────────────────

// PUT /v1/videos/:videoId/transcode-status - update transcoding status
app.put('/v1/videos/:videoId/transcode-status', async (req, res) => {
  try {
    const { videoId } = req.params;
    const { status, progress, quality, errorMessage } = req.body || {};

    if (!status || typeof status !== 'string') {
      return res.status(400).json({ error: 'status is required' });
    }

    const validStatuses = ['pending', 'processing', 'completed', 'failed', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: `status must be one of: ${validStatuses.join(', ')}` });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const patch: Record<string, any> = {
      transcodeStatus: status,
      transcodeUpdatedAt: now,
      updatedAt: now
    };

    if (typeof progress === 'number' && progress >= 0 && progress <= 100) {
      patch.transcodeProgress = progress;
    }
    if (quality) {
      patch.transcodeQuality = quality;
    }
    if (errorMessage) {
      patch.transcodeError = errorMessage;
    }

    await videoRef.update(patch);

    res.json({
      videoId,
      status,
      progress: patch.transcodeProgress || null,
      updatedAt: toIsoString(now)
    });
  } catch (error) {
    console.error('Update transcode status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/transcode-status - get transcoding status
app.get('/v1/videos/:videoId/transcode-status', async (req, res) => {
  try {
    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    res.json({
      videoId,
      status: videoData.transcodeStatus || 'unknown',
      progress: videoData.transcodeProgress || 0,
      quality: videoData.transcodeQuality || null,
      error: videoData.transcodeError || null,
      updatedAt: videoData.transcodeUpdatedAt ? toIsoString(videoData.transcodeUpdatedAt) : null
    });
  } catch (error) {
    console.error('Get transcode status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/transcoding - list videos currently being transcoded
app.get('/v1/videos/transcoding', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { status } = req.query;

    const query = db.collection('videos')
      .where('ownerId', '==', user.userId);

    if (status && typeof status === 'string') {
      query.where('transcodeStatus', '==', status);
    } else {
      query.where('transcodeStatus', 'in', ['pending', 'processing']);
    }

    const snap = await query
      .orderBy('transcodeUpdatedAt', 'desc')
      .limit(50)
      .get();

    const videos = snap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        title: data.title,
        transcodeStatus: data.transcodeStatus || 'unknown',
        transcodeProgress: data.transcodeProgress || 0,
        transcodeQuality: data.transcodeQuality || null,
        transcodeError: data.transcodeError || null,
        transcodeUpdatedAt: data.transcodeUpdatedAt ? toIsoString(data.transcodeUpdatedAt) : null
      };
    });

    res.json({
      userId: user.userId,
      videos
    });
  } catch (error) {
    console.error('List transcoding videos error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Archive API
// ─────────────────────────────────────────────────────────────────────────────

// PUT /v1/videos/:videoId/archive - archive a video
app.put('/v1/videos/:videoId/archive', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    await videoRef.update({
      status: 'archived',
      archivedAt: now,
      privacy: 'private',
      updatedAt: now
    });

    res.json({
      videoId,
      status: 'archived',
      archivedAt: toIsoString(now)
    });
  } catch (error) {
    console.error('Archive video error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/videos/:videoId/unarchive - unarchive a video
app.put('/v1/videos/:videoId/unarchive', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    await videoRef.update({
      status: 'published',
      archivedAt: null,
      privacy: 'public',
      updatedAt: now
    });

    res.json({
      videoId,
      status: 'published'
    });
  } catch (error) {
    console.error('Unarchive video error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/users/:userId/archived - list archived videos
app.get('/v1/users/:userId/archived', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const archivedSnap = await db.collection('videos')
      .where('ownerId', '==', userId)
      .where('status', '==', 'archived')
      .orderBy('archivedAt', 'desc')
      .offset(offset)
      .limit(limit)
      .get();

    const videoIds = archivedSnap.docs.map(doc => doc.id);
    const userIds = new Set<string>();

    archivedSnap.docs.forEach(doc => {
      const data = doc.data();
      if (data.ownerId) userIds.add(String(data.ownerId));
    });

    const usersMap = await loadUsersMap(Array.from(userIds));

    const videos = archivedSnap.docs.map(doc => {
      const data = doc.data();
      const userData = data.ownerId ? usersMap[String(data.ownerId)] || null : null;
      return formatVideoSummary(doc.id, data, userData);
    });

    res.json({
      userId,
      videos,
      pagination: {
        page,
        limit,
        hasMore: videos.length === limit
      }
    });
  } catch (error) {
    console.error('List archived videos error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Report/Flag API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/:videoId/report - report a video
app.post('/v1/videos/:videoId/report', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { reason, category, description } = req.body || {};

    if (!reason || typeof reason !== 'string') {
      return res.status(400).json({ error: 'reason is required' });
    }

    if (!category || typeof category !== 'string') {
      return res.status(400).json({ error: 'category is required' });
    }

    const validCategories = ['violence', 'hate', 'harassment', 'spam', 'misinformation', 'copyright', 'other'];
    if (!validCategories.includes(category)) {
      return res.status(400).json({ error: `category must be one of: ${validCategories.join(', ')}` });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const reportRef = db.collection('videos').doc(videoId).collection('reports').doc();

    await reportRef.set({
      videoId,
      reporterId: user.userId,
      reason: reason.trim(),
      category,
      description: description || '',
      status: 'pending',
      createdAt: now,
      reviewedAt: null,
      reviewedBy: null,
      actionTaken: null
    });

    await videoRef.update({
      reportCount: admin.firestore.FieldValue.increment(1),
      updatedAt: now
    });

    const reportSnap = await reportRef.get();

    res.status(201).json({
      reportId: reportRef.id,
      videoId,
      reason: reportSnap.data()!.reason,
      category: reportSnap.data()!.category,
      status: reportSnap.data()!.status,
      createdAt: toIsoString(reportSnap.data()!.createdAt)
    });
  } catch (error) {
    console.error('Report video error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/reports - list reports for a video (admin only)
app.get('/v1/videos/:videoId/reports', async (req, res) => {
  try {
    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const reportsSnap = await videoRef.collection('reports')
      .orderBy('createdAt', 'desc')
      .limit(100)
      .get();

    const reports = reportsSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        videoId: data.videoId,
        reporterId: data.reporterId,
        reason: data.reason,
        category: data.category,
        description: data.description,
        status: data.status,
        createdAt: toIsoString(data.createdAt),
        reviewedAt: data.reviewedAt ? toIsoString(data.reviewedAt) : null,
        reviewedBy: data.reviewedBy || null,
        actionTaken: data.actionTaken || null
      };
    });

    res.json({
      videoId,
      reports
    });
  } catch (error) {
    console.error('List reports error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/videos/:videoId/reports/:reportId/review - review a report (admin only)
app.put('/v1/videos/:videoId/reports/:reportId/review', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId, reportId } = req.params;
    const { status, actionTaken, notes } = req.body || {};

    if (!status || typeof status !== 'string') {
      return res.status(400).json({ error: 'status is required' });
    }

    const validStatuses = ['pending', 'approved', 'rejected', 'escalated'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: `status must be one of: ${validStatuses.join(', ')}` });
    }

    const reportRef = db.collection('videos').doc(videoId).collection('reports').doc(reportId);
    const reportSnap = await reportRef.get();

    if (!reportSnap.exists) {
      return res.status(404).json({ error: 'Report not found' });
    }

    const now = admin.firestore.Timestamp.now();
    await reportRef.update({
      status,
      reviewedAt: now,
      reviewedBy: user.userId,
      actionTaken: actionTaken || null,
      reviewNotes: notes || ''
    });

    res.json({
      reportId,
      status,
      reviewedAt: toIsoString(now)
    });
  } catch (error) {
    console.error('Review report error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Thumbnail Customization API
// ─────────────────────────────────────────────────────────────────────────────

// PUT /v1/videos/:videoId/thumbnail - set custom thumbnail
app.put('/v1/videos/:videoId/thumbnail', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { thumbnailUrl, timestamp } = req.body || {};

    if (!thumbnailUrl || typeof thumbnailUrl !== 'string') {
      return res.status(400).json({ error: 'thumbnailUrl is required' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const patch: Record<string, any> = {
      thumbnailUrl: thumbnailUrl.trim(),
      updatedAt: now
    };

    if (typeof timestamp === 'number') {
      patch.thumbnailTimestamp = timestamp;
    }

    await videoRef.update(patch);

    res.json({
      videoId,
      thumbnailUrl: thumbnailUrl.trim(),
      thumbnailTimestamp: patch.thumbnailTimestamp || null
    });
  } catch (error) {
    console.error('Set thumbnail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/videos/:videoId/thumbnails/generate - generate auto thumbnails
app.post('/v1/videos/:videoId/thumbnails/generate', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { count } = req.body || {};

    const thumbnailCount = typeof count === 'number' ? Math.min(Math.max(count, 1), 10) : 3;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const duration = videoData.duration || 0;
    const interval = duration > 0 ? duration / thumbnailCount : 0;

    const thumbnails: any[] = [];
    for (let i = 0; i < thumbnailCount; i++) {
      const timestamp = interval > 0 ? Math.round(i * interval) : 0;
      const thumbnailRef = videoRef.collection('thumbnails').doc();
      const thumbnailId = thumbnailRef.id;

      await thumbnailRef.set({
        videoId,
        thumbnailId,
        timestamp,
        url: videoData.thumbnailUrl || null,
        status: 'pending',
        createdAt: now
      });

      thumbnails.push({
        id: thumbnailId,
        timestamp,
        status: 'pending'
      });
    }

    await videoRef.update({
      hasCustomThumbnails: true,
      updatedAt: now
    });

    res.status(201).json({
      videoId,
      thumbnails
    });
  } catch (error) {
    console.error('Generate thumbnails error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/thumbnails - list video thumbnails
app.get('/v1/videos/:videoId/thumbnails', async (req, res) => {
  try {
    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const thumbnailsSnap = await videoRef.collection('thumbnails')
      .orderBy('timestamp', 'asc')
      .get();

    const thumbnails = thumbnailsSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        timestamp: data.timestamp,
        url: data.url,
        status: data.status,
        createdAt: toIsoString(data.createdAt)
      };
    });

    res.json({
      videoId,
      currentThumbnail: videoSnap.data()!.thumbnailUrl || null,
      thumbnails
    });
  } catch (error) {
    console.error('List thumbnails error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Quality Presets API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/users/:userId/quality-presets - create a quality preset
app.post('/v1/users/:userId/quality-presets', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { name, resolution, bitrate, framerate, codec } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (!name || typeof name !== 'string') {
      return res.status(400).json({ error: 'name is required' });
    }

    const now = admin.firestore.Timestamp.now();
    const presetRef = db.collection('users').doc(userId).collection('qualityPresets').doc();

    await presetRef.set({
      name: name.trim(),
      resolution: resolution || '1080p',
      bitrate: bitrate || null,
      framerate: framerate || null,
      codec: codec || 'h264',
      createdAt: now,
      updatedAt: now
    });

    const presetSnap = await presetRef.get();

    res.status(201).json({
      presetId: presetRef.id,
      name: presetSnap.data()!.name,
      resolution: presetSnap.data()!.resolution,
      bitrate: presetSnap.data()!.bitrate,
      framerate: presetSnap.data()!.framerate,
      codec: presetSnap.data()!.codec,
      createdAt: toIsoString(presetSnap.data()!.createdAt)
    });
  } catch (error) {
    console.error('Create quality preset error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/users/:userId/quality-presets - list quality presets
app.get('/v1/users/:userId/quality-presets', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const presetsSnap = await db.collection('users').doc(userId).collection('qualityPresets')
      .orderBy('createdAt', 'desc')
      .get();

    const presets = presetsSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        name: data.name,
        resolution: data.resolution,
        bitrate: data.bitrate,
        framerate: data.framerate,
        codec: data.codec,
        createdAt: toIsoString(data.createdAt),
        updatedAt: data.updatedAt ? toIsoString(data.updatedAt) : null
      };
    });

    res.json({
      userId,
      presets
    });
  } catch (error) {
    console.error('List quality presets error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/users/:userId/quality-presets/:presetId - update a quality preset
app.put('/v1/users/:userId/quality-presets/:presetId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId, presetId } = req.params;
    const { name, resolution, bitrate, framerate, codec } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const presetRef = db.collection('users').doc(userId).collection('qualityPresets').doc(presetId);
    const presetSnap = await presetRef.get();

    if (!presetSnap.exists) {
      return res.status(404).json({ error: 'Preset not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const patch: Record<string, any> = {
      updatedAt: now
    };

    if (name) patch.name = name.trim();
    if (resolution) patch.resolution = resolution;
    if (typeof bitrate === 'number') patch.bitrate = bitrate;
    if (typeof framerate === 'number') patch.framerate = framerate;
    if (codec) patch.codec = codec;

    await presetRef.update(patch);

    res.json({
      presetId,
      updatedAt: toIsoString(now)
    });
  } catch (error) {
    console.error('Update quality preset error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/users/:userId/quality-presets/:presetId - delete a quality preset
app.delete('/v1/users/:userId/quality-presets/:presetId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId, presetId } = req.params;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const presetRef = db.collection('users').doc(userId).collection('qualityPresets').doc(presetId);
    await presetRef.delete();

    res.json({ message: 'Preset deleted' });
  } catch (error) {
    console.error('Delete quality preset error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Export/Download History API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/:videoId/download - track video download
app.post('/v1/videos/:videoId/download', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { quality, format, size } = req.body || {};

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const downloadRef = db.collection('users').doc(user.userId).collection('downloadHistory').doc();

    await downloadRef.set({
      videoId,
      quality: quality || 'unknown',
      format: format || 'mp4',
      size: size || null,
      downloadedAt: now
    });

    await videoRef.update({
      downloadCount: admin.firestore.FieldValue.increment(1),
      updatedAt: now
    });

    res.json({ ok: true });
  } catch (error) {
    console.error('Track download error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/users/:userId/download-history - list download history
app.get('/v1/users/:userId/download-history', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const downloadSnap = await db.collection('users').doc(userId).collection('downloadHistory')
      .orderBy('downloadedAt', 'desc')
      .offset(offset)
      .limit(limit)
      .get();

    const videoIds = downloadSnap.docs.map(doc => doc.get('videoId'));
    const videosMap: Record<string, FirestoreData> = {};
    const userIds = new Set<string>();

    for (const vid of videoIds) {
      const videoSnap = await db.collection('videos').doc(vid).get();
      if (videoSnap.exists) {
        const videoData = videoSnap.data()!;
        videosMap[vid] = videoData;
        if (videoData.ownerId) userIds.add(String(videoData.ownerId));
      }
    }

    const usersMap = await loadUsersMap(Array.from(userIds));

    const downloads = downloadSnap.docs.map(doc => {
      const videoId = doc.get('videoId');
      const videoData = videosMap[videoId] || null;
      const userData = videoData ? usersMap[String(videoData.ownerId || '')] || null : null;
      return {
        videoId,
        quality: doc.get('quality'),
        format: doc.get('format'),
        size: doc.get('size'),
        downloadedAt: toIsoString(doc.get('downloadedAt')),
        video: videoData ? formatVideoSummary('', videoData, userData) : null
      };
    });

    res.json({
      userId,
      downloads,
      pagination: {
        page,
        limit,
        hasMore: downloads.length === limit
      }
    });
  } catch (error) {
    console.error('List download history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Description Templates API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/users/:userId/description-templates - create a description template
app.post('/v1/users/:userId/description-templates', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { name, template, tags } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (!name || typeof name !== 'string') {
      return res.status(400).json({ error: 'name is required' });
    }

    if (!template || typeof template !== 'string') {
      return res.status(400).json({ error: 'template is required' });
    }

    const now = admin.firestore.Timestamp.now();
    const templateRef = db.collection('users').doc(userId).collection('descriptionTemplates').doc();

    await templateRef.set({
      name: name.trim(),
      template: template.trim(),
      tags: Array.isArray(tags) ? tags : [],
      createdAt: now,
      updatedAt: now
    });

    const templateSnap = await templateRef.get();

    res.status(201).json({
      templateId: templateRef.id,
      name: templateSnap.data()!.name,
      template: templateSnap.data()!.template,
      tags: templateSnap.data()!.tags,
      createdAt: toIsoString(templateSnap.data()!.createdAt)
    });
  } catch (error) {
    console.error('Create description template error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/users/:userId/description-templates - list description templates
app.get('/v1/users/:userId/description-templates', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const templatesSnap = await db.collection('users').doc(userId).collection('descriptionTemplates')
      .orderBy('createdAt', 'desc')
      .get();

    const templates = templatesSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        name: data.name,
        template: data.template,
        tags: data.tags,
        createdAt: toIsoString(data.createdAt),
        updatedAt: data.updatedAt ? toIsoString(data.updatedAt) : null
      };
    });

    res.json({
      userId,
      templates
    });
  } catch (error) {
    console.error('List description templates error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/users/:userId/description-templates/:templateId - update a description template
app.put('/v1/users/:userId/description-templates/:templateId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId, templateId } = req.params;
    const { name, template, tags } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const templateRef = db.collection('users').doc(userId).collection('descriptionTemplates').doc(templateId);
    const templateSnap = await templateRef.get();

    if (!templateSnap.exists) {
      return res.status(404).json({ error: 'Template not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const patch: Record<string, any> = {
      updatedAt: now
    };

    if (name) patch.name = name.trim();
    if (template) patch.template = template.trim();
    if (Array.isArray(tags)) patch.tags = tags;

    await templateRef.update(patch);

    res.json({
      templateId,
      updatedAt: toIsoString(now)
    });
  } catch (error) {
    console.error('Update description template error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/users/:userId/description-templates/:templateId - delete a description template
app.delete('/v1/users/:userId/description-templates/:templateId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId, templateId } = req.params;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const templateRef = db.collection('users').doc(userId).collection('descriptionTemplates').doc(templateId);
    await templateRef.delete();

    res.json({ message: 'Template deleted' });
  } catch (error) {
    console.error('Delete description template error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video End Screen Configuration API
// ─────────────────────────────────────────────────────────────────────────────

// PUT /v1/videos/:videoId/end-screen - set end screen configuration
app.put('/v1/videos/:videoId/end-screen', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { elements } = req.body || {};

    if (!Array.isArray(elements)) {
      return res.status(400).json({ error: 'elements array is required' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const validElements = elements.filter((el: any) => 
      el.type && (el.type === 'video' || el.type === 'playlist' || el.type === 'channel') && el.targetId
    );

    await videoRef.update({
      endScreenElements: validElements,
      hasEndScreen: validElements.length > 0,
      updatedAt: now
    });

    res.json({
      videoId,
      elements: validElements,
      hasEndScreen: validElements.length > 0
    });
  } catch (error) {
    console.error('Set end screen error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/end-screen - get end screen configuration
app.get('/v1/videos/:videoId/end-screen', async (req, res) => {
  try {
    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    res.json({
      videoId,
      elements: videoData.endScreenElements || [],
      hasEndScreen: videoData.hasEndScreen || false
    });
  } catch (error) {
    console.error('Get end screen error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Playlist Collaboration API
// ─────────────────────────────────────────────────────────────────────────────

// PUT /v1/playlists/:playlistId/share - share playlist and add collaborators
app.put('/v1/playlists/:playlistId/share', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { playlistId } = req.params;
    const { isPublic, collaboratorIds } = req.body || {};

    const playlistRef = db.collection('playlists').doc(playlistId);
    const playlistSnap = await playlistRef.get();

    if (!playlistSnap.exists) {
      return res.status(404).json({ error: 'Playlist not found' });
    }

    const playlistData = playlistSnap.data()!;

    if (String(playlistData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const patch: Record<string, any> = {
      updatedAt: now
    };

    if (typeof isPublic === 'boolean') {
      patch.isPublic = isPublic;
    }

    if (Array.isArray(collaboratorIds)) {
      patch.collaboratorIds = collaboratorIds;
    }

    await playlistRef.update(patch);

    res.json({
      playlistId,
      isPublic: patch.isPublic || playlistData.isPublic,
      collaboratorIds: patch.collaboratorIds || playlistData.collaboratorIds || []
    });
  } catch (error) {
    console.error('Share playlist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/playlists/:playlistId/collaborators - add collaborator to playlist
app.post('/v1/playlists/:playlistId/collaborators', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { playlistId } = req.params;
    const { collaboratorId, role } = req.body || {};

    if (!collaboratorId || typeof collaboratorId !== 'string') {
      return res.status(400).json({ error: 'collaboratorId is required' });
    }

    const playlistRef = db.collection('playlists').doc(playlistId);
    const playlistSnap = await playlistRef.get();

    if (!playlistSnap.exists) {
      return res.status(404).json({ error: 'Playlist not found' });
    }

    const playlistData = playlistSnap.data()!;

    if (String(playlistData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const collaboratorRef = playlistRef.collection('collaborators').doc(collaboratorId);

    await collaboratorRef.set({
      userId: collaboratorId,
      role: role || 'editor',
      addedBy: user.userId,
      addedAt: now
    });

    const currentCollaboratorIds = Array.isArray(playlistData.collaboratorIds) ? playlistData.collaboratorIds : [];
    if (!currentCollaboratorIds.includes(collaboratorId)) {
      await playlistRef.update({
        collaboratorIds: [...currentCollaboratorIds, collaboratorId],
        updatedAt: now
      });
    }

    res.status(201).json({
      collaboratorId,
      role: role || 'editor',
      addedAt: toIsoString(now)
    });
  } catch (error) {
    console.error('Add collaborator error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/playlists/:playlistId/collaborators/:collaboratorId - remove collaborator
app.delete('/v1/playlists/:playlistId/collaborators/:collaboratorId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { playlistId, collaboratorId } = req.params;

    const playlistRef = db.collection('playlists').doc(playlistId);
    const playlistSnap = await playlistRef.get();

    if (!playlistSnap.exists) {
      return res.status(404).json({ error: 'Playlist not found' });
    }

    const playlistData = playlistSnap.data()!;

    if (String(playlistData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    await playlistRef.collection('collaborators').doc(collaboratorId).delete();

    const currentCollaboratorIds = Array.isArray(playlistData.collaboratorIds) ? playlistData.collaboratorIds : [];
    const updatedCollaboratorIds = currentCollaboratorIds.filter(id => id !== collaboratorId);

    await playlistRef.update({
      collaboratorIds: updatedCollaboratorIds,
      updatedAt: now
    });

    res.json({ message: 'Collaborator removed' });
  } catch (error) {
    console.error('Remove collaborator error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/playlists/:playlistId/collaborators - list playlist collaborators
app.get('/v1/playlists/:playlistId/collaborators', async (req, res) => {
  try {
    const { playlistId } = req.params;

    const playlistRef = db.collection('playlists').doc(playlistId);
    const playlistSnap = await playlistRef.get();

    if (!playlistSnap.exists) {
      return res.status(404).json({ error: 'Playlist not found' });
    }

    const collaboratorsSnap = await playlistRef.collection('collaborators').get();

    const collaborators = collaboratorsSnap.docs.map(doc => {
      const data = doc.data();
      return {
        userId: data.userId,
        role: data.role,
        addedBy: data.addedBy,
        addedAt: toIsoString(data.addedAt)
      };
    });

    res.json({
      playlistId,
      collaborators
    });
  } catch (error) {
    console.error('List collaborators error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Milestone Tracking API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/:videoId/milestones - track video milestone
app.post('/v1/videos/:videoId/milestones', async (req, res) => {
  try {
    const { videoId } = req.params;
    const { type, value, notified } = req.body || {};

    if (!type || typeof type !== 'string') {
      return res.status(400).json({ error: 'type is required' });
    }

    const validTypes = ['views', 'likes', 'comments', 'shares', 'subscribers', 'watchTime'];
    if (!validTypes.includes(type)) {
      return res.status(400).json({ error: `type must be one of: ${validTypes.join(', ')}` });
    }

    if (typeof value !== 'number') {
      return res.status(400).json({ error: 'value is required' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const milestoneRef = db.collection('videos').doc(videoId).collection('milestones').doc(`${type}_${value}`);

    await milestoneRef.set({
      videoId,
      type,
      value,
      notified: notified || false,
      achievedAt: now
    }, { merge: true });

    res.status(201).json({
      milestoneId: milestoneRef.id,
      type,
      value,
      achievedAt: toIsoString(now)
    });
  } catch (error) {
    console.error('Track milestone error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/milestones - list video milestones
app.get('/v1/videos/:videoId/milestones', async (req, res) => {
  try {
    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const milestonesSnap = await videoRef.collection('milestones')
      .orderBy('achievedAt', 'desc')
      .limit(100)
      .get();

    const milestones = milestonesSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        type: data.type,
        value: data.value,
        notified: data.notified,
        achievedAt: toIsoString(data.achievedAt)
      };
    });

    res.json({
      videoId,
      milestones
    });
  } catch (error) {
    console.error('List milestones error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/users/:userId/milestones - list milestones across user's videos
app.get('/v1/users/:userId/milestones', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { type } = req.query;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const userVideosSnap = await db.collection('videos')
      .where('ownerId', '==', userId)
      .select('id')
      .get();

    const videoIds = userVideosSnap.docs.map(doc => doc.id);

    if (videoIds.length === 0) {
      return res.json({ userId, milestones: [] });
    }

    const allMilestones: any[] = [];
    for (const vid of videoIds) {
      const query = db.collection('videos').doc(vid).collection('milestones');
      if (type && typeof type === 'string') {
        query.where('type', '==', type);
      }
      const milestonesSnap = await query
        .orderBy('achievedAt', 'desc')
        .limit(10)
        .get();

      milestonesSnap.docs.forEach(doc => {
        const data = doc.data();
        allMilestones.push({
          id: doc.id,
          videoId: vid,
          type: data.type,
          value: data.value,
          notified: data.notified,
          achievedAt: toIsoString(data.achievedAt)
        });
      });
    }

    allMilestones.sort((a, b) => new Date(b.achievedAt).getTime() - new Date(a.achievedAt).getTime());

    res.json({
      userId,
      milestones: allMilestones.slice(0, 50)
    });
  } catch (error) {
    console.error('List user milestones error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Watermarking API
// ─────────────────────────────────────────────────────────────────────────────

// PUT /v1/videos/:videoId/watermark - set video watermark
app.put('/v1/videos/:videoId/watermark', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { imageUrl, position, opacity, size } = req.body || {};

    if (!imageUrl || typeof imageUrl !== 'string') {
      return res.status(400).json({ error: 'imageUrl is required' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const patch: Record<string, any> = {
      watermarkUrl: imageUrl.trim(),
      watermarkPosition: position || 'bottom-right',
      watermarkOpacity: typeof opacity === 'number' ? opacity : 0.5,
      watermarkSize: size || 'medium',
      hasWatermark: true,
      updatedAt: now
    };

    const validPositions = ['top-left', 'top-right', 'bottom-left', 'bottom-right', 'center'];
    if (!validPositions.includes(patch.watermarkPosition)) {
      patch.watermarkPosition = 'bottom-right';
    }

    const validSizes = ['small', 'medium', 'large'];
    if (!validSizes.includes(patch.watermarkSize)) {
      patch.watermarkSize = 'medium';
    }

    await videoRef.update(patch);

    res.json({
      videoId,
      watermarkUrl: patch.watermarkUrl,
      watermarkPosition: patch.watermarkPosition,
      watermarkOpacity: patch.watermarkOpacity,
      watermarkSize: patch.watermarkSize
    });
  } catch (error) {
    console.error('Set watermark error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/watermark - get video watermark
app.get('/v1/videos/:videoId/watermark', async (req, res) => {
  try {
    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    res.json({
      videoId,
      watermarkUrl: videoData.watermarkUrl || null,
      watermarkPosition: videoData.watermarkPosition || 'bottom-right',
      watermarkOpacity: videoData.watermarkOpacity || 0.5,
      watermarkSize: videoData.watermarkSize || 'medium',
      hasWatermark: videoData.hasWatermark || false
    });
  } catch (error) {
    console.error('Get watermark error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/videos/:videoId/watermark - remove video watermark
app.delete('/v1/videos/:videoId/watermark', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    await videoRef.update({
      watermarkUrl: null,
      watermarkPosition: null,
      watermarkOpacity: null,
      watermarkSize: null,
      hasWatermark: false,
      updatedAt: now
    });

    res.json({ message: 'Watermark removed' });
  } catch (error) {
    console.error('Remove watermark error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Branding/Intros API
// ─────────────────────────────────────────────────────────────────────────────

// PUT /v1/users/:userId/branding - set user branding (intro/outro)
app.put('/v1/users/:userId/branding', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { introVideoUrl, outroVideoUrl, logoUrl, backgroundColor } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const patch: Record<string, any> = {
      updatedAt: now
    };

    if (introVideoUrl) patch.introVideoUrl = introVideoUrl.trim();
    if (outroVideoUrl) patch.outroVideoUrl = outroVideoUrl.trim();
    if (logoUrl) patch.logoUrl = logoUrl.trim();
    if (backgroundColor) patch.backgroundColor = backgroundColor.trim();

    await db.collection('users').doc(userId).collection('branding').doc('default').set(patch, { merge: true });

    res.json({
      userId,
      introVideoUrl: patch.introVideoUrl || null,
      outroVideoUrl: patch.outroVideoUrl || null,
      logoUrl: patch.logoUrl || null,
      backgroundColor: patch.backgroundColor || null
    });
  } catch (error) {
    console.error('Set branding error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/users/:userId/branding - get user branding
app.get('/v1/users/:userId/branding', async (req, res) => {
  try {
    const { userId } = req.params;

    const brandingRef = db.collection('users').doc(userId).collection('branding').doc('default');
    const brandingSnap = await brandingRef.get();

    if (!brandingSnap.exists) {
      return res.json({
        userId,
        introVideoUrl: null,
        outroVideoUrl: null,
        logoUrl: null,
        backgroundColor: null
      });
    }

    const data = brandingSnap.data()!;

    res.json({
      userId,
      introVideoUrl: data.introVideoUrl || null,
      outroVideoUrl: data.outroVideoUrl || null,
      logoUrl: data.logoUrl || null,
      backgroundColor: data.backgroundColor || null
    });
  } catch (error) {
    console.error('Get branding error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/videos/:videoId/branding - apply branding to specific video
app.put('/v1/videos/:videoId/branding', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { applyIntro, applyOutro, applyLogo } = req.body || {};

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const patch: Record<string, any> = {
      updatedAt: now
    };

    if (typeof applyIntro === 'boolean') patch.applyIntro = applyIntro;
    if (typeof applyOutro === 'boolean') patch.applyOutro = applyOutro;
    if (typeof applyLogo === 'boolean') patch.applyLogo = applyLogo;

    await videoRef.update(patch);

    res.json({
      videoId,
      applyIntro: patch.applyIntro || false,
      applyOutro: patch.applyOutro || false,
      applyLogo: patch.applyLogo || false
    });
  } catch (error) {
    console.error('Apply video branding error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Accessibility API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/:videoId/audio-descriptions - add audio description track
app.post('/v1/videos/:videoId/audio-descriptions', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { language, audioUrl, description } = req.body || {};

    if (!language || typeof language !== 'string') {
      return res.status(400).json({ error: 'language is required' });
    }

    if (!audioUrl || typeof audioUrl !== 'string') {
      return res.status(400).json({ error: 'audioUrl is required' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const audioDescRef = videoRef.collection('audioDescriptions').doc();

    await audioDescRef.set({
      videoId,
      language: language.trim(),
      audioUrl: audioUrl.trim(),
      description: description || '',
      createdAt: now
    });

    await videoRef.update({
      hasAudioDescriptions: true,
      updatedAt: now
    });

    const audioDescSnap = await audioDescRef.get();

    res.status(201).json({
      audioDescriptionId: audioDescRef.id,
      language: audioDescSnap.data()!.language,
      audioUrl: audioDescSnap.data()!.audioUrl,
      description: audioDescSnap.data()!.description,
      createdAt: toIsoString(audioDescSnap.data()!.createdAt)
    });
  } catch (error) {
    console.error('Add audio description error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/audio-descriptions - list audio description tracks
app.get('/v1/videos/:videoId/audio-descriptions', async (req, res) => {
  try {
    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const audioDescSnap = await videoRef.collection('audioDescriptions')
      .orderBy('createdAt', 'desc')
      .get();

    const audioDescriptions = audioDescSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        language: data.language,
        audioUrl: data.audioUrl,
        description: data.description,
        createdAt: toIsoString(data.createdAt)
      };
    });

    res.json({
      videoId,
      audioDescriptions
    });
  } catch (error) {
    console.error('List audio descriptions error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/videos/:videoId/accessibility - update video accessibility settings
app.put('/v1/videos/:videoId/accessibility', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { hasCaptions, hasAudioDescriptions, hasSignLanguage } = req.body || {};

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const patch: Record<string, any> = {
      updatedAt: now
    };

    if (typeof hasCaptions === 'boolean') patch.hasCaptions = hasCaptions;
    if (typeof hasAudioDescriptions === 'boolean') patch.hasAudioDescriptions = hasAudioDescriptions;
    if (typeof hasSignLanguage === 'boolean') patch.hasSignLanguage = hasSignLanguage;

    await videoRef.update(patch);

    res.json({
      videoId,
      hasCaptions: patch.hasCaptions || videoData.hasCaptions || false,
      hasAudioDescriptions: patch.hasAudioDescriptions || videoData.hasAudioDescriptions || false,
      hasSignLanguage: patch.hasSignLanguage || videoData.hasSignLanguage || false
    });
  } catch (error) {
    console.error('Update accessibility error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Localization API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/:videoId/localizations - add localized metadata
app.post('/v1/videos/:videoId/localizations', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { language, title, description, tags } = req.body || {};

    if (!language || typeof language !== 'string') {
      return res.status(400).json({ error: 'language is required' });
    }

    if (!title || typeof title !== 'string') {
      return res.status(400).json({ error: 'title is required' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const localizationRef = videoRef.collection('localizations').doc(language.trim().toLowerCase());

    await localizationRef.set({
      videoId,
      language: language.trim(),
      title: title.trim(),
      description: description || '',
      tags: Array.isArray(tags) ? tags : [],
      createdAt: now,
      updatedAt: now
    }, { merge: true });

    await videoRef.update({
      hasLocalizations: true,
      updatedAt: now
    });

    const localizationSnap = await localizationRef.get();

    res.status(201).json({
      language: localizationSnap.data()!.language,
      title: localizationSnap.data()!.title,
      description: localizationSnap.data()!.description,
      tags: localizationSnap.data()!.tags,
      createdAt: toIsoString(localizationSnap.data()!.createdAt)
    });
  } catch (error) {
    console.error('Add localization error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/localizations - list video localizations
app.get('/v1/videos/:videoId/localizations', async (req, res) => {
  try {
    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const localizationsSnap = await videoRef.collection('localizations').get();

    const localizations = localizationsSnap.docs.map(doc => {
      const data = doc.data();
      return {
        language: data.language,
        title: data.title,
        description: data.description,
        tags: data.tags,
        createdAt: toIsoString(data.createdAt),
        updatedAt: data.updatedAt ? toIsoString(data.updatedAt) : null
      };
    });

    res.json({
      videoId,
      localizations
    });
  } catch (error) {
    console.error('List localizations error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/videos/:videoId/localizations/:language - update localization
app.put('/v1/videos/:videoId/localizations/:language', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId, language } = req.params;
    const { title, description, tags } = req.body || {};

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const localizationRef = videoRef.collection('localizations').doc(language.toLowerCase());
    const localizationSnap = await localizationRef.get();

    if (!localizationSnap.exists) {
      return res.status(404).json({ error: 'Localization not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const patch: Record<string, any> = {
      updatedAt: now
    };

    if (title) patch.title = title.trim();
    if (description !== undefined) patch.description = description;
    if (Array.isArray(tags)) patch.tags = tags;

    await localizationRef.update(patch);

    res.json({
      language,
      updatedAt: toIsoString(now)
    });
  } catch (error) {
    console.error('Update localization error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/videos/:videoId/localizations/:language - delete localization
app.delete('/v1/videos/:videoId/localizations/:language', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId, language } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    await videoRef.collection('localizations').doc(language.toLowerCase()).delete();

    const remainingLocalizationsSnap = await videoRef.collection('localizations').limit(1).get();
    if (remainingLocalizationsSnap.empty) {
      await videoRef.update({ hasLocalizations: false });
    }

    res.json({ message: 'Localization deleted' });
  } catch (error) {
    console.error('Delete localization error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Cards/Annotations API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/:videoId/cards - create video card/annotation
app.post('/v1/videos/:videoId/cards', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { type, startTime, endTime, targetId, text, imageUrl, position } = req.body || {};

    if (!type || typeof type !== 'string') {
      return res.status(400).json({ error: 'type is required' });
    }

    if (typeof startTime !== 'number' || typeof endTime !== 'number') {
      return res.status(400).json({ error: 'startTime and endTime are required' });
    }

    if (startTime >= endTime) {
      return res.status(400).json({ error: 'startTime must be less than endTime' });
    }

    const validTypes = ['video', 'playlist', 'channel', 'link', 'text', 'info'];
    if (!validTypes.includes(type)) {
      return res.status(400).json({ error: `type must be one of: ${validTypes.join(', ')}` });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const cardRef = videoRef.collection('cards').doc();

    await cardRef.set({
      videoId,
      type,
      startTime,
      endTime,
      targetId: targetId || null,
      text: text || '',
      imageUrl: imageUrl || null,
      position: position || 'top-right',
      createdAt: now
    });

    await videoRef.update({
      hasCards: true,
      updatedAt: now
    });

    const cardSnap = await cardRef.get();

    res.status(201).json({
      cardId: cardRef.id,
      type: cardSnap.data()!.type,
      startTime: cardSnap.data()!.startTime,
      endTime: cardSnap.data()!.endTime,
      targetId: cardSnap.data()!.targetId,
      text: cardSnap.data()!.text,
      imageUrl: cardSnap.data()!.imageUrl,
      position: cardSnap.data()!.position,
      createdAt: toIsoString(cardSnap.data()!.createdAt)
    });
  } catch (error) {
    console.error('Create card error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/cards - list video cards
app.get('/v1/videos/:videoId/cards', async (req, res) => {
  try {
    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const cardsSnap = await videoRef.collection('cards')
      .orderBy('startTime', 'asc')
      .get();

    const cards = cardsSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        type: data.type,
        startTime: data.startTime,
        endTime: data.endTime,
        targetId: data.targetId,
        text: data.text,
        imageUrl: data.imageUrl,
        position: data.position,
        createdAt: toIsoString(data.createdAt)
      };
    });

    res.json({
      videoId,
      cards
    });
  } catch (error) {
    console.error('List cards error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/videos/:videoId/cards/:cardId - update video card
app.put('/v1/videos/:videoId/cards/:cardId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId, cardId } = req.params;
    const { startTime, endTime, text, imageUrl, position } = req.body || {};

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const cardRef = videoRef.collection('cards').doc(cardId);
    const cardSnap = await cardRef.get();

    if (!cardSnap.exists) {
      return res.status(404).json({ error: 'Card not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const patch: Record<string, any> = {};

    if (typeof startTime === 'number') patch.startTime = startTime;
    if (typeof endTime === 'number') patch.endTime = endTime;
    if (text !== undefined) patch.text = text;
    if (imageUrl !== undefined) patch.imageUrl = imageUrl;
    if (position) patch.position = position;

    await cardRef.update(patch);

    res.json({
      cardId,
      updatedAt: toIsoString(now)
    });
  } catch (error) {
    console.error('Update card error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/videos/:videoId/cards/:cardId - delete video card
app.delete('/v1/videos/:videoId/cards/:cardId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId, cardId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    await videoRef.collection('cards').doc(cardId).delete();

    const remainingCardsSnap = await videoRef.collection('cards').limit(1).get();
    if (remainingCardsSnap.empty) {
      await videoRef.update({ hasCards: false });
    }

    res.json({ message: 'Card deleted' });
  } catch (error) {
    console.error('Delete card error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// User Session Management API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/users/:userId/sessions - create user session
app.post('/v1/users/:userId/sessions', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { deviceType, deviceName, userAgent, ipAddress } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const sessionRef = db.collection('users').doc(userId).collection('sessions').doc();

    const sessionId = sessionRef.id;

    await sessionRef.set({
      userId,
      sessionId,
      deviceType: deviceType || 'unknown',
      deviceName: deviceName || '',
      userAgent: userAgent || '',
      ipAddress: ipAddress || '',
      createdAt: now,
      lastActiveAt: now,
      isActive: true
    });

    res.status(201).json({
      sessionId,
      deviceType: deviceType || 'unknown',
      deviceName: deviceName || '',
      createdAt: toIsoString(now)
    });
  } catch (error) {
    console.error('Create session error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/users/:userId/sessions - list user sessions
app.get('/v1/users/:userId/sessions', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const sessionsSnap = await db.collection('users').doc(userId).collection('sessions')
      .orderBy('lastActiveAt', 'desc')
      .limit(20)
      .get();

    const sessions = sessionsSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        deviceType: data.deviceType,
        deviceName: data.deviceName,
        userAgent: data.userAgent,
        ipAddress: data.ipAddress,
        createdAt: toIsoString(data.createdAt),
        lastActiveAt: toIsoString(data.lastActiveAt),
        isActive: data.isActive
      };
    });

    res.json({
      userId,
      sessions
    });
  } catch (error) {
    console.error('List sessions error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/users/:userId/sessions/:sessionId - revoke specific session
app.delete('/v1/users/:userId/sessions/:sessionId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId, sessionId } = req.params;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    await db.collection('users').doc(userId).collection('sessions').doc(sessionId).update({
      isActive: false,
      revokedAt: now
    });

    res.json({ message: 'Session revoked' });
  } catch (error) {
    console.error('Revoke session error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/users/:userId/sessions - revoke all sessions except current
app.delete('/v1/users/:userId/sessions', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { currentSessionId } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const sessionsSnap = await db.collection('users').doc(userId).collection('sessions')
      .where('isActive', '==', true)
      .get();

    const batch = db.batch();
    sessionsSnap.docs.forEach(doc => {
      if (doc.id !== currentSessionId) {
        batch.update(doc.ref, { isActive: false, revokedAt: now });
      }
    });

    await batch.commit();

    res.json({ message: 'Sessions revoked' });
  } catch (error) {
    console.error('Revoke all sessions error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Processing Queue Status API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/:videoId/queue - add video to processing queue
app.post('/v1/videos/:videoId/queue', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { operation, priority } = req.body || {};

    if (!operation || typeof operation !== 'string') {
      return res.status(400).json({ error: 'operation is required' });
    }

    const validOperations = ['transcode', 'thumbnail', 'caption', 'watermark', 'branding'];
    if (!validOperations.includes(operation)) {
      return res.status(400).json({ error: `operation must be one of: ${validOperations.join(', ')}` });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const queueRef = db.collection('processingQueue').doc();

    await queueRef.set({
      videoId,
      operation,
      priority: priority || 'normal',
      status: 'queued',
      userId: user.userId,
      createdAt: now,
      startedAt: null,
      completedAt: null,
      error: null
    });

    await videoRef.update({
      processingStatus: 'queued',
      processingOperation: operation,
      updatedAt: now
    });

    const queueSnap = await queueRef.get();

    res.status(201).json({
      queueId: queueRef.id,
      videoId,
      operation: queueSnap.data()!.operation,
      priority: queueSnap.data()!.priority,
      status: queueSnap.data()!.status,
      createdAt: toIsoString(queueSnap.data()!.createdAt)
    });
  } catch (error) {
    console.error('Add to queue error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/queue-status - get video processing queue status
app.get('/v1/videos/:videoId/queue-status', async (req, res) => {
  try {
    const { videoId } = req.params;

    const queueSnap = await db.collection('processingQueue')
      .where('videoId', '==', videoId)
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();

    const queueItems = queueSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        operation: data.operation,
        priority: data.priority,
        status: data.status,
        createdAt: toIsoString(data.createdAt),
        startedAt: data.startedAt ? toIsoString(data.startedAt) : null,
        completedAt: data.completedAt ? toIsoString(data.completedAt) : null,
        error: data.error
      };
    });

    res.json({
      videoId,
      queueItems
    });
  } catch (error) {
    console.error('Get queue status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/processing-queue - list processing queue items
app.get('/v1/processing-queue', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { status, limit } = req.query;
    const queueLimit = Math.min(parseInt(limit as string) || 50, 100);

    const query = db.collection('processingQueue');
    if (status && typeof status === 'string') {
      query.where('status', '==', status);
    }

    const queueSnap = await query
      .orderBy('createdAt', 'desc')
      .limit(queueLimit)
      .get();

    const queueItems = queueSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        videoId: data.videoId,
        operation: data.operation,
        priority: data.priority,
        status: data.status,
        userId: data.userId,
        createdAt: toIsoString(data.createdAt),
        startedAt: data.startedAt ? toIsoString(data.startedAt) : null,
        completedAt: data.completedAt ? toIsoString(data.completedAt) : null,
        error: data.error
      };
    });

    res.json({
      queueItems
    });
  } catch (error) {
    console.error('List processing queue error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/processing-queue/:queueId - cancel queue item
app.delete('/v1/processing-queue/:queueId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { queueId } = req.params;

    const queueRef = db.collection('processingQueue').doc(queueId);
    const queueSnap = await queueRef.get();

    if (!queueSnap.exists) {
      return res.status(404).json({ error: 'Queue item not found' });
    }

    const queueData = queueSnap.data()!;

    if (String(queueData.userId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    await queueRef.update({
      status: 'cancelled',
      completedAt: now
    });

    res.json({ message: 'Queue item cancelled' });
  } catch (error) {
    console.error('Cancel queue item error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video SEO Optimization API
// ─────────────────────────────────────────────────────────────────────────────

// PUT /v1/videos/:videoId/seo - update video SEO metadata
app.put('/v1/videos/:videoId/seo', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { seoTitle, seoDescription, keywords, focusKeyword, metaTags } = req.body || {};

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const patch: Record<string, any> = {
      updatedAt: now
    };

    if (seoTitle) patch.seoTitle = seoTitle.trim();
    if (seoDescription) patch.seoDescription = seoDescription.trim();
    if (Array.isArray(keywords)) patch.seoKeywords = keywords;
    if (focusKeyword) patch.focusKeyword = focusKeyword.trim();
    if (Array.isArray(metaTags)) patch.seoMetaTags = metaTags;

    await videoRef.update(patch);

    res.json({
      videoId,
      seoTitle: patch.seoTitle || videoData.seoTitle || null,
      seoDescription: patch.seoDescription || videoData.seoDescription || null,
      keywords: patch.seoKeywords || videoData.seoKeywords || [],
      focusKeyword: patch.focusKeyword || videoData.focusKeyword || null
    });
  } catch (error) {
    console.error('Update SEO metadata error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/seo - get video SEO metadata
app.get('/v1/videos/:videoId/seo', async (req, res) => {
  try {
    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    const score = calculateSEOScore(videoData);

    res.json({
      videoId,
      seoTitle: videoData.seoTitle || null,
      seoDescription: videoData.seoDescription || null,
      keywords: videoData.seoKeywords || [],
      focusKeyword: videoData.focusKeyword || null,
      metaTags: videoData.seoMetaTags || [],
      seoScore: score
    });
  } catch (error) {
    console.error('Get SEO metadata error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/seo/analyze - analyze video SEO
app.get('/v1/videos/:videoId/seo/analyze', async (req, res) => {
  try {
    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    const analysis = analyzeSEO(videoData);

    res.json({
      videoId,
      analysis
    });
  } catch (error) {
    console.error('Analyze SEO error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/videos/:videoId/seo/keywords - generate SEO keywords
app.post('/v1/videos/:videoId/seo/keywords', async (req, res) => {
  try {
    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    const keywords = generateSEOKeywords(videoData);

    res.json({
      videoId,
      keywords
    });
  } catch (error) {
    console.error('Generate keywords error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

function calculateSEOScore(videoData: FirestoreData): number {
  let score = 0;
  const maxScore = 100;

  if (videoData.seoTitle && videoData.seoTitle.length > 10) score += 20;
  if (videoData.seoDescription && videoData.seoDescription.length > 50) score += 20;
  if (Array.isArray(videoData.seoKeywords) && videoData.seoKeywords.length >= 5) score += 15;
  if (videoData.focusKeyword) score += 10;
  if (videoData.thumbnailUrl) score += 15;
  if (videoData.tags && Array.isArray(videoData.tags) && videoData.tags.length >= 3) score += 10;
  if (videoData.category) score += 10;

  return Math.min(score, maxScore);
}

function analyzeSEO(videoData: FirestoreData): Record<string, any> {
  const issues: string[] = [];
  const suggestions: string[] = [];

  if (!videoData.seoTitle || videoData.seoTitle.length < 10) {
    issues.push('SEO title is missing or too short (should be at least 10 characters)');
    suggestions.push('Add a descriptive SEO title with relevant keywords');
  }

  if (!videoData.seoDescription || videoData.seoDescription.length < 50) {
    issues.push('SEO description is missing or too short (should be at least 50 characters)');
    suggestions.push('Write a compelling description that includes your focus keyword');
  }

  if (!Array.isArray(videoData.seoKeywords) || videoData.seoKeywords.length < 5) {
    issues.push('Keywords are missing or insufficient (should have at least 5 keywords)');
    suggestions.push('Add relevant keywords to help users discover your video');
  }

  if (!videoData.focusKeyword) {
    issues.push('Focus keyword is missing');
    suggestions.push('Set a focus keyword that represents the main topic of your video');
  }

  if (!videoData.thumbnailUrl) {
    issues.push('Thumbnail is missing');
    suggestions.push('Add an attractive thumbnail to improve click-through rate');
  }

  return {
    score: calculateSEOScore(videoData),
    issues,
    suggestions,
    hasIssues: issues.length > 0
  };
}

function generateSEOKeywords(videoData: FirestoreData): string[] {
  const keywords: string[] = [];

  if (videoData.title) {
    const titleWords = videoData.title.toLowerCase().split(/\s+/);
    titleWords.forEach(word => {
      if (word.length > 3 && !keywords.includes(word)) {
        keywords.push(word);
      }
    });
  }

  if (Array.isArray(videoData.tags)) {
    videoData.tags.forEach((tag: string) => {
      const tagLower = tag.toLowerCase();
      if (!keywords.includes(tagLower)) {
        keywords.push(tagLower);
      }
    });
  }

  if (videoData.category) {
    const categoryLower = videoData.category.toLowerCase();
    if (!keywords.includes(categoryLower)) {
      keywords.push(categoryLower);
    }
  }

  return keywords.slice(0, 15);
}

// ─────────────────────────────────────────────────────────────────────────────
// Video A/B Testing API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/:videoId/ab-tests - create A/B test
app.post('/v1/videos/:videoId/ab-tests', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { testName, variantType, variantA, variantB, trafficSplit } = req.body || {};

    if (!testName || typeof testName !== 'string') {
      return res.status(400).json({ error: 'testName is required' });
    }

    if (!variantType || typeof variantType !== 'string') {
      return res.status(400).json({ error: 'variantType is required' });
    }

    const validTypes = ['thumbnail', 'title', 'description', 'metadata'];
    if (!validTypes.includes(variantType)) {
      return res.status(400).json({ error: `variantType must be one of: ${validTypes.join(', ')}` });
    }

    if (!variantA || !variantB) {
      return res.status(400).json({ error: 'variantA and variantB are required' });
    }

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const testRef = videoRef.collection('abTests').doc();

    await testRef.set({
      videoId,
      testName: testName.trim(),
      variantType,
      variantA,
      variantB,
      trafficSplit: trafficSplit || 50,
      status: 'active',
      createdAt: now,
      startedAt: now,
      endedAt: null,
      results: {
        variantA: { impressions: 0, clicks: 0, ctr: 0 },
        variantB: { impressions: 0, clicks: 0, ctr: 0 }
      }
    });

    res.status(201).json({
      testId: testRef.id,
      testName: testName.trim(),
      variantType,
      status: 'active',
      createdAt: toIsoString(now)
    });
  } catch (error) {
    console.error('Create A/B test error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/videos/:videoId/ab-tests - list A/B tests
app.get('/v1/videos/:videoId/ab-tests', async (req, res) => {
  try {
    const { videoId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const testsSnap = await videoRef.collection('abTests')
      .orderBy('createdAt', 'desc')
      .get();

    const tests = testsSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        testName: data.testName,
        variantType: data.variantType,
        status: data.status,
        trafficSplit: data.trafficSplit,
        createdAt: toIsoString(data.createdAt),
        startedAt: toIsoString(data.startedAt),
        endedAt: data.endedAt ? toIsoString(data.endedAt) : null,
        results: data.results
      };
    });

    res.json({
      videoId,
      tests
    });
  } catch (error) {
    console.error('List A/B tests error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/videos/:videoId/ab-tests/:testId/end - end A/B test
app.put('/v1/videos/:videoId/ab-tests/:testId/end', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId, testId } = req.params;

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const testRef = videoRef.collection('abTests').doc(testId);
    const testSnap = await testRef.get();

    if (!testSnap.exists) {
      return res.status(404).json({ error: 'Test not found' });
    }

    const now = admin.firestore.Timestamp.now();
    await testRef.update({
      status: 'ended',
      endedAt: now
    });

    res.json({
      testId,
      status: 'ended',
      endedAt: toIsoString(now)
    });
  } catch (error) {
    console.error('End A/B test error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Granular User Preferences API
// ─────────────────────────────────────────────────────────────────────────────

// PUT /v1/users/:userId/preferences - update user preferences
app.put('/v1/users/:userId/preferences', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { autoplay, annotations, captionsQuality, playbackSpeed, theme, language, notifications, privacy } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const patch: Record<string, any> = {
      updatedAt: now
    };

    if (typeof autoplay === 'boolean') patch.autoplay = autoplay;
    if (typeof annotations === 'boolean') patch.showAnnotations = annotations;
    if (captionsQuality) patch.captionsQuality = captionsQuality;
    if (typeof playbackSpeed === 'number') patch.defaultPlaybackSpeed = playbackSpeed;
    if (theme) patch.theme = theme;
    if (language) patch.language = language;
    if (notifications) patch.notificationSettings = notifications;
    if (privacy) patch.privacySettings = privacy;

    await db.collection('users').doc(userId).collection('preferences').doc('settings').set(patch, { merge: true });

    res.json({
      userId,
      preferences: patch
    });
  } catch (error) {
    console.error('Update preferences error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/users/:userId/preferences - get user preferences
app.get('/v1/users/:userId/preferences', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const prefRef = db.collection('users').doc(userId).collection('preferences').doc('settings');
    const prefSnap = await prefRef.get();

    if (!prefSnap.exists) {
      return res.json({
        userId,
        preferences: {
          autoplay: true,
          showAnnotations: true,
          captionsQuality: 'auto',
          defaultPlaybackSpeed: 1,
          theme: 'system',
          language: 'en',
          notificationSettings: {},
          privacySettings: {}
        }
      });
    }

    const data = prefSnap.data()!;

    res.json({
      userId,
      preferences: {
        autoplay: data.autoplay !== undefined ? data.autoplay : true,
        showAnnotations: data.showAnnotations !== undefined ? data.showAnnotations : true,
        captionsQuality: data.captionsQuality || 'auto',
        defaultPlaybackSpeed: data.defaultPlaybackSpeed || 1,
        theme: data.theme || 'system',
        language: data.language || 'en',
        notificationSettings: data.notificationSettings || {},
        privacySettings: data.privacySettings || {}
      }
    });
  } catch (error) {
    console.error('Get preferences error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/users/:userId/preferences/reset - reset preferences to defaults
app.post('/v1/users/:userId/preferences/reset', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const defaultPreferences = {
      autoplay: true,
      showAnnotations: true,
      captionsQuality: 'auto',
      defaultPlaybackSpeed: 1,
      theme: 'system',
      language: 'en',
      notificationSettings: {},
      privacySettings: {},
      updatedAt: now
    };

    await db.collection('users').doc(userId).collection('preferences').doc('settings').set(defaultPreferences);

    res.json({
      userId,
      preferences: defaultPreferences
    });
  } catch (error) {
    console.error('Reset preferences error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Video Analytics Export API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/videos/:videoId/analytics/export - export video analytics
app.post('/v1/videos/:videoId/analytics/export', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId } = req.params;
    const { format, dateRange, metrics } = req.body || {};

    const videoRef = db.collection('videos').doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const videoData = videoSnap.data()!;

    if (String(videoData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const exportRef = db.collection('users').doc(user.userId).collection('analyticsExports').doc();

    await exportRef.set({
      userId: user.userId,
      videoId,
      exportType: 'video',
      format: format || 'csv',
      dateRange: dateRange || '30d',
      metrics: metrics || ['views', 'likes', 'comments', 'shares', 'watchTime'],
      status: 'pending',
      createdAt: now,
      completedAt: null,
      downloadUrl: null
    });

    res.status(201).json({
      exportId: exportRef.id,
      videoId,
      format: format || 'csv',
      status: 'pending',
      createdAt: toIsoString(now)
    });
  } catch (error) {
    console.error('Export video analytics error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/users/:userId/analytics/export - export channel analytics
app.post('/v1/users/:userId/analytics/export', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { format, dateRange, metrics } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const exportRef = db.collection('users').doc(userId).collection('analyticsExports').doc();

    await exportRef.set({
      userId,
      exportType: 'channel',
      format: format || 'csv',
      dateRange: dateRange || '30d',
      metrics: metrics || ['views', 'subscribers', 'revenue', 'engagement'],
      status: 'pending',
      createdAt: now,
      completedAt: null,
      downloadUrl: null
    });

    res.status(201).json({
      exportId: exportRef.id,
      exportType: 'channel',
      format: format || 'csv',
      status: 'pending',
      createdAt: toIsoString(now)
    });
  } catch (error) {
    console.error('Export channel analytics error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/users/:userId/analytics/exports - list export jobs
app.get('/v1/users/:userId/analytics/exports', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const exportsSnap = await db.collection('users').doc(userId).collection('analyticsExports')
      .orderBy('createdAt', 'desc')
      .limit(20)
      .get();

    const exports = exportsSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        exportType: data.exportType,
        videoId: data.videoId || null,
        format: data.format,
        dateRange: data.dateRange,
        metrics: data.metrics,
        status: data.status,
        createdAt: toIsoString(data.createdAt),
        completedAt: data.completedAt ? toIsoString(data.completedAt) : null,
        downloadUrl: data.downloadUrl
      };
    });

    res.json({
      userId,
      exports
    });
  } catch (error) {
    console.error('List exports error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Creator Tools API
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/users/:userId/quick-actions - execute quick action
app.post('/v1/users/:userId/quick-actions', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { actionType, targetId, params } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (!actionType || typeof actionType !== 'string') {
      return res.status(400).json({ error: 'actionType is required' });
    }

    const validActions = ['publish', 'unpublish', 'delete', 'archive', 'unarchive', 'add_to_playlist', 'remove_from_playlist'];
    if (!validActions.includes(actionType)) {
      return res.status(400).json({ error: `actionType must be one of: ${validActions.join(', ')}` });
    }

    const now = admin.firestore.Timestamp.now();
    const actionRef = db.collection('users').doc(userId).collection('quickActions').doc();

    await actionRef.set({
      userId,
      actionType,
      targetId: targetId || null,
      params: params || {},
      status: 'pending',
      createdAt: now,
      completedAt: null,
      result: null
    });

    res.status(201).json({
      actionId: actionRef.id,
      actionType,
      status: 'pending',
      createdAt: toIsoString(now)
    });
  } catch (error) {
    console.error('Execute quick action error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/users/:userId/bulk-actions - execute bulk action
app.post('/v1/users/:userId/bulk-actions', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { actionType, targetIds, params } = req.body || {};

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (!actionType || typeof actionType !== 'string') {
      return res.status(400).json({ error: 'actionType is required' });
    }

    if (!Array.isArray(targetIds) || targetIds.length === 0) {
      return res.status(400).json({ error: 'targetIds array is required' });
    }

    if (targetIds.length > 100) {
      return res.status(400).json({ error: 'targetIds array cannot exceed 100 items' });
    }

    const now = admin.firestore.Timestamp.now();
    const bulkActionRef = db.collection('users').doc(userId).collection('bulkActions').doc();

    await bulkActionRef.set({
      userId,
      actionType,
      targetIds,
      params: params || {},
      status: 'pending',
      progress: 0,
      total: targetIds.length,
      completed: 0,
      failed: 0,
      createdAt: now,
      completedAt: null
    });

    res.status(201).json({
      bulkActionId: bulkActionRef.id,
      actionType,
      total: targetIds.length,
      status: 'pending',
      createdAt: toIsoString(now)
    });
  } catch (error) {
    console.error('Execute bulk action error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/users/:userId/actions - list action history
app.get('/v1/users/:userId/actions', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { userId } = req.params;
    const { type } = req.query;

    if (userId !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const actions: any[] = [];

    const quickActionsSnap = await db.collection('users').doc(userId).collection('quickActions')
      .orderBy('createdAt', 'desc')
      .limit(20)
      .get();

    quickActionsSnap.docs.forEach(doc => {
      const data = doc.data();
      if (type && typeof type === 'string' && data.actionType !== type) return;
      actions.push({
        id: doc.id,
        type: 'quick',
        actionType: data.actionType,
        targetId: data.targetId,
        status: data.status,
        createdAt: toIsoString(data.createdAt),
        completedAt: data.completedAt ? toIsoString(data.completedAt) : null
      });
    });

    const bulkActionsSnap = await db.collection('users').doc(userId).collection('bulkActions')
      .orderBy('createdAt', 'desc')
      .limit(20)
      .get();

    bulkActionsSnap.docs.forEach(doc => {
      const data = doc.data();
      if (type && typeof type === 'string' && data.actionType !== type) return;
      actions.push({
        id: doc.id,
        type: 'bulk',
        actionType: data.actionType,
        total: data.total,
        progress: data.progress,
        completed: data.completed,
        failed: data.failed,
        status: data.status,
        createdAt: toIsoString(data.createdAt),
        completedAt: data.completedAt ? toIsoString(data.completedAt) : null
      });
    });

    actions.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    res.json({
      userId,
      actions: actions.slice(0, 40)
    });
  } catch (error) {
    console.error('List actions error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`📺 Content service listening on port ${port}`);
});


