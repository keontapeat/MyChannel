import express from 'express';
import cors from 'cors';
import admin from 'firebase-admin';

// Real lexical/relevance search over the `videos` collection, plus channel
// search over `users`. Field names below match the actual schema written by
// web-v2 / iOS (see firestore.rules + web-v2/lib/firebase/services/video-service.ts):
//   videos:  isPublic, viewCount, likeCount, commentCount, creatorId, createdAt, tags
//   users:   username, displayName, subscriberCount, isVerified, profileImageURL
// A previous version of this file used YouTube-style field names
// (status/views/likes/ownerId/publishedAt) that don't exist in this schema —
// every query silently matched zero documents. This rewrite fixes that and
// keeps the same relevance-scoring approach (token coverage + popularity +
// recency), which is still a legitimate lexical ranker even without a
// dedicated search engine (Algolia/Typesense/Elasticsearch).

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function extractStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map((item) => String(item).trim()).filter(Boolean);
}

function normalizeSearchText(value: unknown): string {
  return String(value || '').trim().toLowerCase();
}

function tokenizeQuery(value: string): string[] {
  return Array.from(
    new Set(
      normalizeSearchText(value)
        .split(/[^a-z0-9@#_]+/i)
        .map((token) => token.trim())
        .filter((token) => token.length >= 2)
    )
  );
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

function toIsoString(value: any): string | null {
  if (!value) return null;
  if (typeof value === 'string') return value;
  if (value instanceof Date) return value.toISOString();
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (typeof value._seconds === 'number') return new Date(value._seconds * 1000).toISOString();
  return null;
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
  const views = Number(data.viewCount || 0);
  const likes = Number(data.likeCount || 0);
  const comments = Number(data.commentCount || 0);
  return Math.min(8, Math.log10(Math.max(views, 1)) * 2 + Math.log10(Math.max(likes + comments, 1)));
}

function computeVideoSearchScore(
  queryText: string,
  tokens: string[],
  data: Record<string, any>,
  creator: Record<string, any>
): number {
  if (!queryText) {
    return computePopularityBoost(data) + computeRecencyBoost(data.createdAt);
  }

  const title = normalizeSearchText(data.title);
  const description = normalizeSearchText(data.description);
  const tags = extractStringList(data.tags).map(normalizeSearchText).join(' ');
  const category = normalizeSearchText(data.category);
  const creatorUsername = normalizeSearchText(creator.username);
  const creatorDisplayName = normalizeSearchText(creator.displayName);

  let score = 0;

  if (title === queryText) score += 40;
  else if (title.startsWith(queryText)) score += 25;
  else if (title.includes(queryText)) score += 15;

  if (creatorUsername === queryText || creatorDisplayName === queryText) score += 18;

  score += computeTokenCoverageScore(title, tokens) * 3;
  score += computeTokenCoverageScore(tags, tokens) * 2.5;
  score += computeTokenCoverageScore(creatorUsername, tokens) * 2;
  score += computeTokenCoverageScore(creatorDisplayName, tokens) * 2;
  score += computeTokenCoverageScore(category, tokens) * 1.5;
  score += computeTokenCoverageScore(description, tokens) * 1;
  score += computePopularityBoost(data);
  score += computeRecencyBoost(data.createdAt);

  return Number(score.toFixed(2));
}

async function loadUsersMap(userIds: string[]): Promise<Record<string, Record<string, any> | null>> {
  const ids = Array.from(new Set(userIds.map((id) => String(id || '')).filter(Boolean)));
  const usersMap: Record<string, Record<string, any> | null> = {};
  if (!ids.length) return usersMap;

  const snaps = await Promise.all(ids.map((id) => db.collection('users').doc(id).get()));
  for (const snap of snaps) {
    usersMap[snap.id] = snap.exists ? (snap.data() as Record<string, any>) : null;
  }
  return usersMap;
}

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// GET /v1/search?q=term
app.get('/v1/search', async (req, res) => {
  try {
    const q = String(req.query.q || '').trim();
    const normalizedQuery = normalizeSearchText(q);
    const queryTokens = tokenizeQuery(q);
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    const category = (req.query.category as string) || null;
    const durationMin = parseInt(req.query.durationMin as string) || null;
    const durationMax = parseInt(req.query.durationMax as string) || null;
    const dateAfter = (req.query.dateAfter as string) || null;
    const dateBefore = (req.query.dateBefore as string) || null;
    const sortBy = (req.query.sortBy as string) || 'relevance';

    let firestoreQuery: any = db.collection('videos').where('isPublic', '==', true);

    if (category) {
      firestoreQuery = firestoreQuery.where('category', '==', category);
    }
    if (durationMin !== null) {
      firestoreQuery = firestoreQuery.where('duration', '>=', durationMin);
    }
    if (durationMax !== null) {
      firestoreQuery = firestoreQuery.where('duration', '<=', durationMax);
    }
    if (dateAfter) {
      firestoreQuery = firestoreQuery.where(
        'createdAt',
        '>=',
        admin.firestore.Timestamp.fromDate(new Date(dateAfter))
      );
    }
    if (dateBefore) {
      firestoreQuery = firestoreQuery.where(
        'createdAt',
        '<=',
        admin.firestore.Timestamp.fromDate(new Date(dateBefore))
      );
    }

    const orderByField =
      sortBy === 'views' ? 'viewCount' : sortBy === 'likes' ? 'likeCount' : sortBy === 'date' ? 'createdAt' : 'viewCount';

    firestoreQuery = firestoreQuery.orderBy(orderByField, 'desc');

    // Over-fetch a candidate window (relevance re-ranking happens in-memory
    // below since Firestore can't score free text), capped to keep reads bounded.
    const snap = await firestoreQuery.limit(Math.min(Math.max(page * limit * 5, 60), 240)).get();

    const creatorIds = snap.docs.map((d: any) => String(d.get('creatorId') || ''));
    const usersMap = await loadUsersMap(creatorIds);

    const rankedDocs = snap.docs
      .map((d: any) => {
        const data = d.data();
        const creator = usersMap[String(data.creatorId || '')] || {};
        const fields = [
          String(data.title || ''),
          String(data.description || ''),
          String(data.category || ''),
          ...extractStringList(data.tags),
          String(creator.username || ''),
          String(creator.displayName || ''),
        ];
        const matches =
          !normalizedQuery ||
          fields.some((value) => normalizeSearchText(value).includes(normalizedQuery)) ||
          queryTokens.every((token) => fields.some((value) => normalizeSearchText(value).includes(token)));
        if (!matches) return null;

        return {
          doc: d,
          data,
          creator,
          score: computeVideoSearchScore(normalizedQuery, queryTokens, data, creator),
        };
      })
      .filter(
        (entry: any): entry is { doc: any; data: Record<string, any>; creator: Record<string, any>; score: number } =>
          Boolean(entry)
      );

    rankedDocs.sort((a: any, b: any) => {
      if (sortBy === 'date') {
        return new Date(toIsoString(b.data.createdAt) || 0).getTime() - new Date(toIsoString(a.data.createdAt) || 0).getTime();
      }
      if (sortBy === 'likes') {
        return Number(b.data.likeCount || 0) - Number(a.data.likeCount || 0) || b.score - a.score;
      }
      if (sortBy === 'views') {
        return Number(b.data.viewCount || 0) - Number(a.data.viewCount || 0) || b.score - a.score;
      }
      return b.score - a.score || Number(b.data.viewCount || 0) - Number(a.data.viewCount || 0);
    });

    const items = rankedDocs.slice(offset, offset + limit).map(({ doc, data, creator, score }: any) => ({
      id: doc.id,
      title: data.title || '',
      description: data.description || null,
      thumbnailURL: data.thumbnailURL || null,
      duration: typeof data.duration === 'number' ? data.duration : data.duration ? Number(data.duration) : null,
      viewCount: Number(data.viewCount || 0),
      likeCount: Number(data.likeCount || 0),
      commentCount: Number(data.commentCount || 0),
      createdAt: toIsoString(data.createdAt),
      category: data.category || null,
      creator: {
        id: String(data.creatorId || ''),
        username: creator.username || '',
        displayName: creator.displayName || creator.username || '',
        profileImageURL: creator.profileImageURL || null,
        isVerified: !!creator.isVerified,
        subscriberCount: Number(creator.subscriberCount || 0),
      },
      relevanceScore: score,
    }));

    const facets: any = { categories: {}, durations: {} };
    rankedDocs.forEach(({ data }: any) => {
      if (data.category) {
        facets.categories[data.category] = (facets.categories[data.category] || 0) + 1;
      }
      const duration = typeof data.duration === 'number' ? data.duration : null;
      if (duration) {
        if (duration < 300) facets.durations['short'] = (facets.durations['short'] || 0) + 1;
        else if (duration < 1200) facets.durations['medium'] = (facets.durations['medium'] || 0) + 1;
        else facets.durations['long'] = (facets.durations['long'] || 0) + 1;
      }
    });

    return res.json({
      items,
      total: rankedDocs.length,
      q,
      filters: { category, durationMin, durationMax, dateAfter, dateBefore, sortBy },
      facets,
      pagination: {
        page,
        limit,
        hasMore: rankedDocs.length > offset + items.length,
      },
    });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

// GET /v1/search/channels?q=term
app.get('/v1/search/channels', async (req, res) => {
  try {
    const q = String(req.query.q || '').trim();
    const normalizedQuery = normalizeSearchText(q);
    const queryTokens = tokenizeQuery(q);
    const limitCount = Math.min(parseInt(req.query.limit as string) || 20, 50);

    if (!normalizedQuery) {
      return res.json({ items: [] });
    }

    // No native prefix/full-text index on displayName; fetch a popularity-ordered
    // window and score in-memory, same approach as video search.
    const snap = await db.collection('users').orderBy('subscriberCount', 'desc').limit(300).get();

    const ranked = snap.docs
      .map((d) => {
        const data = d.data();
        const username = normalizeSearchText(data.username);
        const displayName = normalizeSearchText(data.displayName);
        const matches =
          username.includes(normalizedQuery) ||
          displayName.includes(normalizedQuery) ||
          queryTokens.every((t) => username.includes(t) || displayName.includes(t));
        if (!matches) return null;

        let score = 0;
        if (username === normalizedQuery || displayName === normalizedQuery) score += 40;
        else if (username.startsWith(normalizedQuery) || displayName.startsWith(normalizedQuery)) score += 25;
        score += computeTokenCoverageScore(username, queryTokens) * 2;
        score += computeTokenCoverageScore(displayName, queryTokens) * 2;
        score += Math.log10(Math.max(Number(data.subscriberCount || 0), 1)) * 3;

        return { id: d.id, data, score };
      })
      .filter((entry): entry is { id: string; data: Record<string, any>; score: number } => Boolean(entry))
      .sort((a, b) => b.score - a.score)
      .slice(0, limitCount)
      .map(({ id, data }) => ({
        id,
        username: data.username || '',
        displayName: data.displayName || data.username || '',
        profileImageURL: data.profileImageURL || null,
        isVerified: !!data.isVerified,
        subscriberCount: Number(data.subscriberCount || 0),
      }));

    return res.json({ items: ranked });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

// GET /v1/suggest?q=te
app.get('/v1/suggest', async (req, res) => {
  try {
    const q = String(req.query.q || '').trim();
    const limitCount = Math.min(parseInt(req.query.limit as string) || 8, 20);
    const qLower = normalizeSearchText(q);
    const queryTokens = tokenizeQuery(q);
    if (!qLower) {
      return res.json({ suggestions: [] });
    }

    const snap = await db.collection('videos').where('isPublic', '==', true).orderBy('viewCount', 'desc').limit(150).get();

    const suggestions = new Set<string>();
    for (const doc of snap.docs) {
      const data = doc.data();
      const title = String(data.title || '').trim();
      const normalizedTitle = normalizeSearchText(title);
      if (title && (normalizedTitle.includes(qLower) || queryTokens.every((token) => normalizedTitle.includes(token)))) {
        suggestions.add(title);
      }

      for (const tag of extractStringList(data.tags)) {
        const normalizedTag = normalizeSearchText(tag);
        if (normalizedTag.includes(qLower) || queryTokens.every((token) => normalizedTag.includes(token))) {
          suggestions.add(tag);
        }
      }

      const category = String(data.category || '').trim();
      const normalizedCategory = normalizeSearchText(category);
      if (category && (normalizedCategory.includes(qLower) || queryTokens.every((token) => normalizedCategory.includes(token)))) {
        suggestions.add(category);
      }

      if (suggestions.size >= limitCount) break;
    }

    return res.json({ suggestions: Array.from(suggestions).slice(0, limitCount) });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`search service listening on ${port}`));
