import express from 'express';
import cors from 'cors';
import { createClient } from '@supabase/supabase-js';
import rateLimit from 'express-rate-limit';

const app = express();
const supabase = createClient(
  process.env.SUPABASE_URL || 'your-supabase-url',
  process.env.SUPABASE_SERVICE_KEY || 'your-supabase-service-key'
);

app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json({ limit: '50mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // limit each IP to 1000 requests per windowMs
  message: { error: 'Too many requests, please try again later' }
});
app.use(limiter);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'content', timestamp: new Date().toISOString() });
});

// Get home feed with personalized recommendations
app.get('/v1/feed/home', async (req, res) => {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    // Get trending/popular videos for anonymous users
    const { data: videos, error } = await supabase
      .from('videos')
      .select(`
        id, title, description, thumbnail_url, duration, view_count, 
        like_count, comment_count, created_at, published_at,
        users!inner(
          id, username, display_name, avatar_url, verified, subscriber_count
        )
      `)
      .eq('status', 'ready')
      .eq('visibility', 'public')
      .order('view_count', { ascending: false })
      .order('published_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      console.error('Database error:', error);
      return res.status(500).json({ error: 'Failed to fetch videos' });
    }

    const formattedVideos = videos?.map(video => ({
      id: video.id,
      title: video.title,
      description: video.description,
      thumbnailUrl: video.thumbnail_url,
      duration: video.duration,
      viewCount: video.view_count,
      likeCount: video.like_count,
      commentCount: video.comment_count,
      publishedAt: video.published_at,
      createdAt: video.created_at,
      creator: {
        id: video.users.id,
        username: video.users.username,
        displayName: video.users.display_name,
        avatarUrl: video.users.avatar_url,
        verified: video.users.verified,
        subscriberCount: video.users.subscriber_count
      }
    })) || [];

    res.json({
      videos: formattedVideos,
      pagination: {
        page,
        limit,
        hasMore: formattedVideos.length === limit
      }
    });
  } catch (error) {
    console.error('Home feed error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get video by ID
app.get('/v1/videos/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const { data: video, error } = await supabase
      .from('videos')
      .select(`
        id, title, description, thumbnail_url, video_url, duration, 
        file_size, status, quality_variants, captions, chapters,
        visibility, is_live, is_premium, view_count, like_count,
        dislike_count, comment_count, share_count, category, tags,
        language, age_restriction, published_at, created_at, updated_at,
        users!inner(
          id, username, display_name, avatar_url, bio, verified, 
          subscriber_count, video_count, total_views
        )
      `)
      .eq('id', id)
      .single();

    if (error || !video) {
      return res.status(404).json({ error: 'Video not found' });
    }

    // Check if video is accessible
    if (video.status !== 'ready') {
      return res.status(404).json({ error: 'Video not available' });
    }

    if (video.visibility === 'private') {
      return res.status(403).json({ error: 'Video is private' });
    }

    // Increment view count (fire and forget)
    supabase
      .from('videos')
      .update({ view_count: video.view_count + 1 })
      .eq('id', id)
      .then(() => {
        // Also log analytics event
        return supabase
          .from('video_analytics')
          .insert({
            video_id: id,
            event_type: 'view',
            value: 1,
            timestamp: new Date().toISOString(),
            user_agent: req.headers['user-agent'],
            ip_address: req.ip,
            referrer: req.headers['referer']
          });
      })
      .catch(err => console.error('View tracking error:', err));

    const formattedVideo = {
      id: video.id,
      title: video.title,
      description: video.description,
      thumbnailUrl: video.thumbnail_url,
      videoUrl: video.video_url,
      duration: video.duration,
      fileSize: video.file_size,
      status: video.status,
      qualityVariants: video.quality_variants,
      captions: video.captions,
      chapters: video.chapters,
      visibility: video.visibility,
      isLive: video.is_live,
      isPremium: video.is_premium,
      viewCount: video.view_count + 1, // Include the incremented view
      likeCount: video.like_count,
      dislikeCount: video.dislike_count,
      commentCount: video.comment_count,
      shareCount: video.share_count,
      category: video.category,
      tags: video.tags,
      language: video.language,
      ageRestriction: video.age_restriction,
      publishedAt: video.published_at,
      createdAt: video.created_at,
      updatedAt: video.updated_at,
      creator: {
        id: video.users.id,
        username: video.users.username,
        displayName: video.users.display_name,
        avatarUrl: video.users.avatar_url,
        bio: video.users.bio,
        verified: video.users.verified,
        subscriberCount: video.users.subscriber_count,
        videoCount: video.users.video_count,
        totalViews: video.users.total_views
      }
    };

    res.json({ video: formattedVideo });
  } catch (error) {
    console.error('Video fetch error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Search videos
app.get('/v1/search', async (req, res) => {
  try {
    const query = req.query.q as string;
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    if (!query || query.trim().length === 0) {
      return res.status(400).json({ error: 'Search query is required' });
    }

    // Use full-text search with PostgreSQL
    const { data: videos, error } = await supabase
      .from('videos')
      .select(`
        id, title, description, thumbnail_url, duration, view_count, 
        like_count, comment_count, created_at, published_at,
        users!inner(
          id, username, display_name, avatar_url, verified, subscriber_count
        )
      `)
      .eq('status', 'ready')
      .eq('visibility', 'public')
      .textSearch('search_vector', query)
      .order('view_count', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      console.error('Search error:', error);
      return res.status(500).json({ error: 'Search failed' });
    }

    const formattedVideos = videos?.map(video => ({
      id: video.id,
      title: video.title,
      description: video.description,
      thumbnailUrl: video.thumbnail_url,
      duration: video.duration,
      viewCount: video.view_count,
      likeCount: video.like_count,
      commentCount: video.comment_count,
      publishedAt: video.published_at,
      createdAt: video.created_at,
      creator: {
        id: video.users.id,
        username: video.users.username,
        displayName: video.users.display_name,
        avatarUrl: video.users.avatar_url,
        verified: video.users.verified,
        subscriberCount: video.users.subscriber_count
      }
    })) || [];

    res.json({
      query,
      videos: formattedVideos,
      pagination: {
        page,
        limit,
        hasMore: formattedVideos.length === limit
      }
    });
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get trending videos
app.get('/v1/feed/trending', async (req, res) => {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;
    const timeframe = req.query.timeframe as string || 'week'; // day, week, month, all

    let timeFilter = '';
    const now = new Date();
    
    switch (timeframe) {
      case 'day':
        timeFilter = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
        break;
      case 'week':
        timeFilter = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
        break;
      case 'month':
        timeFilter = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();
        break;
      default:
        timeFilter = '';
    }

    let query = supabase
      .from('videos')
      .select(`
        id, title, description, thumbnail_url, duration, view_count, 
        like_count, comment_count, created_at, published_at,
        users!inner(
          id, username, display_name, avatar_url, verified, subscriber_count
        )
      `)
      .eq('status', 'ready')
      .eq('visibility', 'public');

    if (timeFilter) {
      query = query.gte('published_at', timeFilter);
    }

    const { data: videos, error } = await query
      .order('view_count', { ascending: false })
      .order('like_count', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      console.error('Trending fetch error:', error);
      return res.status(500).json({ error: 'Failed to fetch trending videos' });
    }

    const formattedVideos = videos?.map(video => ({
      id: video.id,
      title: video.title,
      description: video.description,
      thumbnailUrl: video.thumbnail_url,
      duration: video.duration,
      viewCount: video.view_count,
      likeCount: video.like_count,
      commentCount: video.comment_count,
      publishedAt: video.published_at,
      createdAt: video.created_at,
      creator: {
        id: video.users.id,
        username: video.users.username,
        displayName: video.users.display_name,
        avatarUrl: video.users.avatar_url,
        verified: video.users.verified,
        subscriberCount: video.users.subscriber_count
      }
    })) || [];

    res.json({
      timeframe,
      videos: formattedVideos,
      pagination: {
        page,
        limit,
        hasMore: formattedVideos.length === limit
      }
    });
  } catch (error) {
    console.error('Trending error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get videos by category
app.get('/v1/feed/category/:category', async (req, res) => {
  try {
    const { category } = req.params;
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const offset = (page - 1) * limit;

    const { data: videos, error } = await supabase
      .from('videos')
      .select(`
        id, title, description, thumbnail_url, duration, view_count, 
        like_count, comment_count, created_at, published_at,
        users!inner(
          id, username, display_name, avatar_url, verified, subscriber_count
        )
      `)
      .eq('status', 'ready')
      .eq('visibility', 'public')
      .eq('category', category)
      .order('published_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      console.error('Category fetch error:', error);
      return res.status(500).json({ error: 'Failed to fetch category videos' });
    }

    const formattedVideos = videos?.map(video => ({
      id: video.id,
      title: video.title,
      description: video.description,
      thumbnailUrl: video.thumbnail_url,
      duration: video.duration,
      viewCount: video.view_count,
      likeCount: video.like_count,
      commentCount: video.comment_count,
      publishedAt: video.published_at,
      createdAt: video.created_at,
      creator: {
        id: video.users.id,
        username: video.users.username,
        displayName: video.users.display_name,
        avatarUrl: video.users.avatar_url,
        verified: video.users.verified,
        subscriberCount: video.users.subscriber_count
      }
    })) || [];

    res.json({
      category,
      videos: formattedVideos,
      pagination: {
        page,
        limit,
        hasMore: formattedVideos.length === limit
      }
    });
  } catch (error) {
    console.error('Category error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get related/recommended videos
app.get('/v1/videos/:id/related', async (req, res) => {
  try {
    const { id } = req.params;
    const limit = Math.min(parseInt(req.query.limit as string) || 12, 24);

    // Get the current video to find related content
    const { data: currentVideo } = await supabase
      .from('videos')
      .select('category, tags, users!inner(id)')
      .eq('id', id)
      .single();

    if (!currentVideo) {
      return res.status(404).json({ error: 'Video not found' });
    }

    // Find related videos by category and tags
    const { data: videos, error } = await supabase
      .from('videos')
      .select(`
        id, title, description, thumbnail_url, duration, view_count, 
        like_count, comment_count, created_at, published_at,
        users!inner(
          id, username, display_name, avatar_url, verified, subscriber_count
        )
      `)
      .eq('status', 'ready')
      .eq('visibility', 'public')
      .neq('id', id) // Exclude current video
      .or(`category.eq.${currentVideo.category},user_id.eq.${currentVideo.users.id}`)
      .order('view_count', { ascending: false })
      .limit(limit);

    if (error) {
      console.error('Related videos error:', error);
      return res.status(500).json({ error: 'Failed to fetch related videos' });
    }

    const formattedVideos = videos?.map(video => ({
      id: video.id,
      title: video.title,
      description: video.description,
      thumbnailUrl: video.thumbnail_url,
      duration: video.duration,
      viewCount: video.view_count,
      likeCount: video.like_count,
      commentCount: video.comment_count,
      publishedAt: video.published_at,
      createdAt: video.created_at,
      creator: {
        id: video.users.id,
        username: video.users.username,
        displayName: video.users.display_name,
        avatarUrl: video.users.avatar_url,
        verified: video.users.verified,
        subscriberCount: video.users.subscriber_count
      }
    })) || [];

    res.json({ videos: formattedVideos });
  } catch (error) {
    console.error('Related videos error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`📺 Content service listening on port ${port}`);
});


