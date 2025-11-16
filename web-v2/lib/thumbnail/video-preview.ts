// 🔥 VIDEO THUMBNAIL PREVIEW - LIVE VIDEO BACKGROUND 💣

import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { storage } from '@/lib/firebase/config';

// Types
export interface VideoFrame {
  timestamp: number;
  imageData: string; // base64
  width: number;
  height: number;
}

export interface VideoThumbnailOptions {
  videoUrl: string;
  frameTime?: number; // seconds
  width?: number;
  height?: number;
  quality?: number; // 0-1
}

// Extract frame from video
export async function extractVideoFrame(
  videoUrl: string,
  frameTime: number = 0
): Promise<VideoFrame> {
  return new Promise((resolve, reject) => {
    const video = document.createElement('video');
    video.crossOrigin = 'anonymous';
    video.src = videoUrl;

    video.addEventListener('loadedmetadata', () => {
      // Seek to specific time
      video.currentTime = Math.min(frameTime, video.duration);
    });

    video.addEventListener('seeked', () => {
      try {
        // Create canvas
        const canvas = document.createElement('canvas');
        canvas.width = video.videoWidth;
        canvas.height = video.videoHeight;

        const ctx = canvas.getContext('2d');
        if (!ctx) {
          reject(new Error('Failed to get canvas context'));
          return;
        }

        // Draw video frame
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

        // Get image data
        const imageData = canvas.toDataURL('image/png');

        resolve({
          timestamp: frameTime,
          imageData,
          width: canvas.width,
          height: canvas.height,
        });

        // Cleanup
        video.remove();
      } catch (error) {
        reject(error);
      }
    });

    video.addEventListener('error', () => {
      reject(new Error('Failed to load video'));
    });
  });
}

// Extract multiple frames for preview
export async function extractVideoFrames(
  videoUrl: string,
  count: number = 10
): Promise<VideoFrame[]> {
  return new Promise((resolve, reject) => {
    const video = document.createElement('video');
    video.crossOrigin = 'anonymous';
    video.src = videoUrl;

    video.addEventListener('loadedmetadata', async () => {
      const frames: VideoFrame[] = [];
      const duration = video.duration;
      const interval = duration / count;

      for (let i = 0; i < count; i++) {
        const timestamp = i * interval;
        try {
          const frame = await extractVideoFrame(videoUrl, timestamp);
          frames.push(frame);
        } catch (error) {
          console.error('Failed to extract frame:', error);
        }
      }

      resolve(frames);
      video.remove();
    });

    video.addEventListener('error', () => {
      reject(new Error('Failed to load video'));
    });
  });
}

// Create animated thumbnail preview
export async function createAnimatedPreview(
  videoUrl: string,
  duration: number = 3, // seconds
  fps: number = 10
): Promise<Blob> {
  const frameCount = duration * fps;
  const frames = await extractVideoFrames(videoUrl, frameCount);

  // Create GIF using gif.js (would need to install)
  // For now, return first frame as static image
  const firstFrame = frames[0];
  const blob = await fetch(firstFrame.imageData).then((r) => r.blob());

  return blob;
}

// Upload video thumbnail to storage
export async function uploadVideoThumbnail(
  userId: string,
  videoId: string,
  imageData: string
): Promise<string> {
  try {
    // Convert base64 to blob
    const blob = await fetch(imageData).then((r) => r.blob());

    // Upload to Firebase Storage
    const storageRef = ref(storage, `thumbnails/${userId}/${videoId}.png`);
    await uploadBytes(storageRef, blob);

    // Get download URL
    const downloadURL = await getDownloadURL(storageRef);

    console.log('✅ Video thumbnail uploaded:', downloadURL);
    return downloadURL;
  } catch (error) {
    console.error('🚨 Failed to upload video thumbnail:', error);
    throw error;
  }
}

