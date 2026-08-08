'use client';

import Image from 'next/image';
import {CheckCircle, Heart, Share2, Flag} from 'lucide-react';
import {formatViewCount} from '@/lib/utils/format';
import type {LiveStream} from '@/types/live';
import {
  recordLiveShare,
  setLiveLike,
  subscribeToLiveLike,
} from '@/lib/firebase/live-engagement';
import {useEffect, useState} from 'react';
import SubscribeButton from '@/components/video/SubscribeButton';
import ContentReportDialog from '@/components/moderation/ContentReportDialog';

interface LiveInfoProps {
  stream: LiveStream;
}

const LiveInfo = ({stream}: LiveInfoProps) => {
  const [isLiked, setIsLiked] = useState(false);
  const [isLikePending, setIsLikePending] = useState(false);
  const [showReportDialog, setShowReportDialog] = useState(false);

  useEffect(() => subscribeToLiveLike(stream.id, setIsLiked), [stream.id]);

  const handleLike = async () => {
    if (isLikePending) return;
    setIsLikePending(true);
    try {
      await setLiveLike(stream.id, !isLiked);
    } finally {
      setIsLikePending(false);
    }
  };

  const handleShare = async () => {
    const shareData = {title: stream.title, url: window.location.href};
    try {
      if (navigator.share) {
        await navigator.share(shareData);
      } else {
        await navigator.clipboard.writeText(shareData.url);
      }
    } catch {
      return;
    }
    await recordLiveShare(stream.id).catch(() => undefined);
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
          {stream.streamer.profileImageURL ? (
            <Image
              src={stream.streamer.profileImageURL}
              alt={stream.streamer.displayName}
              width={48}
              height={48}
              unoptimized
              className="h-12 w-12 rounded-full object-cover"
            />
          ) : (
            <div
              className="flex h-12 w-12 items-center justify-center rounded-full bg-[rgb(var(--color-surface-hover))] text-sm font-semibold text-[rgb(var(--color-text-primary))]"
              aria-hidden="true"
            >
              {stream.streamer.displayName.slice(0, 1).toUpperCase()}
            </div>
          )}

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

        {stream.streamer.id && <SubscribeButton channelId={stream.streamer.id} />}
      </div>

      {/* Engagement Actions */}
      <div className="flex items-center gap-2 flex-wrap mb-4">
        {/* Like Button */}
        <button
          type="button"
          onClick={() => { void handleLike(); }}
          disabled={isLikePending}
          aria-pressed={isLiked}
          className={`flex min-h-11 items-center gap-2 rounded-full px-4 py-2 transition-colors disabled:opacity-60 ${
            isLiked
              ? 'bg-red-500 text-white'
              : 'bg-[rgb(var(--color-surface))] hover:bg-[rgb(var(--color-surface-hover))] text-[rgb(var(--color-text-primary))]'
          }`}
        >
          <Heart size={18} className={isLiked ? 'fill-white' : ''} />
          <span className="text-sm font-medium">
            {formatViewCount(stream.likeCount)}
          </span>
        </button>

        {/* Share Button */}
        <button
          type="button"
          onClick={() => { void handleShare(); }}
          className="flex min-h-11 items-center gap-2 rounded-full bg-[rgb(var(--color-surface))] px-4 py-2 transition-colors hover:bg-[rgb(var(--color-surface-hover))]"
        >
          <Share2 size={18} className="text-[rgb(var(--color-text-primary))]" />
          <span className="text-sm font-medium text-[rgb(var(--color-text-primary))]">
            Share
          </span>
        </button>

        {/* Report Button */}
        <button
          type="button"
          onClick={() => setShowReportDialog(true)}
          className="flex min-h-11 items-center gap-2 rounded-full bg-[rgb(var(--color-surface))] px-4 py-2 transition-colors hover:bg-[rgb(var(--color-surface-hover))]"
        >
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

      {showReportDialog && (
        <ContentReportDialog
          contentType="live_stream"
          contentId={stream.id}
          contentCreatorId={stream.streamer.id}
          title="live stream"
          onClose={() => setShowReportDialog(false)}
        />
      )}
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

