import express from 'express';
import cors from 'cors';
import admin from 'firebase-admin';
import jwt from 'jsonwebtoken';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const JWT_SECRET = process.env.JWT_SECRET || '';

type AuthenticatedUser = {
  userId: string;
  email: string | null;
  username: string | null;
  premiumTier: string | null;
};

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

async function verifyUser(authHeader: string | undefined): Promise<AuthenticatedUser | null> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
  const token = authHeader.slice(7).trim();
  if (!token) return null;

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    return {
      userId: decoded.uid,
      email: decoded.email || null,
      username: decoded.name || (decoded.email ? decoded.email.split('@')[0] : null),
      premiumTier: null
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
      premiumTier: decoded.premiumTier || null
    };
  } catch {
    return null;
  }
}

async function requireUser(req: any, res: any): Promise<AuthenticatedUser | null> {
  const user = await verifyUser(req.headers.authorization);
  if (!user) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
  return user;
}

const app = express();
app.use(cors());
app.use(express.json());

// GET /v1/creator/drafts
app.get('/v1/creator/drafts', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;
    const snap = await db.collection('videos')
      .where('ownerId', '==', user.userId)
      .orderBy('updatedAt', 'desc')
      .limit(Math.min(Math.max(page * limit * 4, 40), 200))
      .get();

    const filteredDocs = snap.docs.filter(doc => String(doc.get('status') || 'draft') !== 'published');
    const drafts = filteredDocs.slice(offset, offset + limit).map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        title: data.title || '',
        description: data.description || null,
        thumbnailUrl: data.thumbnailUrl || null,
        videoUrl: data.videoUrl || null,
        visibility: data.visibility || 'private',
        status: data.status || 'draft',
        category: data.category || null,
        tags: extractStringList(data.tags),
        isPremium: !!data.isPremium,
        createdAt: toIsoString(data.createdAt),
        updatedAt: toIsoString(data.updatedAt) || toIsoString(data.createdAt)
      };
    });

    return res.json({
      drafts,
      pagination: {
        page,
        limit,
        hasMore: filteredDocs.length > offset + drafts.length
      }
    });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

// POST /v1/creator/drafts
app.post('/v1/creator/drafts', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const body = req.body || {};
    const draftId = String(body.id || '').trim();
    const now = admin.firestore.Timestamp.now();
    const draftRef = draftId ? db.collection('videos').doc(draftId) : db.collection('videos').doc();
    const existing = await draftRef.get();

    if (existing.exists && String(existing.get('ownerId') || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const payload = {
      ownerId: user.userId,
      title: String(body.title || '').trim() || 'Untitled Draft',
      description: String(body.description || '').trim() || null,
      thumbnailUrl: String(body.thumbnailUrl || '').trim() || null,
      videoUrl: String(body.videoUrl || '').trim() || null,
      visibility: String(body.visibility || 'private').trim().toLowerCase() || 'private',
      status: 'draft',
      category: String(body.category || '').trim() || null,
      tags: Array.from(new Set(extractStringList(body.tags).map(tag => tag.toLowerCase()))).slice(0, 25),
      isPremium: !!body.isPremium,
      language: String(body.language || 'en').trim() || 'en',
      updatedAt: now,
      createdAt: existing.exists ? (existing.get('createdAt') || now) : now
    };

    await draftRef.set(payload, { merge: true });

    return res.status(existing.exists ? 200 : 201).json({
      id: draftRef.id,
      draft: {
        id: draftRef.id,
        title: payload.title,
        description: payload.description,
        thumbnailUrl: payload.thumbnailUrl,
        videoUrl: payload.videoUrl,
        visibility: payload.visibility,
        status: payload.status,
        category: payload.category,
        tags: payload.tags,
        isPremium: payload.isPremium,
        createdAt: toIsoString(payload.createdAt),
        updatedAt: toIsoString(payload.updatedAt)
      }
    });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

// GET /v1/creator/analytics
app.get('/v1/creator/analytics', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const [videosSnap, userSnap] = await Promise.all([
      db.collection('videos')
        .where('ownerId', '==', user.userId)
        .orderBy('createdAt', 'desc')
        .limit(200)
        .get(),
      db.collection('users').doc(user.userId).get()
    ]);

    const videos = videosSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    const publishedVideos = videos.filter(video => String(video.status || '') === 'published');
    const draftVideos = videos.filter(video => String(video.status || '') !== 'published');
    const views = publishedVideos.reduce((sum, video) => sum + Number(video.views || 0), 0);
    const watchTime = publishedVideos.reduce((sum, video) => sum + Number(video.watchTime || video.watchTimeMinutes || 0), 0);
    const likes = publishedVideos.reduce((sum, video) => sum + Number(video.likes || 0), 0);
    const comments = publishedVideos.reduce((sum, video) => sum + Number(video.comments || 0), 0);
    const subscribers = Number(userSnap.data()?.subscriberCount || userSnap.data()?.subscriber_count || 0);

    return res.json({
      views,
      watchTime,
      subscribers,
      likes,
      comments,
      videoCount: publishedVideos.length,
      draftCount: draftVideos.length,
      recentVideos: videos.slice(0, 5).map(video => ({
        id: video.id,
        title: video.title || '',
        status: video.status || 'draft',
        viewCount: Number(video.views || 0),
        likeCount: Number(video.likes || 0),
        commentCount: Number(video.comments || 0),
        createdAt: toIsoString(video.createdAt),
        updatedAt: toIsoString(video.updatedAt) || toIsoString(video.createdAt)
      }))
    });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`creator service listening on ${port}`));




