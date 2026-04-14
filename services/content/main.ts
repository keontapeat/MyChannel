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

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`📺 Content service listening on port ${port}`);
});


