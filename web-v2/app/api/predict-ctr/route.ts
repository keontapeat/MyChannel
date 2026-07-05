// predict-ctr — Thumbnail CTR prediction via Vertex AI Vision
// Analyses a thumbnail image and returns an estimated click-through rate.
//
// NOTE: Route handlers do not ship with the static export (output: 'export').
// This must be hosted on a Node runtime (Cloud Functions / Cloud Run) to work.

import { NextRequest, NextResponse } from 'next/server';
import { verifyRequestAuth } from '@/lib/server/api-auth';

export async function POST(request: NextRequest) {
  const authResult = await verifyRequestAuth(request);
  if (authResult.error) return authResult.error;

  try {
    const { imageData } = await request.json();

    if (!imageData || typeof imageData !== 'string') {
      return NextResponse.json({ error: 'imageData is required' }, { status: 400 });
    }

    const projectId = process.env.NEXT_PUBLIC_VERTEX_AI_PROJECT_ID ?? process.env.GOOGLE_CLOUD_PROJECT;
    const location = 'us-central1';

    // Try real Vertex AI Vision Safe Search + label detection for CTR signals
    if (projectId) {
      try {
        const { GoogleAuth } = await import('google-auth-library');
        const googleAuth = new GoogleAuth({
          scopes: 'https://www.googleapis.com/auth/cloud-platform',
        });
        const client = await googleAuth.getClient();
        const tokenResponse = await client.getAccessToken();
        const accessToken = tokenResponse.token;

        // Use Gemini Vision via Vertex AI to analyse the thumbnail
        const endpoint = `https://${location}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${location}/publishers/google/models/gemini-1.5-flash:generateContent`;

        // Strip data URI prefix if present
        const base64 = imageData.replace(/^data:image\/[a-z]+;base64,/, '');

        const visionResp = await fetch(endpoint, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            contents: [{
              parts: [
                {
                  inlineData: {
                    mimeType: 'image/png',
                    data: base64,
                  },
                },
                {
                  text: 'Analyse this YouTube thumbnail. Rate its expected click-through rate (CTR) on a scale of 1-20%. Consider: faces visible, high contrast colors, readable text, emotional appeal, curiosity gap. Return ONLY a JSON object like: {"ctr": 12.5, "signals": ["faces", "high contrast"], "suggestions": ["Add face closeup"]}',
                },
              ],
            }],
            generationConfig: { temperature: 0.2, maxOutputTokens: 256 },
          }),
        });

        if (visionResp.ok) {
          const visionData = await visionResp.json();
          const text = visionData.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
          const jsonMatch = text.match(/\{[\s\S]*\}/);
          if (jsonMatch) {
            const parsed = JSON.parse(jsonMatch[0]);
            return NextResponse.json({
              ctr: parsed.ctr ?? 8,
              signals: parsed.signals ?? [],
              suggestions: parsed.suggestions ?? [],
              model: 'gemini-1.5-flash',
            });
          }
        }
      } catch (err) {
        console.warn('[predict-ctr] Vertex AI unavailable, using heuristic:', err);
      }
    }

    // Heuristic fallback — analyse base64 data length as proxy for image complexity
    // (more data generally = more detail = slightly higher CTR)
    const base64Len = imageData.length;
    const complexityScore = Math.min(5, (base64Len / 100_000) * 2);
    const baseCTR = 6 + complexityScore + Math.random() * 2;

    return NextResponse.json({
      ctr: parseFloat(baseCTR.toFixed(1)),
      signals: ['heuristic estimate'],
      suggestions: [
        'Add a face with strong emotion for +2-4% CTR',
        'Use high-contrast colors (red/yellow/white) for +1-3% CTR',
        'Include 3–5 words of bold text for +1-2% CTR',
      ],
      model: 'heuristic',
    });
  } catch (error) {
    console.error('[predict-ctr] error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
