/**
 * Response Compression Middleware
 * Reduces API response sizes by 40-70%
 */

import { Request, Response, NextFunction } from 'express';
import zlib from 'zlib';
import { promisify } from 'util';

const gzip = promisify(zlib.gzip);
const brotli = promisify(zlib.brotliCompress);

interface CompressionOptions {
  threshold?: number; // Minimum size to compress (bytes)
  level?: number; // Compression level (0-9)
  preferBrotli?: boolean;
}

class CompressionService {
  private readonly defaultThreshold = 1024; // 1KB
  private readonly defaultLevel = 6; // Balanced compression

  /**
   * Compress response data based on Accept-Encoding header
   */
  async compress(
    data: string | Buffer,
    acceptEncoding: string = '',
    options: CompressionOptions = {}
  ): Promise<{ data: Buffer; encoding: string }> {
    const threshold = options.threshold || this.defaultThreshold;
    const level = options.level || this.defaultLevel;

    // Convert to buffer if string
    const buffer = Buffer.isBuffer(data) ? data : Buffer.from(data);

    // Don't compress if below threshold
    if (buffer.length < threshold) {
      return { data: buffer, encoding: 'identity' };
    }

    const encodings = acceptEncoding.toLowerCase().split(',').map((e) => e.trim());

    // Prefer Brotli (better compression)
    if (encodings.includes('br') && options.preferBrotli !== false) {
      const compressed = await brotli(buffer, {
        params: {
          [zlib.constants.BROTLI_PARAM_QUALITY]: level,
        },
      });
      console.log(
        `🔥 [Compression] Brotli: ${buffer.length} → ${compressed.length} bytes (${this.compressionRatio(buffer.length, compressed.length)}% saved)`
      );
      return { data: compressed, encoding: 'br' };
    }

    // Fallback to Gzip
    if (encodings.includes('gzip')) {
      const compressed = await gzip(buffer, { level });
      console.log(
        `✅ [Compression] Gzip: ${buffer.length} → ${compressed.length} bytes (${this.compressionRatio(buffer.length, compressed.length)}% saved)`
      );
      return { data: compressed, encoding: 'gzip' };
    }

    // No compression supported
    return { data: buffer, encoding: 'identity' };
  }

  /**
   * Express middleware for automatic response compression
   */
  middleware(options: CompressionOptions = {}) {
    return async (req: Request, res: Response, next: NextFunction) => {
      const originalSend = res.send.bind(res);
      const originalJson = res.json.bind(res);

      // Override res.send
      res.send = function (data: any): Response {
        return compressAndSend(this, data, originalSend, req.headers['accept-encoding']);
      };

      // Override res.json
      res.json = function (data: any): Response {
        const json = JSON.stringify(data);
        return compressAndSend(this, json, originalSend, req.headers['accept-encoding']);
      };

      async function compressAndSend(
        response: Response,
        data: any,
        sendFn: Function,
        acceptEncoding?: string
      ): Promise<Response> {
        try {
          const { data: compressed, encoding } = await compressionService.compress(
            data,
            acceptEncoding,
            options
          );

          if (encoding !== 'identity') {
            response.setHeader('Content-Encoding', encoding);
            response.setHeader('Vary', 'Accept-Encoding');
          }

          response.setHeader('Content-Length', compressed.length);
          return sendFn(compressed);
        } catch (error) {
          console.error('❌ [Compression] Error:', error);
          return sendFn(data);
        }
      }

      next();
    };
  }

  private compressionRatio(original: number, compressed: number): number {
    return Math.round(((original - compressed) / original) * 100);
  }

  /**
   * Compress static assets
   */
  async compressAsset(filePath: string): Promise<Buffer> {
    const fs = require('fs').promises;
    const data = await fs.readFile(filePath);
    const { data: compressed } = await this.compress(data, 'br, gzip', {
      level: 9, // Maximum compression for static assets
      preferBrotli: true,
    });
    return compressed;
  }
}

export const compressionService = new CompressionService();
export default compressionService;
