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

function normalizeTags(value: unknown): string[] {
  return Array.from(new Set(extractStringList(value).map(tag => tag.toLowerCase()))).slice(0, 25);
}

function toNumber(value: unknown): number {
  const num = Number(value || 0);
  return Number.isFinite(num) ? num : 0;
}

function publishedAtMillis(value: any): number {
  const iso = toIsoString(value);
  return iso ? new Date(iso).getTime() : 0;
}

function computePublishReadiness(data: Record<string, any>) {
  const checklist = {
    title: !!String(data.title || '').trim(),
    description: String(data.description || '').trim().length >= 20,
    thumbnail: !!String(data.thumbnailUrl || '').trim(),
    video: !!String(data.videoUrl || '').trim(),
    category: !!String(data.category || '').trim(),
    tags: normalizeTags(data.tags).length >= 3,
    visibility: ['private', 'unlisted', 'public'].includes(String(data.visibility || '').trim().toLowerCase())
  };

  const completed = Object.values(checklist).filter(Boolean).length;
  const total = Object.keys(checklist).length;
  return {
    checklist,
    completed,
    total,
    score: Number((completed / total).toFixed(2)),
    ready: completed === total
  };
}

function computeEngagementRate(video: Record<string, any>): number {
  const views = Math.max(1, toNumber(video.views));
  const interactions = toNumber(video.likes) + toNumber(video.comments) + toNumber(video.shares);
  return Number(((interactions / views) * 100).toFixed(2));
}

function computeAverageViewDuration(video: Record<string, any>): number | null {
  const views = toNumber(video.views);
  const watchTime = toNumber(video.watchTime || video.watchTimeMinutes || 0);
  if (!views || !watchTime) return null;
  return Number((watchTime / views).toFixed(2));
}

function formatDraft(doc: FirebaseFirestore.QueryDocumentSnapshot | FirebaseFirestore.DocumentSnapshot) {
  const data = doc.data() || {};
  const readiness = computePublishReadiness(data as Record<string, any>);
  return {
    id: doc.id,
    title: data.title || '',
    description: data.description || null,
    thumbnailUrl: data.thumbnailUrl || null,
    videoUrl: data.videoUrl || null,
    visibility: data.visibility || 'private',
    status: data.status || 'draft',
    category: data.category || null,
    tags: normalizeTags(data.tags),
    isPremium: !!data.isPremium,
    language: data.language || 'en',
    monetizationStatus: data.monetizationStatus || 'not_reviewed',
    scheduledPublishAt: toIsoString(data.scheduledPublishAt),
    createdAt: toIsoString(data.createdAt),
    updatedAt: toIsoString(data.updatedAt) || toIsoString(data.createdAt),
    publishReadiness: readiness
  };
}

function formatVideoPerformance(video: Record<string, any>) {
  return {
    id: String(video.id || ''),
    title: video.title || '',
    status: video.status || 'draft',
    visibility: video.visibility || 'private',
    publishedAt: toIsoString(video.publishedAt || video.createdAt),
    viewCount: toNumber(video.views),
    likeCount: toNumber(video.likes),
    commentCount: toNumber(video.comments),
    shareCount: toNumber(video.shares),
    watchTime: toNumber(video.watchTime || video.watchTimeMinutes || 0),
    avgViewDuration: computeAverageViewDuration(video),
    engagementRate: computeEngagementRate(video),
    ctr: video.ctr != null ? Number(Number(video.ctr).toFixed(2)) : null,
    revenue: toNumber(video.revenue),
    estimatedRevenue: toNumber(video.estimatedRevenue || video.revenue),
    monetizationStatus: video.monetizationStatus || 'not_reviewed',
    updatedAt: toIsoString(video.updatedAt) || toIsoString(video.createdAt)
  };
}

