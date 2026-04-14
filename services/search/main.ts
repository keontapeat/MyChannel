import express from 'express';
import cors from 'cors';
import admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function extractStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map(item => String(item).trim()).filter(Boolean);
}

function toIsoString(value: any): string | null {
  if (!value) return null;
  if (typeof value === 'string') return value;
  if (value instanceof Date) return value.toISOString();
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (typeof value._seconds === 'number') return new Date(value._seconds * 1000).toISOString();
  return null;
}

async function loadUsersMap(userIds: string[]): Promise<Record<string, Record<string, any> | null>> {
  const ids = Array.from(new Set(userIds.map(id => String(id || '')).filter(Boolean)));
  const usersMap: Record<string, Record<string, any> | null> = {};
  if (!ids.length) return usersMap;

  const snaps = await Promise.all(ids.map(id => db.collection('users').doc(id).get()));
  for (const snap of snaps) {
    usersMap[snap.id] = snap.exists ? (snap.data() as Record<string, any>) : null;
  }
  return usersMap;
}

const app = express();
app.use(cors());
app.use(express.json());

// GET /v1/search?q=term
app.get('/v1/search', async (req, res) => {
  try {
    const q = String(req.query.q || '').trim();
    if (!q) return res.json({ items: [], total: 0 });

    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;
    const qLower = q.toLowerCase();
    const snap = await db.collection('videos')
      .where('status', '==', 'published')
      .orderBy('views', 'desc')
      .limit(Math.min(Math.max(page * limit * 5, 60), 240))
      .get();

    const usersMap = await loadUsersMap(snap.docs.map(doc => String(doc.get('ownerId') || '')));
    const filteredDocs = snap.docs.filter(doc => {
      const data = doc.data();
      const user = usersMap[String(data.ownerId || '')] || {};
      const fields = [
        String(data.title || ''),
        String(data.description || ''),
        String(data.searchText || ''),
        ...extractStringList(data.tags),
        String(user.username || ''),
        String(user.displayName || user.name || '')
      ];
      return fields.some(value => value.toLowerCase().includes(qLower));
    });

    const items = filteredDocs.slice(offset, offset + limit).map(doc => {
      const data = doc.data();
      const user = usersMap[String(data.ownerId || '')] || {};
      return {
        id: doc.id,
        title: data.title || '',
        description: data.description || null,
        thumbnailUrl: data.thumbnailUrl || null,
        duration: typeof data.duration === 'number' ? data.duration : (data.duration ? Number(data.duration) : null),
        viewCount: Number(data.views || 0),
        likeCount: Number(data.likes || 0),
        commentCount: Number(data.comments || 0),
        publishedAt: toIsoString(data.publishedAt),
        createdAt: toIsoString(data.createdAt),
        creator: {
          id: String(data.ownerId || ''),
          username: user.username || '',
          displayName: user.displayName || user.name || user.username || '',
          avatarUrl: user.avatarUrl || null,
          verified: !!user.verified,
          subscriberCount: Number(user.subscriberCount || user.subscriber_count || 0)
        }
      };
    });

    return res.json({
      items,
      total: filteredDocs.length,
      q,
      pagination: {
        page,
        limit,
        hasMore: filteredDocs.length > offset + items.length
      }
    });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

// GET /v1/suggest?q=te
app.get('/v1/suggest', async (req, res) => {
  try {
    const q = String(req.query.q || '').trim();
    const limit = Math.min(parseInt(req.query.limit as string) || 8, 20);
    const qLower = q.toLowerCase();
    if (!qLower) {
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
      if (title && title.toLowerCase().includes(qLower)) {
        suggestions.add(title);
      }

      for (const tag of extractStringList(data.tags)) {
        if (tag.toLowerCase().includes(qLower)) {
          suggestions.add(tag);
        }
      }

      if (suggestions.size >= limit) {
        break;
      }
    }

    return res.json({ suggestions: Array.from(suggestions).slice(0, limit) });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`search service listening on ${port}`));




