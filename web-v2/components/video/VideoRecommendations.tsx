'use client';

import Link from 'next/link';
import { CheckCircle } from 'lucide-react';
import { formatViewCount, formatTimeAgo, formatDuration } from '@/lib/utils/format';
import type { Video } from '@/types';

interface VideoRecommendationsProps {
  currentVideoId: string;
}

const VideoRecommendations = ({ currentVideoId }: VideoRecommendationsProps) => {
  // Mock data - replace with actual recommendations
  const recommendations: Video[] = Array.from({ length: 10 }, (_, i) => ({
    id: `rec-${i + 1}`,
    title: `Recommended Video ${i + 1} - Interesting Content`,
    description: '',
    videoURL: '',
    thumbnailURL: `https://picsum.photos/seed/rec${i}/168/94`,
    duration: Math.floor(Math.random() * 1800) + 60,
    viewCount: Math.floor(Math.random() * 500000),
    likeCount: 0,
    dislikeCount: 0,
    commentCount: 0,
    shareCount: 0,
    createdAt: new Date(Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000),
    updatedAt: new Date(),
    creatorId: 'user-1',
    creator: {
      id: 'user-1',
      username: 'creator',
      displayName: 'Creator Name',
      email: '',
      profileImageURL: `https://i.pravatar.cc/150?img=${i + 3}`,
      bannerImageURL: '',
      subscriberCount: 0,
      videoCount: 0,
      createdAt: new Date(),
      isVerified: Math.random() > 0.5,
      isAdmin: false,
    },
    category: { id: '', name: '', slug: '' },
    tags: [],
    isPublic: true,
    ageRestricted: false,
    madeForKids: false,
    commentsEnabled: true,
    likesEnabled: true,
    downloadsEnabled: true,
  }));

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

