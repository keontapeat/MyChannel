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

function classifySeverity(score: number, flags: string[]): 'low' | 'medium' | 'high' | 'critical' {
  if (flags.includes('hate_speech')) return 'critical';
  if (score >= 0.8) return 'high';
  if (score >= 0.45) return 'medium';
  return 'low';
}

function recommendAction(score: number, flags: string[]): 'allow' | 'monitor' | 'review' | 'block' {
  if (flags.includes('hate_speech')) return 'block';
  if (score >= 0.75) return 'block';
  if (score >= 0.4) return 'review';
  if (score >= 0.2) return 'monitor';
  return 'allow';
}

function mergeFlags(...groups: string[][]): string[] {
  return Array.from(new Set(groups.flat()));
}

function buildReasons(flags: string[]): string[] {
  const reasons: Record<string, string> = {
    adult_content: 'Detected adult sexual language patterns',
    graphic_violence: 'Detected violent or graphic language patterns',
    hate_speech: 'Detected hateful or extremist language patterns',
    spam: 'Detected promotional spam signals',
    profanity: 'Detected profanity',
    scam_content: 'Detected scam or financial abuse language',
    link_spam: 'Detected suspicious outbound link patterns',
    emoji_spam: 'Detected excessive emoji spam patterns',
    repetitive_content: 'Detected repetitive or duplicated content patterns',
    aggressive_formatting: 'Detected excessive capitalization or aggressive formatting',
    invalid_thumbnail_uri: 'Thumbnail URI is not from an allowed protocol',
    adult_thumbnail_hint: 'Thumbnail URI text suggests adult content',
    violent_thumbnail_hint: 'Thumbnail URI text suggests violent content'
  };
  return flags.map(flag => reasons[flag] || flag);
}

function evaluateText(text: string) {
  const trimmed = text.trim();
  if (!trimmed) {
    return {
      safe: true,
      flags: [] as string[],
      score: 0,
      requiresReview: false,
      severity: 'low' as const,
      recommendedAction: 'allow' as const,
      signals: {}
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

  const score = Math.min(adultHits * 0.45 + violenceHits * 0.4 + hateHits * 0.8 + spamHits * 0.25 + profanityHits * 0.15 + scamHits * 0.45 + (linkSpam.suspicious ? 0.3 : 0) + (emojiSpam.suspicious ? 0.15 : 0) + (repetitive.suspicious ? 0.2 : 0) + (excessiveCaps ? 0.1 : 0), 1);
  const normalizedScore = Math.min(Number(score.toFixed(2)), 1);
  const severity = classifySeverity(normalizedScore, flags);
  const recommendedAction = recommendAction(normalizedScore, flags);
  return {
    safe: recommendedAction === 'allow' || recommendedAction === 'monitor',
    flags,
    score: normalizedScore,
    requiresReview: recommendedAction === 'review' || recommendedAction === 'block',
    severity,
    recommendedAction,
    signals: {
      adultHits,
      violenceHits,
      hateHits,
      spamHits,
      profanityHits,
      scamHits,
      linkCount: linkSpam.count,
      suspiciousLinkSpam: linkSpam.suspicious,
      emojiCount: emojiSpam.count,
      suspiciousEmojiSpam: emojiSpam.suspicious,
      repeatedChars: repetitive.repeatedChars,
      repeatedWords: repetitive.repeatedWords,
      excessiveCaps
    }
  };
}

function evaluateThumbnailUri(thumbnailUri: string) {
  const trimmed = thumbnailUri.trim();
  if (!trimmed) {
    return {
      safe: true,
      flags: [] as string[],
      score: 0,
      requiresReview: false,
      severity: 'low' as const,
      recommendedAction: 'allow' as const,
      signals: {}
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
  const normalizedScore = Math.min(Number(score.toFixed(2)), 1);
  const severity = classifySeverity(normalizedScore, flags);
  const recommendedAction = recommendAction(normalizedScore, flags);
  return {
    safe: recommendedAction === 'allow' || recommendedAction === 'monitor',
    flags,
    score: normalizedScore,
    requiresReview: recommendedAction === 'review' || recommendedAction === 'block',
    severity,
    recommendedAction,
    signals: {
      invalidProtocol: flags.includes('invalid_thumbnail_uri'),
      adultHint: flags.includes('adult_thumbnail_hint'),
      violentHint: flags.includes('violent_thumbnail_hint')
    }
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
    const flags = mergeFlags(
      titleResult.flags,
      descriptionResult.flags,
      thumbnailResult.flags,
    );
    const overallScore = Math.min(Number(Math.max(titleResult.score, descriptionResult.score, thumbnailResult.score).toFixed(2)), 1);
    const severity = classifySeverity(overallScore, flags);
    const recommendedAction = recommendAction(overallScore, flags);
    const result = {
      titleSafe: titleResult.safe,
      descriptionSafe: descriptionResult.safe,
      thumbnailSafe: thumbnailResult.safe,
      flags,
      reasons: buildReasons(flags),
      requiresReview: titleResult.requiresReview || descriptionResult.requiresReview || thumbnailResult.requiresReview,
      severity,
      recommendedAction,
      safe: recommendedAction === 'allow' || recommendedAction === 'monitor',
      scores: {
        title: titleResult.score,
        description: descriptionResult.score,
        thumbnail: thumbnailResult.score,
        overall: overallScore
      },
      verdicts: {
        title: {
          severity: titleResult.severity,
          recommendedAction: titleResult.recommendedAction,
          signals: titleResult.signals
        },
        description: {
          severity: descriptionResult.severity,
          recommendedAction: descriptionResult.recommendedAction,
          signals: descriptionResult.signals
        },
        thumbnail: {
          severity: thumbnailResult.severity,
          recommendedAction: thumbnailResult.recommendedAction,
          signals: thumbnailResult.signals
        }
      }
    };
    return res.json(result);
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`moderation service listening on ${port}`));




