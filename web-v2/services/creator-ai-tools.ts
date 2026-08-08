/**
 * Creator Studio AI Tools — Real Vertex AI integrations for creator productivity.
 *
 * These functions call the Vertex AI Gemini API to provide:
 * - Video summarization from transcripts
 * - Auto-chapter generation with timestamps
 * - SEO title/description suggestions
 * - Thumbnail copy and hook suggestions
 * - Creator coaching insights
 */

import { db, auth } from '@/lib/firebase/config';
import { doc, getDoc, setDoc, serverTimestamp } from 'firebase/firestore';

const VERTEX_AI_ENDPOINT = 'https://us-central1-aiplatform.googleapis.com/v1/projects/mychannel-ca26d/locations/us-central1/publishers/google/models/gemini-1.5-flash:generateContent';

interface AIToolResult {
  success: boolean;
  data: any;
  error?: string;
}

/**
 * Gets an auth token for Vertex AI calls. In production this would use a
 * service account; for client-side we route through a Cloud Function proxy.
 */
async function getVertexToken(): Promise<string | null> {
  const user = auth.currentUser;
  if (!user) return null;
  return user.getIdToken();
}

// ─── VIDEO SUMMARIZATION ─────────────────────────────────────────────────────

/**
 * Generates a concise video summary from a transcript.
 * Useful for: video descriptions, social media posts, search indexing.
 */
export async function summarizeVideo(
  videoId: string,
  transcript: string,
  options: { length?: 'short' | 'medium' | 'long'; style?: 'professional' | 'casual' } = {}
): Promise<AIToolResult> {
  const { length = 'medium', style = 'professional' } = options;
  const wordTarget = length === 'short' ? 50 : length === 'medium' ? 150 : 300;

  const prompt = `You are a YouTube-grade video summarizer. Given this transcript, write a ${style} summary of approximately ${wordTarget} words that captures the key points, is engaging, and would work as a video description.

TRANSCRIPT:
${transcript.substring(0, 8000)}

Respond with ONLY the summary text, no headers or labels.`;

  try {
    const response = await callVertexAI(prompt);
    // Cache the result
    await setDoc(doc(db, 'videos', videoId, 'ai_tools', 'summary'), {
      summary: response,
      length,
      style,
      generatedAt: serverTimestamp(),
    });
    return { success: true, data: { summary: response } };
  } catch (e: any) {
    return { success: false, data: null, error: e.message };
  }
}

// ─── AUTO-CHAPTERS ───────────────────────────────────────────────────────────

export interface Chapter {
  timestamp: number; // seconds
  title: string;
}

/**
 * Generates chapter markers with timestamps from a transcript with timing info.
 * YouTube-style chapters that appear in the progress bar.
 */
export async function generateChapters(
  videoId: string,
  transcript: string,
  videoDurationSeconds: number
): Promise<AIToolResult> {
  const prompt = `You are a video chapter generator. Given this transcript from a ${Math.round(videoDurationSeconds / 60)}-minute video, identify natural topic breaks and generate chapter titles.

Rules:
- First chapter MUST start at 0:00
- Minimum 3 chapters, maximum 12
- Each chapter title should be 2-6 words
- Chapters should be at least 30 seconds apart
- Titles should be descriptive and engaging

TRANSCRIPT:
${transcript.substring(0, 10000)}

Respond in JSON format ONLY:
[{"timestamp": 0, "title": "Introduction"}, {"timestamp": 45, "title": "..."}, ...]`;

  try {
    const response = await callVertexAI(prompt);
    const chapters: Chapter[] = JSON.parse(response.match(/\[[\s\S]*\]/)?.[0] || '[]');

    // Validate and clean
    const valid = chapters
      .filter((c) => c.timestamp >= 0 && c.timestamp < videoDurationSeconds && c.title)
      .sort((a, b) => a.timestamp - b.timestamp);

    if (valid.length > 0 && valid[0].timestamp !== 0) {
      valid.unshift({ timestamp: 0, title: 'Introduction' });
    }

    await setDoc(doc(db, 'videos', videoId, 'ai_tools', 'chapters'), {
      chapters: valid,
      generatedAt: serverTimestamp(),
    });

    return { success: true, data: { chapters: valid } };
  } catch (e: any) {
    return { success: false, data: null, error: e.message };
  }
}

// ─── SEO TITLE & DESCRIPTION ────────────────────────────────────────────────

export interface SEOSuggestions {
  titles: string[];
  descriptions: string[];
  tags: string[];
  hashtags: string[];
}

/**
 * Generates SEO-optimized title and description alternatives.
 * Maximizes click-through rate while being accurate to content.
 */
