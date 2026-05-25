import express from 'express';
import cors from 'cors';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcrypt';
import { createClient } from '@supabase/supabase-js';
import rateLimit from 'express-rate-limit';

const app = express();
if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_KEY || !process.env.JWT_SECRET) {
  throw new Error('Missing SUPABASE_URL, SUPABASE_SERVICE_KEY or JWT_SECRET');
}
const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
);

const JWT_SECRET = process.env.JWT_SECRET!;
const SALT_ROUNDS = 12;

app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json({ limit: '10mb' }));

// Rate limiting
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // limit each IP to 10 requests per windowMs
  message: { error: 'Too many authentication attempts, please try again later' }
});

const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { error: 'Too many requests, please try again later' }
});

app.use('/v1/auth/register', authLimiter);
app.use('/v1/auth/login', authLimiter);
app.use(generalLimiter);

// Middleware to verify JWT token
const authenticateToken = async (req: any, res: any, next: any) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid or expired token' });
  }
};

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'auth', timestamp: new Date().toISOString() });
});

// Register new user
app.post('/v1/auth/register', async (req, res) => {
  try {
    const { email, username, password, displayName } = req.body;

    // Validation
    if (!email || !username || !password) {
      return res.status(400).json({ error: 'Email, username, and password are required' });
    }

    if (password.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters long' });
    }

    // Check if user already exists
    const { data: existingUser } = await supabase
      .from('users')
      .select('id')
      .or(`email.eq.${email},username.eq.${username}`)
      .single();

    if (existingUser) {
      return res.status(409).json({ error: 'User with this email or username already exists' });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);

    // Create user
    const { data: user, error } = await supabase
      .from('users')
      .insert({
        email,
        username,
        display_name: displayName || username,
        password_hash: hashedPassword,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .select('id, email, username, display_name, avatar_url, verified, premium_tier, created_at')
      .single();

    if (error) {
      console.error('Database error:', error);
      return res.status(500).json({ error: 'Failed to create user' });
    }

    // Generate JWT token
    const token = jwt.sign(
      { 
        userId: user.id, 
        email: user.email, 
        username: user.username,
        premiumTier: user.premium_tier 
      },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    // Create user preferences
    await supabase
      .from('user_preferences')
      .insert({
        user_id: user.id,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      });

    res.status(201).json({
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        displayName: user.display_name,
        avatarUrl: user.avatar_url,
        verified: user.verified,
        premiumTier: user.premium_tier,
        createdAt: user.created_at
      },
      token,
      expiresIn: '7d'
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Login user
app.post('/v1/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    // Find user by email or username
    const { data: user } = await supabase
      .from('users')
      .select('*')
      .or(`email.eq.${email},username.eq.${email}`)
      .single();

    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Verify password
    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Update last active timestamp
    await supabase
      .from('users')
      .update({ last_active_at: new Date().toISOString() })
      .eq('id', user.id);

    // Generate JWT token
    const token = jwt.sign(
      { 
        userId: user.id, 
        email: user.email, 
        username: user.username,
        premiumTier: user.premium_tier 
      },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        displayName: user.display_name,
        avatarUrl: user.avatar_url,
        verified: user.verified,
        premiumTier: user.premium_tier,
        subscriberCount: user.subscriber_count,
        videoCount: user.video_count,
        totalViews: user.total_views,
        createdAt: user.created_at
      },
      token,
      expiresIn: '7d'
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Refresh token
app.post('/v1/auth/refresh', authenticateToken, async (req: any, res) => {
  try {
    const userId = req.user.userId;

    // Get latest user data
    const { data: user } = await supabase
      .from('users')
      .select('id, email, username, display_name, avatar_url, verified, premium_tier, subscriber_count, video_count, total_views, created_at')
      .eq('id', userId)
      .single();

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Generate new token
    const token = jwt.sign(
      { 
        userId: user.id, 
        email: user.email, 
        username: user.username,
        premiumTier: user.premium_tier 
      },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        displayName: user.display_name,
        avatarUrl: user.avatar_url,
        verified: user.verified,
        premiumTier: user.premium_tier,
        subscriberCount: user.subscriber_count,
        videoCount: user.video_count,
        totalViews: user.total_views,
        createdAt: user.created_at
      },
      token,
      expiresIn: '7d'
    });
  } catch (error) {
    console.error('Token refresh error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user profile
app.get('/v1/auth/profile', authenticateToken, async (req: any, res) => {
  try {
    const userId = req.user.userId;

    const { data: user } = await supabase
      .from('users')
      .select(`
        id, email, username, display_name, avatar_url, bio, website_url, 
        location, verified, premium_tier, subscriber_count, video_count, 
        total_views, profile_visibility, allow_comments, allow_messages,
        preferred_language, timezone, email_notifications, push_notifications,
        created_at, updated_at, last_active_at
      `)
      .eq('id', userId)
      .single();

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user });
  } catch (error) {
    console.error('Profile fetch error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update user profile
app.put('/v1/auth/profile', authenticateToken, async (req: any, res) => {
  try {
    const userId = req.user.userId;
    const updates = req.body;

    // Remove sensitive fields that shouldn't be updated via this endpoint
    delete updates.id;
    delete updates.email;
    delete updates.password_hash;
    delete updates.created_at;
    delete updates.subscriber_count;
    delete updates.video_count;
    delete updates.total_views;

    // Add updated timestamp
    updates.updated_at = new Date().toISOString();

    const { data: user, error } = await supabase
      .from('users')
      .update(updates)
      .eq('id', userId)
      .select(`
        id, email, username, display_name, avatar_url, bio, website_url, 
        location, verified, premium_tier, subscriber_count, video_count, 
        total_views, profile_visibility, allow_comments, allow_messages,
        preferred_language, timezone, email_notifications, push_notifications,
        created_at, updated_at, last_active_at
      `)
      .single();

    if (error) {
      console.error('Profile update error:', error);
      return res.status(500).json({ error: 'Failed to update profile' });
    }

    res.json({ user });
  } catch (error) {
    console.error('Profile update error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Change password
app.post('/v1/auth/change-password', authenticateToken, async (req: any, res) => {
  try {
    const userId = req.user.userId;
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Current password and new password are required' });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({ error: 'New password must be at least 8 characters long' });
    }

    // Get current user
    const { data: user } = await supabase
      .from('users')
      .select('password_hash')
      .eq('id', userId)
      .single();

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Verify current password
    const validPassword = await bcrypt.compare(currentPassword, user.password_hash);
    if (!validPassword) {
      return res.status(401).json({ error: 'Current password is incorrect' });
    }

    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, SALT_ROUNDS);

    // Update password
    const { error } = await supabase
      .from('users')
      .update({ 
        password_hash: hashedPassword,
        updated_at: new Date().toISOString()
      })
      .eq('id', userId);

    if (error) {
      console.error('Password update error:', error);
      return res.status(500).json({ error: 'Failed to update password' });
    }

    res.json({ message: 'Password updated successfully' });
  } catch (error) {
    console.error('Password change error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Logout (client-side token invalidation)
app.post('/v1/auth/logout', authenticateToken, async (req: any, res) => {
  try {
    // Update last active timestamp
    await supabase
      .from('users')
      .update({ last_active_at: new Date().toISOString() })
      .eq('id', req.user.userId);

    res.json({ message: 'Logged out successfully' });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user by username (public profile)
app.get('/v1/users/:username', async (req, res) => {
  try {
    const { username } = req.params;

    const { data: user } = await supabase
      .from('users')
      .select(`
        id, username, display_name, avatar_url, bio, website_url, 
        location, verified, subscriber_count, video_count, total_views,
        created_at
      `)
      .eq('username', username)
      .eq('profile_visibility', 'public')
      .single();

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user });
  } catch (error) {
    console.error('User fetch error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Middleware export for other services
export { authenticateToken };

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`🔐 Auth service listening on port ${port}`);
});

