'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import {
  Bell, CheckCircle, ChevronDown,
} from 'lucide-react';
import {
  doc, getDoc, collection, query, where, orderBy, limit, getDocs,
  updateDoc, increment, setDoc, deleteDoc, serverTimestamp,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import VideoPlayer from '@/components/video/VideoPlayer';
import VideoEngagement from '@/components/video/VideoEngagement';
import CommentSection from '@/components/comments/CommentSection';
import type { Video } from '@/types';

interface WatchPageClientProps {
  videoId: string;
}

// Skeleton while video loads
function PlayerSkeleton() {
  return (
    <div className="aspect-video w-full bg-[rgb(var(--color-surface))] rounded-xl animate-pulse" />
  );
}

// Compact suggested video row (YouTube sidebar style)
function SuggestedVideoRow({ v }: { v: Partial<Video> & { id: string; title: string; thumbnailURL: string } }) {
  return (
    <Link href={`/watch/${v.id}`} className="flex gap-2 group">
      <div className="relative w-[168px] h-[94px] rounded-xl overflow-hidden bg-[rgb(var(--color-surface))] flex-shrink-0">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={v.thumbnailURL}
          alt={v.title}
          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200"
        />
        {(v.duration ?? 0) > 0 && (
          <div className="absolute bottom-1 right-1 px-1.5 py-0.5 bg-black/90 text-white text-[11px] font-semibold rounded">
            {Math.floor((v.duration ?? 0) / 60)}:{String((v.duration ?? 0) % 60).padStart(2, '0')}
          </div>
        )}
      </div>
      <div className="flex-1 min-w-0">
        <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] line-clamp-2 mb-1 group-hover:text-[rgb(var(--color-primary))] transition-colors leading-tight">
          {v.title}
        </h3>
        <p className="text-[12px] text-[rgb(var(--color-text-secondary))] truncate">
          {(v as any).channelName ?? (v as any).creator?.displayName ?? 'Creator'}
        </p>
        <p className="text-[11px] text-[rgb(var(--color-text-tertiary))]">
          {(v.viewCount ?? 0).toLocaleString()} views
        </p>
      </div>
    </Link>
  );
}

