// 🔥 ANIMATION SUPPORT - ANIMATED THUMBNAILS 💣

import GIF from 'gif.js';

// Types
export interface AnimationOptions {
  duration: number; // milliseconds
  fps: number;
  loop: boolean;
  quality: number; // 1-20 (1 = best)
  width: number;
  height: number;
}

export interface AnimationFrame {
  canvas: HTMLCanvasElement;
  delay: number; // milliseconds
}

export interface TextAnimation {
  type: 'fade' | 'slide' | 'bounce' | 'rotate' | 'scale' | 'typewriter';
  duration: number;
  easing: 'linear' | 'easeIn' | 'easeOut' | 'easeInOut' | 'bounce';
}

export interface StickerAnimation {
  type: 'float' | 'spin' | 'pulse' | 'shake' | 'wiggle';
  duration: number;
  intensity: number;
}

// Animation Engine
export class AnimationEngine {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private frames: AnimationFrame[] = [];
  private currentFrame = 0;
  private isPlaying = false;
  private animationId: number | null = null;

  constructor(width: number = 1280, height: number = 720) {
    this.canvas = document.createElement('canvas');
    this.canvas.width = width;
    this.canvas.height = height;
    this.ctx = this.canvas.getContext('2d')!;
  }

  // Add frame
  addFrame(canvas: HTMLCanvasElement, delay: number = 100): void {
    const frameCanvas = document.createElement('canvas');
    frameCanvas.width = canvas.width;
    frameCanvas.height = canvas.height;
    const frameCtx = frameCanvas.getContext('2d')!;
    frameCtx.drawImage(canvas, 0, 0);

    this.frames.push({ canvas: frameCanvas, delay });
  }

  // Clear frames
  clearFrames(): void {
    this.frames = [];
    this.currentFrame = 0;
  }

  // Play animation
  play(loop: boolean = true): void {
    if (this.isPlaying) return;
    this.isPlaying = true;

    const playFrame = () => {
      if (!this.isPlaying) return;

      const frame = this.frames[this.currentFrame];
      this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
      this.ctx.drawImage(frame.canvas, 0, 0);

      this.currentFrame++;
      if (this.currentFrame >= this.frames.length) {
        if (loop) {
          this.currentFrame = 0;
        } else {
          this.stop();
          return;
        }
      }

      this.animationId = window.setTimeout(playFrame, frame.delay);
    };

    playFrame();
  }

  // Stop animation
  stop(): void {
    this.isPlaying = false;
    if (this.animationId !== null) {
      clearTimeout(this.animationId);
      this.animationId = null;
    }
  }

  // Get current canvas
  getCanvas(): HTMLCanvasElement {
    return this.canvas;
  }

  // Export to GIF
  async exportToGIF(options: Partial<AnimationOptions> = {}): Promise<Blob> {
    const {
      quality = 10,
      width = this.canvas.width,
      height = this.canvas.height,
    } = options;

    return new Promise((resolve, reject) => {
      const gif = new GIF({
        workers: 4,
        quality,
        width,
        height,
        workerScript: '/gif.worker.js',
      });

      // Add frames
      this.frames.forEach((frame) => {
        gif.addFrame(frame.canvas, { delay: frame.delay });
      });

      gif.on('finished', (blob: Blob) => {
        resolve(blob);
      });

      gif.on('error', (error: Error) => {
        reject(error);
      });

      gif.render();
    });
  }

  // Export to MP4 (using MediaRecorder)
  async exportToMP4(options: Partial<AnimationOptions> = {}): Promise<Blob> {
    const { fps = 30, duration = 3000 } = options;

    const stream = this.canvas.captureStream(fps);
    const mediaRecorder = new MediaRecorder(stream, {
      mimeType: 'video/webm;codecs=vp9',
    });

    const chunks: Blob[] = [];

    return new Promise((resolve, reject) => {
      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          chunks.push(event.data);
        }
      };

      mediaRecorder.onstop = () => {
        const blob = new Blob(chunks, { type: 'video/webm' });
        resolve(blob);
      };

      mediaRecorder.onerror = reject;

      // Start recording
      mediaRecorder.start();
      this.play(true);

      // Stop after duration
      setTimeout(() => {
        this.stop();
        mediaRecorder.stop();
      }, duration);
    });
  }
}

