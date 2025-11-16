'use client';

import { ThumbsUp, ThumbsDown, Share2, Flag, Plus } from 'lucide-react';
import { formatViewCount } from '@/lib/utils/format';
import type { Video } from '@/types';

interface VideoEngagementProps {
  video: Video;
}

const VideoEngagement = ({ video }: VideoEngagementProps) => {
  return (
    <div className="flex items-center gap-2 flex-wrap">
      {/* Like/Dislike */}
      <div className="flex items-center gap-1 bg-[rgb(var(--color-surface))] rounded-full overflow-hidden">
        <button className="flex items-center gap-2 px-4 py-2 hover:bg-[rgb(var(--color-surface-hover))] transition-colors">
          <ThumbsUp size={18} className="text-[rgb(var(--color-text-primary))]" />
          <span className="text-sm font-medium text-[rgb(var(--color-text-primary))]">
            {formatViewCount(video.likeCount)}
          </span>
        </button>

        <div className="w-px h-6 bg-[rgb(var(--color-border))]" />

        <button className="px-4 py-2 hover:bg-[rgb(var(--color-surface-hover))] transition-colors">
          <ThumbsDown size={18} className="text-[rgb(var(--color-text-primary))]" />
        </button>
      </div>

      {/* Share */}
      <button className="flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-surface))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors">
        <Share2 size={18} className="text-[rgb(var(--color-text-primary))]" />
        <span className="text-sm font-medium text-[rgb(var(--color-text-primary))]">
          Share
        </span>
      </button>

      {/* Save to Playlist */}
      <button className="flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-surface))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors">
        <Plus size={18} className="text-[rgb(var(--color-text-primary))]" />
        <span className="text-sm font-medium text-[rgb(var(--color-text-primary))]">
          Save
        </span>
      </button>

      {/* Report */}
      <button className="flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-surface))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors">
        <Flag size={18} className="text-[rgb(var(--color-text-primary))]" />
        <span className="text-sm font-medium text-[rgb(var(--color-text-primary))]">
          Report
        </span>
      </button>
    </div>
  );
};

export default VideoEngagement;

