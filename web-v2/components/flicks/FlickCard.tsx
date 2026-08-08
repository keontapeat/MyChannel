'use client';

// FlickCard Component - Individual Flick with Video Player and Interactions

import { useRef, useEffect, useState } from 'react';
import { Heart, MessageCircle, Send, Music, CheckCircle, MoreHorizontal, Check, Bookmark, Smile } from 'lucide-react';
import { formatViewCount } from '@/lib/utils/format';
import type { Flick } from '@/types/flick';
import VideoPlayer from '@/components/video/VideoPlayer';
import {
  collection, addDoc, doc, getDoc, setDoc, deleteDoc, serverTimestamp,
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
  const sessionIdRef = useRef('');

  const isSeed = flick.id.startsWith('seed-');

  // Log an immutable semantic event; trusted Functions own aggregate counters.
  const logEvent = async (type: 'view' | 'share') => {
    const uid = auth?.currentUser?.uid;
    if (!uid || isSeed) return;
    if (!sessionIdRef.current) sessionIdRef.current = crypto.randomUUID();
    try {
      await addDoc(collection(db, 'flicks', flick.id, 'events'), {
        userId: uid,
        type,
        sessionId: sessionIdRef.current,
        createdAt: serverTimestamp(),
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
      } else {
        await deleteDoc(ref);
      }
    } catch {
      setIsFollowing(!next);
    }
  };

  return (
    <article className="relative h-dvh w-full overflow-hidden bg-black" aria-label={flick.title}>
      {isVisible && (
        <div className="absolute inset-0">
          <VideoPlayer
            src={flick.videoURL}
            poster={flick.thumbnailURL}
            autoplay={isActive}
            controls={false}
            fullBleed
          />
        </div>
      )}

      <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-black/35 via-transparent via-55% to-black/85" />

      <div className="absolute bottom-[calc(env(safe-area-inset-bottom)+1rem)] left-4 right-[5.6rem] z-10 space-y-2.5 sm:left-6 sm:right-28 sm:max-w-xl">
        <div className="flex items-center gap-2.5">
          <button type="button" className="shrink-0" aria-label={`Open ${flick.creator.displayName}`}>
            <img
              src={flick.creator.profileImageURL}
              alt=""
              className="h-10 w-10 rounded-full border-2 border-white object-cover shadow-lg"
            />
          </button>
          <div className="flex min-w-0 items-center gap-1 text-white">
            <span className="truncate text-[15px] font-bold">{flick.creator.username}</span>
            {flick.creator.isVerified && <CheckCircle size={14} className="fill-white text-black" />}
          </div>
          <button
            type="button"
            onClick={handleFollow}
            className="h-8 rounded-full border border-white/75 bg-black/25 px-4 text-sm font-semibold text-white backdrop-blur-md transition hover:bg-white/15"
          >
            {isFollowing ? 'Following' : 'Follow'}
          </button>
        </div>

        <button
          type="button"
          onClick={() => setShowDescription(!showDescription)}
          className="block max-w-full text-left"
          aria-expanded={showDescription}
        >
          <h2 className="line-clamp-1 text-[15px] font-semibold text-white">{flick.title}</h2>
          {flick.description && (
            <p className={`mt-1 text-sm leading-5 text-white/90 ${showDescription ? '' : 'line-clamp-2'}`}>
              {flick.description}
            </p>
          )}
        </button>

        {flick.tags.length > 0 && (
          <p className="line-clamp-1 text-sm font-semibold text-white/90">
            {flick.tags.slice(0, 3).map((tag) => `#${tag}`).join('  ')}
          </p>
        )}

        {flick.musicTrack && (
          <div className="flex items-center gap-2 text-xs font-medium text-white/85">
            <Music size={14} />
            <span className="truncate">{flick.musicTrack.title} · {flick.musicTrack.artist}</span>
          </div>
        )}

        <button
          type="button"
          onClick={handleComment}
          className="flex h-12 w-full items-center rounded-full border border-white/10 bg-[#17191e]/90 px-5 text-left text-[15px] text-white/65 shadow-xl backdrop-blur-xl"
        >
          <span>Add a comment…</span>
          <Smile size={18} className="ml-auto" />
        </button>
      </div>

      <nav className="absolute bottom-[calc(env(safe-area-inset-bottom)+8.5rem)] right-3 z-10 flex flex-col items-center gap-4 sm:right-5" aria-label="Flick actions">
        <ActionButton onClick={handleLike} label={formatViewCount(localLikeCount)} ariaLabel="Like">
          <Heart size={28} className={isLiked ? 'fill-red-500 text-red-500' : 'text-white'} />
        </ActionButton>
        <ActionButton onClick={handleComment} label={formatViewCount(flick.commentCount)} ariaLabel="Comments">
          <MessageCircle size={28} className="text-white" />
        </ActionButton>
        <ActionButton onClick={handleShare} label={shareFeedback ? 'Copied' : formatViewCount(flick.shareCount)} ariaLabel="Share">
          {shareFeedback ? <Check size={27} className="text-green-400" /> : <Send size={27} className="text-white" />}
        </ActionButton>
        <ActionButton onClick={() => {}} label="Save" ariaLabel="Save">
          <Bookmark size={27} className="text-white" />
        </ActionButton>
        <ActionButton onClick={() => {}} label="" ariaLabel="More options">
          <MoreHorizontal size={28} className="text-white" />
        </ActionButton>
        {flick.musicTrack && (
          <img
            src={flick.musicTrack.albumArt}
            alt={flick.musicTrack.title}
            className="h-11 w-11 animate-spin-slow rounded-xl border border-white/70 object-cover"
          />
        )}
      </nav>
    </article>
  );
};

interface ActionButtonProps {
  onClick: () => void;
  label: string;
  ariaLabel: string;
  children: React.ReactNode;
}

const ActionButton = ({ onClick, label, ariaLabel, children }: ActionButtonProps) => (
  <button type="button" onClick={onClick} className="group flex min-h-12 min-w-12 flex-col items-center justify-center gap-0.5" aria-label={ariaLabel}>
    <span className="flex h-11 w-11 items-center justify-center rounded-full bg-black/30 shadow-lg backdrop-blur-md transition group-hover:bg-black/45">
      {children}
    </span>
    {label && <span className="max-w-14 truncate text-[11px] font-semibold text-white drop-shadow">{label}</span>}
  </button>
);

export default FlickCard;

