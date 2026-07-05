'use client';

// FlickCard Component - Individual Flick with Video Player and Interactions

import { useRef, useEffect, useState } from 'react';
import { Heart, MessageCircle, Share2, Music, CheckCircle, MoreVertical, Check } from 'lucide-react';
import { formatViewCount } from '@/lib/utils/format';
import type { Flick } from '@/types/flick';
import VideoPlayer from '@/components/video/VideoPlayer';
import {
  collection, addDoc, doc, getDoc, setDoc, deleteDoc, updateDoc, increment, serverTimestamp,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

interface FlickCardProps {
  flick: Flick;
  isActive: boolean;
  isVisible: boolean;
}

const FlickCard = ({ flick, isActive, isVisible }: FlickCardProps) => {
  const [isLiked, setIsLiked] = useState(false);
  const [localLikeCount, setLocalLikeCount] = useState(flick.likeCount);
  const [showDescription, setShowDescription] = useState(false);
  const [isFollowing, setIsFollowing] = useState(false);
  const [shareFeedback, setShareFeedback] = useState(false);
  const viewedRef = useRef(false);

  const isSeed = flick.id.startsWith('seed-');

  // Log a flick event (view/like/unlike/share) — the on_short_event_created
  // trigger increments the flick's aggregate counters server-side.
  const logEvent = async (type: 'view' | 'like' | 'unlike' | 'share') => {
    const uid = auth?.currentUser?.uid;
    if (!uid || isSeed) return;
    try {
      await addDoc(collection(db, 'flicks', flick.id, 'events'), {
        userId: uid, type, createdAt: serverTimestamp(),
      });
    } catch { /* non-fatal */ }
  };

  // Load per-user like state + follow state
  useEffect(() => {
    const uid = auth?.currentUser?.uid;
    if (!uid || isSeed) return;
    let cancelled = false;
    getDoc(doc(db, 'users', uid, 'flickLikes', flick.id))
      .then((s) => { if (!cancelled) setIsLiked(s.exists()); }).catch(() => {});
    if (flick.creator.id) {
      getDoc(doc(db, 'users', uid, 'subscriptions', flick.creator.id))
        .then((s) => { if (!cancelled) setIsFollowing(s.exists()); }).catch(() => {});
    }
    return () => { cancelled = true; };
  }, [flick.id, flick.creator.id, isSeed]);

  // Count a view once when the flick becomes active
  useEffect(() => {
    if (isActive && !viewedRef.current) {
      viewedRef.current = true;
      logEvent('view');
    }
  }, [isActive]); // eslint-disable-line react-hooks/exhaustive-deps

  const handleLike = async () => {
    const uid = auth?.currentUser?.uid;
    const next = !isLiked;
    setIsLiked(next);
    setLocalLikeCount((n) => n + (next ? 1 : -1));
    if (!uid || isSeed) return;
    try {
      const ref = doc(db, 'users', uid, 'flickLikes', flick.id);
      if (next) await setDoc(ref, { flickId: flick.id, createdAt: serverTimestamp() });
      else await deleteDoc(ref);
      await logEvent(next ? 'like' : 'unlike');
    } catch {
      setIsLiked(!next);
      setLocalLikeCount((n) => n + (next ? -1 : 1));
    }
  };

  const handleShare = async () => {
    const url = `${typeof window !== 'undefined' ? window.location.origin : ''}/flicks`;
    try {
      if (typeof navigator !== 'undefined' && navigator.share) {
        await navigator.share({ title: flick.title, url });
      } else {
        await navigator.clipboard.writeText(url);
        setShareFeedback(true);
        setTimeout(() => setShareFeedback(false), 1500);
      }
      logEvent('share');
    } catch { /* cancelled */ }
  };

  const handleComment = () => {
    // Comments sheet lands in a follow-up; scroll indicator stays interactive.
  };

  const handleFollow = async () => {
    const uid = auth?.currentUser?.uid;
    const creatorId = flick.creator.id;
    if (!creatorId) return;
    const next = !isFollowing;
    setIsFollowing(next);
    if (!uid || isSeed) return;
    try {
      const ref = doc(db, 'users', uid, 'subscriptions', creatorId);
      if (next) {
        await setDoc(ref, { channelId: creatorId, subscribedAt: serverTimestamp() });
        await updateDoc(doc(db, 'users', creatorId), { subscriberCount: increment(1) });
      } else {
        await deleteDoc(ref);
        await updateDoc(doc(db, 'users', creatorId), { subscriberCount: increment(-1) });
      }
    } catch {
      setIsFollowing(!next);
    }
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
          <button
            onClick={handleFollow}
            className={`ml-2 px-4 py-1.5 rounded-full text-white text-sm font-semibold transition-colors ${
              isFollowing ? 'bg-white/25 hover:bg-white/30' : 'bg-red-600 hover:bg-red-700'
            }`}
          >
            {isFollowing ? 'Following' : 'Follow'}
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
            {shareFeedback ? <Check size={24} className="text-green-400" /> : <Share2 size={24} className="text-white" />}
          </div>
          <span className="text-white text-xs font-medium">{shareFeedback ? 'Copied' : 'Share'}</span>
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

