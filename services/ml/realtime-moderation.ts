/**
 * Real-time ML Content Moderation
 * Instant content screening during upload
 */

import { call_ml_service } from '../../cloud-deployment/vertex-ai/connection-pool';

interface ModerationResult {
  safe: boolean;
  confidence: number;
  flags: string[];
  categories: {
    adult: number;
    violence: number;
    hate: number;
    spam: number;
  };
}

export class RealtimeModerationService {
  /**
   * Moderate video during upload (streaming analysis)
   */
  async moderateVideoStream(videoId: string, chunks: Buffer[]): Promise<ModerationResult> {
    console.log(`🛡️ [Moderation] Analyzing video: ${videoId}`);
    
    // Analyze first 30 seconds for quick screening
    const sampleChunks = chunks.slice(0, 30);
    
    const result = await call_ml_service('content-moderation-service', '/analyze', {
      videoId,
      chunks: sampleChunks.map(c => c.toString('base64')),
      mode: 'realtime'
    });

    const moderation: ModerationResult = {
      safe: result.safe,
      confidence: result.confidence,
      flags: result.flags || [],
      categories: result.categories
    };

    if (!moderation.safe) {
      console.warn(`⚠️ [Moderation] Content flagged: ${videoId} - ${moderation.flags.join(', ')}`);
    } else {
      console.log(`✅ [Moderation] Content approved: ${videoId}`);
    }

    return moderation;
  }

  /**
   * Moderate text content (comments, captions)
   */
  async moderateText(text: string, context: string = 'comment'): Promise<ModerationResult> {
    const result = await call_ml_service('spam-detection-service', '/analyze', {
      text,
      context
    });

    return {
      safe: !result.isSpam && !result.isHate,
      confidence: result.confidence,
      flags: result.flags || [],
      categories: {
        adult: result.categories?.adult || 0,
        violence: result.categories?.violence || 0,
        hate: result.categories?.hate || 0,
        spam: result.categories?.spam || 0
      }
    };
  }

  /**
   * Moderate image/thumbnail
   */
  async moderateImage(imageUrl: string): Promise<ModerationResult> {
    const result = await call_ml_service('content-moderation-service', '/image', {
      imageUrl
    });

    return {
      safe: result.safe,
      confidence: result.confidence,
      flags: result.flags || [],
      categories: result.categories
    };
  }

  /**
   * Real-time deepfake detection
   */
  async detectDeepfake(videoId: string): Promise<{ isDeepfake: boolean; confidence: number }> {
    const result = await call_ml_service('ai-deepfake-detection-service', '/detect', {
      videoId
    });

    return {
      isDeepfake: result.isDeepfake,
      confidence: result.confidence
    };
  }
}

export const moderationService = new RealtimeModerationService();
export default moderationService;
