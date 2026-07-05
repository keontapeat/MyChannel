/**
 * Thumbnail AI — analysis functions relocated from web-v2/app/api.
 *
 * These are the in-scope (analytics / ranking) thumbnail AI endpoints:
 *   - predictThumbnailCtr   (was app/api/predict-ctr)
 *   - aiVideoThumbnail      (was app/api/ai-video-thumbnail)
 *
 * They run here (Node runtime) because the web app is a static export and
 * cannot host route handlers. Auth is enforced by onCall (request.auth); the
 * client calls them with httpsCallable using its Firebase session.
 *
 * Vertex AI is reached over REST using Application Default Credentials — no
 * secrets in code. Uses the same google-auth-library already in this codebase.
 */

import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {GoogleAuth} from 'google-auth-library';

const vertexAuth = new GoogleAuth({
  scopes: 'https://www.googleapis.com/auth/cloud-platform',
});

const VERTEX_LOCATION = 'us-central1';
const PROJECT_ID = process.env.GCLOUD_PROJECT || 'mychannel-ca26d';

async function getVertexToken(): Promise<string> {
  const client = await vertexAuth.getClient();
  const token = await client.getAccessToken();
  return token.token ?? '';
}

function vertexEndpoint(model: string, method: string): string {
  return (
    `https://${VERTEX_LOCATION}-aiplatform.googleapis.com/v1/projects/` +
    `${PROJECT_ID}/locations/${VERTEX_LOCATION}/publishers/google/models/${model}:${method}`
  );
}

// ─── predictThumbnailCtr ────────────────────────────────────────────────────

interface CtrResult {
  ctr: number;
  signals: string[];
  suggestions: string[];
  model: string;
}

function heuristicCtr(imageData: string): CtrResult {
  // Base64 length is a rough proxy for image complexity/detail.
  const complexityScore = Math.min(5, (imageData.length / 100_000) * 2);
  const baseCTR = 6 + complexityScore + Math.random() * 2;
  return {
    ctr: parseFloat(baseCTR.toFixed(1)),
    signals: ['heuristic estimate'],
    suggestions: [
      'Add a face with strong emotion for +2-4% CTR',
      'Use high-contrast colors (red/yellow/white) for +1-3% CTR',
      'Include 3–5 words of bold text for +1-2% CTR',
    ],
    model: 'heuristic',
  };
}

export const predictThumbnailCtr = onCall(
  {region: 'us-east1', timeoutSeconds: 30, memory: '256MiB'},
  async (request): Promise<CtrResult> => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be signed in.');

    const data = request.data as {imageData?: string};
    const imageData = data.imageData;
    if (!imageData || typeof imageData !== 'string') {
      throw new HttpsError('invalid-argument', 'imageData is required');
    }

    try {
      const token = await getVertexToken();
      const base64 = imageData.replace(/^data:image\/[a-z]+;base64,/, '');
      const resp = await fetch(vertexEndpoint('gemini-1.5-flash', 'generateContent'), {
        method: 'POST',
        headers: {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json'},
        body: JSON.stringify({
          contents: [{
            parts: [
              {inlineData: {mimeType: 'image/png', data: base64}},
              {
                text:
                  'Analyse this YouTube thumbnail. Rate its expected click-through ' +
                  'rate (CTR) on a scale of 1-20%. Consider: faces visible, high ' +
                  'contrast colors, readable text, emotional appeal, curiosity gap. ' +
                  'Return ONLY a JSON object like: {"ctr": 12.5, "signals": ' +
                  '["faces"], "suggestions": ["Add face closeup"]}',
              },
            ],
          }],
          generationConfig: {temperature: 0.2, maxOutputTokens: 256},
        }),
      });

      if (resp.ok) {
        const body = await resp.json() as {
          candidates?: Array<{content?: {parts?: Array<{text?: string}>}}>;
        };
        const text = body.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
        const jsonMatch = text.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          const parsed = JSON.parse(jsonMatch[0]) as Partial<CtrResult>;
          return {
            ctr: parsed.ctr ?? 8,
            signals: parsed.signals ?? [],
            suggestions: parsed.suggestions ?? [],
            model: 'gemini-1.5-flash',
          };
        }
      }
    } catch (err) {
      console.warn('[predictThumbnailCtr] Vertex AI unavailable, using heuristic:', err);
    }

    return heuristicCtr(imageData);
  }
);

// ─── aiVideoThumbnail ───────────────────────────────────────────────────────

