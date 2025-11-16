'use client';

// 🔥 YOUTUBE-LEVEL PREMIUM VIDEO CARD COMPONENT 🔥

import Link from 'next/link';
import { CheckCircle, MoreVertical, Minimize2 } from 'lucide-react';
import { useState } from 'react';
import { useMiniPlayer } from '@/contexts/MiniPlayerContext';

interface VideoCardProps {
  video: {
    id: string;
    title: string;
    thumbnailURL: string;
    duration: string;
    channel: string;
    channelIcon: string;
    views: string;
    timeAgo: string;
    isVerified?: boolean;
  };
  index?: number;
}

export default function VideoCard({ video, index = 0 }: VideoCardProps) {
  const [showMenu, setShowMenu] = useState(false);
  const [imageLoaded, setImageLoaded] = useState(false);
  const { openMiniPlayer } = useMiniPlayer();

  const handlePlayInMiniPlayer = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    openMiniPlayer({
      id: video.id,
      title: video.title,
      channel: video.channel,
      thumbnailURL: video.thumbnailURL,
    });
    setShowMenu(false);
  };

  return (
    <Link 
      href={`/watch/${video.id}`}
      className={`video-card group block fade-in-up stagger-${(index % 4) + 1}`}
    >
      <div className="space-y-3">
        {/* Thumbnail Container */}
        <div className="relative aspect-video rounded-xl overflow-hidden bg-[rgb(var(--color-surface))]">
          {/* Thumbnail Image */}
          <img
            src={video.thumbnailURL}
            alt={video.title}
            onLoad={() => setImageLoaded(true)}
            className={`
              video-card-thumbnail
              w-full h-full object-cover
              ${imageLoaded ? 'opacity-100' : 'opacity-0'}
              transition-opacity duration-300
            `}
          />
          
          {/* Loading Skeleton */}
          {!imageLoaded && (
            <div className="absolute inset-0 skeleton" />
          )}

          {/* Gradient Overlay on Hover */}
          <div className="
            absolute inset-0 
            bg-gradient-to-t from-black/60 via-transparent to-transparent
            opacity-0 group-hover:opacity-100
            transition-opacity duration-200
          " />

          {/* Duration Badge */}
          <div className="
            absolute bottom-2 right-2
            px-2 py-0.5
            bg-black/90 backdrop-blur-sm
            text-white text-xs font-semibold
            rounded
            pointer-events-none
          ">
            {video.duration}
          </div>

          {/* Play Icon Overlay (appears on hover) */}
          <div className="
            absolute inset-0
            flex items-center justify-center
            opacity-0 group-hover:opacity-100
            transition-opacity duration-200
            pointer-events-none
          ">
            <div className="
              w-14 h-14
              bg-black/80 backdrop-blur-sm
              rounded-full
              flex items-center justify-center
              transform group-hover:scale-110
              transition-transform duration-200
            ">
              <div className="
                w-0 h-0
                border-t-[8px] border-t-transparent
                border-l-[14px] border-l-white
                border-b-[8px] border-b-transparent
                ml-1
              " />
            </div>
          </div>
        </div>

        {/* Video Info */}
        <div className="flex gap-3 px-0.5">
          {/* Channel Avatar */}
          <div className="relative flex-shrink-0">
            <img
              src={video.channelIcon}
              alt={video.channel}
              className="
                w-9 h-9 rounded-full
                ring-0 group-hover:ring-2 ring-[rgb(var(--color-primary))]
                transition-all duration-200
              "
            />
            {video.isVerified && (
              <div className="
                absolute -bottom-0.5 -right-0.5
                w-3.5 h-3.5
                bg-white dark:bg-[rgb(var(--color-background))]
                rounded-full
                flex items-center justify-center
              ">
                <CheckCircle size={12} className="text-[rgb(var(--color-text-secondary))]" fill="currentColor" />
              </div>
            )}
          </div>

          {/* Title and Metadata */}
          <div className="flex-1 min-w-0">
            <h3 className="
              text-sm font-semibold
              text-[rgb(var(--color-text-primary))]
              line-clamp-2
              leading-tight
              mb-1
              group-hover:text-[rgb(var(--color-primary))]
              transition-colors duration-150
            ">
              {video.title}
            </h3>

            {/* Channel Name */}
            <p className="
              text-xs
              text-[rgb(var(--color-text-secondary))]
              truncate
              mb-0.5
              group-hover:text-[rgb(var(--color-text-primary))]
              transition-colors duration-150
            ">
              {video.channel}
            </p>

            {/* Views and Date */}
            <p className="
              text-xs
              text-[rgb(var(--color-text-tertiary))]
            ">
              {video.views} views • {video.timeAgo}
            </p>
          </div>

          {/* More Options Button (appears on hover) */}
          <button
            onClick={(e) => {
              e.preventDefault();
              setShowMenu(!showMenu);
            }}
            className="
              flex-shrink-0
              w-8 h-8
              rounded-full
              flex items-center justify-center
              opacity-0 group-hover:opacity-100
              hover:bg-[rgb(var(--color-surface))]
              transition-all duration-150
            "
          >
            <MoreVertical size={18} className="text-[rgb(var(--color-text-primary))]" />
          </button>
        </div>
      </div>

      {/* Options Menu (hidden by default) */}
      {showMenu && (
        <div className="
          absolute right-0 top-full mt-2
          w-52
          bg-white dark:bg-[rgb(var(--color-surface))]
          border border-[rgb(var(--color-border))]
          rounded-lg
          shadow-lg-yt
          overflow-hidden
          z-50
        ">
          <button
            onClick={handlePlayInMiniPlayer}
            className="
              w-full px-4 py-2.5
              flex items-center gap-3
              text-left text-sm
              text-[rgb(var(--color-text-primary))]
              hover:bg-[rgb(var(--color-surface-hover))]
              transition-colors
            "
          >
            <Minimize2 size={16} className="text-[rgb(var(--color-text-secondary))]" />
            <span>Play in Mini Player</span>
          </button>
          <div className="border-t border-[rgb(var(--color-border))]"></div>
          <button className="
            w-full px-4 py-2
            text-left text-sm
            text-[rgb(var(--color-text-primary))]
            hover:bg-[rgb(var(--color-surface-hover))]
            transition-colors
          ">
            Save to Watch Later
          </button>
          <button className="
            w-full px-4 py-2
            text-left text-sm
            text-[rgb(var(--color-text-primary))]
            hover:bg-[rgb(var(--color-surface-hover))]
            transition-colors
          ">
            Save to Playlist
          </button>
          <button className="
            w-full px-4 py-2
            text-left text-sm
            text-[rgb(var(--color-text-primary))]
            hover:bg-[rgb(var(--color-surface-hover))]
            transition-colors
          ">
            Not interested
          </button>
        </div>
      )}
    </Link>
  );
}
