// 🔥 VIDEO SERVICE - Fetches real videos from Firebase
// Replaces mock data with actual Firestore data

import { 
  collection, 
  query, 
  where, 
  orderBy, 
  limit, 
  startAfter,
  getDocs,
  getDoc,
  doc,
  QueryDocumentSnapshot,
  DocumentData,
  Timestamp
} from 'firebase/firestore';
import { firestore } from '../config';

// Video interface matching iOS app
export interface Video {
  id: string;
  title: string;
  description: string;
  thumbnailURL: string;
  videoURL: string;
  duration: number;
  viewCount: number;
  likeCount: number;
  commentCount?: number;
  creator: Creator;
  category: VideoCategory;
  tags: string[];
  isPublic: boolean;
  createdAt: Date;
  updatedAt?: Date;
}

export interface Creator {
  id: string;
  username: string;
  displayName: string;
  email?: string;
  profileImageURL?: string;
  bio?: string;
  subscriberCount?: number;
  isVerified?: boolean;
}

export type VideoCategory = 
  | 'entertainment'
  | 'music'
  | 'gaming'
  | 'education'
  | 'sports'
  | 'news'
  | 'technology'
  | 'lifestyle'
  | 'comedy'
  | 'other';

// Pagination result
export interface PaginatedResult<T> {
  items: T[];
  lastDoc: QueryDocumentSnapshot<DocumentData> | null;
  hasMore: boolean;
}

class VideoService {
  private static instance: VideoService;
  private videosCollection = 'videos';
  private usersCollection = 'users';

  private constructor() {}

  static getInstance(): VideoService {
    if (!VideoService.instance) {
      VideoService.instance = new VideoService();
    }
    return VideoService.instance;
  }

  // Convert Firestore document to Video
  private docToVideo(doc: QueryDocumentSnapshot<DocumentData>): Video {
    const data = doc.data();
    return {
      id: doc.id,
      title: data.title || 'Untitled',
      description: data.description || '',
      thumbnailURL: data.thumbnailURL || data.thumbnail || '',
      videoURL: data.videoURL || data.url || '',
      duration: data.duration || 0,
      viewCount: data.viewCount || data.views || 0,
      likeCount: data.likeCount || data.likes || 0,
      commentCount: data.commentCount || 0,
      creator: {
        id: data.creatorId || data.creator?.id || '',
        username: data.creator?.username || 'Unknown',
        displayName: data.creator?.displayName || data.creator?.username || 'Unknown',
        profileImageURL: data.creator?.profileImageURL || data.creator?.avatar || '',
        subscriberCount: data.creator?.subscriberCount || 0,
        isVerified: data.creator?.isVerified || false,
      },
      category: data.category || 'entertainment',
      tags: data.tags || [],
      isPublic: data.isPublic !== false,
      createdAt: data.createdAt instanceof Timestamp 
        ? data.createdAt.toDate() 
        : new Date(data.createdAt || Date.now()),
      updatedAt: data.updatedAt instanceof Timestamp 
        ? data.updatedAt.toDate() 
        : undefined,
    };
  }

  // Fetch trending videos (most views in last 7 days)
  async fetchTrendingVideos(pageSize: number = 24): Promise<Video[]> {
    try {
      const q = query(
        collection(firestore, this.videosCollection),
        where('isPublic', '==', true),
        orderBy('viewCount', 'desc'),
        limit(pageSize)
      );

      const snapshot = await getDocs(q);
      return snapshot.docs.map(doc => this.docToVideo(doc));
    } catch (error) {
      console.error('🚨 Error fetching trending videos:', error);
      return [];
    }
  }

  // Fetch latest videos
  async fetchLatestVideos(pageSize: number = 24): Promise<Video[]> {
    try {
      const q = query(
        collection(firestore, this.videosCollection),
        where('isPublic', '==', true),
        orderBy('createdAt', 'desc'),
        limit(pageSize)
      );

      const snapshot = await getDocs(q);
      return snapshot.docs.map(doc => this.docToVideo(doc));
    } catch (error) {
      console.error('🚨 Error fetching latest videos:', error);
      return [];
    }
  }

  // Fetch videos by category
  async fetchVideosByCategory(
    category: VideoCategory, 
    pageSize: number = 24
  ): Promise<Video[]> {
    try {
      const q = query(
        collection(firestore, this.videosCollection),
        where('isPublic', '==', true),
        where('category', '==', category),
        orderBy('createdAt', 'desc'),
        limit(pageSize)
      );

      const snapshot = await getDocs(q);
      return snapshot.docs.map(doc => this.docToVideo(doc));
    } catch (error) {
      console.error(`🚨 Error fetching ${category} videos:`, error);
      return [];
    }
  }

