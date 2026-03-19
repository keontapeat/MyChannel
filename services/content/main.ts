import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import admin from 'firebase-admin';
import { Storage } from '@google-cloud/storage';

// Initialize Firebase Admin (Application Default Credentials or service account)
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();
const storage = new Storage();
const STORIES_BUCKET = process.env.STORIES_BUCKET || 'mychannel-ingest';

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
    const ownerIds = Array.from(new Set(videoDocs.map(d => d.get('ownerId')).filter(Boolean)));
    const ownersMap: Record<string, FirebaseFirestore.DocumentData | null> = {};
    if (ownerIds.length) {
      const ownerSnaps = await Promise.all(ownerIds.map(id => db.collection('users').doc(String(id)).get()));
      for (const ds of ownerSnaps) {
        ownersMap[ds.id] = ds.exists ? ds.data()! : null;
      }
    }

    const formattedVideos = videoDocs.map(d => {
      const v = d.data();
      const u = ownersMap[String(v.ownerId)] || {};
      return {
        id: d.id,
        title: v.title || '',
        description: v.description || null,
        thumbnailUrl: v.thumbnailUrl || null,
        duration: v.duration || null,
        viewCount: v.views || 0,
        likeCount: v.likes || 0,
        commentCount: v.comments || 0,
        publishedAt: v.publishedAt || null,
        createdAt: v.createdAt || null,
        creator: {
          id: String(v.ownerId || ''),
          username: u.username || '',
          displayName: u.displayName || u.name || '',
          avatarUrl: u.avatarUrl || null,
          verified: !!u.verified,
          subscriberCount: u.subscriberCount || 0
        }
      };
    });

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
    if (v.status && v.status !== 'published') {
      return res.status(404).json({ error: 'Video not available' });
    }
    if (v.visibility && v.visibility === 'private') {
      return res.status(403).json({ error: 'Video is private' });
    }

    // Fetch creator
    let creator: any = { id: String(v.ownerId || '') };
    if (v.ownerId) {
      const uSnap = await db.collection('users').doc(String(v.ownerId)).get();
      const u = uSnap.exists ? uSnap.data()! : {};
      creator = {
        id: String(v.ownerId),
        username: u.username || '',
        displayName: u.displayName || u.name || '',
        avatarUrl: u.avatarUrl || null,
        bio: u.bio || null,
        verified: !!u.verified,
        subscriberCount: u.subscriberCount || 0,
        videoCount: u.videoCount || 0,
        totalViews: u.totalViews || 0
      };
    }

    const formattedVideo = {
      id: doc.id,
      title: v.title || '',
      description: v.description || null,
      thumbnailUrl: v.thumbnailUrl || null,
      videoUrl: v.videoUrl || null,
      duration: v.duration || null,
      fileSize: v.fileSize || null,
      status: v.status || 'ready',
      qualityVariants: v.qualityVariants || [],
      captions: v.captions || [],
      chapters: v.chapters || [],
      visibility: v.visibility || 'public',
      isLive: !!v.isLive,
      isPremium: !!v.isPremium,
      viewCount: v.views || 0,
      likeCount: v.likes || 0,
      dislikeCount: v.dislikes || 0,
      commentCount: v.comments || 0,
      shareCount: v.shares || 0,
      category: v.category || null,
      tags: v.tags || [],
      language: v.language || 'en',
      ageRestriction: v.ageRestriction || 0,
      publishedAt: v.publishedAt || null,
      createdAt: v.createdAt || null,
      updatedAt: v.updatedAt || null,
      creator
    };

    res.json({ video: formattedVideo });
  } catch (error) {
    console.error('Video fetch error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Search videos
app.get('/v1/search', async (req, res) => {
  try {
    const query = req.query.q as string;
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    if (!query || query.trim().length === 0) {
      return res.status(400).json({ error: 'Search query is required' });
    }

    // Firestore naive search: match tags or title prefix if maintained
    const qLower = query.toLowerCase();
    const byTagsSnap = await db.collection('videos')
      .where('status', '==', 'published')
      .where('tags', 'array-contains', qLower)
      .orderBy('views', 'desc')
      .offset(offset)
      .limit(limit)
      .get();
    const docs = byTagsSnap.docs;

    const ownerIds = Array.from(new Set(docs.map(d => d.get('ownerId')).filter(Boolean)));
    const ownersMap: Record<string, FirebaseFirestore.DocumentData | null> = {};
    if (ownerIds.length) {
      const ownerSnaps = await Promise.all(ownerIds.map(id => db.collection('users').doc(String(id)).get()));
      for (const ds of ownerSnaps) {
        ownersMap[ds.id] = ds.exists ? ds.data()! : null;
      }
    }
    const formattedVideos = docs.map(d => {
      const v = d.data();
      const u = ownersMap[String(v.ownerId)] || {};
      return {
        id: d.id,
        title: v.title || '',
        description: v.description || null,
        thumbnailUrl: v.thumbnailUrl || null,
        duration: v.duration || null,
        viewCount: v.views || 0,
        likeCount: v.likes || 0,
        commentCount: v.comments || 0,
        publishedAt: v.publishedAt || null,
        createdAt: v.createdAt || null,
        creator: {
          id: String(v.ownerId || ''),
          username: u.username || '',
          displayName: u.displayName || u.name || '',
          avatarUrl: u.avatarUrl || null,
          verified: !!u.verified,
          subscriberCount: u.subscriberCount || 0
        }
      };
    });

    res.json({
      query,
      videos: formattedVideos,
      pagination: {
        page,
        limit,
        hasMore: formattedVideos.length === limit
      }
    });
  } catch (error) {
    console.error('Search error:', error);
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
    let afterTs: FirebaseFirestore.Timestamp | null = null;
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

    const ownerIds = Array.from(new Set(docs.map(d => d.get('ownerId')).filter(Boolean)));
    const ownersMap: Record<string, FirebaseFirestore.DocumentData | null> = {};
    if (ownerIds.length) {
      const ownerSnaps = await Promise.all(ownerIds.map(id => db.collection('users').doc(String(id)).get()));
      for (const ds of ownerSnaps) {
        ownersMap[ds.id] = ds.exists ? ds.data()! : null;
      }
    }

    const formattedVideos = docs.map(d => {
      const v = d.data();
      const u = ownersMap[String(v.ownerId)] || {};
      return {
        id: d.id,
        title: v.title || '',
        description: v.description || null,
        thumbnailUrl: v.thumbnailUrl || null,
        duration: v.duration || null,
        viewCount: v.views || 0,
        likeCount: v.likes || 0,
        commentCount: v.comments || 0,
        publishedAt: v.publishedAt || null,
        createdAt: v.createdAt || null,
        creator: {
          id: String(v.ownerId || ''),
          username: u.username || '',
          displayName: u.displayName || u.name || '',
          avatarUrl: u.avatarUrl || null,
          verified: !!u.verified,
          subscriberCount: u.subscriberCount || 0
        }
      };
    });

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
    const ownerIds = Array.from(new Set(docs.map(d => d.get('ownerId')).filter(Boolean)));
    const ownersMap: Record<string, FirebaseFirestore.DocumentData | null> = {};
    if (ownerIds.length) {
      const ownerSnaps = await Promise.all(ownerIds.map(id => db.collection('users').doc(String(id)).get()));
      for (const ds of ownerSnaps) {
        ownersMap[ds.id] = ds.exists ? ds.data()! : null;
      }
    }
    const formattedVideos = docs.map(d => {
      const v = d.data();
      const u = ownersMap[String(v.ownerId)] || {};
      return {
        id: d.id,
        title: v.title || '',
        description: v.description || null,
        thumbnailUrl: v.thumbnailUrl || null,
        duration: v.duration || null,
        viewCount: v.views || 0,
        likeCount: v.likes || 0,
        commentCount: v.comments || 0,
        publishedAt: v.publishedAt || null,
        createdAt: v.createdAt || null,
        creator: {
          id: String(v.ownerId || ''),
          username: u.username || '',
          displayName: u.displayName || u.name || '',
          avatarUrl: u.avatarUrl || null,
          verified: !!u.verified,
          subscriberCount: u.subscriberCount || 0
        }
      };
    });

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
    const ownerIds = Array.from(new Set(docs.map(d => d.get('ownerId')).filter(Boolean)));
    const ownersMap: Record<string, FirebaseFirestore.DocumentData | null> = {};
    if (ownerIds.length) {
      const ownerSnaps = await Promise.all(ownerIds.map(oid => db.collection('users').doc(String(oid)).get()));
      for (const ds of ownerSnaps) {
        ownersMap[ds.id] = ds.exists ? ds.data()! : null;
      }
    }
    const formattedVideos = docs.map(d => {
      const v = d.data();
      const u = ownersMap[String(v.ownerId)] || {};
      return {
        id: d.id,
        title: v.title || '',
        description: v.description || null,
        thumbnailUrl: v.thumbnailUrl || null,
        duration: v.duration || null,
        viewCount: v.views || 0,
        likeCount: v.likes || 0,
        commentCount: v.comments || 0,
        publishedAt: v.publishedAt || null,
        createdAt: v.createdAt || null,
        creator: {
          id: String(v.ownerId || ''),
          username: u.username || '',
          displayName: u.displayName || u.name || '',
          avatarUrl: u.avatarUrl || null,
          verified: !!u.verified,
          subscriberCount: u.subscriberCount || 0
        }
      };
    });

    res.json({ videos: formattedVideos });
  } catch (error) {
    console.error('Related videos error:', error);
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

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`📺 Content service listening on port ${port}`);
});


