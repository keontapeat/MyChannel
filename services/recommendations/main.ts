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
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // limit each IP to 1000 requests per windowMs
  message: { error: 'Too many requests, please try again later' }
});
app.use(limiter);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'recommendations', timestamp: new Date().toISOString() });
});

// MARK: - Recommendation Algorithms

// Simple content-based filtering
async function getContentBasedRecommendations(userId: string, limit: number = 10) {
  try {
    // Get user's watch history and liked videos
    const { data: userHistory } = await supabase
      .from('watch_history')
      .select(`
        video_id,
        videos!inner(
          id, category, tags, creator:user_id
        )
      `)
      .eq('user_id', userId)
      .order('last_watched_at', { ascending: false })
      .limit(50);

    if (!userHistory || userHistory.length === 0) {
      return getPopularVideos(limit);
    }

    // Extract user preferences
    const categoryPreferences = new Map<string, number>();
    const tagPreferences = new Map<string, number>();
    const creatorPreferences = new Map<string, number>();

    userHistory.forEach(item => {
      const video = item.videos;
      
      // Category preferences
      if (video.category) {
        categoryPreferences.set(
          video.category, 
          (categoryPreferences.get(video.category) || 0) + 1
        );
      }
      
      // Tag preferences
      if (video.tags && Array.isArray(video.tags)) {
        video.tags.forEach(tag => {
          tagPreferences.set(tag, (tagPreferences.get(tag) || 0) + 1);
        });
      }
      
      // Creator preferences
      if (video.creator) {
        creatorPreferences.set(
          video.creator, 
          (creatorPreferences.get(video.creator) || 0) + 1
        );
      }
    });

    // Get top preferences
    const topCategories = Array.from(categoryPreferences.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(entry => entry[0]);

    const topTags = Array.from(tagPreferences.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(entry => entry[0]);

    const topCreators = Array.from(creatorPreferences.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(entry => entry[0]);

    // Find similar videos
    const watchedVideoIds = userHistory.map(item => item.video_id);
    
    let query = supabase
      .from('videos')
      .select(`
        id, title, description, thumbnail_url, duration, view_count, 
        like_count, comment_count, created_at, published_at, category, tags,
        users!inner(
          id, username, display_name, avatar_url, verified, subscriber_count
        )
      `)
      .eq('status', 'ready')
      .eq('visibility', 'public')
      .not('id', 'in', `(${watchedVideoIds.join(',')})`) // Exclude watched videos
      .order('view_count', { ascending: false })
      .limit(limit * 3); // Get more to filter and rank

    const { data: candidateVideos } = await query;

    if (!candidateVideos) {
      return [];
    }

    // Score videos based on user preferences
    const scoredVideos = candidateVideos.map(video => {
      let score = 0;
      
      // Category match
      if (video.category && topCategories.includes(video.category)) {
        score += 10;
      }
      
      // Tag matches
      if (video.tags && Array.isArray(video.tags)) {
        const tagMatches = video.tags.filter(tag => topTags.includes(tag)).length;
        score += tagMatches * 2;
      }
      
      // Creator match
      if (topCreators.includes(video.users.id)) {
        score += 15;
      }
      
      // Popularity boost
      score += Math.log10(video.view_count + 1);
      
      // Recency boost
      const publishedAt = new Date(video.published_at || video.created_at);
      const daysSincePublished = (Date.now() - publishedAt.getTime()) / (1000 * 60 * 60 * 24);
      if (daysSincePublished < 7) {
        score += 5;
      } else if (daysSincePublished < 30) {
        score += 2;
      }

      return { ...video, score };
    });

    // Sort by score and return top results
    return scoredVideos
      .sort((a, b) => b.score - a.score)
      .slice(0, limit)
      .map(({ score, ...video }) => video);

  } catch (error) {
    console.error('Content-based recommendation error:', error);
    return getPopularVideos(limit);
  }
}

// Collaborative filtering (simplified user-based)
async function getCollaborativeRecommendations(userId: string, limit: number = 10) {
  try {
    // Get users with similar viewing patterns
    const { data: userHistory } = await supabase
      .from('watch_history')
      .select('video_id')
      .eq('user_id', userId)
      .limit(100);

    if (!userHistory || userHistory.length === 0) {
      return getPopularVideos(limit);
    }

    const userVideoIds = userHistory.map(item => item.video_id);

    // Find users who watched similar videos
    const { data: similarUsers } = await supabase
      .from('watch_history')
      .select('user_id, video_id')
      .in('video_id', userVideoIds)
      .neq('user_id', userId);

    if (!similarUsers || similarUsers.length === 0) {
      return getPopularVideos(limit);
    }

    // Calculate user similarity scores
    const userSimilarity = new Map<string, number>();
    
    similarUsers.forEach(item => {
      const similarUserId = item.user_id;
      userSimilarity.set(
        similarUserId, 
        (userSimilarity.get(similarUserId) || 0) + 1
      );
    });

    // Get top similar users
    const topSimilarUsers = Array.from(userSimilarity.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 20)
      .map(entry => entry[0]);

    // Get videos watched by similar users that current user hasn't watched
    const { data: recommendations } = await supabase
      .from('watch_history')
      .select(`
        video_id,
        videos!inner(
          id, title, description, thumbnail_url, duration, view_count, 
          like_count, comment_count, created_at, published_at,
          users!inner(
            id, username, display_name, avatar_url, verified, subscriber_count
          )
        )
      `)
      .in('user_id', topSimilarUsers)
      .not('video_id', 'in', `(${userVideoIds.join(',')})`)
      .eq('videos.status', 'ready')
      .eq('videos.visibility', 'public')
      .order('videos.view_count', { ascending: false })
      .limit(limit);

    return recommendations?.map(item => item.videos) || [];

  } catch (error) {
    console.error('Collaborative filtering error:', error);
    return getPopularVideos(limit);
  }
}

// Get popular videos as fallback
async function getPopularVideos(limit: number = 10) {
  const { data: videos } = await supabase
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
    .limit(limit);

  return videos || [];
}

// Get trending videos with time decay
async function getTrendingVideos(limit: number = 10, timeframe: string = 'week') {
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

  const { data: videos } = await query
    .order('view_count', { ascending: false })
    .order('like_count', { ascending: false })
    .limit(limit);

  return videos || [];
}

// MARK: - API Endpoints

// Get personalized recommendations for authenticated user
app.get('/v1/recommendations/personal', async (req, res) => {
  try {
    const userId = req.headers['x-user-id'] as string; // From auth middleware
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const algorithm = req.query.algorithm as string || 'hybrid';

    if (!userId) {
      // Return popular videos for anonymous users
      const videos = await getPopularVideos(limit);
      return res.json({ videos, algorithm: 'popular' });
    }

    let recommendations = [];

    switch (algorithm) {
      case 'content':
        recommendations = await getContentBasedRecommendations(userId, limit);
        break;
      case 'collaborative':
        recommendations = await getCollaborativeRecommendations(userId, limit);
        break;
      case 'hybrid':
      default:
        // Mix of content-based and collaborative
        const contentRecs = await getContentBasedRecommendations(userId, Math.ceil(limit * 0.7));
        const collabRecs = await getCollaborativeRecommendations(userId, Math.ceil(limit * 0.3));
        
        // Combine and deduplicate
        const combined = [...contentRecs, ...collabRecs];
        const uniqueVideos = combined.filter((video, index, self) => 
          index === self.findIndex(v => v.id === video.id)
        );
        
        recommendations = uniqueVideos.slice(0, limit);
        break;
    }

    // Format response
    const formattedVideos = recommendations.map(video => ({
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
    }));

    res.json({
      videos: formattedVideos,
      algorithm,
      userId: userId || 'anonymous'
    });

  } catch (error) {
    console.error('Personal recommendations error:', error);
    res.status(500).json({ error: 'Failed to get recommendations' });
  }
});

// Get trending videos
app.get('/v1/recommendations/trending', async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const timeframe = req.query.timeframe as string || 'week';

    const videos = await getTrendingVideos(limit, timeframe);

    const formattedVideos = videos.map(video => ({
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
    }));

    res.json({
      videos: formattedVideos,
      timeframe,
      algorithm: 'trending'
    });

  } catch (error) {
    console.error('Trending recommendations error:', error);
    res.status(500).json({ error: 'Failed to get trending videos' });
  }
});

// Get similar videos for a specific video
app.get('/v1/recommendations/similar/:videoId', async (req, res) => {
  try {
    const { videoId } = req.params;
    const limit = Math.min(parseInt(req.query.limit as string) || 12, 24);

    // Get the current video details
    const { data: currentVideo } = await supabase
      .from('videos')
      .select('category, tags, user_id')
      .eq('id', videoId)
      .single();

    if (!currentVideo) {
      return res.status(404).json({ error: 'Video not found' });
    }

    // Find similar videos
    const { data: similarVideos } = await supabase
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
      .neq('id', videoId)
      .or(`category.eq.${currentVideo.category},user_id.eq.${currentVideo.user_id}`)
      .order('view_count', { ascending: false })
      .limit(limit);

    const formattedVideos = similarVideos?.map(video => ({
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
      baseVideoId: videoId,
      algorithm: 'similar'
    });

  } catch (error) {
    console.error('Similar videos error:', error);
    res.status(500).json({ error: 'Failed to get similar videos' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`🤖 Recommendations service listening on port ${port}`);
});











