'use client';

// FlickCard Component - Individual Flick with Video Player and Interactions

import { useRef, useEffect, useState } from 'react';
import { Heart, MessageCircle, Share2, Music, CheckCircle, MoreVertical } from 'lucide-react';
import { formatViewCount } from '@/lib/utils/format';
import type { Flick } from '@/types/flick';
import VideoPlayer from '@/components/video/VideoPlayer';

interface FlickCardProps {
  flick: Flick;
  isActive: boolean;
  isVisible: boolean;
}

const FlickCard = ({ flick, isActive, isVisible }: FlickCardProps) => {
  const [isLiked, setIsLiked] = useState(false);
  const [localLikeCount, setLocalLikeCount] = useState(flick.likeCount);
  const [showDescription, setShowDescription] = useState(false);

  const handleLike = () => {
    if (isLiked) {
      setIsLiked(false);
      setLocalLikeCount(localLikeCount - 1);
    } else {
      setIsLiked(true);
      setLocalLikeCount(localLikeCount + 1);
    }
  };

  const handleShare = () => {
    // Share functionality
    console.log('Share flick:', flick.id);
  };

  const handleComment = () => {
    // Open comments
    console.log('Open comments for:', flick.id);
  };

  return (
    <div className="relative w-full h-screen bg-black">
      {/* Video Player */}
      {isVisible && (
        <div className="absolute inset-0">
          <VideoPlayer
            src={flick.videoURL}
            poster={flick.thumbnailURL}
            autoplay={isActive}
            controls={false}
          />
        </div>
      )}

      {/* Gradient Overlays */}
      <div className="absolute inset-0 bg-gradient-to-b from-black/40 via-transparent to-black/60 pointer-events-none" />

      {/* Top Info */}
      <div className="absolute top-0 left-0 right-0 p-4 flex items-center justify-between z-10">
        <div className="flex items-center gap-3">
          <img
            src={flick.creator.profileImageURL}
            alt={flick.creator.displayName}
            className="w-10 h-10 rounded-full border-2 border-white"
          />
          <div>
            <div className="flex items-center gap-1">
              <span className="text-white font-semibold text-sm">
                {flick.creator.displayName}
              </span>
              {flick.creator.isVerified && (
                <CheckCircle size={14} className="text-blue-500" />
              )}
            </div>
            <span className="text-white/80 text-xs">
              @{flick.creator.username}
            </span>
          </div>
          <button className="ml-2 px-4 py-1.5 bg-red-600 hover:bg-red-700 rounded-full text-white text-sm font-semibold transition-colors">
            Follow
          </button>
        </div>

        <button className="text-white hover:bg-white/20 p-2 rounded-full transition-colors">
          <MoreVertical size={20} />
        </button>
      </div>

      {/* Bottom Info */}
      <div className="absolute bottom-0 left-0 right-20 p-4 z-10">
        <div className="space-y-2">
          <h3 className="text-white font-semibold text-lg">
            {flick.title}
          </h3>

          <div
            onClick={() => setShowDescription(!showDescription)}
            className="cursor-pointer"
          >
            <p className={`text-white/90 text-sm ${showDescription ? '' : 'line-clamp-2'}`}>
              {flick.description}
            </p>
            {flick.description.length > 100 && (
              <span className="text-white/70 text-xs">
                {showDescription ? 'Show less' : 'Show more'}
              </span>
            )}
          </div>

          {/* Tags */}
          <div className="flex flex-wrap gap-2">
            {flick.tags.map((tag) => (
              <span
                key={tag}
                className="text-white/90 text-sm font-medium"
              >
                #{tag}
              </span>
            ))}
          </div>

          {/* Music Track */}
          {flick.musicTrack && (
            <div className="flex items-center gap-2 text-white/90 text-sm">
              <Music size={16} />
              <span>
                {flick.musicTrack.title} • {flick.musicTrack.artist}
              </span>
            </div>
          )}
        </div>
      </div>

      {/* Right Side Actions */}
      <div className="absolute right-4 bottom-20 flex flex-col items-center gap-6 z-10">
        {/* Like Button */}
        <button
          onClick={handleLike}
          className="flex flex-col items-center gap-1 group"
        >
          <div className="w-12 h-12 rounded-full bg-white/10 backdrop-blur flex items-center justify-center group-hover:bg-white/20 transition-colors">
            <Heart
              size={24}
              className={`${isLiked ? 'fill-red-500 text-red-500' : 'text-white'} transition-colors`}
            />
          </div>
          <span className="text-white text-xs font-medium">
            {formatViewCount(localLikeCount)}
          </span>
        </button>

        {/* Comment Button */}
        <button
          onClick={handleComment}
          className="flex flex-col items-center gap-1 group"
        >
          <div className="w-12 h-12 rounded-full bg-white/10 backdrop-blur flex items-center justify-center group-hover:bg-white/20 transition-colors">
            <MessageCircle size={24} className="text-white" />
          </div>
          <span className="text-white text-xs font-medium">
            {formatViewCount(flick.commentCount)}
          </span>
        </button>

        {/* Share Button */}
        <button
          onClick={handleShare}
          className="flex flex-col items-center gap-1 group"
        >
          <div className="w-12 h-12 rounded-full bg-white/10 backdrop-blur flex items-center justify-center group-hover:bg-white/20 transition-colors">
            <Share2 size={24} className="text-white" />
          </div>
          <span className="text-white text-xs font-medium">Share</span>
        </button>

        {/* Music Album Art (spinning) */}
        {flick.musicTrack && (
          <div className="w-12 h-12 rounded-full overflow-hidden animate-spin-slow">
            <img
              src={flick.musicTrack.albumArt}
              alt={flick.musicTrack.title}
              className="w-full h-full object-cover"
            />
          </div>
        )}
      </div>
    </div>
  );
};

export default FlickCard;

