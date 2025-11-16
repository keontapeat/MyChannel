'use client';

import { CheckCircle, Heart, Share2, Flag } from 'lucide-react';
import { formatViewCount } from '@/lib/utils/format';
import type { LiveStream } from '@/types/live';
import { useState } from 'react';

interface LiveInfoProps {
  stream: LiveStream;
}

const LiveInfo = ({ stream }: LiveInfoProps) => {
  const [isLiked, setIsLiked] = useState(false);
  const [localLikeCount, setLocalLikeCount] = useState(stream.likeCount);

  const handleLike = () => {
    if (isLiked) {
      setIsLiked(false);
      setLocalLikeCount(localLikeCount - 1);
    } else {
      setIsLiked(true);
      setLocalLikeCount(localLikeCount + 1);
    }
  };

  return (
    <div>
      {/* Stream Title */}
      <h1 className="text-xl font-semibold text-[rgb(var(--color-text-primary))] mb-3">
        {stream.title}
      </h1>

      {/* Streamer Info and Actions */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <img
            src={stream.streamer.profileImageURL}
            alt={stream.streamer.displayName}
            className="w-12 h-12 rounded-full"
          />

          <div>
            <div className="flex items-center gap-1">
              <h2 className="text-sm font-medium text-[rgb(var(--color-text-primary))]">
                {stream.streamer.displayName}
              </h2>
              {stream.streamer.isVerified && (
                <CheckCircle size={14} className="text-[rgb(var(--color-text-secondary))]" />
              )}
            </div>
            <p className="text-xs text-[rgb(var(--color-text-secondary))]">
              {formatViewCount(stream.streamer.subscriberCount)} subscribers
            </p>
          </div>
        </div>

        <button className="btn-youtube">
          Subscribe
        </button>
      </div>

      {/* Engagement Actions */}
      <div className="flex items-center gap-2 flex-wrap mb-4">
        {/* Like Button */}
        <button
          onClick={handleLike}
          className={`flex items-center gap-2 px-4 py-2 rounded-full transition-colors ${
            isLiked
              ? 'bg-red-500 text-white'
              : 'bg-[rgb(var(--color-surface))] hover:bg-[rgb(var(--color-surface-hover))] text-[rgb(var(--color-text-primary))]'
          }`}
        >
          <Heart size={18} className={isLiked ? 'fill-white' : ''} />
          <span className="text-sm font-medium">
            {formatViewCount(localLikeCount)}
          </span>
        </button>

        {/* Share Button */}
        <button className="flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-surface))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors">
          <Share2 size={18} className="text-[rgb(var(--color-text-primary))]" />
          <span className="text-sm font-medium text-[rgb(var(--color-text-primary))]">
            Share
          </span>
        </button>

        {/* Report Button */}
        <button className="flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-surface))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors">
          <Flag size={18} className="text-[rgb(var(--color-text-primary))]" />
          <span className="text-sm font-medium text-[rgb(var(--color-text-primary))]">
            Report
          </span>
        </button>
      </div>

      {/* Description */}
      <div className="p-4 bg-[rgb(var(--color-surface))] rounded-lg">
        <div className="flex items-center gap-4 mb-2 text-sm text-[rgb(var(--color-text-secondary))]">
          <span className="font-medium">
            {formatViewCount(stream.viewerCount)} watching now
          </span>
          <span>•</span>
          <span>Started {getStreamDuration(stream.startedAt)}</span>
          <span>•</span>
          <span className="px-2 py-0.5 bg-[rgb(var(--color-surface-hover))] rounded">
            {stream.category}
          </span>
        </div>

        <p className="text-sm text-[rgb(var(--color-text-primary))] whitespace-pre-wrap">
          {stream.description}
        </p>

        {/* Tags */}
        {stream.tags && stream.tags.length > 0 && (
          <div className="flex flex-wrap gap-2 mt-3">
            {stream.tags.map((tag) => (
              <span
                key={tag}
                className="px-3 py-1 bg-[rgb(var(--color-surface-hover))] rounded-full text-xs font-medium text-[rgb(var(--color-text-primary))]"
              >
                #{tag}
              </span>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

function getStreamDuration(startedAt: Date): string {
  const hours = Math.floor((Date.now() - startedAt.getTime()) / (1000 * 60 * 60));
  const minutes = Math.floor((Date.now() - startedAt.getTime()) / (1000 * 60)) % 60;

  if (hours > 0) {
    return `${hours}h ${minutes}m ago`;
  }
  return `${minutes}m ago`;
}

export default LiveInfo;

