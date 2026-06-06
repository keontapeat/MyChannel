'use client';

import { useState, useEffect } from 'react';
import {
  ThumbsUp, ThumbsDown, Share2, Flag, BookmarkPlus, Check, Link2,
} from 'lucide-react';
import {
  doc,
  updateDoc,
  increment,
  setDoc,
  deleteDoc,
  getDoc,
  serverTimestamp,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import { formatViewCount } from '@/lib/utils/format';
import type { Video } from '@/types';

interface VideoEngagementProps {
  video: Video;
}

const VideoEngagement = ({ video }: VideoEngagementProps) => {
  const [isLiked, setIsLiked] = useState(false);
  const [isDisliked, setIsDisliked] = useState(false);
  const [likeCount, setLikeCount] = useState(video.likeCount ?? 0);
  const [isSaved, setIsSaved] = useState(false);
  const [copyFeedback, setCopyFeedback] = useState(false);

  // Load initial like/save state from Firestore when user is signed in
  useEffect(() => {
    const uid = auth?.currentUser?.uid;
    if (!uid || !video.id) return;

    let cancelled = false;

    const load = async () => {
      try {
        const [likeSnap, saveSnap] = await Promise.all([
          getDoc(doc(db, 'users', uid, 'videoLikes', video.id)),
          getDoc(doc(db, 'users', uid, 'watchLater', video.id)),
        ]);
        if (cancelled) return;
        if (likeSnap.exists()) setIsLiked(likeSnap.data()?.value === 'like');
        if (likeSnap.exists()) setIsDisliked(likeSnap.data()?.value === 'dislike');
        setIsSaved(saveSnap.exists());
      } catch {
        // non-fatal — UI stays at defaults
      }
    };

    load();
    return () => { cancelled = true; };
  }, [video.id]);

  const handleLike = async () => {
    const uid = auth?.currentUser?.uid;
    const nextLiked = !isLiked;
    const wasDisliked = isDisliked;

    // Optimistic update
    setIsLiked(nextLiked);
    if (wasDisliked) setIsDisliked(false);
    setLikeCount((n) =>
      n + (nextLiked ? 1 : -1) + (wasDisliked ? 1 : 0)
    );

    try {
      if (uid) {
        const ref = doc(db, 'users', uid, 'videoLikes', video.id);
        if (nextLiked) {
          await setDoc(ref, { value: 'like', videoId: video.id, createdAt: serverTimestamp() });
        } else {
          await deleteDoc(ref);
        }
      }
      const videoRef = doc(db, 'videos', video.id);
      await updateDoc(videoRef, {
        likeCount: increment(nextLiked ? 1 : -1),
        ...(wasDisliked && { dislikeCount: increment(-1) }),
      });
    } catch {
      // rollback optimistic
      setIsLiked(!nextLiked);
      if (wasDisliked) setIsDisliked(true);
      setLikeCount((n) =>
        n + (nextLiked ? -1 : 1) + (wasDisliked ? -1 : 0)
      );
    }
  };

  const handleDislike = async () => {
    const uid = auth?.currentUser?.uid;
    const nextDisliked = !isDisliked;
    const wasLiked = isLiked;

    setIsDisliked(nextDisliked);
    if (wasLiked) {
      setIsLiked(false);
      setLikeCount((n) => n - 1);
    }

    try {
      if (uid) {
        const ref = doc(db, 'users', uid, 'videoLikes', video.id);
        if (nextDisliked) {
          await setDoc(ref, { value: 'dislike', videoId: video.id, createdAt: serverTimestamp() });
        } else {
          await deleteDoc(ref);
        }
      }
      const videoRef = doc(db, 'videos', video.id);
      await updateDoc(videoRef, {
        dislikeCount: increment(nextDisliked ? 1 : -1),
        ...(wasLiked && { likeCount: increment(-1) }),
      });
    } catch {
      setIsDisliked(!nextDisliked);
      if (wasLiked) { setIsLiked(true); setLikeCount((n) => n + 1); }
    }
  };

  const handleSave = async () => {
    const uid = auth?.currentUser?.uid;
    const next = !isSaved;
    setIsSaved(next);

    if (!uid) return;
    try {
      const ref = doc(db, 'users', uid, 'watchLater', video.id);
      if (next) {
        await setDoc(ref, {
          videoId: video.id,
          title: video.title,
          thumbnailURL: video.thumbnailURL,
          addedAt: serverTimestamp(),
        });
      } else {
        await deleteDoc(ref);
      }
    } catch {
      setIsSaved(!next);
    }
  };

  const handleShare = async () => {
    const url = `${typeof window !== 'undefined' ? window.location.origin : ''}/watch/${video.id}`;
    try {
      if (typeof navigator !== 'undefined' && navigator.share) {
        await navigator.share({ title: video.title, url });
      } else {
        await navigator.clipboard.writeText(url);
        setCopyFeedback(true);
        setTimeout(() => setCopyFeedback(false), 2000);
      }
    } catch {
      // user cancelled share — silent
    }
  };

  return (
    <div className="flex items-center gap-2 flex-wrap">
      {/* Like / Dislike pill */}
      <div className="flex items-center bg-[rgb(var(--color-surface))] rounded-full overflow-hidden">
        <button
          onClick={handleLike}
          aria-label={isLiked ? 'Unlike' : 'Like'}
          className={`flex items-center gap-2 px-4 py-2 hover:bg-[rgb(var(--color-surface-hover))] transition-colors ${
            isLiked ? 'text-[rgb(var(--color-primary))]' : 'text-[rgb(var(--color-text-primary))]'
          }`}
        >
          <ThumbsUp size={18} fill={isLiked ? 'currentColor' : 'none'} />
          <span className="text-sm font-medium">{formatViewCount(likeCount)}</span>
        </button>

        <div className="w-px h-6 bg-[rgb(var(--color-border))]" />

        <button
          onClick={handleDislike}
          aria-label={isDisliked ? 'Remove dislike' : 'Dislike'}
          className={`px-4 py-2 hover:bg-[rgb(var(--color-surface-hover))] transition-colors ${
            isDisliked ? 'text-[rgb(var(--color-primary))]' : 'text-[rgb(var(--color-text-primary))]'
          }`}
        >
          <ThumbsDown size={18} fill={isDisliked ? 'currentColor' : 'none'} />
        </button>
      </div>

      {/* Share */}
      <button
        onClick={handleShare}
        className="flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-surface))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors text-[rgb(var(--color-text-primary))]"
      >
        {copyFeedback ? (
          <>
            <Check size={18} className="text-green-500" />
            <span className="text-sm font-medium text-green-500">Copied!</span>
          </>
        ) : (
          <>
            <Share2 size={18} />
            <span className="text-sm font-medium">Share</span>
          </>
        )}
      </button>

      {/* Save / Watch Later */}
      <button
        onClick={handleSave}
        aria-label={isSaved ? 'Remove from Watch Later' : 'Save to Watch Later'}
        className={`flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-surface))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors ${
          isSaved ? 'text-[rgb(var(--color-primary))]' : 'text-[rgb(var(--color-text-primary))]'
        }`}
      >
        {isSaved ? <Check size={18} /> : <BookmarkPlus size={18} />}
        <span className="text-sm font-medium">{isSaved ? 'Saved' : 'Save'}</span>
      </button>

      {/* Copy link */}
      <button
        onClick={async () => {
          const url = `${typeof window !== 'undefined' ? window.location.origin : ''}/watch/${video.id}`;
          await navigator.clipboard.writeText(url).catch(() => {});
          setCopyFeedback(true);
          setTimeout(() => setCopyFeedback(false), 2000);
        }}
        className="flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-surface))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors text-[rgb(var(--color-text-primary))]"
        title="Copy link"
        aria-label="Copy video link"
      >
        <Link2 size={18} />
        <span className="text-sm font-medium hidden sm:inline">Copy link</span>
      </button>

      {/* Report */}
      <button
        className="flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-surface))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors text-[rgb(var(--color-text-primary))]"
        aria-label="Report video"
      >
        <Flag size={18} />
        <span className="text-sm font-medium hidden sm:inline">Report</span>
      </button>
    </div>
  );
};

export default VideoEngagement;
