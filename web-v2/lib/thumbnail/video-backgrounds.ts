// 🔥 VIDEO BACKGROUNDS - LIVE VIDEO IN THUMBNAILS 💣

// Types
export interface VideoBackgroundOptions {
  videoUrl: string;
  startTime?: number; // seconds
  duration?: number; // seconds
  loop?: boolean;
  muted?: boolean;
  playbackRate?: number;
  filters?: VideoFilters;
}

export interface VideoFilters {
  brightness?: number; // 0-2
  contrast?: number; // 0-2
  saturation?: number; // 0-2
  blur?: number; // 0-20
  hueRotate?: number; // 0-360
  grayscale?: number; // 0-1
  sepia?: number; // 0-1
}

export interface VideoFrameCapture {
  timestamp: number;
  canvas: HTMLCanvasElement;
}

// Video Background Manager
export class VideoBackgroundManager {
  private video: HTMLVideoElement;
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private isPlaying = false;
  private animationId: number | null = null;

  constructor(width: number = 1280, height: number = 720) {
    // Create video element
    this.video = document.createElement('video');
    this.video.crossOrigin = 'anonymous';
    this.video.width = width;
    this.video.height = height;

    // Create canvas
    this.canvas = document.createElement('canvas');
    this.canvas.width = width;
    this.canvas.height = height;
    this.ctx = this.canvas.getContext('2d')!;
  }

  // Load video
  async loadVideo(options: VideoBackgroundOptions): Promise<void> {
    return new Promise((resolve, reject) => {
      this.video.src = options.videoUrl;
      this.video.muted = options.muted ?? true;
      this.video.loop = options.loop ?? false;
      this.video.playbackRate = options.playbackRate ?? 1.0;

      this.video.addEventListener('loadedmetadata', () => {
        if (options.startTime) {
          this.video.currentTime = options.startTime;
        }
        resolve();
      });

      this.video.addEventListener('error', () => {
        reject(new Error('Failed to load video'));
      });
    });
  }

  // Play video
  play(): void {
    if (this.isPlaying) return;

    this.video.play();
    this.isPlaying = true;

    const renderFrame = () => {
      if (!this.isPlaying) return;

      // Draw video frame to canvas
      this.ctx.drawImage(this.video, 0, 0, this.canvas.width, this.canvas.height);

      this.animationId = requestAnimationFrame(renderFrame);
    };

    renderFrame();
  }

  // Pause video
  pause(): void {
    this.isPlaying = false;
    this.video.pause();

    if (this.animationId !== null) {
      cancelAnimationFrame(this.animationId);
      this.animationId = null;
    }
  }

  // Seek to time
  seekTo(time: number): void {
    this.video.currentTime = time;
  }

  // Get current canvas
  getCanvas(): HTMLCanvasElement {
    return this.canvas;
  }

  // Capture current frame
  captureFrame(): HTMLCanvasElement {
    const frameCanvas = document.createElement('canvas');
    frameCanvas.width = this.canvas.width;
    frameCanvas.height = this.canvas.height;
    const frameCtx = frameCanvas.getContext('2d')!;
    frameCtx.drawImage(this.canvas, 0, 0);
    return frameCanvas;
  }

  // Apply filters
  applyFilters(filters: VideoFilters): void {
    const filterString = this.buildFilterString(filters);
    this.ctx.filter = filterString;
  }

  private buildFilterString(filters: VideoFilters): string {
    const parts: string[] = [];

    if (filters.brightness !== undefined) {
      parts.push(`brightness(${filters.brightness})`);
    }
    if (filters.contrast !== undefined) {
      parts.push(`contrast(${filters.contrast})`);
    }
    if (filters.saturation !== undefined) {
      parts.push(`saturate(${filters.saturation})`);
    }
    if (filters.blur !== undefined) {
      parts.push(`blur(${filters.blur}px)`);
    }
    if (filters.hueRotate !== undefined) {
      parts.push(`hue-rotate(${filters.hueRotate}deg)`);
    }
    if (filters.grayscale !== undefined) {
      parts.push(`grayscale(${filters.grayscale})`);
    }
    if (filters.sepia !== undefined) {
      parts.push(`sepia(${filters.sepia})`);
    }

    return parts.join(' ') || 'none';
  }

