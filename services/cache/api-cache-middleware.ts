/**
 * API Response Caching Middleware
 * Integrates Redis caching with Express routes
 */

import { Request, Response, NextFunction } from 'express';
import redisCache from './redis-service.js';
import crypto from 'crypto';

interface CacheMiddlewareOptions {
  ttl?: number;
  keyPrefix?: string;
  varyBy?: string[]; // Headers to include in cache key
  skipCache?: (req: Request) => boolean;
  invalidateOn?: string[]; // HTTP methods that invalidate cache
}

class APICacheMiddleware {
  /**
   * Generate cache key from request
   */
  private generateCacheKey(req: Request, options: CacheMiddlewareOptions): string {
    const prefix = options.keyPrefix || 'api';
    const path = req.path;
    const query = JSON.stringify(req.query);

    // Include specified headers in cache key
    const varyHeaders = (options.varyBy || [])
      .map((header) => `${header}:${req.get(header) || ''}`)
      .join('|');

    const keyData = `${path}:${query}:${varyHeaders}`;
    const hash = crypto.createHash('md5').update(keyData).digest('hex');

    return `${prefix}:${hash}`;
  }

  /**
   * Cache middleware for GET requests
   */
  cache(options: CacheMiddlewareOptions = {}) {
    return async (req: Request, res: Response, next: NextFunction) => {
      // Only cache GET requests by default
      if (req.method !== 'GET') {
        return next();
      }

      // Skip cache if specified
      if (options.skipCache && options.skipCache(req)) {
        return next();
      }

      const cacheKey = this.generateCacheKey(req, options);

      try {
        // Try to get from cache
        const cached = await redisCache.get<{
          status: number;
          headers: Record<string, string>;
          body: any;
        }>(cacheKey);

        if (cached) {
          // Cache hit - return cached response
          res.set(cached.headers);
          res.set('X-Cache', 'HIT');
          res.set('X-Cache-Key', cacheKey);
          return res.status(cached.status).json(cached.body);
        }

        // Cache miss - intercept response
        const originalJson = res.json.bind(res);
        const originalSend = res.send.bind(res);

        res.json = function (body: any): Response {
          // Store in cache
          const cacheData = {
            status: res.statusCode,
            headers: {
              'Content-Type': 'application/json',
            },
            body,
          };

          redisCache.set(cacheKey, cacheData, { ttl: options.ttl }).catch(console.error);

          res.set('X-Cache', 'MISS');
          res.set('X-Cache-Key', cacheKey);
          return originalJson(body);
        };

        res.send = function (body: any): Response {
          const cacheData = {
            status: res.statusCode,
            headers: {
              'Content-Type': res.get('Content-Type') || 'text/html',
            },
            body,
          };

          redisCache.set(cacheKey, cacheData, { ttl: options.ttl }).catch(console.error);

          res.set('X-Cache', 'MISS');
          res.set('X-Cache-Key', cacheKey);
          return originalSend(body);
        };

        next();
      } catch (error) {
        console.error('❌ [Cache Middleware] Error:', error);
        next();
      }
    };
  }

  /**
   * Invalidate cache on mutations
   */
  invalidate(options: CacheMiddlewareOptions = {}) {
    return async (req: Request, res: Response, next: NextFunction) => {
      const methods = options.invalidateOn || ['POST', 'PUT', 'PATCH', 'DELETE'];

      if (methods.includes(req.method)) {
        const prefix = options.keyPrefix || 'api';
        const pattern = `${prefix}:*`;

        // Invalidate matching cache entries
        await redisCache.invalidatePattern(pattern);
        console.log(`🔥 [Cache] Invalidated cache for ${req.method} ${req.path}`);
      }

      next();
    };
  }

  /**
   * Cache with tag-based invalidation
   */
  cacheWithTags(tags: string[], options: CacheMiddlewareOptions = {}) {
    return async (req: Request, res: Response, next: NextFunction) => {
      const cacheKey = this.generateCacheKey(req, options);

      // Store tags for this cache entry
      const tagPromises = tags.map((tag) =>
        redisCache.set(`tag:${tag}:${cacheKey}`, true, { ttl: options.ttl })
      );

      await Promise.all(tagPromises);

      return this.cache(options)(req, res, next);
    };
  }

  /**
   * Invalidate by tag
   */
  async invalidateByTag(tag: string): Promise<void> {
    await redisCache.invalidatePattern(`tag:${tag}:*`);
    console.log(`🔥 [Cache] Invalidated all entries with tag: ${tag}`);
  }
}

export const apiCacheMiddleware = new APICacheMiddleware();
export default apiCacheMiddleware;
