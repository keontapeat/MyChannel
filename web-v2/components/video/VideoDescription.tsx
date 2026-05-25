'use client';

import { useState } from 'react';
import { ChevronDown, ChevronUp } from 'lucide-react';
import type { Video } from '@/types';

interface VideoDescriptionProps {
  video: Video;
}

const VideoDescription = ({ video }: VideoDescriptionProps) => {
  const [isExpanded, setIsExpanded] = useState(false);

  return (
    <div className="bg-[rgb(var(--color-surface))] rounded-lg p-4">
      <div className={`text-sm text-[rgb(var(--color-text-primary))] whitespace-pre-wrap ${!isExpanded ? 'line-clamp-3' : ''}`}>
        {video.description}
      </div>

      {video.description.length > 150 && (
        <button
          onClick={() => setIsExpanded(!isExpanded)}
          className="flex items-center gap-1 mt-2 text-sm font-medium text-[rgb(var(--color-text-primary))] hover:text-[rgb(var(--color-text-secondary))] transition-colors"
        >
          {isExpanded ? (
            <>
              <span>Show less</span>
              <ChevronUp size={16} />
            </>
          ) : (
            <>
              <span>Show more</span>
              <ChevronDown size={16} />
            </>
          )}
        </button>
      )}

      {/* Tags */}
      {video.tags && video.tags.length > 0 && (
        <div className="flex flex-wrap gap-2 mt-3">
          {video.tags.map((tag) => (
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
  );
};

export default VideoDescription;