// Text Animations
export class TextAnimator {
  // Fade in animation
  static fadeIn(
    text: string,
    x: number,
    y: number,
    fontSize: number,
    color: string,
    duration: number = 1000,
    fps: number = 30
  ): AnimationFrame[] {
    const frames: AnimationFrame[] = [];
    const frameCount = (duration / 1000) * fps;
    const delay = 1000 / fps;

    for (let i = 0; i <= frameCount; i++) {
      const canvas = document.createElement('canvas');
      canvas.width = 1280;
      canvas.height = 720;
      const ctx = canvas.getContext('2d')!;

      const opacity = i / frameCount;
      ctx.globalAlpha = opacity;
      ctx.font = `${fontSize}px Arial`;
      ctx.fillStyle = color;
      ctx.fillText(text, x, y);

      frames.push({ canvas, delay });
    }

    return frames;
  }

  // Slide in animation
  static slideIn(
    text: string,
    startX: number,
    endX: number,
    y: number,
    fontSize: number,
    color: string,
    duration: number = 1000,
    fps: number = 30
  ): AnimationFrame[] {
    const frames: AnimationFrame[] = [];
    const frameCount = (duration / 1000) * fps;
    const delay = 1000 / fps;
    const step = (endX - startX) / frameCount;

    for (let i = 0; i <= frameCount; i++) {
      const canvas = document.createElement('canvas');
      canvas.width = 1280;
      canvas.height = 720;
      const ctx = canvas.getContext('2d')!;

      const x = startX + step * i;
      ctx.font = `${fontSize}px Arial`;
      ctx.fillStyle = color;
      ctx.fillText(text, x, y);

      frames.push({ canvas, delay });
    }

    return frames;
  }

  // Bounce animation
  static bounce(
    text: string,
    x: number,
    baseY: number,
    bounceHeight: number,
    fontSize: number,
    color: string,
    duration: number = 1000,
    fps: number = 30
  ): AnimationFrame[] {
    const frames: AnimationFrame[] = [];
    const frameCount = (duration / 1000) * fps;
    const delay = 1000 / fps;

    for (let i = 0; i <= frameCount; i++) {
      const canvas = document.createElement('canvas');
      canvas.width = 1280;
      canvas.height = 720;
      const ctx = canvas.getContext('2d')!;

      const progress = i / frameCount;
      const bounce = Math.abs(Math.sin(progress * Math.PI * 2)) * bounceHeight;
      const y = baseY - bounce;

      ctx.font = `${fontSize}px Arial`;
      ctx.fillStyle = color;
      ctx.fillText(text, x, y);

      frames.push({ canvas, delay });
    }

    return frames;
  }

  // Rotate animation
  static rotate(
    text: string,
    x: number,
    y: number,
    fontSize: number,
    color: string,
    duration: number = 2000,
    fps: number = 30
  ): AnimationFrame[] {
    const frames: AnimationFrame[] = [];
    const frameCount = (duration / 1000) * fps;
    const delay = 1000 / fps;
    const rotationStep = (Math.PI * 2) / frameCount;

    for (let i = 0; i <= frameCount; i++) {
      const canvas = document.createElement('canvas');
      canvas.width = 1280;
      canvas.height = 720;
      const ctx = canvas.getContext('2d')!;

      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(i * rotationStep);
      ctx.font = `${fontSize}px Arial`;
      ctx.fillStyle = color;
      ctx.fillText(text, 0, 0);
      ctx.restore();

      frames.push({ canvas, delay });
    }

    return frames;
  }

