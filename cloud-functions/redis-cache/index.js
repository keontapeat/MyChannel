/**
 * 🔥 REDIS CACHE CLOUD FUNCTION
 * High-performance cache layer using Google Memorystore Redis
 * 
 * Deployment: gcloud functions deploy redis-cache --gen2 --runtime=nodejs20 --trigger-http
 */

const functions = require('@google-cloud/functions-framework');
const Redis = require('ioredis');

// Redis connection (lazy initialization)
let redis = null;
let connectionStatus = 'disconnected';

function getRedisClient() {
  if (redis && connectionStatus === 'connected') {
    return redis;
  }

  const host = process.env.REDIS_HOST || 'localhost';
  const port = parseInt(process.env.REDIS_PORT || '6379');
  
  console.log(`🔄 Connecting to Redis at ${host}:${port}...`);

  redis = new Redis({
    host: host,
    port: port,
    password: process.env.REDIS_AUTH_STRING,
    enableReadyCheck: false, // Don't wait for ready
    lazyConnect: true, // Connect on first command
    maxRetriesPerRequest: 3,
    retryStrategy: (times) => {
      if (times > 3) return null; // Stop retrying
      return Math.min(times * 100, 1000);
    },
    connectTimeout: 5000,
    commandTimeout: 3000,
  });

  redis.on('error', (err) => {
    console.error('Redis error:', err.message);
    connectionStatus = 'error';
  });
  
  redis.on('connect', () => {
    console.log('✅ Connected to Redis');
    connectionStatus = 'connected';
  });

  redis.on('close', () => {
    console.log('🔌 Redis connection closed');
    connectionStatus = 'disconnected';
  });

  return redis;
}

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Admin-Key',
};

/**
 * Main HTTP handler
 */
functions.http('redisCache', async (req, res) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders);
    res.status(204).send('');
    return;
  }

  res.set(corsHeaders);

  const path = req.path;

  // Health check doesn't require Redis connection
  if (path === '/health' || path === '/') {
    return await handleHealth(req, res);
  }

  try {
    const client = getRedisClient();
    
    switch (path) {
      case '/get':
        await handleGet(req, res, client);
        break;
      case '/set':
        await handleSet(req, res, client);
        break;
      case '/delete':
        await handleDelete(req, res, client);
        break;
      case '/mget':
        await handleMGet(req, res, client);
        break;
      case '/mset':
        await handleMSet(req, res, client);
        break;
      case '/flush':
        await handleFlush(req, res, client);
        break;
      case '/stats':
        await handleStats(req, res, client);
        break;
      default:
        res.status(404).json({ error: 'Not found', availableEndpoints: ['/get', '/set', '/delete', '/mget', '/mset', '/health', '/stats'] });
    }
  } catch (error) {
    console.error('Redis error:', error);
    res.status(500).json({ error: error.message, hint: 'Redis may not be reachable. Check VPC connector.' });
  }
});

/**
 * GET - Retrieve single value
 */
async function handleGet(req, res, client) {
  const key = req.query.key;
  if (!key) {
    return res.status(400).json({ error: 'Missing key parameter' });
  }

  const startTime = Date.now();
  const value = await client.get(key);
  const latency = Date.now() - startTime;

  console.log(`📖 GET ${key} - ${value ? 'HIT' : 'MISS'} (${latency}ms)`);

  if (value === null) {
    return res.status(200).send('null');
  }

  res.status(200).send(value);
}

/**
 * SET - Store single value with TTL
 */
async function handleSet(req, res, client) {
  const { key, value, ttl } = req.body;

  if (!key || value === undefined) {
    return res.status(400).json({ error: 'Missing key or value' });
  }

  const startTime = Date.now();
  
  // Set with TTL (default 5 minutes)
  const ttlSeconds = ttl || 300;
  await client.setex(key, ttlSeconds, typeof value === 'string' ? value : JSON.stringify(value));
  
  const latency = Date.now() - startTime;
  console.log(`💾 SET ${key} TTL=${ttlSeconds}s (${latency}ms)`);

  res.status(200).json({ success: true, latency });
}