// Generate thumbnail from video URL
export async function generateThumbnailFromVideo(
  options: VideoThumbnailOptions
): Promise<string> {
  const {
    videoUrl,
    frameTime = 0,
    width = 1280,
    height = 720,
    quality = 0.9,
  } = options;

  try {
    // Extract frame
    const frame = await extractVideoFrame(videoUrl, frameTime);

    // Resize if needed
    if (frame.width !== width || frame.height !== height) {
      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;

      const ctx = canvas.getContext('2d');
      if (!ctx) throw new Error('Failed to get canvas context');

      const img = new Image();
      img.src = frame.imageData;

      await new Promise((resolve) => {
        img.onload = () => {
          ctx.drawImage(img, 0, 0, width, height);
          resolve(null);
        };
      });

      return canvas.toDataURL('image/png', quality);
    }

    return frame.imageData;
  } catch (error) {
    console.error('🚨 Failed to generate thumbnail from video:', error);
    throw error;
  }
}

// Smart frame selection (find most interesting frame)
export async function findBestFrame(videoUrl: string): Promise<VideoFrame> {
  // Extract multiple frames
  const frames = await extractVideoFrames(videoUrl, 20);

  // Analyze each frame for "interestingness"
  const scores = await Promise.all(
    frames.map(async (frame) => {
      const score = await analyzeFrameInterest(frame.imageData);
      return { frame, score };
    })
  );

  // Sort by score and return best
  scores.sort((a, b) => b.score - a.score);
  return scores[0].frame;
}

// Analyze frame interest (simple algorithm)
async function analyzeFrameInterest(imageData: string): Promise<number> {
  return new Promise((resolve) => {
    const img = new Image();
    img.src = imageData;

    img.onload = () => {
      const canvas = document.createElement('canvas');
      canvas.width = img.width;
      canvas.height = img.height;

      const ctx = canvas.getContext('2d');
      if (!ctx) {
        resolve(0);
        return;
      }

      ctx.drawImage(img, 0, 0);
      const imageDataObj = ctx.getImageData(0, 0, canvas.width, canvas.height);
      const data = imageDataObj.data;

      // Calculate variance (higher = more interesting)
      let sum = 0;
      let sumSq = 0;
      const pixelCount = data.length / 4;

      for (let i = 0; i < data.length; i += 4) {
        const brightness = (data[i] + data[i + 1] + data[i + 2]) / 3;
        sum += brightness;
        sumSq += brightness * brightness;
      }

      const mean = sum / pixelCount;
      const variance = sumSq / pixelCount - mean * mean;

      resolve(variance);
    };
  });
}

// Create video thumbnail with overlay
export async function createVideoThumbnailWithOverlay(
  videoUrl: string,
  overlayText: string,
  frameTime: number = 0
): Promise<string> {
  const frame = await extractVideoFrame(videoUrl, frameTime);

  const canvas = document.createElement('canvas');
  canvas.width = frame.width;
  canvas.height = frame.height;

  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('Failed to get canvas context');

  // Draw video frame
  const img = new Image();
  img.src = frame.imageData;

  await new Promise((resolve) => {
    img.onload = () => {
      ctx.drawImage(img, 0, 0);

      // Add overlay
      ctx.fillStyle = 'rgba(0, 0, 0, 0.5)';
      ctx.fillRect(0, frame.height - 100, frame.width, 100);

      ctx.fillStyle = '#FFFFFF';
      ctx.font = 'bold 48px Inter';
      ctx.textAlign = 'center';
      ctx.fillText(overlayText, frame.width / 2, frame.height - 40);

      resolve(null);
    };
  });

  return canvas.toDataURL('image/png');
}

// Batch process video thumbnails
export async function batchProcessVideoThumbnails(
  videos: Array<{ id: string; url: string }>,
  onProgress?: (progress: number) => void
): Promise<Array<{ id: string; thumbnail: string }>> {
  const results: Array<{ id: string; thumbnail: string }> = [];
  let completed = 0;

  for (const video of videos) {
    try {
      const frame = await findBestFrame(video.url);
      results.push({
        id: video.id,
        thumbnail: frame.imageData,
      });
    } catch (error) {
      console.error(`Failed to process video ${video.id}:`, error);
    }

    completed++;
    if (onProgress) {
      onProgress((completed / videos.length) * 100);
    }
  }

  return results;
}


