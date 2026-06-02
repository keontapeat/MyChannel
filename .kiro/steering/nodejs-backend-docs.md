# Node.js & Backend Development Documentation Reference

This steering file provides essential Node.js, Express, and backend development documentation for senior developers.

## Node.js Core

### Official Documentation
- **Node.js Docs**: https://nodejs.org/docs/latest/api/
- **Getting Started**: https://nodejs.org/en/docs/guides/getting-started-guide
- **ES Modules**: https://nodejs.org/api/esm.html
- **CommonJS Modules**: https://nodejs.org/api/modules.html
- **Package.json**: https://docs.npmjs.com/cli/v10/configuring-npm/package-json
- **NPM CLI**: https://docs.npmjs.com/cli/v10/commands

### Core Modules
- **fs (File System)**: https://nodejs.org/api/fs.html
- **path**: https://nodejs.org/api/path.html
- **http/https**: https://nodejs.org/api/http.html
- **crypto**: https://nodejs.org/api/crypto.html
- **stream**: https://nodejs.org/api/stream.html
- **events**: https://nodejs.org/api/events.html
- **child_process**: https://nodejs.org/api/child_process.html
- **worker_threads**: https://nodejs.org/api/worker_threads.html
- **cluster**: https://nodejs.org/api/cluster.html

### Async Programming
- **Promises**: https://nodejs.org/api/async_context.html
- **async/await**: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/async_function
- **Event Loop**: https://nodejs.org/en/docs/guides/event-loop-timers-and-nexttick
- **Timers**: https://nodejs.org/api/timers.html

## Express.js Framework
- **Express Docs**: https://expressjs.com/en/4x/api.html
- **Routing**: https://expressjs.com/en/guide/routing.html
- **Middleware**: https://expressjs.com/en/guide/using-middleware.html
- **Error Handling**: https://expressjs.com/en/guide/error-handling.html
- **Request**: https://expressjs.com/en/4x/api.html#req
- **Response**: https://expressjs.com/en/4x/api.html#res
- **Router**: https://expressjs.com/en/4x/api.html#router

## TypeScript for Node.js
- **TypeScript Handbook**: https://www.typescriptlang.org/docs/handbook/intro.html
- **TypeScript with Node**: https://nodejs.org/en/learn/getting-started/nodejs-with-typescript
- **tsconfig.json**: https://www.typescriptlang.org/tsconfig
- **Type Declarations**: https://www.typescriptlang.org/docs/handbook/declaration-files/introduction.html
- **@types packages**: https://www.npmjs.com/~types

## Testing Frameworks

### Jest
- **Jest Docs**: https://jestjs.io/docs/getting-started
- **Matchers**: https://jestjs.io/docs/expect
- **Mocking**: https://jestjs.io/docs/mock-functions
- **Async Testing**: https://jestjs.io/docs/asynchronous

### Mocha
- **Mocha Docs**: https://mochajs.org/
- **Hooks**: https://mochajs.org/#hooks
- **Async Tests**: https://mochajs.org/#asynchronous-code

### Chai (Assertions)
- **Chai Docs**: https://www.chaijs.com/api/
- **BDD Style**: https://www.chaijs.com/api/bdd/
- **Expect**: https://www.chaijs.com/api/bdd/#method_expect

### Supertest (HTTP Testing)
- **Supertest**: https://github.com/ladjs/supertest

## Database Libraries

### PostgreSQL
- **node-postgres (pg)**: https://node-postgres.com/
- **Queries**: https://node-postgres.com/features/queries
- **Transactions**: https://node-postgres.com/features/transactions
- **Connection Pooling**: https://node-postgres.com/features/pooling

### MongoDB
- **MongoDB Node Driver**: https://www.mongodb.com/docs/drivers/node/current/
- **CRUD Operations**: https://www.mongodb.com/docs/drivers/node/current/usage-examples/
- **Mongoose ODM**: https://mongoosejs.com/docs/guide.html

### Redis
- **node-redis**: https://github.com/redis/node-redis
- **Commands**: https://redis.io/commands/
- **Pub/Sub**: https://redis.io/docs/manual/pubsub/

## Authentication & Security

### JWT (JSON Web Tokens)
- **jsonwebtoken**: https://github.com/auth0/node-jsonwebtoken
- **JWT.io**: https://jwt.io/introduction

### Passport.js
- **Passport Docs**: https://www.passportjs.org/docs/
- **Strategies**: https://www.passportjs.org/packages/

### bcrypt (Password Hashing)
- **bcrypt**: https://github.com/kelektiv/node.bcrypt.js

