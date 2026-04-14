import express from 'express';
import cors from 'cors';

const adultTerms = ['nude', 'porn', 'xxx', 'onlyfans', 'sex'];
const violenceTerms = ['kill', 'murder', 'beheading', 'shooting', 'bomb'];
const hateTerms = ['racial slur', 'neo nazi', 'terrorist manifesto'];
const spamTerms = ['free money', 'click here', 'guaranteed profit', 'double your money', 'crypto giveaway'];

function countMatches(text: string, terms: string[]): number {
  const lower = text.toLowerCase();
  return terms.reduce((sum, term) => sum + (lower.includes(term) ? 1 : 0), 0);
}

function evaluateText(text: string) {
  const trimmed = text.trim();
  if (!trimmed) {
    return {
      safe: true,
      flags: [] as string[],
      score: 0,
      requiresReview: false
    };
  }

  const flags: string[] = [];
  const adultHits = countMatches(trimmed, adultTerms);
  const violenceHits = countMatches(trimmed, violenceTerms);
  const hateHits = countMatches(trimmed, hateTerms);
  const spamHits = countMatches(trimmed, spamTerms);
  const urlHits = (trimmed.match(/https?:\/\//gi) || []).length;
  const excessiveCaps = trimmed.length >= 12 && trimmed === trimmed.toUpperCase();

  if (adultHits > 0) flags.push('adult_content');
  if (violenceHits > 0) flags.push('graphic_violence');
  if (hateHits > 0) flags.push('hate_speech');
  if (spamHits > 0 || urlHits >= 3) flags.push('spam');
  if (excessiveCaps) flags.push('aggressive_formatting');

  const score = adultHits * 0.45 + violenceHits * 0.4 + hateHits * 0.5 + spamHits * 0.25 + Math.min(urlHits, 4) * 0.08 + (excessiveCaps ? 0.1 : 0);
  return {
    safe: score < 0.5 && !flags.includes('hate_speech'),
    flags,
    score: Math.min(Number(score.toFixed(2)), 1),
    requiresReview: score >= 0.35 || flags.includes('hate_speech')
  };
}

function evaluateThumbnailUri(thumbnailUri: string) {
  const trimmed = thumbnailUri.trim();
  if (!trimmed) {
    return {
      safe: true,
      flags: [] as string[],
      score: 0,
      requiresReview: false
    };
  }

  const flags: string[] = [];
  const lower = trimmed.toLowerCase();
  if (!/^https?:\/\//i.test(trimmed) && !/^gs:\/\//i.test(trimmed)) {
    flags.push('invalid_thumbnail_uri');
  }
  if (adultTerms.some(term => lower.includes(term))) {
    flags.push('adult_thumbnail_hint');
  }
  if (violenceTerms.some(term => lower.includes(term))) {
    flags.push('violent_thumbnail_hint');
  }

  const score = flags.includes('invalid_thumbnail_uri') ? 0.25 : flags.length * 0.3;
  return {
    safe: flags.length === 0,
    flags,
    score: Math.min(Number(score.toFixed(2)), 1),
    requiresReview: flags.length > 0
  };
}

const app = express();
app.use(cors());
app.use(express.json());

// POST /v1/moderate/video { title, description, thumbnailUri }
app.post('/v1/moderate/video', async (req, res) => {
  try {
    const { title, description, thumbnailUri } = req.body || {};
    const titleResult = evaluateText(String(title || ''));
    const descriptionResult = evaluateText(String(description || ''));
    const thumbnailResult = evaluateThumbnailUri(String(thumbnailUri || ''));
    const flags = Array.from(new Set([
      ...titleResult.flags,
      ...descriptionResult.flags,
      ...thumbnailResult.flags,
    ]));
    const result = {
      titleSafe: titleResult.safe,
      descriptionSafe: descriptionResult.safe,
      thumbnailSafe: thumbnailResult.safe,
      flags,
      requiresReview: titleResult.requiresReview || descriptionResult.requiresReview || thumbnailResult.requiresReview,
      scores: {
        title: titleResult.score,
        description: descriptionResult.score,
        thumbnail: thumbnailResult.score
      }
    };
    return res.json(result);
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`moderation service listening on ${port}`));




