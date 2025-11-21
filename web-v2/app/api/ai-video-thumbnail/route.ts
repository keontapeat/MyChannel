// 🔥 AI VIDEO THUMBNAIL EXTRACTION - FIND BEST MOMENTS 💣

import { NextRequest, NextResponse } from 'next/server';
import { VertexAI } from '@google-cloud/vertexai';

const vertexAI = new VertexAI({
  project: process.env.NEXT_PUBLIC_VERTEX_AI_PROJECT_ID || 'mychannel-ca26d',
  location: 'us-central1',
});

export async function POST(request: NextRequest) {
  try {
    const { videoUrl, analysisType = 'engagement' } = await request.json();

    if (!videoUrl) {
      return NextResponse.json({ error: 'Video URL required' }, { status: 400 });
    }

    // Use Gemini Pro Vision to analyze video
    const model = vertexAI.getGenerativeModel({
      model: 'gemini-1.5-pro-002',
    });

    const prompt = buildAnalysisPrompt(analysisType);

    const result = await model.generateContent({
      contents: [
        {
          role: 'user',
          parts: [
            {
              text: prompt,
            },
            {
              fileData: {
                mimeType: 'video/mp4',
                fileUri: videoUrl,
              },
            },
          ],
        },
      ],
    });

    const response = result.response;
    const analysis = JSON.parse(response.text());

    console.log('✅ [AI] Video thumbnail analysis complete');

    return NextResponse.json({
      success: true,
      analysis,
      recommendations: generateRecommendations(analysis),
    });
  } catch (error: any) {
    console.error('🚨 [AI] Video thumbnail extraction failed:', error);
    return NextResponse.json(
      { error: error.message || 'Analysis failed' },
      { status: 500 }
    );
  }
}

// Build analysis prompt
function buildAnalysisPrompt(analysisType: string): string {
  const basePrompt = `Analyze this video and identify the best moments for creating a thumbnail. 
For each moment, provide:
1. Timestamp (in seconds)
2. Engagement score (0-100)
3. Visual appeal score (0-100)
4. Emotional impact score (0-100)
5. Description of what's happening
6. Why it would make a good thumbnail
7. Suggested text overlay

Return your analysis as JSON in this format:
{
  "moments": [
    {
      "timestamp": 0,
      "engagementScore": 0,
      "visualAppealScore": 0,
      "emotionalImpactScore": 0,
      "overallScore": 0,
      "description": "",
      "thumbnailReason": "",
      "suggestedText": ""
    }
  ],
  "bestMoment": {
    "timestamp": 0,
    "reason": ""
  },
  "videoSummary": "",
  "dominantColors": [],
  "mood": "",
  "contentType": ""
}`;

  switch (analysisType) {
    case 'engagement':
      return (
        basePrompt +
        '\n\nFocus on moments with high engagement potential (action, emotion, surprise).'
      );

    case 'aesthetic':
      return (
        basePrompt +
        '\n\nFocus on visually stunning moments (composition, lighting, colors).'
      );

    case 'emotional':
      return (
        basePrompt +
        '\n\nFocus on emotionally impactful moments (expressions, reactions, drama).'
      );

    case 'action':
      return (
        basePrompt +
        '\n\nFocus on high-action moments (movement, intensity, excitement).'
      );

    default:
      return basePrompt;
  }
}

// Generate recommendations
function generateRecommendations(analysis: any): any {
  const recommendations = {
    thumbnailStrategy: '',
    textOverlay: '',
    colorScheme: [],
    composition: '',
    callToAction: '',
  };

  // Determine strategy based on content type
  if (analysis.contentType === 'gaming') {
    recommendations.thumbnailStrategy =
      'Use high-action moment with intense expression';
    recommendations.textOverlay = 'Bold, large text with stroke';
    recommendations.callToAction = 'WATCH NOW';
  } else if (analysis.contentType === 'tutorial') {
    recommendations.thumbnailStrategy = 'Show clear before/after or result';
    recommendations.textOverlay = 'Clear, readable text explaining benefit';
    recommendations.callToAction = 'LEARN HOW';
  } else if (analysis.contentType === 'vlog') {
    recommendations.thumbnailStrategy = 'Use expressive face with interesting background';
    recommendations.textOverlay = 'Intriguing question or statement';
    recommendations.callToAction = 'WATCH';
  } else {
    recommendations.thumbnailStrategy = 'Use most visually appealing moment';
    recommendations.textOverlay = 'Descriptive text';
    recommendations.callToAction = 'WATCH NOW';
  }

  // Color scheme from dominant colors
  recommendations.colorScheme = analysis.dominantColors || [
    '#FF0000',
    '#FFFFFF',
    '#000000',
  ];

  // Composition advice
  if (analysis.mood === 'exciting') {
    recommendations.composition = 'Dynamic diagonal composition with high contrast';
  } else if (analysis.mood === 'calm') {
    recommendations.composition = 'Centered composition with soft colors';
  } else {
    recommendations.composition = 'Rule of thirds with balanced elements';
  }

  return recommendations;
}




