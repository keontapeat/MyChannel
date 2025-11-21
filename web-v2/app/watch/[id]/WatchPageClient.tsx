'use client';

// 🔥 YOUTUBE-LEVEL PROFESSIONAL WATCH PAGE 🔥

import { useState, useRef, useEffect } from 'react';
import Link from 'next/link';
import { ThumbsUp, ThumbsDown, Share2, MoreHorizontal, ChevronDown, Bell, CheckCircle } from 'lucide-react';
import VideoCard from '@/components/video/VideoCard';
import { CompactVideoCardSkeleton } from '@/components/skeletons/VideoSkeleton';

interface WatchPageClientProps {
  videoId: string;
}

export default function WatchPageClient({ videoId }: WatchPageClientProps) {
  const [showFullDescription, setShowFullDescription] = useState(false);
  const [isSubscribed, setIsSubscribed] = useState(false);
  const [likeCount, setLikeCount] = useState(1234);
  const [isLiked, setIsLiked] = useState(false);
  const [isDisliked, setIsDisliked] = useState(false);

  // Mock video data - replace with actual fetch
  const video = {
    id: videoId,
    title: 'Amazing Video Title - This is a longer title to show how YouTube handles multiline titles on the watch page',
    videoURL: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    views: '1.2M',
    uploadDate: 'Jan 15, 2025',
    likes: likeCount,
    channel: {
      name: 'Creator Name',
      avatar: 'https://i.pravatar.cc/150?img=1',
      subscribers: '250K',
      isVerified: true,
    },
    description: `This is the video description. It can be quite long and contain multiple paragraphs.

This video demonstrates the premium YouTube-level watch page experience.

🔗 Links:
• Website: https://example.com
• Twitter: @example
• Instagram: @example

📝 Chapters:
0:00 - Introduction
1:30 - Main Content
5:45 - Conclusion

#tag1 #tag2 #tag3`,
  };

  // Mock suggested videos
  const suggestedVideos = Array.from({ length: 12 }, (_, i) => ({
    id: `suggested-${i + 1}`,
    title: `Suggested Video ${i + 1} - Interesting content you might like`,
    channel: 'Channel Name',
    channelIcon: `https://i.pravatar.cc/150?img=${(i % 10) + 2}`,
    views: `${Math.floor(Math.random() * 1000 + 100)}K`,
    timeAgo: `${Math.floor(Math.random() * 30 + 1)} days ago`,
    duration: `${Math.floor(Math.random() * 20 + 5)}:${String(Math.floor(Math.random() * 60)).padStart(2, '0')}`,
    thumbnailURL: `https://picsum.photos/seed/suggested${i + 1}/336/188`,
    isVerified: Math.random() > 0.5,
  }));

  const handleLike = () => {
    if (isLiked) {
      setIsLiked(false);
      setLikeCount(likeCount - 1);
    } else {
      setIsLiked(true);
      setIsDisliked(false);
      setLikeCount(likeCount + (isDisliked ? 2 : 1));
    }
  };

  const handleDislike = () => {
    if (isDisliked) {
      setIsDisliked(false);
      if (isLiked) setLikeCount(likeCount - 1);
    } else {
      setIsDisliked(true);
      if (isLiked) {
        setIsLiked(false);
        setLikeCount(likeCount - 2);
      }
    }
  };

  return (
    <div className="min-h-screen bg-white dark:bg-[rgb(var(--color-background))] pt-14">
      <div className="max-w-[1800px] mx-auto px-6 py-6">
        <div className="flex gap-6">
          {/* Left: Video Player and Info (70%) */}
          <div className="flex-1 max-w-[1280px]">
            {/* Video Player */}
            <div className="aspect-video w-full bg-black rounded-xl overflow-hidden mb-4">
              <video
                controls
                className="w-full h-full"
                src={video.videoURL}
              >
                Your browser does not support the video tag.
              </video>
            </div>

            {/* Video Title */}
            <h1 className="text-xl font-semibold text-[rgb(var(--color-text-primary))] mb-3 leading-tight">
              {video.title}
            </h1>

            {/* Channel Info and Actions */}
            <div className="flex items-center justify-between mb-4 pb-4 border-b border-[rgb(var(--color-border))]">
              {/* Channel Info */}
              <div className="flex items-center gap-4">
                <img
                  src={video.channel.avatar}
                  alt={video.channel.name}
                  className="w-10 h-10 rounded-full"
                />
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-sm font-semibold text-[rgb(var(--color-text-primary))]">
                      {video.channel.name}
                    </h3>
                    {video.channel.isVerified && (
                      <CheckCircle size={14} className="text-[rgb(var(--color-text-secondary))]" fill="currentColor" />
                    )}
                  </div>
                  <p className="text-xs text-[rgb(var(--color-text-secondary))]">
                    {video.channel.subscribers} subscribers
                  </p>
                </div>
                <button
                  onClick={() => setIsSubscribed(!isSubscribed)}
                  className={`
                    flex items-center gap-2 px-4 py-2 rounded-full text-sm font-medium transition-all
                    ${
                      isSubscribed
                        ? 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]'
                        : 'bg-[rgb(var(--color-text-primary))] text-white hover:opacity-90'
                    }
                  `}
                >
                  {isSubscribed ? (
                    <>
                      <Bell size={16} />
                      Subscribed
                    </>
                  ) : (
                    'Subscribe'
                  )}
                </button>
              </div>

              {/* Action Buttons */}
              <div className="flex items-center gap-2">
                <div className="flex items-center bg-[rgb(var(--color-surface))] rounded-full overflow-hidden">
                  <button
                    onClick={handleLike}
                    className={`flex items-center gap-2 px-4 py-2 hover:bg-[rgb(var(--color-surface-hover))] transition-colors border-r border-[rgb(var(--color-border))] ${isLiked ? 'text-[rgb(var(--color-primary))]' : ''}`}
                  >
                    <ThumbsUp size={18} fill={isLiked ? 'currentColor' : 'none'} />
                    <span className="text-sm font-medium">{likeCount.toLocaleString()}</span>
                  </button>
                  <button
                    onClick={handleDislike}
                    className={`px-4 py-2 hover:bg-[rgb(var(--color-surface-hover))] transition-colors ${isDisliked ? 'text-[rgb(var(--color-primary))]' : ''}`}
                  >
                    <ThumbsDown size={18} fill={isDisliked ? 'currentColor' : 'none'} />
                  </button>
                </div>

                <button className="flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-surface))] hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
                  <Share2 size={18} />
                  <span className="text-sm font-medium">Share</span>
                </button>

                <button className="p-2 bg-[rgb(var(--color-surface))] hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
                  <MoreHorizontal size={18} />
                </button>
              </div>
            </div>

            {/* Description */}
            <div className="bg-[rgb(var(--color-surface))] rounded-xl p-4">
              <div className="flex items-center gap-2 text-sm font-medium text-[rgb(var(--color-text-primary))] mb-2">
                <span>{video.views} views</span>
                <span>•</span>
                <span>{video.uploadDate}</span>
              </div>
              <div className={`text-sm text-[rgb(var(--color-text-primary))] whitespace-pre-wrap ${!showFullDescription ? 'line-clamp-3' : ''}`}>
                {video.description}
              </div>
              <button
                onClick={() => setShowFullDescription(!showFullDescription)}
                className="flex items-center gap-1 text-sm font-medium text-[rgb(var(--color-text-primary))] mt-2 hover:text-[rgb(var(--color-text-secondary))] transition-colors"
              >
                {showFullDescription ? 'Show less' : 'Show more'}
                <ChevronDown size={16} className={`transition-transform ${showFullDescription ? 'rotate-180' : ''}`} />
              </button>
            </div>

            {/* Comments Section (Placeholder) */}
            <div className="mt-6">
              <h2 className="text-lg font-semibold text-[rgb(var(--color-text-primary))] mb-4">
                Comments
              </h2>
              <div className="text-sm text-[rgb(var(--color-text-secondary))]">
                Comments coming soon...
              </div>
            </div>
          </div>

          {/* Right: Suggested Videos (30%) */}
          <div className="w-full max-w-[402px] space-y-2">
            {suggestedVideos.map((suggestedVideo) => (
              <Link
                key={suggestedVideo.id}
                href={`/watch/${suggestedVideo.id}`}
                className="flex gap-2 group"
              >
                {/* Compact Thumbnail */}
                <div className="relative w-[168px] h-[94px] rounded-lg overflow-hidden bg-[rgb(var(--color-surface))] flex-shrink-0">
                  <img
                    src={suggestedVideo.thumbnailURL}
                    alt={suggestedVideo.title}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200"
                  />
                  <div className="absolute bottom-1 right-1 px-1.5 py-0.5 bg-black/90 text-white text-xs font-semibold rounded">
                    {suggestedVideo.duration}
                  </div>
                </div>

                {/* Compact Info */}
                <div className="flex-1 min-w-0">
                  <h3 className="text-sm font-semibold text-[rgb(var(--color-text-primary))] line-clamp-2 mb-1 group-hover:text-[rgb(var(--color-primary))] transition-colors leading-tight">
                    {suggestedVideo.title}
                  </h3>
                  <p className="text-xs text-[rgb(var(--color-text-secondary))] truncate mb-0.5">
                    {suggestedVideo.channel}
                  </p>
                  <p className="text-xs text-[rgb(var(--color-text-tertiary))]">
                    {suggestedVideo.views} views • {suggestedVideo.timeAgo}
                  </p>
                </div>
              </Link>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}