function summarizeWindow(videos: Record<string, any>[], days: number) {
  const cutoff = Date.now() - days * 24 * 60 * 60 * 1000;
  const inWindow = videos.filter(video => publishedAtMillis(video.publishedAt || video.createdAt) >= cutoff);
  return {
    days,
    videoCount: inWindow.length,
    views: inWindow.reduce((sum, video) => sum + toNumber(video.views), 0),
    watchTime: inWindow.reduce((sum, video) => sum + toNumber(video.watchTime || video.watchTimeMinutes || 0), 0),
    likes: inWindow.reduce((sum, video) => sum + toNumber(video.likes), 0),
    comments: inWindow.reduce((sum, video) => sum + toNumber(video.comments), 0),
    revenue: inWindow.reduce((sum, video) => sum + toNumber(video.estimatedRevenue || video.revenue), 0)
  };
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
    const drafts = filteredDocs.slice(offset, offset + limit).map(doc => formatDraft(doc));

    return res.json({
      drafts,
      summary: {
        totalDrafts: filteredDocs.length,
        readyToPublish: drafts.filter(draft => draft.publishReadiness.ready).length,
        scheduled: drafts.filter(draft => !!draft.scheduledPublishAt).length,
        monetized: drafts.filter(draft => draft.isPremium || draft.monetizationStatus === 'approved').length
      },
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
      status: String(body.status || existing.get('status') || 'draft').trim().toLowerCase() || 'draft',
      category: String(body.category || '').trim() || null,
      tags: normalizeTags(body.tags),
      isPremium: !!body.isPremium,
      language: String(body.language || 'en').trim() || 'en',
      monetizationStatus: String(body.monetizationStatus || existing.get('monetizationStatus') || 'not_reviewed').trim().toLowerCase() || 'not_reviewed',
      scheduledPublishAt: body.scheduledPublishAt ? admin.firestore.Timestamp.fromDate(new Date(String(body.scheduledPublishAt))) : (existing.get('scheduledPublishAt') || null),
      metadataCompletionScore: computePublishReadiness(body).score,
      updatedAt: now,
      createdAt: existing.exists ? (existing.get('createdAt') || now) : now
    };

    await draftRef.set(payload, { merge: true });

    const updatedDraft = await draftRef.get();

    return res.status(existing.exists ? 200 : 201).json({
      id: draftRef.id,
      draft: formatDraft(updatedDraft),
      publishReady: formatDraft(updatedDraft).publishReadiness.ready
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
    const revenue = publishedVideos.reduce((sum, video) => sum + toNumber(video.estimatedRevenue || video.revenue), 0);
    const averageViewsPerVideo = publishedVideos.length ? Number((views / publishedVideos.length).toFixed(2)) : 0;
    const averageEngagementRate = publishedVideos.length
      ? Number((publishedVideos.reduce((sum, video) => sum + computeEngagementRate(video), 0) / publishedVideos.length).toFixed(2))
      : 0;
    const topVideos = publishedVideos
      .map(video => formatVideoPerformance(video))
      .sort((a, b) => b.viewCount - a.viewCount || b.engagementRate - a.engagementRate)
      .slice(0, 5);
    const recentVideos = videos
      .slice(0, 10)
      .map(video => formatVideoPerformance(video));
    const readinessSummary = draftVideos
      .map(video => computePublishReadiness(video))
      .reduce((acc, readiness) => {
        acc.readyToPublish += readiness.ready ? 1 : 0;
        acc.avgCompletionScore += readiness.score;
        return acc;
      }, { readyToPublish: 0, avgCompletionScore: 0 });
    const avgDraftCompletionScore = draftVideos.length
      ? Number((readinessSummary.avgCompletionScore / draftVideos.length).toFixed(2))
      : 0;

    return res.json({
      views,
      watchTime,
      subscribers,
      likes,
      comments,
      revenue,
      videoCount: publishedVideos.length,
      draftCount: draftVideos.length,
      averageViewsPerVideo,
      averageEngagementRate,
      draftReadiness: {
        readyToPublish: readinessSummary.readyToPublish,
        avgCompletionScore: avgDraftCompletionScore
      },
      windows: {
        last7Days: summarizeWindow(publishedVideos, 7),
        last28Days: summarizeWindow(publishedVideos, 28),
        last90Days: summarizeWindow(publishedVideos, 90)
      },
      topVideos,
      recentVideos
    });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`creator service listening on ${port}`));




