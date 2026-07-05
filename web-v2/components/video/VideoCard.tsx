'use client';

// 🔥 YOUTUBE-LEVEL PREMIUM VIDEO CARD COMPONENT 🔥

import Link from 'next/link';
import { CheckCircle, MoreVertical, Minimize2, EyeOff, UserX } from 'lucide-react';
import { useState } from 'react';
import { useMiniPlayer } from '@/contexts/MiniPlayerContext';
import { doc, setDoc, serverTimestamp } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

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
    channelId?: string;
  };
  index?: number;
}

export default function VideoCard({ video, index = 0 }: VideoCardProps) {
  const [showMenu, setShowMenu] = useState(false);
  const [imageLoaded, setImageLoaded] = useState(false);
  const [dismissed, setDismissed] = useState(false);
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

  const handleNotInterested = async (e: React.MouseEvent) => {
    e.preventDefault();
    setDismissed(true);
    setShowMenu(false);
    const uid = auth?.currentUser?.uid;
    if (!uid) return;
    try {
      await setDoc(doc(db, 'users', uid, 'notInterested', video.id), {
        videoId: video.id,
        dismissedAt: serverTimestamp(),
        reason: 'not_interested',
      });
    } catch { /* non-fatal — optimistic dismiss */ }
  };

  const handleDontRecommendChannel = async (e: React.MouseEvent) => {
    e.preventDefault();
    setDismissed(true);
    setShowMenu(false);
    const uid = auth?.currentUser?.uid;
    if (!uid || !video.channelId) return;
    try {
      await setDoc(doc(db, 'users', uid, 'notInterested', `channel_${video.channelId}`), {
        channelId: video.channelId,
        dismissedAt: serverTimestamp(),
        reason: 'dont_recommend_channel',
      });
    } catch { /* non-fatal */ }
  };

  // Hide dismissed cards without layout shift
  if (dismissed) {
    return (
      <div className="aspect-video rounded-xl bg-[rgb(var(--color-surface))] flex items-center justify-center">
        <p className="text-[12px] text-[rgb(var(--color-text-tertiary))]">Video removed from feed</p>
      </div>
    );
  }

  return (
    <Link 
      href={`/watch/${video.id}`}
      className={`video-card group block fade-in-up stagger-${(index % 4) + 1} relative`}
    >
      <div className="space-y-3">
        {/* Thumbnail Container */}
        <div className="relative aspect-video rounded-xl overflow-hidden bg-[rgb(var(--color-surface))]">
          <img
            src={video.thumbnailURL}
            alt={video.title}
            onLoad={() => setImageLoaded(true)}
            className={`video-card-thumbnail w-full h-full object-cover ${imageLoaded ? 'opacity-100' : 'opacity-0'} transition-opacity duration-300`}
          />
          {!imageLoaded && <div className="absolute inset-0 skeleton" />}
          <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-200" />
          <div className="absolute bottom-2 right-2 px-2 py-0.5 bg-black/90 backdrop-blur-sm text-white text-xs font-semibold rounded pointer-events-none">
            {video.duration}
          </div>
          <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none">
            <div className="w-14 h-14 bg-black/80 backdrop-blur-sm rounded-full flex items-center justify-center transform group-hover:scale-110 transition-transform duration-200">
              <div className="w-0 h-0 border-t-[8px] border-t-transparent border-l-[14px] border-l-white border-b-[8px] border-b-transparent ml-1" />
            </div>
          </div>
        </div>

        {/* Video Info */}
        <div className="flex gap-3 px-0.5">
          <div className="relative flex-shrink-0">
            <img
              src={video.channelIcon}
              alt={video.channel}
              className="w-9 h-9 rounded-full ring-0 group-hover:ring-2 ring-[rgb(var(--color-primary))] transition-all duration-200"
            />
            {video.isVerified && (
              <div className="absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 bg-white dark:bg-[rgb(var(--color-background))] rounded-full flex items-center justify-center">
                <CheckCircle size={12} className="text-[rgb(var(--color-text-secondary))]" fill="currentColor" />
              </div>
            )}
          </div>

          <div className="flex-1 min-w-0">
            <h3 className="text-sm font-semibold text-[rgb(var(--color-text-primary))] line-clamp-2 leading-tight mb-1 group-hover:text-[rgb(var(--color-primary))] transition-colors duration-150">
              {video.title}
            </h3>
            <p className="text-xs text-[rgb(var(--color-text-secondary))] truncate mb-0.5 group-hover:text-[rgb(var(--color-text-primary))] transition-colors duration-150">
              {video.channel}
            </p>
            <p className="text-xs text-[rgb(var(--color-text-tertiary))]">
              {video.views} views • {video.timeAgo}
            </p>
          </div>

          {/* More Options */}
          <button
            onClick={(e) => { e.preventDefault(); setShowMenu(!showMenu); }}
            className="flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 hover:bg-[rgb(var(--color-surface))] transition-all duration-150"
            aria-label="More options"
          >
            <MoreVertical size={18} className="text-[rgb(var(--color-text-primary))]" />
          </button>
        </div>
      </div>

      {/* Options Menu */}
      {showMenu && (
        <>
          <div className="fixed inset-0 z-40" onClick={(e) => { e.preventDefault(); setShowMenu(false); }} />
          <div className="absolute right-0 top-full mt-2 w-56 bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] rounded-xl shadow-lg-yt overflow-hidden z-50">
            <button
              onClick={handlePlayInMiniPlayer}
              className="w-full px-4 py-2.5 flex items-center gap-3 text-left text-sm text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
            >
              <Minimize2 size={16} className="text-[rgb(var(--color-text-secondary))]" />
              Play in Mini Player
            </button>
            <div className="border-t border-[rgb(var(--color-border))]" />
            <button
              onClick={(e) => { e.preventDefault(); setShowMenu(false); }}
              className="w-full px-4 py-2.5 text-left text-sm text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
            >
              Save to Watch Later
            </button>
            <button
              onClick={(e) => { e.preventDefault(); setShowMenu(false); }}
              className="w-full px-4 py-2.5 text-left text-sm text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
            >
              Save to Playlist
            </button>
            <div className="border-t border-[rgb(var(--color-border))]" />
            <button
              onClick={handleNotInterested}
              className="w-full px-4 py-2.5 flex items-center gap-3 text-left text-sm text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
            >
              <EyeOff size={16} className="text-[rgb(var(--color-text-secondary))]" />
              Not interested
            </button>
            {video.channelId && (
              <button
                onClick={handleDontRecommendChannel}
                className="w-full px-4 py-2.5 flex items-center gap-3 text-left text-sm text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
              >
                <UserX size={16} className="text-[rgb(var(--color-text-secondary))]" />
                Don&apos;t recommend channel
              </button>
            )}
          </div>
        </>
      )}
    </Link>
  );
}