  // Scale animation
  static scale(
    text: string,
    x: number,
    y: number,
    startSize: number,
    endSize: number,
    color: string,
    duration: number = 1000,
    fps: number = 30
  ): AnimationFrame[] {
    const frames: AnimationFrame[] = [];
    const frameCount = (duration / 1000) * fps;
    const delay = 1000 / fps;
    const sizeStep = (endSize - startSize) / frameCount;

    for (let i = 0; i <= frameCount; i++) {
      const canvas = document.createElement('canvas');
      canvas.width = 1280;
      canvas.height = 720;
      const ctx = canvas.getContext('2d')!;

      const fontSize = startSize + sizeStep * i;
      ctx.font = `${fontSize}px Arial`;
      ctx.fillStyle = color;
      ctx.fillText(text, x, y);

      frames.push({ canvas, delay });
    }

    return frames;
  }

  // Typewriter animation
  static typewriter(
    text: string,
    x: number,
    y: number,
    fontSize: number,
    color: string,
    duration: number = 2000,
    fps: number = 30
  ): AnimationFrame[] {
    const frames: AnimationFrame[] = [];
    const frameCount = (duration / 1000) * fps;
    const delay = 1000 / fps;
    const charsPerFrame = text.length / frameCount;

    for (let i = 0; i <= frameCount; i++) {
      const canvas = document.createElement('canvas');
      canvas.width = 1280;
      canvas.height = 720;
      const ctx = canvas.getContext('2d')!;

      const charCount = Math.floor(i * charsPerFrame);
      const displayText = text.substring(0, charCount);

      ctx.font = `${fontSize}px Arial`;
      ctx.fillStyle = color;
      ctx.fillText(displayText, x, y);

      frames.push({ canvas, delay });
    }

    return frames;
  }
}

// Sticker Animations
export class StickerAnimator {
  // Float animation
  static float(
    image: HTMLImageElement,
    x: number,
    baseY: number,
    floatHeight: number,
    width: number,
    height: number,
    duration: number = 2000,
    fps: number = 30
  ): AnimationFrame[] {
    const frames: AnimationFrame[] = [];
    const frameCount = (duration / 1000) * fps;
    const delay = 1000 / fps;

    for (let i = 0; i <= frameCount; i++) {
      const canvas = document.createElement('canvas');
      canvas.width = 1280;
      canvas.height = 720;
      const ctx = canvas.getContext('2d')!;

      const progress = i / frameCount;
      const float = Math.sin(progress * Math.PI * 2) * floatHeight;
      const y = baseY + float;

      ctx.drawImage(image, x, y, width, height);

      frames.push({ canvas, delay });
    }

    return frames;
  }

  // Spin animation
  static spin(
    image: HTMLImageElement,
    x: number,
    y: number,
    width: number,
    height: number,
    duration: number = 2000,
    fps: number = 30
  ): AnimationFrame[] {
    const frames: AnimationFrame[] = [];
    const frameCount = (duration / 1000) * fps;
    const delay = 1000 / fps;
    const rotationStep = (Math.PI * 2) / frameCount;

    for (let i = 0; i <= frameCount; i++) {
      const canvas = document.createElement('canvas');
      canvas.width = 1280;
      canvas.height = 720;
      const ctx = canvas.getContext('2d')!;

      ctx.save();
      ctx.translate(x + width / 2, y + height / 2);
      ctx.rotate(i * rotationStep);
      ctx.drawImage(image, -width / 2, -height / 2, width, height);
      ctx.restore();

      frames.push({ canvas, delay });
    }

    return frames;
  }

  // Pulse animation
  static pulse(
    image: HTMLImageElement,
    x: number,
    y: number,
    baseWidth: number,
    baseHeight: number,
    pulseAmount: number,
    duration: number = 1000,
    fps: number = 30
  ): AnimationFrame[] {
    const frames: AnimationFrame[] = [];
    const frameCount = (duration / 1000) * fps;
    const delay = 1000 / fps;

    for (let i = 0; i <= frameCount; i++) {
      const canvas = document.createElement('canvas');
      canvas.width = 1280;
      canvas.height = 720;
      const ctx = canvas.getContext('2d')!;

      const progress = i / frameCount;
      const scale = 1 + Math.sin(progress * Math.PI * 2) * pulseAmount;
      const width = baseWidth * scale;
      const height = baseHeight * scale;
      const offsetX = (baseWidth - width) / 2;
      const offsetY = (baseHeight - height) / 2;

      ctx.drawImage(image, x + offsetX, y + offsetY, width, height);

      frames.push({ canvas, delay });
    }

    return frames;
  }

