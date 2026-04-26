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

function normalizeSearchText(value: unknown): string {
  return String(value || '').trim().toLowerCase();
}

function tokenizeQuery(value: string): string[] {
  return Array.from(new Set(
    normalizeSearchText(value)
      .split(/[^a-z0-9@#_]+/i)
      .map(token => token.trim())
      .filter(token => token.length >= 2)
  ));
}

function computeTokenCoverageScore(haystack: string, tokens: string[]): number {
  if (!tokens.length || !haystack) return 0;
  let score = 0;
  for (const token of tokens) {
    if (haystack === token) {
      score += 10;
      continue;
    }
    if (haystack.startsWith(token)) {
      score += 6;
      continue;
    }
    if (haystack.includes(` ${token} `) || haystack.endsWith(` ${token}`) || haystack.startsWith(`${token} `)) {
      score += 4;
      continue;
    }
    if (haystack.includes(token)) {
      score += 2;
    }
  }
  return score;
}

function computeRecencyBoost(value: any): number {
  const iso = toIsoString(value);
  if (!iso) return 0;
  const ageMs = Date.now() - new Date(iso).getTime();
  if (!Number.isFinite(ageMs) || ageMs < 0) return 0;
  const days = ageMs / (1000 * 60 * 60 * 24);
  if (days <= 3) return 4;
  if (days <= 7) return 3;
  if (days <= 30) return 2;
  if (days <= 90) return 1;
  return 0;
}

function computePopularityBoost(data: Record<string, any>): number {
  const views = Number(data.views || 0);
  const likes = Number(data.likes || 0);
  const comments = Number(data.comments || 0);
  return Math.min(8, Math.log10(Math.max(views, 1)) * 2 + Math.log10(Math.max(likes + comments, 1)));
}

function computeVideoSearchScore(
  queryText: string,
  tokens: string[],
  data: Record<string, any>,
  user: Record<string, any>
): number {
  if (!queryText) {
    return computePopularityBoost(data) + computeRecencyBoost(data.publishedAt || data.createdAt);
  }

  const title = normalizeSearchText(data.title);
  const description = normalizeSearchText(data.description);
  const searchText = normalizeSearchText(data.searchText);
  const tags = extractStringList(data.tags).map(normalizeSearchText).join(' ');
  const creatorUsername = normalizeSearchText(user.username);
  const creatorDisplayName = normalizeSearchText(user.displayName || user.name || user.username);

  let score = 0;

  if (title === queryText) score += 40;
  else if (title.startsWith(queryText)) score += 25;
  else if (title.includes(queryText)) score += 15;

  if (creatorUsername === queryText || creatorDisplayName === queryText) score += 18;

  score += computeTokenCoverageScore(title, tokens) * 3;
  score += computeTokenCoverageScore(tags, tokens) * 2.5;
  score += computeTokenCoverageScore(creatorUsername, tokens) * 2;
  score += computeTokenCoverageScore(creatorDisplayName, tokens) * 2;
  score += computeTokenCoverageScore(searchText, tokens) * 1.5;
  score += computeTokenCoverageScore(description, tokens) * 1;
  score += computePopularityBoost(data);
  score += computeRecencyBoost(data.publishedAt || data.createdAt);

  return Number(score.toFixed(2));
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
    const normalizedQuery = normalizeSearchText(q);
    const queryTokens = tokenizeQuery(q);
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    const category = req.query.category as string || null;
    const durationMin = parseInt(req.query.durationMin as string) || null;
    const durationMax = parseInt(req.query.durationMax as string) || null;
    const dateAfter = req.query.dateAfter as string || null;
    const dateBefore = req.query.dateBefore as string || null;
    const sortBy = (req.query.sortBy as string) || 'relevance';
    const quality = req.query.quality as string || null;

    let query: any = db.collection('videos').where('status', '==', 'published');

    if (category) {
      query = query.where('category', '==', category);
    }

    if (durationMin !== null) {
      query = query.where('duration', '>=', durationMin);
    }

    if (durationMax !== null) {
      query = query.where('duration', '<=', durationMax);
    }

    if (dateAfter) {
      const afterDate = new Date(dateAfter);
      query = query.where('publishedAt', '>=', admin.firestore.Timestamp.fromDate(afterDate));
    }

    if (dateBefore) {
      const beforeDate = new Date(dateBefore);
      query = query.where('publishedAt', '<=', admin.firestore.Timestamp.fromDate(beforeDate));
    }

    if (quality) {
      query = query.where('quality', '==', quality);
    }

    const orderByField = sortBy === 'views' ? 'views' : sortBy === 'likes' ? 'likes' : sortBy === 'date' ? 'publishedAt' : 'views';
    const orderByDir = sortBy === 'date' ? 'desc' : 'desc';

    query = query.orderBy(orderByField, orderByDir);

    const snap = await query.limit(Math.min(Math.max(page * limit * 5, 60), 240)).get();

    const usersMap = await loadUsersMap(snap.docs.map(doc => String(doc.get('ownerId') || '')));
    const rankedDocs = snap.docs.map(doc => {
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
      const matches = !normalizedQuery || fields.some(value => normalizeSearchText(value).includes(normalizedQuery)) || queryTokens.every(token => fields.some(value => normalizeSearchText(value).includes(token)));
      if (!matches) {
        return null;
      }

      return {
        doc,
        data,
        user,
        score: computeVideoSearchScore(normalizedQuery, queryTokens, data, user)
      };
    }).filter((entry): entry is { doc: FirebaseFirestore.QueryDocumentSnapshot; data: Record<string, any>; user: Record<string, any>; score: number } => Boolean(entry));

    rankedDocs.sort((a, b) => {
      if (sortBy === 'date') {
        return new Date(toIsoString(b.data.publishedAt || b.data.createdAt) || 0).getTime() - new Date(toIsoString(a.data.publishedAt || a.data.createdAt) || 0).getTime();
      }
      if (sortBy === 'likes') {
        return Number(b.data.likes || 0) - Number(a.data.likes || 0) || b.score - a.score;
      }
      if (sortBy === 'views') {
        return Number(b.data.views || 0) - Number(a.data.views || 0) || b.score - a.score;
      }
      return b.score - a.score || Number(b.data.views || 0) - Number(a.data.views || 0);
    });

    const items = rankedDocs.slice(offset, offset + limit).map(({ doc, data, user, score }) => {
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
        category: data.category || null,
        quality: data.quality || null,
        creator: {
          id: String(data.ownerId || ''),
          username: user.username || '',
          displayName: user.displayName || user.name || user.username || '',
          avatarUrl: user.avatarUrl || null,
          verified: !!user.verified,
          subscriberCount: Number(user.subscriberCount || user.subscriber_count || 0)
        },
        relevanceScore: score
      };
    });

    const facets: any = {
      categories: {},
      durations: {},
      qualities: {}
    };

    rankedDocs.forEach(({ data }) => {
      if (data.category) {
        facets.categories[data.category] = (facets.categories[data.category] || 0) + 1;
      }
      const duration = typeof data.duration === 'number' ? data.duration : null;
      if (duration) {
        if (duration < 300) facets.durations['short'] = (facets.durations['short'] || 0) + 1;
        else if (duration < 1200) facets.durations['medium'] = (facets.durations['medium'] || 0) + 1;
        else facets.durations['long'] = (facets.durations['long'] || 0) + 1;
      }
      if (data.quality) {
        facets.qualities[data.quality] = (facets.qualities[data.quality] || 0) + 1;
      }
    });

    return res.json({
      items,
      total: rankedDocs.length,
      q,
      filters: { category, durationMin, durationMax, dateAfter, dateBefore, sortBy, quality },
      facets,
      pagination: {
        page,
        limit,
        hasMore: rankedDocs.length > offset + items.length
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
    const qLower = normalizeSearchText(q);
    const queryTokens = tokenizeQuery(q);
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
      const normalizedTitle = normalizeSearchText(title);
      if (title && (normalizedTitle.includes(qLower) || queryTokens.every(token => normalizedTitle.includes(token)))) {
        suggestions.add(title);
      }

      for (const tag of extractStringList(data.tags)) {
        const normalizedTag = normalizeSearchText(tag);
        if (normalizedTag.includes(qLower) || queryTokens.every(token => normalizedTag.includes(token))) {
          suggestions.add(tag);
        }
      }

      const category = String(data.category || '').trim();
      const normalizedCategory = normalizeSearchText(category);
      if (category && (normalizedCategory.includes(qLower) || queryTokens.every(token => normalizedCategory.includes(token)))) {
        suggestions.add(category);
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