export default function WatchPageClient({ videoId }: WatchPageClientProps) {
  const [video, setVideo] = useState<Video | null>(null);
  const [loading, setLoading] = useState(true);
  const [showFullDescription, setShowFullDescription] = useState(false);
  const [isSubscribed, setIsSubscribed] = useState(false);
  const [suggested, setSuggested] = useState<Video[]>([]);

  // Record watch history + increment view count (once per mount)
  useEffect(() => {
    if (!videoId || videoId === '_fallback') return;

    const recordView = async () => {
      try {
        await updateDoc(doc(db, 'videos', videoId), {
          viewCount: increment(1),
        });

        const uid = auth?.currentUser?.uid;
        if (uid) {
          await setDoc(doc(db, 'users', uid, 'watchHistory', videoId), {
            videoId,
            watchedAt: serverTimestamp(),
          });
        }
      } catch {
        // non-fatal
      }
    };

    recordView();
  }, [videoId]);

  // Fetch video doc
  useEffect(() => {
    if (!videoId || videoId === '_fallback') {
      setLoading(false);
      return;
    }

    let cancelled = false;
    const load = async () => {
      try {
        const snap = await getDoc(doc(db, 'videos', videoId));
        if (cancelled) return;
        if (snap.exists()) {
          const data = snap.data();
          setVideo({
            id: snap.id,
            ...data,
            createdAt: data.createdAt?.toDate?.() ?? new Date(),
            updatedAt: data.updatedAt?.toDate?.() ?? new Date(),
          } as Video);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    load();
    return () => { cancelled = true; };
  }, [videoId]);

  // Load suggested videos (same category, excluding current)
  useEffect(() => {
    if (!video) return;
    const loadSuggested = async () => {
      try {
        const q = query(
          collection(db, 'videos'),
          where('isPublic', '==', true),
          orderBy('viewCount', 'desc'),
          limit(15)
        );
        const snap = await getDocs(q);
        const vids = snap.docs
          .map((d) => {
            const data = d.data();
            return {
              id: d.id,
              ...data,
              createdAt: data.createdAt?.toDate?.() ?? new Date(),
              updatedAt: data.updatedAt?.toDate?.() ?? new Date(),
            } as Video;
          })
          .filter((v) => v.id !== videoId);
        setSuggested(vids);
      } catch {
        // non-fatal
      }
    };
    loadSuggested();
  }, [video, videoId]);

  // Check subscription state
  useEffect(() => {
    if (!video?.creatorId) return;
    const uid = auth?.currentUser?.uid;
    if (!uid) return;
    let cancelled = false;
    getDoc(doc(db, 'users', uid, 'subscriptions', video.creatorId))
      .then((snap) => { if (!cancelled) setIsSubscribed(snap.exists()); })
      .catch(() => {});
    return () => { cancelled = true; };
  }, [video?.creatorId]);

  const handleSubscribe = async () => {
    if (!video?.creatorId) return;
    const uid = auth?.currentUser?.uid;
    const next = !isSubscribed;
    setIsSubscribed(next);
    if (!uid) return;
    try {
      const ref = doc(db, 'users', uid, 'subscriptions', video.creatorId);
      if (next) {
        await setDoc(ref, { channelId: video.creatorId, subscribedAt: serverTimestamp() });
        await updateDoc(doc(db, 'users', video.creatorId), { subscriberCount: increment(1) });
      } else {
        await deleteDoc(ref);
        await updateDoc(doc(db, 'users', video.creatorId), { subscriberCount: increment(-1) });
      }
    } catch {
      setIsSubscribed(!next);
    }
  };

  const creatorName = (video as any)?.creator?.displayName ?? (video as any)?.channelName ?? 'Creator';
  const creatorAvatar = (video as any)?.creator?.profileImageURL ?? `https://i.pravatar.cc/150?u=${video?.creatorId}`;
  const subscriberCount = (video as any)?.creator?.subscriberCount ?? 0;

  // Format upload date
  const uploadDate = video?.createdAt
    ? new Date(video.createdAt).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })
    : '';

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14">
      <div className="max-w-[1800px] mx-auto px-4 md:px-6 py-4 md:py-6">
        <div className="flex flex-col lg:flex-row gap-6">

          {/* ── Left column: player + info ── */}
          <div className="flex-1 min-w-0 max-w-[1280px]">

            {/* Player */}
            {loading ? (
              <PlayerSkeleton />
            ) : video ? (
              <div className="aspect-video w-full bg-black rounded-xl overflow-hidden">
                <VideoPlayer
                  src={video.videoURL}
                  poster={video.thumbnailURL}
                  autoplay={false}
                  controls
                />
              </div>
            ) : (
              <div className="aspect-video w-full bg-[rgb(var(--color-surface))] rounded-xl flex items-center justify-center">
                <p className="text-[rgb(var(--color-text-secondary))] text-sm">Video not found</p>
              </div>
            )}

            {/* Title */}
            <h1 className="text-[18px] md:text-xl font-semibold text-[rgb(var(--color-text-primary))] mt-3 mb-3 leading-snug">
              {loading ? (
                <span className="block h-6 w-3/4 bg-[rgb(var(--color-surface))] rounded animate-pulse" />
              ) : (
                video?.title ?? 'Video not found'
              )}
            </h1>

            {/* Channel row + actions */}
            {video && (
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4 pb-4 border-b border-[rgb(var(--color-border))]">
                {/* Channel */}
                <div className="flex items-center gap-3">
                  <Link href={`/profile/${video.creatorId}`}>
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={creatorAvatar}
                      alt={creatorName}
                      className="w-10 h-10 rounded-full hover:opacity-90 transition-opacity"
                    />
                  </Link>
                  <div>
                    <div className="flex items-center gap-1.5">
                      <Link
                        href={`/profile/${video.creatorId}`}
                        className="text-[14px] font-semibold text-[rgb(var(--color-text-primary))] hover:text-[rgb(var(--color-primary))] transition-colors"
                      >
                        {creatorName}
                      </Link>
                      {(video as any)?.creator?.isVerified && (
                        <CheckCircle size={14} className="text-[rgb(var(--color-text-secondary))]" fill="currentColor" />
                      )}
                    </div>
                    <p className="text-[12px] text-[rgb(var(--color-text-secondary))]">
                      {subscriberCount > 0 ? `${subscriberCount.toLocaleString()} subscribers` : ''}
                    </p>
                  </div>
                  <button
                    onClick={handleSubscribe}
                    className={`flex items-center gap-1.5 px-4 py-2 rounded-full text-[13px] font-medium transition-all ${
                      isSubscribed
                        ? 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]'
                        : 'bg-[rgb(var(--color-text-primary))] text-[rgb(var(--color-background))] hover:opacity-90'
                    }`}
                  >
                    {isSubscribed ? <><Bell size={15} /> Subscribed</> : 'Subscribe'}
                  </button>
                </div>

                {/* Engagement actions */}
                <VideoEngagement video={video} />
              </div>
            )}

            {/* Description */}
            {video && (
              <div className="bg-[rgb(var(--color-surface))] rounded-xl p-4 mb-6">
                <div className="flex items-center gap-2 text-[13px] font-medium text-[rgb(var(--color-text-primary))] mb-2">
                  <span>{(video.viewCount ?? 0).toLocaleString()} views</span>
                  {uploadDate && <><span>•</span><span>{uploadDate}</span></>}
                  {video.tags?.slice(0, 5).map((t) => (
                    <Link key={t} href={`/search?q=%23${t}`} className="text-[rgb(var(--color-primary))] hover:underline">
                      #{t}
                    </Link>
                  ))}
                </div>
                <div
                  className={`text-[13.5px] text-[rgb(var(--color-text-primary))] whitespace-pre-wrap leading-relaxed ${
                    !showFullDescription ? 'line-clamp-3' : ''
                  }`}
                >
                  {video.description || 'No description provided.'}
                </div>
                <button
                  onClick={() => setShowFullDescription((v) => !v)}
                  className="flex items-center gap-1 text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mt-2 hover:text-[rgb(var(--color-text-secondary))] transition-colors"
                >
                  {showFullDescription ? 'Show less' : 'Show more'}
                  <ChevronDown
                    size={15}
                    className={`transition-transform ${showFullDescription ? 'rotate-180' : ''}`}
                  />
                </button>
              </div>
            )}

            {/* Comments */}
            {video && (
              <CommentSection videoId={videoId} commentCount={video.commentCount ?? 0} />
            )}
          </div>

          {/* ── Right column: suggested ── */}
          <aside className="w-full lg:w-[402px] space-y-2 flex-shrink-0">
            {suggested.map((v) => (
              <SuggestedVideoRow key={v.id} v={v} />
            ))}
            {suggested.length === 0 && !loading && (
              <p className="text-[13px] text-[rgb(var(--color-text-secondary))] py-8 text-center">
                No suggestions yet
              </p>
            )}
          </aside>
        </div>
      </div>
    </div>
  );
}
