'use client';

import { useState, useEffect } from 'react';
import { onAuthStateChanged } from 'firebase/auth';
import {
  ThumbsUp, ThumbsDown, Share2, Flag, BookmarkPlus, Check, Link2, Heart, Download, Loader2,
} from 'lucide-react';
import {
  doc,
  getDoc,
  serverTimestamp,
  writeBatch,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import { appendVideoEngagement, recordVideoEngagement } from '@/lib/firebase/video-engagement';
import { formatViewCount } from '@/lib/utils/format';
import SaveToPlaylistModal from './SaveToPlaylistModal';
import ContentReportDialog from '@/components/moderation/ContentReportDialog';
import type { Video } from '@/types';

interface VideoEngagementProps {
  video: Video;
  onSuperThanks?: () => void;
}

const VideoEngagement = ({ video, onSuperThanks }: VideoEngagementProps) => {
  const [isLiked, setIsLiked] = useState(false);
  const [isDisliked, setIsDisliked] = useState(false);
  const [likeCount, setLikeCount] = useState(video.likeCount ?? 0);
  const [isSaved, setIsSaved] = useState(false);
  const [copyFeedback, setCopyFeedback] = useState(false);
  const [showSaveModal, setShowSaveModal] = useState(false);
  const [showReportDialog, setShowReportDialog] = useState(false);
  const [downloading, setDownloading] = useState(false);

  // Download is allowed only when the creator enabled it and the file is a
  // direct download (mp4). HLS (.m3u8) playlists can't be saved as a single file.
  const canDownload =
    video.downloadsEnabled === true &&
    !!video.videoURL &&
    !video.videoURL.includes('.m3u8');

  const handleDownload = async () => {
    if (!canDownload || downloading) return;
    setDownloading(true);
    try {
      const res = await fetch(video.videoURL);
      const blob = await res.blob();
      const objectUrl = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = objectUrl;
      a.download = `${video.title || 'video'}.mp4`.replace(/[\\/:*?"<>|]+/g, '_');
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(objectUrl);
    } catch {
      // Fallback: open in a new tab so the user can save manually
      window.open(video.videoURL, '_blank', 'noopener');
    } finally {
      setDownloading(false);
    }
  };

  // Subscribe to auth resolution before loading private reaction/save state.
  useEffect(() => {
    let cancelled = false;

    const unsubscribe = onAuthStateChanged(auth, (user) => {
      if (!user || !video.id) {
        if (!cancelled) {
          setIsLiked(false);
          setIsDisliked(false);
          setIsSaved(false);
        }
        return;
      }

      void Promise.all([
        getDoc(doc(db, 'users', user.uid, 'videoLikes', video.id)),
        getDoc(doc(db, 'users', user.uid, 'watchLater', video.id)),
      ]).then(([likeSnap, saveSnap]) => {
        if (cancelled) return;
        setIsLiked(likeSnap.exists() && likeSnap.data()?.value === 'like');
        setIsDisliked(likeSnap.exists() && likeSnap.data()?.value === 'dislike');
        setIsSaved(saveSnap.exists());
      }).catch(() => {
        // Non-fatal — the public video remains usable.
      });
    });

    return () => {
      cancelled = true;
      unsubscribe();
    };
  }, [video.id]);

  const handleLike = async () => {
    const uid = auth?.currentUser?.uid;
    const nextLiked = !isLiked;
    const wasDisliked = isDisliked;

    // A dislike→like switch adds one public like, not two.
    setIsLiked(nextLiked);
    if (wasDisliked) setIsDisliked(false);
    setLikeCount((count) => Math.max(0, count + (nextLiked ? 1 : -1)));

    try {
      if (!uid) throw new Error('Authentication required');
      const ref = doc(db, 'users', uid, 'videoLikes', video.id);
      const batch = writeBatch(db);
      if (nextLiked) {
        batch.set(ref, { value: 'like', videoId: video.id, createdAt: serverTimestamp() });
      } else {
        batch.delete(ref);
      }
      // The server transition ledger automatically replaces a prior dislike.
      appendVideoEngagement(batch, video.id, nextLiked ? 'like' : 'unlike');
      await batch.commit();
    } catch {
      setIsLiked(!nextLiked);
      if (wasDisliked) setIsDisliked(true);
      setLikeCount((count) => Math.max(0, count + (nextLiked ? -1 : 1)));
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
      if (!uid) throw new Error('Authentication required');
      const ref = doc(db, 'users', uid, 'videoLikes', video.id);
      const batch = writeBatch(db);
      if (nextDisliked) {
        batch.set(ref, { value: 'dislike', videoId: video.id, createdAt: serverTimestamp() });
      } else {
        batch.delete(ref);
      }
      // The server transition ledger automatically replaces a prior like.
      appendVideoEngagement(batch, video.id, nextDisliked ? 'dislike' : 'undislike');
      await batch.commit();
    } catch {
      setIsDisliked(!nextDisliked);
      if (wasLiked) { setIsLiked(true); setLikeCount((n) => n + 1); }
    }
  };

  const handleSaveModalClose = async () => {
    setShowSaveModal(false);
    const uid = auth?.currentUser?.uid;
    if (!uid) return;
    try {
      const snap = await getDoc(doc(db, 'users', uid, 'watchLater', video.id));
      setIsSaved(snap.exists());
    } catch {
      // non-fatal
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
      if (auth.currentUser) {
        await recordVideoEngagement(video.id, 'share').catch(() => {});
      }
    } catch {
      // User cancellation is not a completed share and must not be counted.
    }
  };

  return (
    <>
    <div className="flex items-center gap-2 flex-wrap">
      {/* Like / Dislike pill */}
      <div className="flex items-center bg-[rgb(var(--color-surface))] rounded-full overflow-hidden">
        <button
          onClick={handleLike}
          aria-label={isLiked ? 'Unlike' : 'Like'}
          aria-pressed={isLiked}
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
          aria-pressed={isDisliked}
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

      {/* Save / Watch Later → playlist picker */}
      <button
        onClick={() => setShowSaveModal(true)}
        aria-label="Save video"
        aria-pressed={isSaved}
        className={`flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-surface))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors ${
          isSaved ? 'text-[rgb(var(--color-primary))]' : 'text-[rgb(var(--color-text-primary))]'
        }`}
      >
        {isSaved ? <Check size={18} /> : <BookmarkPlus size={18} />}
        <span className="text-sm font-medium">{isSaved ? 'Saved' : 'Save'}</span>
      </button>

      {/* Super Thanks */}
      {onSuperThanks && (
        <button
          onClick={onSuperThanks}
          aria-label="Send Super Thanks"
          className="flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-surface))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors text-[rgb(var(--color-text-primary))]"
        >
          <Heart size={18} className="text-red-500" />
          <span className="text-sm font-medium hidden sm:inline">Thanks</span>
        </button>
      )}

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

      {/* Download (creator-enabled, mp4 only) */}
      {canDownload && (
        <button
          onClick={handleDownload}
          disabled={downloading}
          aria-label="Download video"
          className="flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-surface))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors text-[rgb(var(--color-text-primary))] disabled:opacity-50"
        >
          {downloading ? <Loader2 size={18} className="animate-spin" /> : <Download size={18} />}
          <span className="text-sm font-medium hidden sm:inline">{downloading ? 'Downloading…' : 'Download'}</span>
        </button>
      )}

      {/* Report */}
      <button
        type="button"
        onClick={() => setShowReportDialog(true)}
        className="flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-surface))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors text-[rgb(var(--color-text-primary))]"
        aria-label="Report video"
      >
        <Flag size={18} />
        <span className="text-sm font-medium hidden sm:inline">Report</span>
      </button>
    </div>

    {showSaveModal && (
      <SaveToPlaylistModal video={video} onClose={handleSaveModalClose} />
    )}
    {showReportDialog && (
      <ContentReportDialog
        contentType="video"
        contentId={video.id}
        contentCreatorId={video.creatorId}
        title="video"
        onClose={() => setShowReportDialog(false)}
      />
    )}
    </>
  );
};

export default VideoEngagement;