### Helmet (Security Headers)
- **Helmet**: https://helmetjs.github.io/

### CORS
- **cors middleware**: https://github.com/expressjs/cors

## Validation & Sanitization

### Joi
- **Joi Docs**: https://joi.dev/api/
- **Validation**: https://joi.dev/api/?v=17.9.1#introduction

### Zod
- **Zod Docs**: https://zod.dev/
- **Schema Validation**: https://zod.dev/?id=basic-usage

### express-validator
- **express-validator**: https://express-validator.github.io/docs/

## HTTP Clients

### Axios
- **Axios Docs**: https://axios-http.com/docs/intro
- **Requests**: https://axios-http.com/docs/req_config
- **Interceptors**: https://axios-http.com/docs/interceptors

### node-fetch
- **node-fetch**: https://github.com/node-fetch/node-fetch

## Logging

### Winston
- **Winston Docs**: https://github.com/winstonjs/winston
- **Transports**: https://github.com/winstonjs/winston#transports
- **Formats**: https://github.com/winstonjs/winston#formats

### Pino
- **Pino Docs**: https://getpino.io/#/
- **Fast Logging**: https://getpino.io/#/docs/benchmarks

### Morgan (HTTP Logging)
- **Morgan**: https://github.com/expressjs/morgan

## Process Management

### PM2
- **PM2 Docs**: https://pm2.keymetrics.io/docs/usage/quick-start/
- **Cluster Mode**: https://pm2.keymetrics.io/docs/usage/cluster-mode/
- **Monitoring**: https://pm2.keymetrics.io/docs/usage/monitoring/

### Nodemon (Development)
- **Nodemon**: https://nodemon.io/

## Environment & Configuration

### dotenv
- **dotenv**: https://github.com/motdotla/dotenv

### config
- **node-config**: https://github.com/node-config/node-config

## Task Queues & Job Processing

### Bull
- **Bull Docs**: https://github.com/OptimalBits/bull
- **Queue Options**: https://github.com/OptimalBits/bull/blob/master/REFERENCE.md#queue

### BullMQ
- **BullMQ Docs**: https://docs.bullmq.io/

## WebSockets

### Socket.io
- **Socket.io Docs**: https://socket.io/docs/v4/
- **Server API**: https://socket.io/docs/v4/server-api/
- **Client API**: https://socket.io/docs/v4/client-api/
- **Rooms**: https://socket.io/docs/v4/rooms/

### ws (WebSocket Library)
- **ws**: https://github.com/websockets/ws

## API Documentation

### Swagger/OpenAPI
- **OpenAPI Spec**: https://swagger.io/specification/
- **swagger-jsdoc**: https://github.com/Surnet/swagger-jsdoc
- **swagger-ui-express**: https://github.com/scottie1984/swagger-ui-express

## Performance & Monitoring

### Clinic.js
- **Clinic.js**: https://clinicjs.org/

### New Relic
- **New Relic Node**: https://docs.newrelic.com/docs/apm/agents/nodejs-agent/

### Datadog
- **Datadog APM**: https://docs.datadoghq.com/tracing/setup_overview/setup/nodejs/

## Caching Strategies
- **In-Memory Cache**: Use `node-cache` or simple Map
- **Redis Cache**: Distributed caching with TTL
- **CDN Cache**: Static assets and API responses
- **Database Query Cache**: Cache frequent queries
- **Application-Level Cache**: Memoization patterns

## Error Handling Best Practices
```javascript
// Centralized error handler
app.use((err, req, res, next) => {
  logger.error(err.stack);
  
  // Don't leak error details in production
  const isDev = process.env.NODE_ENV === 'development';
  
  res.status(err.statusCode || 500).json({
    error: {
      message: isDev ? err.message : 'Internal server error',
      ...(isDev && { stack: err.stack })
    }
  });
});

// Async error wrapper
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

// Custom error classes
class AppError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}
```

## API Design Patterns

### RESTful API Best Practices
- **Use HTTP methods correctly**: GET (read), POST (create), PUT/PATCH (update), DELETE (delete)
- **Use plural nouns**: `/api/users`, `/api/videos`
- **Use nested resources**: `/api/users/:userId/videos`
- **Version your API**: `/api/v1/users`
- **Use query params for filtering**: `/api/videos?category=gaming&limit=10`
- **Return proper status codes**: 200 (OK), 201 (Created), 400 (Bad Request), 401 (Unauthorized), 404 (Not Found), 500 (Server Error)
- **Use pagination**: `?page=1&limit=20` or cursor-based
- **Include metadata**: Total count, next/prev links
- **Use HATEOAS**: Include links to related resources

