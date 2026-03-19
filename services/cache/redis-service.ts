/**
 * Redis Caching Service
 * High-performance caching layer for API responses
 */

import { createClient, RedisClientType } from 'redis';

interface CacheOptions {
  ttl?: number; // Time to live in seconds
  compress?: boolean;
}

class RedisCacheService {
  private client: RedisClientType | null = null;
  private isConnected = false;
  private readonly defaultTTL = 300; // 5 minutes

  async connect(): Promise<void> {
    if (this.isConnected) return;

    try {
      this.client = createClient({
        url: process.env.REDIS_URL || 'redis://localhost:6379',
        socket: {
          reconnectStrategy: (retries) => {
            if (retries > 10) return new Error('Max retries reached');
            return Math.min(retries * 100, 3000);
          },
        },
      });

      this.client.on('error', (err) => console.error('Redis Client Error', err));
      this.client.on('connect', () => console.log('✅ Redis connected'));
      this.client.on('disconnect', () => console.log('⚠️ Redis disconnected'));

      await this.client.connect();
      this.isConnected = true;
      console.log('🔥 [Redis] Cache service initialized');
    } catch (error) {
      console.error('❌ [Redis] Connection failed:', error);
      throw error;
    }
  }

  async get<T>(key: string): Promise<T | null> {
    if (!this.client) return null;

    try {
      const value = await this.client.get(key);
      if (!value) return null;

      const parsed = JSON.parse(value);
      console.log(`✅ [Redis] Cache HIT: ${key}`);
      return parsed as T;
    } catch (error) {
      console.error(`❌ [Redis] Get error for ${key}:`, error);
      return null;
    }
  }

  async set<T>(key: string, value: T, options: CacheOptions = {}): Promise<void> {
    if (!this.client) return;

    try {
      const ttl = options.ttl || this.defaultTTL;
      const serialized = JSON.stringify(value);

      await this.client.setEx(key, ttl, serialized);
      console.log(`✅ [Redis] Cache SET: ${key} (TTL: ${ttl}s)`);
    } catch (error) {
      console.error(`❌ [Redis] Set error for ${key}:`, error);
    }
  }

  async delete(key: string): Promise<void> {
    if (!this.client) return;

    try {
      await this.client.del(key);
      console.log(`✅ [Redis] Cache DELETE: ${key}`);
    } catch (error) {
      console.error(`❌ [Redis] Delete error for ${key}:`, error);
    }
  }

  async invalidatePattern(pattern: string): Promise<void> {
    if (!this.client) return;

    try {
      const keys = await this.client.keys(pattern);
      if (keys.length > 0) {
        await this.client.del(keys);
        console.log(`✅ [Redis] Invalidated ${keys.length} keys matching: ${pattern}`);
      }
    } catch (error) {
      console.error(`❌ [Redis] Invalidate pattern error:`, error);
    }
  }

  async getOrSet<T>(
    key: string,
    fetchFn: () => Promise<T>,
    options: CacheOptions = {}
  ): Promise<T> {
    // Try to get from cache first
    const cached = await this.get<T>(key);
    if (cached !== null) return cached;

    // Cache miss - fetch and store
    console.log(`⚠️ [Redis] Cache MISS: ${key} - fetching...`);
    const value = await fetchFn();
    await this.set(key, value, options);
    return value;
  }

  async mget<T>(keys: string[]): Promise<(T | null)[]> {
    if (!this.client || keys.length === 0) return [];

    try {
      const values = await this.client.mGet(keys);
      return values.map((v) => (v ? JSON.parse(v) : null));
    } catch (error) {
      console.error('❌ [Redis] mGet error:', error);
      return keys.map(() => null);
    }
  }

  async mset<T>(entries: Array<{ key: string; value: T; ttl?: number }>): Promise<void> {
    if (!this.client || entries.length === 0) return;

    try {
      const pipeline = this.client.multi();

      for (const entry of entries) {
        const ttl = entry.ttl || this.defaultTTL;
        pipeline.setEx(entry.key, ttl, JSON.stringify(entry.value));
      }

      await pipeline.exec();
      console.log(`✅ [Redis] Batch SET: ${entries.length} keys`);
    } catch (error) {
      console.error('❌ [Redis] mSet error:', error);
    }
  }

  async increment(key: string, amount: number = 1): Promise<number> {
    if (!this.client) return 0;

    try {
      const result = await this.client.incrBy(key, amount);
      return result;
    } catch (error) {
      console.error(`❌ [Redis] Increment error for ${key}:`, error);
      return 0;
    }
  }

  async getStats(): Promise<{
    hits: number;
    misses: number;
    hitRate: number;
    keyCount: number;
  }> {
    if (!this.client) return { hits: 0, misses: 0, hitRate: 0, keyCount: 0 };

    try {
      const info = await this.client.info('stats');
      const keyCount = await this.client.dbSize();

      // Parse stats from info string
      const hits = parseInt(info.match(/keyspace_hits:(\d+)/)?.[1] || '0');
      const misses = parseInt(info.match(/keyspace_misses:(\d+)/)?.[1] || '0');
      const total = hits + misses;
      const hitRate = total > 0 ? hits / total : 0;

      return { hits, misses, hitRate, keyCount };
    } catch (error) {
      console.error('❌ [Redis] Stats error:', error);
      return { hits: 0, misses: 0, hitRate: 0, keyCount: 0 };
    }
  }

  async disconnect(): Promise<void> {
    if (this.client && this.isConnected) {
      await this.client.quit();
      this.isConnected = false;
      console.log('👋 [Redis] Disconnected');
    }
  }
}

export const redisCache = new RedisCacheService();

// Auto-connect on import
redisCache.connect().catch(console.error);

export default redisCache;
