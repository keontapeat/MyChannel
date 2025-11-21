// 🔥 BATCH EXPORT - EXPORT MULTIPLE THUMBNAILS AT ONCE 💣
// Works on both Web and iOS (via React Native Bridge)

import JSZip from 'jszip';
import { saveAs } from 'file-saver';

// Types
export interface ExportOptions {
  format: 'png' | 'jpg' | 'webp';
  quality: number; // 0-1
  width: number;
  height: number;
  includeMetadata: boolean;
}

export interface ExportItem {
  id: string;
  name: string;
  canvas: HTMLCanvasElement;
  metadata?: {
    title?: string;
    description?: string;
    tags?: string[];
  };
}

export interface ExportProgress {
  current: number;
  total: number;
  percentage: number;
  currentItem: string;
}

// Platform detection
const isWeb = typeof window !== 'undefined' && !window.hasOwnProperty('ReactNativeWebView');
const isIOS = typeof window !== 'undefined' && window.hasOwnProperty('ReactNativeWebView');

// Export single thumbnail
export async function exportSingleThumbnail(
  canvas: HTMLCanvasElement,
  filename: string,
  options: Partial<ExportOptions> = {}
): Promise<void> {
  const {
    format = 'png',
    quality = 0.95,
    width = 1280,
    height = 720,
  } = options;

  try {
    // Resize if needed
    const resizedCanvas = resizeCanvas(canvas, width, height);

    if (isWeb) {
      // Web: Download directly
      const blob = await canvasToBlob(resizedCanvas, format, quality);
      saveAs(blob, `${filename}.${format}`);
      console.log('✅ [Web] Exported:', filename);
    } else if (isIOS) {
      // iOS: Send to React Native
      const base64 = resizedCanvas.toDataURL(`image/${format}`, quality);
      await sendToNative('exportThumbnail', {
        filename: `${filename}.${format}`,
        data: base64,
        format,
      });
      console.log('✅ [iOS] Exported:', filename);
    }
  } catch (error) {
    console.error('🚨 Export failed:', error);
    throw error;
  }
}

// Batch export multiple thumbnails
export async function batchExportThumbnails(
  items: ExportItem[],
  options: Partial<ExportOptions> = {},
  onProgress?: (progress: ExportProgress) => void
): Promise<void> {
  const {
    format = 'png',
    quality = 0.95,
    width = 1280,
    height = 720,
    includeMetadata = true,
  } = options;

  try {
    if (isWeb) {
      // Web: Create ZIP file
      const zip = new JSZip();
      const folder = zip.folder('thumbnails');

      for (let i = 0; i < items.length; i++) {
        const item = items[i];

        // Update progress
        if (onProgress) {
          onProgress({
            current: i + 1,
            total: items.length,
            percentage: ((i + 1) / items.length) * 100,
            currentItem: item.name,
          });
        }

        // Resize canvas
        const resizedCanvas = resizeCanvas(item.canvas, width, height);

        // Convert to blob
        const blob = await canvasToBlob(resizedCanvas, format, quality);

        // Add to ZIP
        folder?.file(`${item.name}.${format}`, blob);

        // Add metadata if requested
        if (includeMetadata && item.metadata) {
          folder?.file(`${item.name}.json`, JSON.stringify(item.metadata, null, 2));
        }
      }

      // Generate and download ZIP
      const zipBlob = await zip.generateAsync({ type: 'blob' });
      saveAs(zipBlob, `thumbnails-${Date.now()}.zip`);

      console.log('✅ [Web] Batch export complete:', items.length);
    } else if (isIOS) {
      // iOS: Send array to React Native
      const exports = [];

      for (let i = 0; i < items.length; i++) {
        const item = items[i];

        // Update progress
        if (onProgress) {
          onProgress({
            current: i + 1,
            total: items.length,
            percentage: ((i + 1) / items.length) * 100,
            currentItem: item.name,
          });
        }

        // Resize canvas
        const resizedCanvas = resizeCanvas(item.canvas, width, height);

        // Convert to base64
        const base64 = resizedCanvas.toDataURL(`image/${format}`, quality);

        exports.push({
          filename: `${item.name}.${format}`,
          data: base64,
          metadata: includeMetadata ? item.metadata : undefined,
        });
      }

      // Send batch to native
      await sendToNative('batchExportThumbnails', {
        exports,
        format,
      });

      console.log('✅ [iOS] Batch export complete:', items.length);
    }
  } catch (error) {
    console.error('🚨 Batch export failed:', error);
    throw error;
  }
}

// Export to specific formats
export async function exportToMultipleFormats(
  canvas: HTMLCanvasElement,
  filename: string,
  formats: Array<'png' | 'jpg' | 'webp'> = ['png', 'jpg']
): Promise<void> {
  for (const format of formats) {
    await exportSingleThumbnail(canvas, `${filename}_${format}`, { format });
  }
}