export async function generateSEOSuggestions(
  videoId: string,
  currentTitle: string,
  transcript: string,
  category: string
): Promise<AIToolResult> {
  const prompt = `You are a YouTube SEO expert. Given this video's current title and transcript, generate optimized alternatives.

Current Title: "${currentTitle}"
Category: ${category}
Transcript excerpt: ${transcript.substring(0, 3000)}

Generate:
1. 5 alternative titles (60 chars max, hook-driven, curiosity-inducing)
2. 3 description options (first 2 lines are crucial for CTR, include keywords)
3. 15 relevant tags (mix of broad and specific)
4. 5 hashtags

JSON response:
{
  "titles": ["...", "...", "...", "...", "..."],
  "descriptions": ["...", "...", "..."],
  "tags": ["...", "...", ...],
  "hashtags": ["#...", "#...", "#...", "#...", "#..."]
}`;

  try {
    const response = await callVertexAI(prompt);
    const suggestions: SEOSuggestions = JSON.parse(response.match(/\{[\s\S]*\}/)?.[0] || '{}');

    await setDoc(doc(db, 'videos', videoId, 'ai_tools', 'seo'), {
      suggestions,
      generatedAt: serverTimestamp(),
    });

    return { success: true, data: suggestions };
  } catch (e: any) {
    return { success: false, data: null, error: e.message };
  }
}

// ─── THUMBNAIL HOOKS ─────────────────────────────────────────────────────────

/**
 * Generates thumbnail text overlay suggestions and hook concepts.
 */
export async function generateThumbnailHooks(
  videoTitle: string,
  category: string,
  targetAudience: string
): Promise<AIToolResult> {
  const prompt = `You are a thumbnail design expert for YouTube. Generate compelling text overlays and visual concepts for a video thumbnail.

Video Title: "${videoTitle}"
Category: ${category}
Target Audience: ${targetAudience}

Generate 5 thumbnail concepts, each with:
- Text overlay (3-5 words max, bold and attention-grabbing)
- Emotion to convey (shock, curiosity, excitement, etc.)
- Color scheme suggestion
- Visual hook (what the main image should show)

JSON: [{"text": "...", "emotion": "...", "colors": "...", "visualHook": "..."}]`;

  try {
    const response = await callVertexAI(prompt);
    const hooks = JSON.parse(response.match(/\[[\s\S]*\]/)?.[0] || '[]');
    return { success: true, data: { hooks } };
  } catch (e: any) {
    return { success: false, data: null, error: e.message };
  }
}

// ─── CREATOR COACHING ────────────────────────────────────────────────────────

/**
 * Generates personalized creator coaching insights based on channel analytics.
 */
export async function generateCreatorInsights(
  channelStats: {
    avgViews: number;
    avgRetention: number;
    subscriberGrowthRate: number;
    topVideos: string[];
    worstVideos: string[];
    uploadFrequency: string;
    avgCTR: number;
  }
): Promise<AIToolResult> {
  const prompt = `You are a YouTube growth coach. Analyze this creator's channel performance and provide actionable coaching.

Channel Metrics:
- Average views per video: ${channelStats.avgViews}
- Average retention: ${channelStats.avgRetention}%
- Subscriber growth rate: ${channelStats.subscriberGrowthRate}%/month
- Upload frequency: ${channelStats.uploadFrequency}
- Average CTR: ${channelStats.avgCTR}%
- Top performing videos: ${channelStats.topVideos.join(', ')}
- Lowest performing: ${channelStats.worstVideos.join(', ')}

Provide 5 specific, actionable recommendations:
1. What to improve immediately (biggest lever)
2. Content strategy adjustment
3. Thumbnail/title optimization
4. Upload schedule optimization
5. Engagement/community building tactic

For each: why it matters, specific action to take, expected impact.

JSON: [{"area": "...", "recommendation": "...", "action": "...", "expectedImpact": "...", "priority": "high|medium|low"}]`;

  try {
    const response = await callVertexAI(prompt);
    const insights = JSON.parse(response.match(/\[[\s\S]*\]/)?.[0] || '[]');
    return { success: true, data: { insights } };
  } catch (e: any) {
    return { success: false, data: null, error: e.message };
  }
}

// ─── VERTEX AI CALLER ────────────────────────────────────────────────────────

/**
 * Calls Vertex AI Gemini. In production this routes through a Cloud Function
 * (since client-side can't auth to Vertex directly with service accounts).
 * Falls back to Firebase Functions callable.
 */
async function callVertexAI(prompt: string): Promise<string> {
  const token = await getVertexToken();
  if (!token) throw new Error('Authentication required');

  // Route through our Cloud Function proxy
  const { getFunctions, httpsCallable } = await import('firebase/functions');
  const functions = getFunctions();
  const generateAI = httpsCallable(functions, 'generateAIContent');

  const result = await generateAI({ prompt, model: 'gemini-1.5-flash' });
  const data = result.data as { text?: string; error?: string };
  if (data.error) throw new Error(data.error);
  return data.text || '';
}
