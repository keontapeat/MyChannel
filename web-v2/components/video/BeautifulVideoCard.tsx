'use client';

// 🔥🎨 BEAUTIFUL YOUTUBE-PREMIUM STYLE VIDEO CARD 🎨🔥
// The most beautiful video card component ever created

import Link from 'next/link';
import { CheckCircle, MoreVertical, Clock, Eye } from 'lucide-react';
import { useState, useMemo, useEffect } from 'react';
import { useMiniPlayer } from '@/contexts/MiniPlayerContext';
import { imagePrefetcher } from '@/lib/performance/ImagePrefetcher';

interface BeautifulVideoCardProps {
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
  index: number;
  allVideos?: any[];
}

export default function BeautifulVideoCard({ video, index, allVideos = [] }: BeautifulVideoCardProps) {
  const [isHovered, setIsHovered] = useState(false);
  const [imageLoaded, setImageLoaded] = useState(false);
  const [showMenu, setShowMenu] = useState(false);
  const { openMiniPlayer } = useMiniPlayer();

  // 🔥 PERFORMANCE: Pre-compute expensive values
  const formattedViews = useMemo(() => video.views, [video.views]);
  const formattedTime = useMemo(() => video.timeAgo, [video.timeAgo]);

  // 🔥 PERFORMANCE: Aggressive prefetching
  useEffect(() => {
    if (allVideos.length > 0 && index < allVideos.length - 1) {
      const prefetchRange = allVideos.slice(index + 1, Math.min(allVideos.length, index + 13));
      const urls = prefetchRange.map(v => v.thumbnailURL).filter(Boolean);
      imagePrefetcher.prefetchMultiple(urls);
    }
  }, [index, allVideos]);

  return (
    <div 
      className="group cursor-pointer animate-fadeIn"
      style={{ animationDelay: `${index * 0.05}s` }}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => {
        setIsHovered(false);
        setShowMenu(false);
      }}
    >
      {/* Thumbnail Container - YouTube Premium Style */}
      <Link href={`/watch/${video.id}`}>
        <div className="relative aspect-video rounded-xl overflow-hidden mb-3 bg-[rgb(var(--color-surface))]">
          {/* Thumbnail Image */}
          <img
            src={video.thumbnailURL}
            alt={video.title}
            className={`
              w-full h-full object-cover
              transition-all duration-300
              ${imageLoaded ? 'opacity-100 scale-100' : 'opacity-0 scale-95'}
              ${isHovered ? 'scale-105' : 'scale-100'}
            `}
            onLoad={() => setImageLoaded(true)}
            loading="lazy"
          />

          {/* Gradient Overlay on Hover */}
          <div className={`
            absolute inset-0
            bg-gradient-to-t from-black/60 via-transparent to-transparent
            opacity-0 group-hover:opacity-100
            transition-opacity duration-300
          `} />

          {/* Duration Badge - YouTube Style */}
          <div className="absolute bottom-2 right-2 px-2 py-0.5 rounded-md bg-black/90 backdrop-blur-sm text-white text-xs font-semibold">
            {video.duration}
          </div>

          {/* Hover Preview Indicator */}
          {isHovered && (
            <div className="absolute top-2 right-2 px-2 py-1 rounded-full bg-black/70 backdrop-blur-sm text-white text-xs font-medium flex items-center gap-1.5 animate-scaleIn">
              <Eye size={12} />
              <span>Preview</span>
            </div>
          )}

          {/* Loading Skeleton */}
          {!imageLoaded && (
            <div className="absolute inset-0 skeleton-youtube" />
          )}

          {/* Hover Glow Effect (Premium) */}
          {isHovered && (
            <div className="absolute inset-0 ring-2 ring-[rgb(var(--color-primary))]/20 rounded-xl pointer-events-none" />
          )}
        </div>
      </Link>

      {/* Metadata Container - YouTube Layout */}
      <div className="flex gap-3">
        {/* Channel Avatar */}
        <Link href={`/profile/${video.channel}`}>
          <img
            src={video.channelIcon}
            alt={video.channel}
            className="w-10 h-10 rounded-full flex-shrink-0 hover:opacity-80 transition-opacity ring-2 ring-[rgb(var(--color-border))]/20"
            loading="lazy"
          />
        </Link>

        {/* Video Info */}
        <div className="flex-1 min-w-0 flex flex-col gap-1">
          {/* Title */}
          <Link href={`/watch/${video.id}`}>
            <h3 className={`
              font-medium text-[rgb(var(--color-text-primary))]
              line-clamp-2 text-[15px] leading-[1.4rem]
              transition-colors duration-200
              ${isHovered ? 'text-[rgb(var(--color-primary))]' : ''}
            `}>
              {video.title}
            </h3>
          </Link>

          {/* Channel Name with Verified Badge */}
          <Link href={`/profile/${video.channel}`}>
            <div className="flex items-center gap-1.5 group/channel">
              <span className="text-[rgb(var(--color-text-secondary))] text-sm font-medium group-hover/channel:text-[rgb(var(--color-text-primary))] transition-colors">
                {video.channel}
              </span>
              {video.isVerified && (
                <CheckCircle 
                  size={14} 
                  className="text-[rgb(var(--color-text-secondary))] fill-current"
                  strokeWidth={0}
                />
              )}
            </div>
          </Link>

          {/* Views & Time - YouTube Style */}
          <div className="flex items-center gap-1.5 text-[rgb(var(--color-text-secondary))] text-sm">
            <span className="flex items-center gap-1">
              <Eye size={12} className="opacity-60" />
              {formattedViews}
            </span>
            <span className="opacity-50">•</span>
            <span className="flex items-center gap-1">
              <Clock size={12} className="opacity-60" />
              {formattedTime}
            </span>
          </div>
        </div>

        {/* More Menu Button - YouTube Style */}
        <button
          onClick={(e) => {
            e.preventDefault();
            setShowMenu(!showMenu);
          }}
          className={`
            p-2 rounded-full
            transition-all duration-200
            hover:bg-[rgb(var(--color-surface-hover))]
            ${isHovered ? 'opacity-100' : 'opacity-0'}
            focus-visible-youtube
          `}
          aria-label="More options"
        >
          <MoreVertical size={18} className="text-[rgb(var(--color-text-secondary))]" />
        </button>
      </div>

      {/* Context Menu (if shown) */}
      {showMenu && (
        <div className="absolute right-0 mt-2 w-56 bg-[rgb(var(--color-elevated))] rounded-xl shadow-xl border border-[rgb(var(--color-border))]/10 py-2 z-50 animate-scaleIn">
          <MenuOption icon="📥" text="Save to Watch Later" />
          <MenuOption icon="➕" text="Add to Playlist" />
          <MenuOption icon="🚫" text="Not Interested" />
          <MenuOption icon="⚠️" text="Report" />
        </div>
      )}
    </div>
  );
}

// Menu Option Component
function MenuOption({ icon, text }: { icon: string; text: string }) {
  return (
    <button className="w-full px-4 py-2.5 text-left hover:bg-[rgb(var(--color-surface-hover))] transition-colors flex items-center gap-3">
      <span className="text-lg">{icon}</span>
      <span className="text-sm font-medium text-[rgb(var(--color-text-primary))]">{text}</span>
    </button>
  );
}