/**
 * DELETE - Remove single key
 */
async function handleDelete(req, res, client) {
  const { key } = req.body;

  if (!key) {
    return res.status(400).json({ error: 'Missing key' });
  }

  const result = await client.del(key);
  console.log(`🗑️ DELETE ${key} - ${result ? 'OK' : 'NOT_FOUND'}`);

  res.status(200).json({ success: true, deleted: result });
}

/**
 * MGET - Batch retrieve multiple values
 */
async function handleMGet(req, res, client) {
  const { keys } = req.body;

  if (!keys || !Array.isArray(keys) || keys.length === 0) {
    return res.status(400).json({ error: 'Missing keys array' });
  }

  // Limit to 100 keys per request
  const limitedKeys = keys.slice(0, 100);
  
  const startTime = Date.now();
  const values = await client.mget(...limitedKeys);
  const latency = Date.now() - startTime;

  const result = {};
  limitedKeys.forEach((key, i) => {
    if (values[i] !== null) {
      result[key] = values[i];
    }
  });

  console.log(`📚 MGET ${limitedKeys.length} keys - ${Object.keys(result).length} hits (${latency}ms)`);

  res.status(200).json(result);
}

/**
 * MSET - Batch store multiple values
 */
async function handleMSet(req, res, client) {
  const { items, ttl } = req.body;

  if (!items || typeof items !== 'object') {
    return res.status(400).json({ error: 'Missing items object' });
  }

  const ttlSeconds = ttl || 300;
  const pipeline = client.pipeline();

  const entries = Object.entries(items).slice(0, 100); // Limit to 100 items
  
  for (const [key, value] of entries) {
    pipeline.setex(key, ttlSeconds, typeof value === 'string' ? value : JSON.stringify(value));
  }

  const startTime = Date.now();
  await pipeline.exec();
  const latency = Date.now() - startTime;

  console.log(`💾 MSET ${entries.length} keys TTL=${ttlSeconds}s (${latency}ms)`);

  res.status(200).json({ success: true, count: entries.length, latency });
}

/**
 * FLUSH - Clear all keys (use with caution!)
 */
async function handleFlush(req, res, client) {
  // Require auth header for destructive operation
  const authHeader = req.headers['x-admin-key'];
  if (authHeader !== process.env.ADMIN_KEY) {
    return res.status(403).json({ error: 'Unauthorized' });
  }

  await client.flushdb();
  console.log('🧹 FLUSH - All keys deleted');

  res.status(200).json({ success: true, message: 'Cache flushed' });
}

/**
 * HEALTH - Check Redis connection (doesn't actually connect to Redis)
 */
async function handleHealth(req, res) {
  // Return healthy immediately - Redis connection is optional
  res.status(200).json({
    status: 'healthy',
    service: 'redis-cache',
    redis: connectionStatus,
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
}

/**
 * STATS - Get Redis statistics
 */
async function handleStats(req, res, client) {
  try {
    const info = await client.info();
    const dbSize = await client.dbsize();
    const memory = await client.info('memory');

    // Parse memory info
    const usedMemory = memory.match(/used_memory_human:(.+)/)?.[1]?.trim() || 'unknown';
    const maxMemory = memory.match(/maxmemory_human:(.+)/)?.[1]?.trim() || 'unknown';

    res.status(200).json({
      dbSize,
      usedMemory,
      maxMemory,
      uptime: info.match(/uptime_in_seconds:(\d+)/)?.[1] || 0,
      connectedClients: info.match(/connected_clients:(\d+)/)?.[1] || 0,
      hitRate: calculateHitRate(info),
    });
  } catch (error) {
    res.status(503).json({
      error: 'Cannot get stats',
      message: error.message,
      hint: 'Redis may not be connected yet'
    });
  }
}

function calculateHitRate(info) {
  const hits = parseInt(info.match(/keyspace_hits:(\d+)/)?.[1] || '0');
  const misses = parseInt(info.match(/keyspace_misses:(\d+)/)?.[1] || '0');
  const total = hits + misses;
  return total > 0 ? ((hits / total) * 100).toFixed(2) + '%' : '0%';
}
