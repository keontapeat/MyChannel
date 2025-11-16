// 🔥 VERTEX AI IMAGEN 3 - THUMBNAIL GENERATION API 💣

import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const { prompt } = await request.json();

    if (!prompt || typeof prompt !== 'string') {
      return NextResponse.json(
        { error: 'Prompt is required' },
        { status: 400 }
      );
    }

    // Vertex AI Imagen 3 configuration
    const projectId = process.env.NEXT_PUBLIC_VERTEX_AI_PROJECT_ID;
    const location = 'us-central1';
    const model = 'imagegeneration@006'; // Imagen 3

    // Construct the API endpoint
    const endpoint = `https://${location}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${location}/publishers/google/models/${model}:predict`;

    // Enhanced prompt for thumbnail generation
    const enhancedPrompt = `Professional YouTube thumbnail, 16:9 aspect ratio, high quality, vibrant colors, eye-catching composition: ${prompt}. Cinematic lighting, sharp focus, trending on artstation, 8k resolution.`;

    // Request body for Imagen 3
    const requestBody = {
      instances: [
        {
          prompt: enhancedPrompt,
        },
      ],
      parameters: {
        sampleCount: 1,
        aspectRatio: '16:9', // Perfect for YouTube thumbnails
        negativePrompt: 'blurry, low quality, distorted, ugly, bad composition, watermark, text, signature',
        safetySetting: 'block_some',
        personGeneration: 'allow_adult', // Allow face generation
        addWatermark: false,
      },
    };

    // Get access token (in production, use service account)
    const accessToken = await getAccessToken();

    // Call Vertex AI Imagen 3
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('Vertex AI error:', error);
      return NextResponse.json(
        { error: 'Failed to generate thumbnail' },
        { status: 500 }
      );
    }

    const data = await response.json();

    // Extract generated image
    const predictions = data.predictions;
    if (!predictions || predictions.length === 0) {
      return NextResponse.json(
        { error: 'No image generated' },
        { status: 500 }
      );
    }

    // Get base64 image data
    const imageData = predictions[0].bytesBase64Encoded;
    const imageUrl = `data:image/png;base64,${imageData}`;

    return NextResponse.json({
      success: true,
      imageUrl,
      prompt: enhancedPrompt,
      model: 'Imagen 3',
    });
  } catch (error) {
    console.error('Thumbnail generation error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

// Get access token for Vertex AI
async function getAccessToken(): Promise<string> {
  // In production, use Google Cloud service account
  // For now, return mock token (replace with actual implementation)
  
  // TODO: Implement proper OAuth2 flow
  // const { GoogleAuth } = require('google-auth-library');
  // const auth = new GoogleAuth({
  //   scopes: 'https://www.googleapis.com/auth/cloud-platform',
  // });
  // const client = await auth.getClient();
  // const token = await client.getAccessToken();
  // return token.token;

  return process.env.VERTEX_AI_ACCESS_TOKEN || 'mock-token';
}


