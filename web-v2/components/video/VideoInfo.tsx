'use client';

import { CheckCircle } from 'lucide-react';
import { formatViewCount, formatTimeAgo } from '@/lib/utils/format';
import type { Video } from '@/types';

interface VideoInfoProps {
  video: Video;
}

const VideoInfo = ({ video }: VideoInfoProps) => {
  return (
    <div>
      {/* Video Title */}
      <h1 className="text-xl font-semibold text-[rgb(var(--color-text-primary))] mb-3">
        {video.title}
      </h1>

      {/* Creator and Subscribe */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <img
            src={video.creator.profileImageURL}
            alt={video.creator.displayName}
            className="w-10 h-10 rounded-full"
          />

          <div>
            <div className="flex items-center gap-1">
              <h2 className="text-sm font-medium text-[rgb(var(--color-text-primary))]">
                {video.creator.displayName}
              </h2>
              {video.creator.isVerified && (
                <CheckCircle size={14} className="text-[rgb(var(--color-text-secondary))]" />
              )}
            </div>
            <p className="text-xs text-[rgb(var(--color-text-secondary))]">
              {formatViewCount(video.creator.subscriberCount)} subscribers
            </p>
          </div>
        </div>

        <button className="btn-youtube">
          Subscribe
        </button>
      </div>

      {/* Views and Date */}
      <div className="mt-3 text-sm text-[rgb(var(--color-text-secondary))]">
        {formatViewCount(video.viewCount)} views • {formatTimeAgo(video.createdAt)}
      </div>
    </div>
  );
};

export default VideoInfo;

