// 🔥 VERTEX AI VISION - BACKGROUND REMOVAL API 💣

import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const { imageUrl } = await request.json();

    if (!imageUrl || typeof imageUrl !== 'string') {
      return NextResponse.json(
        { error: 'Image URL is required' },
        { status: 400 }
      );
    }

    // Convert data URL to base64
    const base64Data = imageUrl.replace(/^data:image\/\w+;base64,/, '');

    // Vertex AI Vision API configuration
    const projectId = process.env.NEXT_PUBLIC_VERTEX_AI_PROJECT_ID;
    const location = 'us-central1';

    // Use Imagen 3 for background removal (editing mode)
    const model = 'imagegeneration@006';
    const endpoint = `https://${location}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${location}/publishers/google/models/${model}:predict`;

    // Request body for background removal
    const requestBody = {
      instances: [
        {
          prompt: 'Remove background, transparent background, subject only, clean cutout',
          image: {
            bytesBase64Encoded: base64Data,
          },
        },
      ],
      parameters: {
        sampleCount: 1,
        mode: 'background-removal', // Special mode for background removal
        outputFormat: 'png', // PNG for transparency
        safetySetting: 'block_none',
      },
    };

    // Get access token
    const accessToken = await getAccessToken();

    // Call Vertex AI Vision API
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
      console.error('Background removal error:', error);
      
      // Fallback: Use alternative method (remove.bg API or similar)
      return await fallbackBackgroundRemoval(imageUrl);
    }

    const data = await response.json();

    // Extract processed image
    const predictions = data.predictions;
    if (!predictions || predictions.length === 0) {
      return await fallbackBackgroundRemoval(imageUrl);
    }

    // Get base64 image data with transparency
    const processedImageData = predictions[0].bytesBase64Encoded;
    const processedImageUrl = `data:image/png;base64,${processedImageData}`;

    return NextResponse.json({
      success: true,
      imageUrl: processedImageUrl,
      method: 'Vertex AI Vision',
    });
  } catch (error) {
    console.error('Background removal error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

// Fallback background removal using alternative service
async function fallbackBackgroundRemoval(imageUrl: string): Promise<NextResponse> {
  try {
    // Option 1: Use remove.bg API
    const removeBgApiKey = process.env.REMOVE_BG_API_KEY;
    
    if (removeBgApiKey) {
      const formData = new FormData();
      formData.append('image_url', imageUrl);
      formData.append('size', 'auto');

      const response = await fetch('https://api.remove.bg/v1.0/removebg', {
        method: 'POST',
        headers: {
          'X-Api-Key': removeBgApiKey,
        },
        body: formData,
      });

      if (response.ok) {
        const blob = await response.blob();
        const base64 = await blobToBase64(blob);
        return NextResponse.json({
          success: true,
          imageUrl: base64,
          method: 'remove.bg',
        });
      }
    }

    // Option 2: Client-side processing fallback
    return NextResponse.json({
      success: false,
      error: 'Background removal not available',
      fallback: true,
    });
  } catch (error) {
    console.error('Fallback background removal error:', error);
    return NextResponse.json(
      { error: 'Background removal failed' },
      { status: 500 }
    );
  }
}

// Convert blob to base64
function blobToBase64(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result as string);
    reader.onerror = reject;
    reader.readAsDataURL(blob);
  });
}

// Get access token for Vertex AI
async function getAccessToken(): Promise<string> {
  return process.env.VERTEX_AI_ACCESS_TOKEN || 'mock-token';
}






