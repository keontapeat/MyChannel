// 🔥 USE VIDEOS HOOK - React hook for fetching videos from Firebase
// Provides loading states, pagination, and caching

import { useState, useEffect, useCallback, useRef } from 'react';
import { QueryDocumentSnapshot, DocumentData } from 'firebase/firestore';
import { 
  videoService, 
  Video, 
  VideoCategory, 
  PaginatedResult 
} from '@/lib/firebase/services/video-service';

// Video list state
interface UseVideosState {
  videos: Video[];
  isLoading: boolean;
  isLoadingMore: boolean;
  error: string | null;
  hasMore: boolean;
}

// Video list options
interface UseVideosOptions {
  category?: VideoCategory | 'all';
  pageSize?: number;
  autoFetch?: boolean;
}

// Return type for useVideos hook
interface UseVideosReturn extends UseVideosState {
  loadMore: () => Promise<void>;
  refresh: () => Promise<void>;
  setCategory: (category: VideoCategory | 'all') => void;
}

// Main hook for fetching video list
export function useVideos(options: UseVideosOptions = {}): UseVideosReturn {
  const {
    category = 'all',
    pageSize = 24,
    autoFetch = true,
  } = options;

  const [state, setState] = useState<UseVideosState>({
    videos: [],
    isLoading: true,
    isLoadingMore: false,
    error: null,
    hasMore: true,
  });

  const [currentCategory, setCurrentCategory] = useState<VideoCategory | 'all'>(category);
  const lastDocRef = useRef<QueryDocumentSnapshot<DocumentData> | null>(null);
  const isMountedRef = useRef(true);

  // Fetch initial videos
  const fetchVideos = useCallback(async () => {
    if (!isMountedRef.current) return;

    setState(prev => ({ ...prev, isLoading: true, error: null }));
    lastDocRef.current = null;

    try {
      let result: PaginatedResult<Video>;

      if (currentCategory === 'all') {
        result = await videoService.fetchVideosPaginated(pageSize);
      } else {
        result = await videoService.fetchVideosPaginated(pageSize, undefined, currentCategory);
      }

      if (!isMountedRef.current) return;

      setState({
        videos: result.items,
        isLoading: false,
        isLoadingMore: false,
        error: null,
        hasMore: result.hasMore,
      });

      lastDocRef.current = result.lastDoc;
    } catch (error) {
      if (!isMountedRef.current) return;

      setState(prev => ({
        ...prev,
        isLoading: false,
        error: error instanceof Error ? error.message : 'Failed to fetch videos',
      }));
    }
  }, [currentCategory, pageSize]);

  // Load more videos (pagination)
  const loadMore = useCallback(async () => {
    if (!isMountedRef.current || state.isLoadingMore || !state.hasMore) return;

    setState(prev => ({ ...prev, isLoadingMore: true }));

    try {
      let result: PaginatedResult<Video>;

      if (currentCategory === 'all') {
        result = await videoService.fetchVideosPaginated(
          pageSize, 
          lastDocRef.current || undefined
        );
      } else {
        result = await videoService.fetchVideosPaginated(
          pageSize, 
          lastDocRef.current || undefined,
          currentCategory
        );
      }

      if (!isMountedRef.current) return;

      setState(prev => ({
        ...prev,
        videos: [...prev.videos, ...result.items],
        isLoadingMore: false,
        hasMore: result.hasMore,
      }));

      lastDocRef.current = result.lastDoc;
    } catch (error) {
      if (!isMountedRef.current) return;

      setState(prev => ({
        ...prev,
        isLoadingMore: false,
        error: error instanceof Error ? error.message : 'Failed to load more videos',
      }));
    }
  }, [currentCategory, pageSize, state.isLoadingMore, state.hasMore]);

  // Refresh videos
  const refresh = useCallback(async () => {
    await fetchVideos();
  }, [fetchVideos]);

  // Set category and refetch
  const setCategory = useCallback((newCategory: VideoCategory | 'all') => {
    setCurrentCategory(newCategory);
  }, []);

  // Initial fetch
  useEffect(() => {
    isMountedRef.current = true;

    if (autoFetch) {
      fetchVideos();
    }

    return () => {
      isMountedRef.current = false;
    };
  }, [autoFetch, fetchVideos]);

  // Refetch when category changes
  useEffect(() => {
    if (autoFetch) {
      fetchVideos();
    }
  }, [currentCategory]);

  return {
    ...state,
    loadMore,
    refresh,
    setCategory,
  };
}

// Hook for fetching a single video
interface UseSingleVideoReturn {
  video: Video | null;
  isLoading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}

export function useVideo(videoId: string | null): UseSingleVideoReturn {
  const [video, setVideo] = useState<Video | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchVideo = useCallback(async () => {
    if (!videoId) {
      setVideo(null);
      setIsLoading(false);
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      const result = await videoService.fetchVideo(videoId);
      setVideo(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch video');
    } finally {
      setIsLoading(false);
    }
  }, [videoId]);

  useEffect(() => {
    fetchVideo();
  }, [fetchVideo]);

  return {
    video,
    isLoading,
    error,
    refetch: fetchVideo,
  };
}

// Hook for fetching recommended videos
interface UseRecommendedVideosReturn {
  videos: Video[];
  isLoading: boolean;
  error: string | null;
}

export function useRecommendedVideos(
  currentVideoId: string | null,
  category: VideoCategory = 'entertainment',
  count: number = 12
): UseRecommendedVideosReturn {
  const [videos, setVideos] = useState<Video[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!currentVideoId) {
      setVideos([]);
      setIsLoading(false);
      return;
    }

    const fetchRecommended = async () => {
      setIsLoading(true);
      setError(null);

      try {
        const result = await videoService.fetchRecommendedVideos(
          currentVideoId,
          category,
          count
        );
        setVideos(result);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to fetch recommendations');
      } finally {
        setIsLoading(false);
      }
    };

    fetchRecommended();
  }, [currentVideoId, category, count]);

  return { videos, isLoading, error };
}

// Hook for searching videos
interface UseSearchVideosReturn {
  videos: Video[];
  isLoading: boolean;
  error: string | null;
  search: (term: string) => Promise<void>;
}

export function useSearchVideos(): UseSearchVideosReturn {
  const [videos, setVideos] = useState<Video[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const search = useCallback(async (term: string) => {
    if (!term.trim()) {
      setVideos([]);
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      const result = await videoService.searchVideos(term);
      setVideos(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Search failed');
    } finally {
      setIsLoading(false);
    }
  }, []);

  return { videos, isLoading, error, search };
}

// Hook for trending videos
export function useTrendingVideos(count: number = 24) {
  const [videos, setVideos] = useState<Video[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchTrending = async () => {
      setIsLoading(true);
      setError(null);

      try {
        const result = await videoService.fetchTrendingVideos(count);
        setVideos(result);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to fetch trending');
      } finally {
        setIsLoading(false);
      }
    };

    fetchTrending();
  }, [count]);

  return { videos, isLoading, error };
}