  // Get video duration
  getDuration(): number {
    return this.video.duration;
  }

  // Get current time
  getCurrentTime(): number {
    return this.video.currentTime;
  }

  // Set playback rate
  setPlaybackRate(rate: number): void {
    this.video.playbackRate = rate;
  }

  // Dispose
  dispose(): void {
    this.pause();
    this.video.src = '';
    this.video.load();
  }
}

// Extract frames from video background
export async function extractVideoBackgroundFrames(
  videoUrl: string,
  frameCount: number = 30,
  startTime: number = 0,
  duration?: number
): Promise<VideoFrameCapture[]> {
  const manager = new VideoBackgroundManager();
  await manager.loadVideo({ videoUrl, startTime });

  const videoDuration = duration ?? manager.getDuration();
  const interval = videoDuration / frameCount;
  const frames: VideoFrameCapture[] = [];

  for (let i = 0; i < frameCount; i++) {
    const timestamp = startTime + i * interval;
    manager.seekTo(timestamp);

    // Wait for seek to complete
    await new Promise((resolve) => setTimeout(resolve, 100));

    const canvas = manager.captureFrame();
    frames.push({ timestamp, canvas });
  }

  manager.dispose();
  return frames;
}

// Create looping video background
export async function createLoopingVideoBackground(
  videoUrl: string,
  loopDuration: number = 3, // seconds
  fps: number = 30
): Promise<HTMLCanvasElement[]> {
  const manager = new VideoBackgroundManager();
  await manager.loadVideo({ videoUrl, loop: true });

  const frameCount = loopDuration * fps;
  const frames: HTMLCanvasElement[] = [];

  manager.play();

  for (let i = 0; i < frameCount; i++) {
    await new Promise((resolve) => setTimeout(resolve, 1000 / fps));
    frames.push(manager.captureFrame());
  }

  manager.dispose();
  return frames;
}

// Apply video background to thumbnail
export async function applyVideoBackgroundToThumbnail(
  videoUrl: string,
  overlayCanvas: HTMLCanvasElement,
  options: Partial<VideoBackgroundOptions> = {}
): Promise<HTMLCanvasElement> {
  const manager = new VideoBackgroundManager(
    overlayCanvas.width,
    overlayCanvas.height
  );

  await manager.loadVideo({
    videoUrl,
    ...options,
  });

  // Seek to specific time or find best frame
  if (options.startTime !== undefined) {
    manager.seekTo(options.startTime);
  }

  // Apply filters if specified
  if (options.filters) {
    manager.applyFilters(options.filters);
  }

  // Wait for frame to render
  await new Promise((resolve) => setTimeout(resolve, 100));

  // Composite video background with overlay
  const resultCanvas = document.createElement('canvas');
  resultCanvas.width = overlayCanvas.width;
  resultCanvas.height = overlayCanvas.height;
  const resultCtx = resultCanvas.getContext('2d')!;

  // Draw video background
  resultCtx.drawImage(manager.getCanvas(), 0, 0);

  // Draw overlay (text, stickers, etc.)
  resultCtx.drawImage(overlayCanvas, 0, 0);

  manager.dispose();
  return resultCanvas;
}

// Create animated video thumbnail (GIF)
export async function createAnimatedVideoThumbnail(
  videoUrl: string,
  overlayCanvas: HTMLCanvasElement,
  duration: number = 3000, // milliseconds
  fps: number = 15
): Promise<Blob> {
  const manager = new VideoBackgroundManager(
    overlayCanvas.width,
    overlayCanvas.height
  );

  await manager.loadVideo({ videoUrl, loop: true });

  const frameCount = (duration / 1000) * fps;
  const frames: HTMLCanvasElement[] = [];

  manager.play();

  for (let i = 0; i < frameCount; i++) {
    await new Promise((resolve) => setTimeout(resolve, 1000 / fps));

    // Composite video frame with overlay
    const frameCanvas = document.createElement('canvas');
    frameCanvas.width = overlayCanvas.width;
    frameCanvas.height = overlayCanvas.height;
    const frameCtx = frameCanvas.getContext('2d')!;

    frameCtx.drawImage(manager.getCanvas(), 0, 0);
    frameCtx.drawImage(overlayCanvas, 0, 0);

    frames.push(frameCanvas);
  }

  manager.dispose();

  // Convert frames to GIF (would need gif.js library)
  // For now, return first frame as PNG
  const blob = await new Promise<Blob>((resolve) => {
    frames[0].toBlob((b) => resolve(b!), 'image/png');
  });

  return blob;
}