// Export with different sizes
export async function exportMultipleSizes(
  canvas: HTMLCanvasElement,
  filename: string,
  sizes: Array<{ width: number; height: number; suffix: string }> = [
    { width: 1280, height: 720, suffix: 'hd' },
    { width: 640, height: 360, suffix: 'sd' },
    { width: 320, height: 180, suffix: 'thumbnail' },
  ]
): Promise<void> {
  if (isWeb) {
    const zip = new JSZip();

    for (const size of sizes) {
      const resizedCanvas = resizeCanvas(canvas, size.width, size.height);
      const blob = await canvasToBlob(resizedCanvas, 'png', 0.95);
      zip.file(`${filename}_${size.suffix}_${size.width}x${size.height}.png`, blob);
    }

    const zipBlob = await zip.generateAsync({ type: 'blob' });
    saveAs(zipBlob, `${filename}_all_sizes.zip`);

    console.log('✅ [Web] Multiple sizes exported');
  } else if (isIOS) {
    const exports = sizes.map((size) => {
      const resizedCanvas = resizeCanvas(canvas, size.width, size.height);
      return {
        filename: `${filename}_${size.suffix}_${size.width}x${size.height}.png`,
        data: resizedCanvas.toDataURL('image/png', 0.95),
      };
    });

    await sendToNative('exportMultipleSizes', { exports });
    console.log('✅ [iOS] Multiple sizes exported');
  }
}

// Helper: Resize canvas
function resizeCanvas(
  sourceCanvas: HTMLCanvasElement,
  targetWidth: number,
  targetHeight: number
): HTMLCanvasElement {
  if (sourceCanvas.width === targetWidth && sourceCanvas.height === targetHeight) {
    return sourceCanvas;
  }

  const canvas = document.createElement('canvas');
  canvas.width = targetWidth;
  canvas.height = targetHeight;

  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('Failed to get canvas context');

  ctx.drawImage(sourceCanvas, 0, 0, targetWidth, targetHeight);

  return canvas;
}

// Helper: Canvas to Blob
function canvasToBlob(
  canvas: HTMLCanvasElement,
  format: string,
  quality: number
): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        if (blob) {
          resolve(blob);
        } else {
          reject(new Error('Failed to create blob'));
        }
      },
      `image/${format}`,
      quality
    );
  });
}

// Helper: Send to React Native
async function sendToNative(action: string, data: any): Promise<void> {
  if (!isIOS) return;

  return new Promise((resolve, reject) => {
    try {
      // @ts-ignore - React Native WebView
      window.ReactNativeWebView?.postMessage(
        JSON.stringify({
          type: 'thumbnail-export',
          action,
          data,
        })
      );

      // Wait for confirmation
      const handleMessage = (event: MessageEvent) => {
        try {
          const response = JSON.parse(event.data);
          if (response.type === 'thumbnail-export-response' && response.action === action) {
            window.removeEventListener('message', handleMessage);
            if (response.success) {
              resolve();
            } else {
              reject(new Error(response.error || 'Export failed'));
            }
          }
        } catch (error) {
          // Ignore parse errors
        }
      };

      window.addEventListener('message', handleMessage);

      // Timeout after 30 seconds
      setTimeout(() => {
        window.removeEventListener('message', handleMessage);
        reject(new Error('Export timeout'));
      }, 30000);
    } catch (error) {
      reject(error);
    }
  });
}

// Export for social media (optimized sizes)
export async function exportForSocialMedia(
  canvas: HTMLCanvasElement,
  filename: string,
  platforms: Array<'youtube' | 'instagram' | 'twitter' | 'facebook'> = ['youtube']
): Promise<void> {
  const platformSizes: Record<string, { width: number; height: number }> = {
    youtube: { width: 1280, height: 720 },
    instagram: { width: 1080, height: 1080 },
    twitter: { width: 1200, height: 675 },
    facebook: { width: 1200, height: 630 },
  };

  const exports = platforms.map((platform) => {
    const size = platformSizes[platform];
    return {
      ...size,
      suffix: platform,
    };
  });

  await exportMultipleSizes(canvas, filename, exports);
}

// Schedule export (for large batches)
export async function scheduleExport(
  items: ExportItem[],
  options: Partial<ExportOptions> = {}
): Promise<string> {
  // Create export job
  const jobId = `export_${Date.now()}`;

  if (isWeb) {
    // Web: Process in background using Web Worker
    // For now, process immediately
    await batchExportThumbnails(items, options);
  } else if (isIOS) {
    // iOS: Send to native for background processing
    await sendToNative('scheduleExport', {
      jobId,
      itemCount: items.length,
      options,
    });
  }

  return jobId;
}

// Get export history
export function getExportHistory(): Array<{
  id: string;
  timestamp: Date;
  itemCount: number;
  format: string;
}> {
  try {
    const history = localStorage.getItem('export_history');
    if (!history) return [];

    return JSON.parse(history).map((item: any) => ({
      ...item,
      timestamp: new Date(item.timestamp),
    }));
  } catch (error) {
    console.error('Failed to load export history:', error);
    return [];
  }
}

// Save to export history
export function saveToExportHistory(
  itemCount: number,
  format: string
): void {
  try {
    const history = getExportHistory();
    history.unshift({
      id: `export_${Date.now()}`,
      timestamp: new Date(),
      itemCount,
      format,
    });

    // Keep only last 50 exports
    const trimmed = history.slice(0, 50);
    localStorage.setItem('export_history', JSON.stringify(trimmed));
  } catch (error) {
    console.error('Failed to save export history:', error);
  }
}






