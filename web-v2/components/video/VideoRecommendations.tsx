'use client';

import {useEffect, useState} from 'react';
import Link from 'next/link';
import {CheckCircle} from 'lucide-react';
import {formatViewCount, formatTimeAgo, formatDuration} from '@/lib/utils/format';
import {fetchSimilarRecommendations} from '@/lib/recommendations';
import type {Video} from '@/types';

interface VideoRecommendationsProps {
  currentVideoId: string;
}

const VideoRecommendations = ({currentVideoId}: VideoRecommendationsProps) => {
  const [result, setResult] = useState<{videoId: string; videos: Video[]} | null>(null);

  useEffect(() => {
    let cancelled = false;
    void fetchSimilarRecommendations(currentVideoId, 10)
      .then((videos) => { if (!cancelled) setResult({videoId: currentVideoId, videos}); })
      .catch(() => { if (!cancelled) setResult({videoId: currentVideoId, videos: []}); });
    return () => { cancelled = true; };
  }, [currentVideoId]);

  const isLoading = result?.videoId !== currentVideoId;
  const recommendations = isLoading ? [] : result.videos;
  if (isLoading) {
    return <div className="h-40 animate-pulse rounded-xl bg-[rgb(var(--color-surface))]" aria-label="Loading recommendations" />;
  }

  if (recommendations.length === 0) {
    return <p className="py-8 text-center text-sm text-[rgb(var(--color-text-secondary))]">No recommendations yet.</p>;
  }

  return (
    <div className="space-y-2">
      {recommendations.map((video) => (
        <Link
          key={video.id}
          href={`/watch/${video.id}`}
          className="flex gap-2 group hover:bg-[rgb(var(--color-surface))] p-2 rounded-lg transition-colors"
        >
          {/* Thumbnail */}
          <div className="relative w-42 flex-shrink-0">
            <div className="aspect-video rounded-lg overflow-hidden bg-[rgb(var(--color-surface))]">
              <img
                src={video.thumbnailURL}
                alt={video.title}
                className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200"
              />
            </div>

            {/* Duration */}
            <div className="absolute bottom-1 right-1 px-1 py-0.5 bg-black/80 text-white text-[10px] font-medium rounded">
              {formatDuration(video.duration)}
            </div>
          </div>

          {/* Info */}
          <div className="flex-1 min-w-0">
            <h4 className="text-sm font-medium text-[rgb(var(--color-text-primary))] line-clamp-2 mb-1">
              {video.title}
            </h4>

            <div className="flex items-center gap-1 mb-0.5">
              <p className="text-xs text-[rgb(var(--color-text-secondary))]">
                {video.creator.displayName}
              </p>
              {video.creator.isVerified && (
                <CheckCircle size={10} className="text-[rgb(var(--color-text-secondary))]" />
              )}
            </div>

            <p className="text-xs text-[rgb(var(--color-text-secondary))]">
              {formatViewCount(video.viewCount)} views • {formatTimeAgo(video.createdAt)}
            </p>
          </div>
        </Link>
      ))}
    </div>
  );
};

export default VideoRecommendations;

