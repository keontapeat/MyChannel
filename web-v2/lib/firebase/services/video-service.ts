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
  documentId,
  QueryDocumentSnapshot,
  DocumentData,
  Timestamp
} from 'firebase/firestore';
import { firestore, getAppCheckHeaders } from '../config';

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

  // Fetch a specific set of videos by ID, preserving no particular order
  // (caller re-sorts if needed). Firestore `in` queries are capped at 30 IDs,
  // so this chunks the request and merges the results.
  async fetchVideosByIds(videoIds: string[]): Promise<Video[]> {
    const ids = Array.from(new Set(videoIds)).filter(Boolean);
    if (ids.length === 0) return [];

    try {
      const chunks: string[][] = [];
      for (let i = 0; i < ids.length; i += 30) {
        chunks.push(ids.slice(i, i + 30));
      }

      const results = await Promise.all(
        chunks.map((chunk) =>
          getDocs(
            query(collection(firestore, this.videosCollection), where(documentId(), 'in', chunk))
          )
        )
      );

      return results.flatMap((snap) => snap.docs.map((d) => this.docToVideo(d)));
    } catch (error) {
      console.error('🚨 Error fetching videos by ids:', error);
      return [];
    }
  }

  // Fetch latest public videos from a set of creators (subscriptions feed).
  // Chunks creatorIds by 30 (Firestore `in` limit) and merges + re-sorts by date.
  async fetchVideosByCreators(
    creatorIds: string[],
    pageSize: number = 24
  ): Promise<Video[]> {
    const ids = Array.from(new Set(creatorIds)).filter(Boolean);
    if (ids.length === 0) return [];

    try {
      const chunks: string[][] = [];
      for (let i = 0; i < ids.length; i += 30) {
        chunks.push(ids.slice(i, i + 30));
      }

      const results = await Promise.all(
        chunks.map((chunk) =>
          getDocs(
            query(
              collection(firestore, this.videosCollection),
              where('creatorId', 'in', chunk),
              where('isPublic', '==', true),
              orderBy('createdAt', 'desc'),
              limit(pageSize)
            )
          )
        )
      );

      const videos = results.flatMap((snap) => snap.docs.map((d) => this.docToVideo(d)));
      videos.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
      return videos.slice(0, pageSize);
    } catch (error) {
      console.error('🚨 Error fetching subscription feed videos:', error);
      return [];
    }
  }

  // Search videos.
  // Prefers the real search backend (services/search — relevance-ranked
  // lexical search over title/description/tags/creator, with popularity and
  // recency boosts) when NEXT_PUBLIC_SEARCH_API_URL is configured. Falls back
  // to a basic Firestore title-prefix match if the service is unset,
  // unreachable, or errors — so search never fully breaks in dev or if the
  // backend is down.
  async searchVideos(
    searchTerm: string,
    pageSize: number = 24
  ): Promise<Video[]> {
    const term = searchTerm.trim();
    if (!term) return [];

    const apiUrl = process.env.NEXT_PUBLIC_SEARCH_API_URL;
    if (apiUrl) {
      try {
        const headers = await getAppCheckHeaders();
        const res = await fetch(
          `${apiUrl}/v1/search?q=${encodeURIComponent(term)}&limit=${pageSize}`,
          { headers, signal: AbortSignal.timeout(5000) }
        );
        if (res.ok) {
          const json = await res.json();
          const items = Array.isArray(json?.items) ? json.items : [];
          if (items.length > 0) {
            return items.map((item: any) => this.searchResultToVideo(item));
          }
          // Empty result set from the real service is still authoritative —
          // don't fall back to the weaker prefix match in that case.
          return [];
        }
      } catch (error) {
        console.warn('⚠️ Search API unreachable, falling back to Firestore prefix search:', error);
      }
    }

    return this.searchVideosFirestoreFallback(term, pageSize);
  }

  // Maps a services/search `/v1/search` result item to the local Video shape.
  private searchResultToVideo(item: Record<string, any>): Video {
    return {
      id: item.id,
      title: item.title || 'Untitled',
      description: item.description || '',
      thumbnailURL: item.thumbnailURL || '',
      videoURL: '', // Not needed for search-result cards; fetched on watch page.
      duration: item.duration || 0,
      viewCount: item.viewCount || 0,
      likeCount: item.likeCount || 0,
      commentCount: item.commentCount || 0,
      creator: {
        id: item.creator?.id || '',
        username: item.creator?.username || 'Unknown',
        displayName: item.creator?.displayName || item.creator?.username || 'Unknown',
        profileImageURL: item.creator?.profileImageURL || '',
        subscriberCount: item.creator?.subscriberCount || 0,
        isVerified: item.creator?.isVerified || false,
      },
      category: item.category || 'entertainment',
      tags: [],
      isPublic: true,
      createdAt: item.createdAt ? new Date(item.createdAt) : new Date(),
    };
  }

  // Basic Firestore title-prefix match — used only when the real search
  // service isn't configured or is unreachable.
  private async searchVideosFirestoreFallback(searchTerm: string, pageSize: number): Promise<Video[]> {
    try {
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

  // Autocomplete suggestions as the user types (services/search /v1/suggest).
  // Returns an empty list if the search backend isn't configured or errors —
  // callers should treat this as a nice-to-have, not a hard dependency.
  async fetchSuggestions(term: string, limitCount: number = 8): Promise<string[]> {
    const q = term.trim();
    const apiUrl = process.env.NEXT_PUBLIC_SEARCH_API_URL;
    if (!q || !apiUrl) return [];

    try {
      const headers = await getAppCheckHeaders();
      const res = await fetch(
        `${apiUrl}/v1/suggest?q=${encodeURIComponent(q)}&limit=${limitCount}`,
        { headers, signal: AbortSignal.timeout(3000) }
      );
      if (!res.ok) return [];
      const json = await res.json();
      return Array.isArray(json?.suggestions) ? json.suggestions : [];
    } catch {
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