  // Shake animation
  static shake(
    image: HTMLImageElement,
    baseX: number,
    baseY: number,
    width: number,
    height: number,
    intensity: number,
    duration: number = 500,
    fps: number = 30
  ): AnimationFrame[] {
    const frames: AnimationFrame[] = [];
    const frameCount = (duration / 1000) * fps;
    const delay = 1000 / fps;

    for (let i = 0; i <= frameCount; i++) {
      const canvas = document.createElement('canvas');
      canvas.width = 1280;
      canvas.height = 720;
      const ctx = canvas.getContext('2d')!;

      const x = baseX + (Math.random() - 0.5) * intensity;
      const y = baseY + (Math.random() - 0.5) * intensity;

      ctx.drawImage(image, x, y, width, height);

      frames.push({ canvas, delay });
    }

    return frames;
  }
}

// Transition Effects
export class TransitionEffects {
  // Fade transition
  static fade(
    fromCanvas: HTMLCanvasElement,
    toCanvas: HTMLCanvasElement,
    duration: number = 1000,
    fps: number = 30
  ): AnimationFrame[] {
    const frames: AnimationFrame[] = [];
    const frameCount = (duration / 1000) * fps;
    const delay = 1000 / fps;

    for (let i = 0; i <= frameCount; i++) {
      const canvas = document.createElement('canvas');
      canvas.width = fromCanvas.width;
      canvas.height = fromCanvas.height;
      const ctx = canvas.getContext('2d')!;

      const progress = i / frameCount;

      // Draw from canvas
      ctx.globalAlpha = 1 - progress;
      ctx.drawImage(fromCanvas, 0, 0);

      // Draw to canvas
      ctx.globalAlpha = progress;
      ctx.drawImage(toCanvas, 0, 0);

      frames.push({ canvas, delay });
    }

    return frames;
  }

  // Slide transition
  static slide(
    fromCanvas: HTMLCanvasElement,
    toCanvas: HTMLCanvasElement,
    direction: 'left' | 'right' | 'up' | 'down',
    duration: number = 1000,
    fps: number = 30
  ): AnimationFrame[] {
    const frames: AnimationFrame[] = [];
    const frameCount = (duration / 1000) * fps;
    const delay = 1000 / fps;

    for (let i = 0; i <= frameCount; i++) {
      const canvas = document.createElement('canvas');
      canvas.width = fromCanvas.width;
      canvas.height = fromCanvas.height;
      const ctx = canvas.getContext('2d')!;

      const progress = i / frameCount;
      let fromX = 0,
        fromY = 0,
        toX = 0,
        toY = 0;

      switch (direction) {
        case 'left':
          fromX = -canvas.width * progress;
          toX = canvas.width * (1 - progress);
          break;
        case 'right':
          fromX = canvas.width * progress;
          toX = -canvas.width * (1 - progress);
          break;
        case 'up':
          fromY = -canvas.height * progress;
          toY = canvas.height * (1 - progress);
          break;
        case 'down':
          fromY = canvas.height * progress;
          toY = -canvas.height * (1 - progress);
          break;
      }

      ctx.drawImage(fromCanvas, fromX, fromY);
      ctx.drawImage(toCanvas, toX, toY);

      frames.push({ canvas, delay });
    }

    return frames;
  }
}

// Export animation
export async function exportAnimation(
  frames: AnimationFrame[],
  format: 'gif' | 'mp4' = 'gif',
  options: Partial<AnimationOptions> = {}
): Promise<Blob> {
  const engine = new AnimationEngine(options.width, options.height);

  frames.forEach((frame) => {
    engine.addFrame(frame.canvas, frame.delay);
  });

  if (format === 'gif') {
    return engine.exportToGIF(options);
  } else {
    return engine.exportToMP4(options);
  }
}