### Request Validation Pattern
```javascript
const validateRequest = (schema) => {
  return (req, res, next) => {
    const { error } = schema.validate(req.body);
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }
    next();
  };
};

// Usage
router.post('/users', validateRequest(userSchema), createUser);
```

### Rate Limiting Pattern
```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP'
});

app.use('/api/', limiter);
```

## MyChannel Backend Architecture

### Service Structure
```
services/
  ads/              - Ad auction service
    src/
      routes/       - Express routes
      controllers/  - Business logic
      models/       - Data models
      services/     - External integrations
      middleware/   - Custom middleware
      utils/        - Helper functions
      config/       - Configuration
    test/           - Unit & integration tests
    package.json
    
  payment/          - Payment processing
  video/            - Video processing
  analytics/        - Analytics aggregation
  notification/     - Push notifications
```

### Common Middleware Stack
```javascript
app.use(helmet());                    // Security headers
app.use(cors(corsOptions));           // CORS
app.use(express.json());              // JSON body parser
app.use(express.urlencoded({ extended: true }));
app.use(morgan('combined', { stream: logger.stream })); // HTTP logging
app.use(compression());               // Response compression
app.use(rateLimiter);                 // Rate limiting
```

### Authentication Middleware
```javascript
const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }
  
  try {
    // Verify Firebase token
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = decodedToken;
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid token' });
  }
};
```

### Database Transaction Pattern
```javascript
const createVSMatch = async (matchData) => {
  const db = admin.firestore();
  
  return db.runTransaction(async (transaction) => {
    // 1. Read phase
    const userRef = db.collection('users').doc(matchData.userId);
    const userDoc = await transaction.get(userRef);
    
    if (!userDoc.exists) {
      throw new Error('User not found');
    }
    
    const userData = userDoc.data();
    
    // 2. Validation
    if (userData.balance < matchData.wagerAmount) {
      throw new Error('Insufficient balance');
    }
    
    // 3. Write phase
    const matchRef = db.collection('vsMatches').doc();
    const escrowRef = db.collection('escrow').doc();
    
    transaction.create(matchRef, {
      ...matchData,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    transaction.create(escrowRef, {
      matchId: matchRef.id,
      amount: matchData.wagerAmount,
      status: 'locked'
    });
    
    transaction.update(userRef, {
      balance: admin.firestore.FieldValue.increment(-matchData.wagerAmount)
    });
    
    return matchRef.id;
  });
};
```

## Performance Optimization

### Connection Pooling
```javascript
// PostgreSQL pool
const { Pool } = require('pg');
const pool = new Pool({
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

### Caching Strategy
```javascript
const redis = require('redis');
const client = redis.createClient();

const cacheMiddleware = (duration) => {
  return async (req, res, next) => {
    const key = `cache:${req.originalUrl}`;
    
    try {
      const cached = await client.get(key);
      if (cached) {
        return res.json(JSON.parse(cached));
      }
      
      // Store original res.json
      const originalJson = res.json.bind(res);
      
      // Override res.json
      res.json = (data) => {
        client.setEx(key, duration, JSON.stringify(data));
        return originalJson(data);
      };
      
      next();
    } catch (error) {
      next();
    }
  };
};
```

### Async Batch Processing
```javascript
const processBatch = async (items, batchSize = 10) => {
  const results = [];
  
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    const batchResults = await Promise.all(
      batch.map(item => processItem(item))
    );
    results.push(...batchResults);
  }
  
  return results;
};
```

## Security Checklist
- ✅ Use HTTPS only (no HTTP)
- ✅ Validate all input (never trust client data)
- ✅ Sanitize output (prevent XSS)
- ✅ Use parameterized queries (prevent SQL injection)
- ✅ Hash passwords (bcrypt, scrypt, argon2)
- ✅ Use secure session management
- ✅ Implement rate limiting
- ✅ Set security headers (Helmet)
- ✅ Enable CORS properly (don't use `*` in production)
- ✅ Keep dependencies updated
- ✅ Use environment variables for secrets
- ✅ Implement proper error handling (don't leak stack traces)
- ✅ Log security events
- ✅ Use CSP (Content Security Policy)
- ✅ Implement CSRF protection

## Deployment Best Practices
- Use environment-specific configs (dev, staging, prod)
- Implement health check endpoints (`/health`, `/ready`)
- Use graceful shutdown handling
- Implement proper logging (structured logs)
- Monitor error rates and latency
- Use load balancing for high availability
- Implement circuit breakers for external services
- Use blue-green or canary deployments
- Automate deployments (CI/CD)
- Run security audits (`npm audit`)
