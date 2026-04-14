import express from 'express';
import cors from 'cors';

const adultTerms = ['nude', 'porn', 'xxx', 'onlyfans', 'sex'];
const violenceTerms = ['kill', 'murder', 'beheading', 'shooting', 'bomb'];
const hateTerms = ['racial slur', 'neo nazi', 'terrorist manifesto'];
const spamTerms = ['free money', 'click here', 'guaranteed profit', 'double your money', 'crypto giveaway'];
const profanityTerms = ['fuck', 'shit', 'damn', 'ass', 'bitch', 'crap', 'hell', 'dick'];
const scamTerms = ['bitconnect', 'ponzi', 'pyramid scheme', 'mlm scam', 'investment scam'];

function countMatches(text: string, terms: string[]): number {
  const lower = text.toLowerCase();
  return terms.reduce((sum, term) => sum + (lower.includes(term) ? 1 : 0), 0);
}

function detectLinkSpam(text: string): { count: number; suspicious: boolean } {
  const urlMatches = text.match(/https?:\/\/[^\s]+/gi) || [];
  const shortLinkMatches = text.match(/(bit\.ly|tinyurl|goo\.gl|t\.co|ow\.ly)/gi) || [];
  const count = urlMatches.length;
  const suspicious = count >= 3 || shortLinkMatches.length >= 2;
  return { count, suspicious };
}

function detectEmojiSpam(text: string): { count: number; suspicious: boolean } {
  const emojiMatches = text.match(/[\u{1F300}-\u{1F6FF}|\u{1F900}-\u{1F9FF}]/gu) || [];
  const count = emojiMatches.length;
  const suspicious = count >= 10;
  return { count, suspicious };
}

function detectRepetitiveContent(text: string): { suspicious: boolean; repeatedChars: boolean; repeatedWords: boolean } {
  const repeatedChars = /(.)\1{4,}/.test(text);
  const words = text.toLowerCase().split(/\s+/);
  const wordCount = new Map<string, number>();
  words.forEach(word => {
    if (word.length > 2) {
      wordCount.set(word, (wordCount.get(word) || 0) + 1);
    }
  });
  const repeatedWords = Array.from(wordCount.values()).some(count => count >= 3);
  const suspicious = repeatedChars || repeatedWords;
  return { suspicious, repeatedChars, repeatedWords };
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
  const profanityHits = countMatches(trimmed, profanityTerms);
  const scamHits = countMatches(trimmed, scamTerms);
  const linkSpam = detectLinkSpam(trimmed);
  const emojiSpam = detectEmojiSpam(trimmed);
  const repetitive = detectRepetitiveContent(trimmed);
  const excessiveCaps = trimmed.length >= 12 && trimmed === trimmed.toUpperCase();

  if (adultHits > 0) flags.push('adult_content');
  if (violenceHits > 0) flags.push('graphic_violence');
  if (hateHits > 0) flags.push('hate_speech');
  if (spamHits > 0 || linkSpam.suspicious) flags.push('spam');
  if (profanityHits > 0) flags.push('profanity');
  if (scamHits > 0) flags.push('scam_content');
  if (linkSpam.suspicious) flags.push('link_spam');
  if (emojiSpam.suspicious) flags.push('emoji_spam');
  if (repetitive.suspicious) flags.push('repetitive_content');
  if (excessiveCaps) flags.push('aggressive_formatting');

  const score = adultHits * 0.45 + violenceHits * 0.4 + hateHits * 0.5 + spamHits * 0.25 + profanityHits * 0.15 + scamHits * 0.35 + (linkSpam.suspicious ? 0.3 : 0) + (emojiSpam.suspicious ? 0.15 : 0) + (repetitive.suspicious ? 0.2 : 0) + (excessiveCaps ? 0.1 : 0);
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