// Video background presets
export const videoBackgroundPresets = {
  cinematic: {
    filters: {
      brightness: 0.8,
      contrast: 1.2,
      saturation: 0.9,
      blur: 2,
    },
    playbackRate: 0.5,
  },
  vibrant: {
    filters: {
      brightness: 1.1,
      contrast: 1.3,
      saturation: 1.5,
    },
    playbackRate: 1.0,
  },
  vintage: {
    filters: {
      brightness: 0.9,
      contrast: 1.1,
      saturation: 0.7,
      sepia: 0.3,
    },
    playbackRate: 0.8,
  },
  blackAndWhite: {
    filters: {
      brightness: 1.0,
      contrast: 1.2,
      grayscale: 1.0,
    },
    playbackRate: 1.0,
  },
  dreamy: {
    filters: {
      brightness: 1.2,
      contrast: 0.8,
      saturation: 1.3,
      blur: 5,
    },
    playbackRate: 0.7,
  },
  dramatic: {
    filters: {
      brightness: 0.7,
      contrast: 1.5,
      saturation: 0.8,
    },
    playbackRate: 0.6,
  },
};

// Apply preset
export async function applyVideoBackgroundPreset(
  manager: VideoBackgroundManager,
  preset: keyof typeof videoBackgroundPresets
): Promise<void> {
  const presetConfig = videoBackgroundPresets[preset];

  if (presetConfig.filters) {
    manager.applyFilters(presetConfig.filters);
  }

  if (presetConfig.playbackRate) {
    manager.setPlaybackRate(presetConfig.playbackRate);
  }
}

// Smart video background selection
export async function selectBestVideoBackgroundFrame(
  videoUrl: string,
  criteria: 'brightest' | 'darkest' | 'most-colorful' | 'most-contrast' = 'most-colorful'
): Promise<number> {
  // Extract multiple frames
  const frames = await extractVideoBackgroundFrames(videoUrl, 20);

  // Analyze each frame
  const scores = frames.map((frame) => ({
    timestamp: frame.timestamp,
    score: analyzeFrame(frame.canvas, criteria),
  }));

  // Sort by score
  scores.sort((a, b) => b.score - a.score);

  // Return timestamp of best frame
  return scores[0].timestamp;
}

// Analyze frame quality
function analyzeFrame(
  canvas: HTMLCanvasElement,
  criteria: 'brightest' | 'darkest' | 'most-colorful' | 'most-contrast'
): number {
  const ctx = canvas.getContext('2d')!;
  const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
  const data = imageData.data;

  let score = 0;

  switch (criteria) {
    case 'brightest':
      for (let i = 0; i < data.length; i += 4) {
        score += (data[i] + data[i + 1] + data[i + 2]) / 3;
      }
      break;

    case 'darkest':
      for (let i = 0; i < data.length; i += 4) {
        score += 255 - (data[i] + data[i + 1] + data[i + 2]) / 3;
      }
      break;

    case 'most-colorful':
      for (let i = 0; i < data.length; i += 4) {
        const r = data[i];
        const g = data[i + 1];
        const b = data[i + 2];
        const max = Math.max(r, g, b);
        const min = Math.min(r, g, b);
        score += max - min; // Saturation
      }
      break;

    case 'most-contrast':
      let sum = 0;
      let sumSq = 0;
      const pixelCount = data.length / 4;

      for (let i = 0; i < data.length; i += 4) {
        const brightness = (data[i] + data[i + 1] + data[i + 2]) / 3;
        sum += brightness;
        sumSq += brightness * brightness;
      }

      const mean = sum / pixelCount;
      score = sumSq / pixelCount - mean * mean; // Variance
      break;
  }

  return score;
}