function buildAnalysisPrompt(analysisType: string): string {
  const basePrompt =
    'Analyze this video and identify the best moments for creating a thumbnail. ' +
    'For each moment provide timestamp (seconds), engagement/visual/emotional ' +
    'scores (0-100), overall score, description, thumbnail reason, and suggested ' +
    'text overlay. Return JSON: {"moments": [{"timestamp": 0, "engagementScore": ' +
    '0, "visualAppealScore": 0, "emotionalImpactScore": 0, "overallScore": 0, ' +
    '"description": "", "thumbnailReason": "", "suggestedText": ""}], ' +
    '"bestMoment": {"timestamp": 0, "reason": ""}, "videoSummary": "", ' +
    '"dominantColors": [], "mood": "", "contentType": ""}';

  switch (analysisType) {
    case 'aesthetic':
      return basePrompt + '\n\nFocus on visually stunning moments (composition, lighting, colors).';
    case 'emotional':
      return basePrompt + '\n\nFocus on emotionally impactful moments (expressions, reactions, drama).';
    case 'action':
      return basePrompt + '\n\nFocus on high-action moments (movement, intensity, excitement).';
    case 'engagement':
    default:
      return basePrompt + '\n\nFocus on moments with high engagement potential (action, emotion, surprise).';
  }
}

interface VideoAnalysis {
  contentType?: string;
  mood?: string;
  dominantColors?: string[];
  [key: string]: unknown;
}

function generateRecommendations(analysis: VideoAnalysis): Record<string, unknown> {
  let thumbnailStrategy: string;
  let textOverlay: string;
  let callToAction: string;

  switch (analysis.contentType) {
    case 'gaming':
      thumbnailStrategy = 'Use high-action moment with intense expression';
      textOverlay = 'Bold, large text with stroke';
      callToAction = 'WATCH NOW';
      break;
    case 'tutorial':
      thumbnailStrategy = 'Show clear before/after or result';
      textOverlay = 'Clear, readable text explaining benefit';
      callToAction = 'LEARN HOW';
      break;
    case 'vlog':
      thumbnailStrategy = 'Use expressive face with interesting background';
      textOverlay = 'Intriguing question or statement';
      callToAction = 'WATCH';
      break;
    default:
      thumbnailStrategy = 'Use most visually appealing moment';
      textOverlay = 'Descriptive text';
      callToAction = 'WATCH NOW';
  }

  let composition: string;
  if (analysis.mood === 'exciting') {
    composition = 'Dynamic diagonal composition with high contrast';
  } else if (analysis.mood === 'calm') {
    composition = 'Centered composition with soft colors';
  } else {
    composition = 'Rule of thirds with balanced elements';
  }

  return {
    thumbnailStrategy,
    textOverlay,
    callToAction,
    composition,
    colorScheme: analysis.dominantColors ?? ['#FF0000', '#FFFFFF', '#000000'],
  };
}

export const aiVideoThumbnail = onCall(
  {region: 'us-east1', timeoutSeconds: 120, memory: '512MiB'},
  async (request): Promise<{analysis: VideoAnalysis; recommendations: Record<string, unknown>}> => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be signed in.');

    const data = request.data as {videoUrl?: string; analysisType?: string};
    const videoUrl = data.videoUrl;
    const analysisType = data.analysisType ?? 'engagement';
    if (!videoUrl || typeof videoUrl !== 'string') {
      throw new HttpsError('invalid-argument', 'videoUrl is required');
    }

    try {
      const token = await getVertexToken();
      const resp = await fetch(vertexEndpoint('gemini-1.5-pro-002', 'generateContent'), {
        method: 'POST',
        headers: {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json'},
        body: JSON.stringify({
          contents: [{
            role: 'user',
            parts: [
              {text: buildAnalysisPrompt(analysisType)},
              {fileData: {mimeType: 'video/mp4', fileUri: videoUrl}},
            ],
          }],
        }),
      });

      if (!resp.ok) {
        throw new HttpsError('unavailable', `Vertex AI returned ${resp.status}`);
      }

      const body = await resp.json() as {
        candidates?: Array<{content?: {parts?: Array<{text?: string}>}}>;
      };
      const text = body.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        throw new HttpsError('internal', 'Model did not return parseable analysis');
      }
      const analysis = JSON.parse(jsonMatch[0]) as VideoAnalysis;
      return {analysis, recommendations: generateRecommendations(analysis)};
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('[aiVideoThumbnail] failed:', err);
      throw new HttpsError('internal', 'Analysis failed');
    }
  }
);
