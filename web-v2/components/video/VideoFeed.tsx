'use client';

// 🔥 Reusable YouTube-style video feed grid.
// Pulls real videos from Firestore via useVideos / videoService and renders
// VideoCard with infinite-scroll "Load more". Falls back gracefully to an
// empty state when no videos are available (e.g. fresh project).

import { useEffect, useRef, useCallback } from 'react';
import VideoCard from './VideoCard';
import { useVideos } from '@/hooks/useVideos';
import { videoService, type Video, type VideoCategory } from '@/lib/firebase/services/video-service';
import { Loader2 } from 'lucide-react';

interface VideoFeedProps {
  category?: VideoCategory | 'all';
  pageSize?: number;
  /** Optional empty-state message override. */
  emptyMessage?: string;
}

function toCardVideo(video: Video, index: number) {
  return {
    id: video.id,
    title: video.title,
    thumbnailURL: video.thumbnailURL,
    duration: videoService.formatDuration(video.duration),
    channel: video.creator?.displayName ?? 'Unknown',
    channelIcon: video.creator?.profileImageURL ?? '',
    views: videoService.formatViewCount(video.viewCount),
    timeAgo: videoService.formatTimeAgo(video.createdAt),
    isVerified: video.creator?.isVerified ?? false,
    index,
  };
}

export default function VideoFeed({
  category = 'all',
  pageSize = 24,
  emptyMessage = 'No videos yet. Check back soon.',
}: VideoFeedProps) {
  const { videos, isLoading, isLoadingMore, error, hasMore, loadMore } = useVideos({
    category,
    pageSize,
  });

  const sentinelRef = useRef<HTMLDivElement | null>(null);

  // Infinite scroll via IntersectionObserver.
  const handleObserve = useCallback(
    (entries: IntersectionObserverEntry[]) => {
      if (entries[0]?.isIntersecting && hasMore && !isLoadingMore) {
        loadMore();
      }
    },
    [hasMore, isLoadingMore, loadMore]
  );

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node) return;
    const observer = new IntersectionObserver(handleObserve, { rootMargin: '600px' });
    observer.observe(node);
    return () => observer.disconnect();
  }, [handleObserve]);

  if (isLoading) {
    return (
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-3 2xl:grid-cols-4 gap-x-4 gap-y-9">
        {Array.from({ length: 12 }).map((_, i) => (
          <div key={i} className="animate-pulse">
            <div className="aspect-video bg-[rgb(var(--color-surface))] rounded-xl mb-3" />
            <div className="flex gap-3">
              <div className="w-9 h-9 rounded-full bg-[rgb(var(--color-surface))]" />
              <div className="flex-1 space-y-2">
                <div className="h-4 bg-[rgb(var(--color-surface))] rounded w-3/4" />
                <div className="h-3 bg-[rgb(var(--color-surface))] rounded w-1/2" />
              </div>
            </div>
          </div>
        ))}
      </div>
    );
  }

  if (error) {
    return (
      <div className="py-16 text-center text-[rgb(var(--color-text-secondary))]">
        <p className="text-sm">Couldn&apos;t load videos right now.</p>
      </div>
    );
  }

  if (videos.length === 0) {
    return (
      <div className="py-16 text-center text-[rgb(var(--color-text-secondary))]">
        <p className="text-sm">{emptyMessage}</p>
      </div>
    );
  }

  return (
    <>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-3 2xl:grid-cols-4 gap-x-4 gap-y-9">
        {videos.map((video, i) => {
          const card = toCardVideo(video, i);
          return <VideoCard key={video.id} video={card} index={i} />;
        })}
      </div>

      {/* Infinite scroll sentinel + loader */}
      <div ref={sentinelRef} className="h-10" />
      {isLoadingMore && (
        <div className="flex justify-center py-6">
          <Loader2 className="animate-spin text-[rgb(var(--color-text-secondary))]" size={24} />
        </div>
      )}
    </>
  );
}