  // Fetch videos with pagination
  async fetchVideosPaginated(
    pageSize: number = 24,
    lastDocument?: QueryDocumentSnapshot<DocumentData>,
    category?: VideoCategory
  ): Promise<PaginatedResult<Video>> {
    try {
      let q = query(
        collection(firestore, this.videosCollection),
        where('isPublic', '==', true),
        orderBy('createdAt', 'desc'),
        limit(pageSize)
      );

      if (category && category !== 'other') {
        q = query(
          collection(firestore, this.videosCollection),
          where('isPublic', '==', true),
          where('category', '==', category),
          orderBy('createdAt', 'desc'),
          limit(pageSize)
        );
      }

      if (lastDocument) {
        q = query(q, startAfter(lastDocument));
      }

      const snapshot = await getDocs(q);
      const videos = snapshot.docs.map(doc => this.docToVideo(doc));
      const lastDoc = snapshot.docs[snapshot.docs.length - 1] || null;

      return {
        items: videos,
        lastDoc,
        hasMore: snapshot.docs.length === pageSize,
      };
    } catch (error) {
      console.error('🚨 Error fetching paginated videos:', error);
      return { items: [], lastDoc: null, hasMore: false };
    }
  }

  // Fetch single video by ID
  async fetchVideo(videoId: string): Promise<Video | null> {
    try {
      const docRef = doc(firestore, this.videosCollection, videoId);
      const docSnap = await getDoc(docRef);

      if (!docSnap.exists()) {
        return null;
      }

      return this.docToVideo(docSnap as QueryDocumentSnapshot<DocumentData>);
    } catch (error) {
      console.error('🚨 Error fetching video:', error);
      return null;
    }
  }

  // Fetch videos by creator
  async fetchVideosByCreator(
    creatorId: string, 
    pageSize: number = 24
  ): Promise<Video[]> {
    try {
      const q = query(
        collection(firestore, this.videosCollection),
        where('creatorId', '==', creatorId),
        where('isPublic', '==', true),
        orderBy('createdAt', 'desc'),
        limit(pageSize)
      );

      const snapshot = await getDocs(q);
      return snapshot.docs.map(doc => this.docToVideo(doc));
    } catch (error) {
      console.error('🚨 Error fetching creator videos:', error);
      return [];
    }
  }

  // Search videos
  async searchVideos(
    searchTerm: string, 
    pageSize: number = 24
  ): Promise<Video[]> {
    try {
      // Note: Firestore doesn't support full-text search natively
      // For production, use Algolia, Typesense, or Cloud Functions
      // This is a basic prefix search on title
      const q = query(
        collection(firestore, this.videosCollection),
        where('isPublic', '==', true),
        where('title', '>=', searchTerm),
        where('title', '<=', searchTerm + '\uf8ff'),
        limit(pageSize)
      );

      const snapshot = await getDocs(q);
      return snapshot.docs.map(doc => this.docToVideo(doc));
    } catch (error) {
      console.error('🚨 Error searching videos:', error);
      return [];
    }
  }

  // Fetch recommended videos (based on category of current video)
  async fetchRecommendedVideos(
    currentVideoId: string,
    category: VideoCategory,
    pageSize: number = 12
  ): Promise<Video[]> {
    try {
      const q = query(
        collection(firestore, this.videosCollection),
        where('isPublic', '==', true),
        where('category', '==', category),
        orderBy('viewCount', 'desc'),
        limit(pageSize + 1) // Fetch one extra to exclude current
      );

      const snapshot = await getDocs(q);
      return snapshot.docs
        .map(doc => this.docToVideo(doc))
        .filter(video => video.id !== currentVideoId)
        .slice(0, pageSize);
    } catch (error) {
      console.error('🚨 Error fetching recommended videos:', error);
      return [];
    }
  }

  // Format view count (e.g., 1.5M, 500K)
  formatViewCount(count: number): string {
    if (count >= 1000000) {
      return (count / 1000000).toFixed(1).replace(/\.0$/, '') + 'M';
    }
    if (count >= 1000) {
      return (count / 1000).toFixed(1).replace(/\.0$/, '') + 'K';
    }
    return count.toString();
  }

  // Format duration (e.g., 5:30, 1:23:45)
  formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = Math.floor(seconds % 60);

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${minutes}:${secs.toString().padStart(2, '0')}`;
  }

  // Format time ago (e.g., "2 days ago")
  formatTimeAgo(date: Date): string {
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffSeconds = Math.floor(diffMs / 1000);
    const diffMinutes = Math.floor(diffSeconds / 60);
    const diffHours = Math.floor(diffMinutes / 60);
    const diffDays = Math.floor(diffHours / 24);
    const diffWeeks = Math.floor(diffDays / 7);
    const diffMonths = Math.floor(diffDays / 30);
    const diffYears = Math.floor(diffDays / 365);

    if (diffYears > 0) return `${diffYears} year${diffYears > 1 ? 's' : ''} ago`;
    if (diffMonths > 0) return `${diffMonths} month${diffMonths > 1 ? 's' : ''} ago`;
    if (diffWeeks > 0) return `${diffWeeks} week${diffWeeks > 1 ? 's' : ''} ago`;
    if (diffDays > 0) return `${diffDays} day${diffDays > 1 ? 's' : ''} ago`;
    if (diffHours > 0) return `${diffHours} hour${diffHours > 1 ? 's' : ''} ago`;
    if (diffMinutes > 0) return `${diffMinutes} minute${diffMinutes > 1 ? 's' : ''} ago`;
    return 'Just now';
  }
}

// Export singleton instance
export const videoService = VideoService.getInstance();

