'use client';

import { useState, useEffect, useRef, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { CheckCircle, X, MoreVertical, Clock, Share2, RectangleHorizontal, Repeat, ListPlus, ListVideo, Trash2, Activity } from 'lucide-react';
import {
  doc, getDoc, collection, query, where, orderBy, limit, getDocs,
  updateDoc, increment, setDoc, serverTimestamp,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import VideoPlayerWithChapters from '@/components/video/VideoPlayerWithChapters';
import SuperThanksModal from '@/components/video/SuperThanksModal';
import SubscribeButton from '@/components/video/SubscribeButton';
import VideoEngagement from '@/components/video/VideoEngagement';
import VideoDescription from '@/components/video/VideoDescription';
import TranscriptPanel from '@/components/video/TranscriptPanel';
import MembershipModal from '@/components/video/MembershipModal';
import CommentSection from '@/components/comments/CommentSection';
import { useQueue, addToQueue } from '@/lib/hooks/useQueue';
import type { Video } from '@/types';

interface WatchPageClientProps {
  videoId: string;
}

// Parse a YouTube-style ?t= value: plain seconds ("90") or "1h2m3s" / "2m30s".
function parseTimeParam(raw: string | null): number {
  if (!raw) return 0;
  if (/^\d+$/.test(raw)) return parseInt(raw, 10);
  const m = raw.match(/^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$/);
  if (!m) return 0;
  return (parseInt(m[1] || '0', 10) * 3600) + (parseInt(m[2] || '0', 10) * 60) + parseInt(m[3] || '0', 10);
}

// ISO-8601 duration for schema.org VideoObject (e.g. 125 -> "PT2M5S")
function isoDuration(totalSeconds: number): string {
  const s = Math.max(0, Math.floor(totalSeconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  return `PT${h ? `${h}H` : ''}${m ? `${m}M` : ''}${sec || (!h && !m) ? `${sec}S` : ''}`;
}

// Relevance ranking for the suggested sidebar. Scores each candidate against the
// current video: same channel, shared category, tag overlap, recency, and a
// log-damped popularity term. Pure client-side so no extra Firestore index is needed.
function rankByRelevance(pool: Video[], current: Video): Video[] {
  const currentTags = new Set((current.tags ?? []).map((t) => t.toLowerCase()));
  const now = Date.now();

  const score = (v: Video): number => {
    let s = 0;
    if (v.creatorId && v.creatorId === current.creatorId) s += 5;
    if (v.category?.id && current.category?.id && v.category.id === current.category.id) s += 3;
    const overlap = (v.tags ?? []).reduce((n, t) => n + (currentTags.has(t.toLowerCase()) ? 1 : 0), 0);
    s += Math.min(overlap, 4); // cap tag contribution
    // Recency: up to +2 for videos in the last ~30 days, decaying
    const ageDays = Math.max(0, (now - new Date(v.createdAt).getTime()) / 86_400_000);
    s += Math.max(0, 2 - ageDays / 15);
    // Popularity: log-damped so a mega-viral video doesn't dominate
    s += Math.log10((v.viewCount ?? 0) + 10) / 2;
    return s;
  };

  return [...pool].sort((a, b) => score(b) - score(a));
}

// Skeleton while video loads
function PlayerSkeleton() {
  return (
    <div className="aspect-video w-full bg-[rgb(var(--color-surface))] rounded-xl animate-pulse" />
  );
}

// Compact suggested video row (YouTube sidebar style) — avatar + 3-dot menu
function SuggestedVideoRow({
  v,
  channelInfo,
}: {
  v: Video;
  channelInfo?: { displayName: string; profileImageURL: string; isVerified: boolean };
}) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [feedback, setFeedback] = useState('');
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!menuOpen) return;
    const onClick = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) setMenuOpen(false);
    };
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, [menuOpen]);

  const channelName = channelInfo?.displayName ?? (v as any).creator?.displayName ?? (v as any).channelName ?? 'Creator';
  const channelAvatar = channelInfo?.profileImageURL || (v as any).creator?.profileImageURL || `https://i.pravatar.cc/150?u=${v.creatorId}`;
  const dur = v.duration ?? 0;

  const saveWatchLater = async () => {
    setMenuOpen(false);
    const uid = auth?.currentUser?.uid;
    if (!uid) { setFeedback('Sign in to save'); setTimeout(() => setFeedback(''), 1500); return; }
    try {
      await setDoc(doc(db, 'users', uid, 'watchLater', v.id), {
        videoId: v.id, title: v.title, thumbnailURL: v.thumbnailURL, addedAt: serverTimestamp(),
      });
      setFeedback('Saved to Watch Later');
    } catch {
      setFeedback('Could not save');
    }
    setTimeout(() => setFeedback(''), 1500);
  };

  const shareVideo = async () => {
    setMenuOpen(false);
    const url = `${typeof window !== 'undefined' ? window.location.origin : ''}/watch/${v.id}`;
    try {
      if (typeof navigator !== 'undefined' && navigator.share) await navigator.share({ title: v.title, url });
      else { await navigator.clipboard.writeText(url); setFeedback('Link copied'); setTimeout(() => setFeedback(''), 1500); }
    } catch { /* cancelled */ }
  };

  const queueVideo = () => {
    setMenuOpen(false);
    const added = addToQueue({ id: v.id, title: v.title, thumbnailURL: v.thumbnailURL, channelName, duration: v.duration });
    setFeedback(added ? 'Added to queue' : 'Already in queue');
    setTimeout(() => setFeedback(''), 1500);
  };

  return (
    <div className="flex gap-2 group relative">
      <Link href={`/watch/${v.id}`} className="relative w-[168px] h-[94px] rounded-xl overflow-hidden bg-[rgb(var(--color-surface))] flex-shrink-0">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={v.thumbnailURL}
          alt={v.title}
          loading="lazy"
          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200"
        />
        {dur > 0 && (
          <div className="absolute bottom-1 right-1 px-1.5 py-0.5 bg-black/90 text-white text-[11px] font-semibold rounded">
            {Math.floor(dur / 60)}:{String(dur % 60).padStart(2, '0')}
          </div>
        )}
      </Link>

      <div className="flex-1 min-w-0">
        <Link href={`/watch/${v.id}`}>
          <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] line-clamp-2 mb-1 group-hover:text-[rgb(var(--color-primary))] transition-colors leading-tight pr-5">
            {v.title}
          </h3>
        </Link>
        <div className="flex items-center gap-1.5">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={channelAvatar} alt={channelName} loading="lazy" className="w-4 h-4 rounded-full" />
          <p className="text-[12px] text-[rgb(var(--color-text-secondary))] truncate">{channelName}</p>
          {channelInfo?.isVerified && (
            <CheckCircle size={11} className="text-[rgb(var(--color-text-secondary))] flex-shrink-0" fill="currentColor" />
          )}
        </div>
        <p className="text-[11px] text-[rgb(var(--color-text-tertiary))]">
          {(v.viewCount ?? 0).toLocaleString()} views
        </p>
      </div>

      {/* 3-dot menu */}
      <div className="absolute top-0 right-0" ref={menuRef}>
        <button
          onClick={() => setMenuOpen((o) => !o)}
          aria-label="More actions"
          className="p-1 rounded-full text-[rgb(var(--color-text-secondary))] opacity-0 group-hover:opacity-100 hover:bg-[rgb(var(--color-surface-hover))] transition-opacity"
        >
          <MoreVertical size={16} />
        </button>
        {menuOpen && (
          <div className="absolute right-0 top-7 w-44 bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] rounded-xl shadow-xl py-1.5 z-50">
            <button onClick={queueVideo} className="w-full flex items-center gap-2.5 px-3 py-2 text-[13px] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]">
              <ListPlus size={15} /> Add to queue
            </button>
            <button onClick={saveWatchLater} className="w-full flex items-center gap-2.5 px-3 py-2 text-[13px] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]">
              <Clock size={15} /> Save to Watch Later
            </button>
            <button onClick={shareVideo} className="w-full flex items-center gap-2.5 px-3 py-2 text-[13px] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]">
              <Share2 size={15} /> Share
            </button>
          </div>
        )}
      </div>

      {feedback && (
        <div className="absolute bottom-0 left-[176px] px-2 py-1 bg-black/80 text-white text-[11px] rounded">
          {feedback}
        </div>
      )}
    </div>
  );
}

export default function WatchPageClient({ videoId }: WatchPageClientProps) {
  const router = useRouter();
  const { queue, remove: removeFromQueue, clear: clearQueue, nextAfter } = useQueue();
  const [video, setVideo] = useState<Video | null>(null);
  const [loading, setLoading] = useState(true);
  const [suggested, setSuggested] = useState<Video[]>([]);
  const [channel, setChannel] = useState<{
    displayName: string;
    profileImageURL: string;
    isVerified: boolean;
    subscriberCount: number;
  } | null>(null);
  const [ageGate, setAgeGate] = useState(false); // blocked by age restriction
  const [showSuperThanks, setShowSuperThanks] = useState(false);
  const [showMembership, setShowMembership] = useState(false);
  const [showTranscript, setShowTranscript] = useState(false);
  const [autoplay, setAutoplay] = useState(true);
  const [sideFilter, setSideFilter] = useState<'all' | 'channel' | 'recent' | 'unwatched'>('all');
  const [channelMap, setChannelMap] = useState<Record<string, { displayName: string; profileImageURL: string; isVerified: boolean }>>({});
  const [watchedIds, setWatchedIds] = useState<Set<string>>(new Set());
  const [nextUp, setNextUp] = useState<Video | null>(null);
  const [countdown, setCountdown] = useState(5);
  const [startTime, setStartTime] = useState(0);
  const [theater, setTheater] = useState(false);
  const [loop, setLoop] = useState(false);
  const [showShortcuts, setShowShortcuts] = useState(false);

  // Restore theater preference
  useEffect(() => {
    if (typeof window === 'undefined') return;
    setTheater(localStorage.getItem('watch:theater') === '1');
  }, []);

  const toggleTheater = () => {
    setTheater((v) => {
      const next = !v;
      if (typeof window !== 'undefined') localStorage.setItem('watch:theater', next ? '1' : '0');
      return next;
    });
  };

  const toggleLoop = () => {
    setLoop((v) => {
      const next = !v;
      window.dispatchEvent(new CustomEvent('mychannel:player-loop', { detail: { enabled: next } }));
      return next;
    });
  };

  // 't' toggles theater mode, '?' shows the shortcuts help (ignored while typing)
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const el = e.target as HTMLElement | null;
      if (el && (el.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(el.tagName))) return;
      if (e.key === 't' || e.key === 'T') toggleTheater();
      if (e.key === '?') setShowShortcuts((v) => !v);
      if (e.key === 'Escape') setShowShortcuts(false);
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, []);

  // Read ?t= deep-link start time once on mount
  useEffect(() => {
    if (typeof window === 'undefined') return;
    const t = parseTimeParam(new URLSearchParams(window.location.search).get('t'));
    if (t > 0) setStartTime(t);
  }, []);

  // Dynamic document title (static export can't do per-video generateMetadata)
  useEffect(() => {
    if (video?.title) document.title = `${video.title} - MyChannel`;
  }, [video?.title]);

  // Docked mini-player on scroll
  const playerSlotRef = useRef<HTMLDivElement>(null);
  const [docked, setDocked] = useState(false);
  const [dockDismissed, setDockDismissed] = useState(false);

  // Restore autoplay preference
  useEffect(() => {
    const saved = typeof window !== 'undefined' ? localStorage.getItem('watch:autoplay') : null;
    if (saved !== null) setAutoplay(saved === '1');
  }, []);

  const toggleAutoplay = () => {
    setAutoplay((v) => {
      const next = !v;
      if (typeof window !== 'undefined') localStorage.setItem('watch:autoplay', next ? '1' : '0');
      return next;
    });
  };

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
          const vid = {
            id: snap.id,
            ...data,
            createdAt: data.createdAt?.toDate?.() ?? new Date(),
            updatedAt: data.updatedAt?.toDate?.() ?? new Date(),
          } as Video;

          // Age restriction gate — signed-out users cannot see 18+ content
          if ((data.ageRestricted === true) && !auth?.currentUser) {
            setAgeGate(true);
            setLoading(false);
            return;
          }

          setVideo(vid);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    load();
    return () => { cancelled = true; };
  }, [videoId]);

  // Fetch the creator's channel doc for accurate subscriber count / avatar / verified
  useEffect(() => {
    const creatorId = video?.creatorId;
    if (!creatorId) return;
    let cancelled = false;
    getDoc(doc(db, 'users', creatorId))
      .then((snap) => {
        if (cancelled || !snap.exists()) return;
        const d = snap.data();
        setChannel({
          displayName: d.displayName ?? d.username ?? 'Creator',
          profileImageURL: d.profileImageURL ?? '',
          isVerified: d.isVerified === true,
          subscriberCount: d.subscriberCount ?? 0,
        });
      })
      .catch(() => {});
    return () => { cancelled = true; };
  }, [video?.creatorId]);

  // Load suggested videos and rank by relevance to the current video
  useEffect(() => {
    if (!video) return;
    const loadSuggested = async () => {
      try {
        // Pull a popularity pool, then re-rank client-side (no extra composite index)
        const q = query(
          collection(db, 'videos'),
          where('isPublic', '==', true),
          orderBy('viewCount', 'desc'),
          limit(40)
        );
        const snap = await getDocs(q);
        const pool = snap.docs
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

        const ranked = rankByRelevance(pool, video).slice(0, 30);
        setSuggested(ranked);

        // Batch-fetch channel docs for accurate avatars / verified badges on rows
        const creatorIds = Array.from(new Set(ranked.map((v) => v.creatorId).filter(Boolean))).slice(0, 20);
        const entries = await Promise.all(
          creatorIds.map(async (cid) => {
            try {
              const cs = await getDoc(doc(db, 'users', cid));
              if (!cs.exists()) return null;
              const cd = cs.data();
              return [cid, {
                displayName: cd.displayName ?? cd.username ?? 'Creator',
                profileImageURL: cd.profileImageURL ?? '',
                isVerified: cd.isVerified === true,
              }] as const;
            } catch {
              return null;
            }
          })
        );
        const map: Record<string, { displayName: string; profileImageURL: string; isVerified: boolean }> = {};
        for (const e of entries) if (e) map[e[0]] = e[1];
        setChannelMap(map);
      } catch {
        // non-fatal
      }
    };
    loadSuggested();
  }, [video, videoId]);

  // Load the user's watched video IDs (for the "Unwatched" filter)
  useEffect(() => {
    const uid = auth?.currentUser?.uid;
    if (!uid) return;
    let cancelled = false;
    getDocs(query(collection(db, 'users', uid, 'watchHistory'), limit(200)))
      .then((snap) => { if (!cancelled) setWatchedIds(new Set(snap.docs.map((d) => d.id))); })
      .catch(() => {});
    return () => { cancelled = true; };
  }, [video]);

  // Dock the player when it scrolls out of view (keeps the same player instance playing)
  useEffect(() => {
    const el = playerSlotRef.current;
    if (!el || !video) return;
    const obs = new IntersectionObserver(
      ([entry]) => setDocked(!entry.isIntersecting),
      { threshold: 0, rootMargin: '-64px 0px 0px 0px' }
    );
    obs.observe(el);
    return () => obs.disconnect();
  }, [video]);

  // Apply the active sidebar filter to the ranked pool
  const displayedSuggested = useMemo(() => {
    let list = suggested;
    if (sideFilter === 'channel' && video?.creatorId) {
      list = list.filter((v) => v.creatorId === video.creatorId);
    } else if (sideFilter === 'recent') {
      list = [...list].sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    } else if (sideFilter === 'unwatched') {
      list = list.filter((v) => !watchedIds.has(v.id));
    }
    return list.slice(0, 15);
  }, [suggested, sideFilter, video?.creatorId, watchedIds]);

  const handleVideoEnded = () => {
    // Queue takes priority over recommendations for autoplay
    const queuedNextId = nextAfter(videoId);
    if (queuedNextId) {
      router.push(`/watch/${queuedNextId}`);
      return;
    }
    const next = displayedSuggested[0];
    if (autoplay && next) {
      setNextUp(next);
      setCountdown(5);
    }
  };

  // Autoplay countdown → navigate to the next video unless cancelled
  useEffect(() => {
    if (!nextUp) return;
    if (countdown <= 0) {
      router.push(`/watch/${nextUp.id}`);
      return;
    }
    const t = setTimeout(() => setCountdown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [nextUp, countdown, router]);

  const creatorName = channel?.displayName ?? (video as any)?.creator?.displayName ?? (video as any)?.channelName ?? 'Creator';
  const creatorAvatar = channel?.profileImageURL || (video as any)?.creator?.profileImageURL || `https://i.pravatar.cc/150?u=${video?.creatorId}`;
  const subscriberCount = channel?.subscriberCount ?? (video as any)?.creator?.subscriberCount ?? 0;
  const creatorVerified = channel?.isVerified ?? (video as any)?.creator?.isVerified ?? false;

  // Format upload date
  const uploadDate = video?.createdAt
    ? new Date(video.createdAt).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })
    : '';

  const showDocked = docked && !dockDismissed && !!video && !loading;

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14">

      {/* SEO: VideoObject structured data (client-injected for static export) */}
      {video && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              '@context': 'https://schema.org',
              '@type': 'VideoObject',
              name: video.title,
              description: video.description || video.title,
              thumbnailUrl: [video.thumbnailURL],
              uploadDate: new Date(video.createdAt).toISOString(),
              duration: isoDuration(video.duration ?? 0),
              contentUrl: video.videoURL,
              embedUrl: `https://www.mychannel.live/watch/${video.id}`,
              interactionStatistic: {
                '@type': 'InteractionCounter',
                interactionType: { '@type': 'https://schema.org/WatchAction' },
                userInteractionCount: video.viewCount ?? 0,
              },
              author: { '@type': 'Person', name: creatorName },
            }),
          }}
        />
      )}

      {/* Super Thanks modal */}
      {showSuperThanks && video && (
        <SuperThanksModal
          videoId={videoId}
          creatorId={video.creatorId}
          creatorName={creatorName}
          onClose={() => setShowSuperThanks(false)}
        />
      )}

      {/* Membership (Join) modal */}
      {showMembership && video && (
        <MembershipModal
          channelId={video.creatorId}
          channelName={creatorName}
          onClose={() => setShowMembership(false)}
        />
      )}

      {/* Keyboard shortcuts help */}
      {showShortcuts && (
        <div
          className="fixed inset-0 z-[60] flex items-center justify-center bg-black/60 p-4"
          onClick={(e) => e.target === e.currentTarget && setShowShortcuts(false)}
          role="dialog"
          aria-modal="true"
          aria-label="Keyboard shortcuts"
        >
          <div className="bg-[rgb(var(--color-background))] w-full max-w-[420px] rounded-2xl shadow-2xl overflow-hidden">
            <div className="flex items-center justify-between px-5 py-4 border-b border-[rgb(var(--color-border))]">
              <h2 className="text-[16px] font-bold text-[rgb(var(--color-text-primary))]">Keyboard shortcuts</h2>
              <button onClick={() => setShowShortcuts(false)} aria-label="Close" className="p-1.5 hover:bg-[rgb(var(--color-surface-hover))] rounded-full">
                <X size={18} className="text-[rgb(var(--color-text-secondary))]" />
              </button>
            </div>
            <div className="px-5 py-4 space-y-2 max-h-[60vh] overflow-y-auto">
              {([
                ['k / Space', 'Play / pause'],
                ['j / l', 'Back / forward 10s'],
                ['← / →', 'Back / forward 5s'],
                ['↑ / ↓', 'Volume up / down'],
                ['0 – 9', 'Jump to 0%–90%'],
                ['m', 'Mute'],
                ['f', 'Fullscreen'],
                ['c', 'Captions'],
                ['t', 'Theater mode'],
                ['Shift + . / ,', 'Speed up / down'],
                ['Double-tap (mobile)', 'Seek ±10s'],
                ['?', 'This help'],
              ] as const).map(([keys, desc]) => (
                <div key={keys} className="flex items-center justify-between gap-4">
                  <span className="text-[13px] text-[rgb(var(--color-text-secondary))]">{desc}</span>
                  <kbd className="text-[12px] font-medium text-[rgb(var(--color-text-primary))] bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded px-2 py-1 whitespace-nowrap">{keys}</kbd>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Age restriction gate */}
      {ageGate && (
        <div className="max-w-[640px] mx-auto px-4 py-20 text-center">
          <div className="text-6xl mb-4">🔞</div>
          <h2 className="text-[20px] font-bold text-[rgb(var(--color-text-primary))] mb-2">Age-restricted content</h2>
          <p className="text-[14px] text-[rgb(var(--color-text-secondary))] mb-6">
            This video may be inappropriate for some users. Sign in to verify your age and watch.
          </p>
          <Link
            href="/login"
            className="inline-block px-6 py-3 bg-[rgb(var(--color-primary))] text-white font-semibold rounded-full hover:opacity-90"
          >
            Sign in to watch
          </Link>
        </div>
      )}

      {!ageGate && (
        <div className="max-w-[1800px] mx-auto px-4 md:px-6 py-4 md:py-6">
        <div
          className="block lg:grid lg:gap-x-6"
          style={{
            gridTemplateColumns: 'minmax(0,1fr) 402px',
            gridTemplateAreas: theater ? `'player player' 'info sidebar'` : `'player sidebar' 'info sidebar'`,
          }}
        >

          {/* ── Player (own grid area so theater can span full width) ── */}
          <div
            style={{ gridArea: 'player' }}
            className={`min-w-0 ${theater ? 'lg:max-w-[calc((100vh_-_7rem)*1.7778)] lg:w-full lg:mx-auto' : ''}`}
          >
            {/* Player slot — preserves layout height while the player is docked */}
            <div ref={playerSlotRef} className="relative aspect-video w-full">
              {/* Ambient glow (blurred thumbnail behind the player) */}
              {video && !showDocked && (
                <div aria-hidden className="absolute -inset-x-10 -top-10 bottom-0 -z-10 overflow-hidden pointer-events-none">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={video.thumbnailURL} alt="" className="w-full h-full object-cover blur-3xl scale-110 opacity-30 saturate-150" />
                </div>
              )}
              {loading ? (
                <PlayerSkeleton />
              ) : video ? (
                <div
                  className={
                    showDocked
                      ? 'fixed bottom-4 right-4 z-40 w-[320px] sm:w-[400px] shadow-2xl rounded-xl overflow-hidden'
                      : 'relative w-full h-full'
                  }
                >
                  {showDocked && (
                    <div className="flex items-center justify-between px-2 py-1 bg-black/90">
                      <span className="text-white text-[11px] font-medium truncate pr-2">{video.title}</span>
                      <button
                        onClick={() => setDockDismissed(true)}
                        aria-label="Close mini player"
                        className="p-1 text-white/80 hover:text-white"
                      >
                        <X size={14} />
                      </button>
                    </div>
                  )}
                  <div className="aspect-video w-full bg-black rounded-xl overflow-hidden">
                    <VideoPlayerWithChapters
                      videoId={videoId}
                      src={video.videoURL}
                      poster={video.thumbnailURL}
                      duration={video.duration ?? 0}
                      creatorId={video.creatorId}
                      creatorName={creatorName}
                      videoTitle={video.title}
                      subtitles={video.subtitles}
                      startTime={startTime}
                      onSuperThanks={() => setShowSuperThanks(true)}
                      onEnded={handleVideoEnded}
                    />
                  </div>

                  {/* Theater + loop controls (top-right overlay) */}
                  {!showDocked && (
                    <div className="absolute top-2 right-2 flex items-center gap-1.5 z-10">
                      <button
                        onClick={() => window.dispatchEvent(new Event('mychannel:player-stats-toggle'))}
                        aria-label="Stats for nerds"
                        title="Stats for nerds"
                        className="p-1.5 rounded-full bg-black/55 text-white hover:bg-black/75 backdrop-blur-sm transition-colors"
                      >
                        <Activity size={15} />
                      </button>
                      <button
                        onClick={toggleLoop}
                        aria-label={loop ? 'Disable loop' : 'Loop video'}
                        aria-pressed={loop}
                        title={loop ? 'Loop on' : 'Loop'}
                        className={`p-1.5 rounded-full backdrop-blur-sm transition-colors ${loop ? 'bg-[rgb(var(--color-primary))] text-white' : 'bg-black/55 text-white hover:bg-black/75'}`}
                      >
                        <Repeat size={15} />
                      </button>
                      <button
                        onClick={toggleTheater}
                        aria-label={theater ? 'Exit theater mode' : 'Theater mode'}
                        aria-pressed={theater}
                        title="Theater mode (t)"
                        className="hidden lg:flex p-1.5 rounded-full bg-black/55 text-white hover:bg-black/75 backdrop-blur-sm transition-colors"
                      >
                        <RectangleHorizontal size={15} />
                      </button>
                    </div>
                  )}

                  {/* Autoplay countdown card */}
                  {nextUp && !showDocked && (
                    <div className="absolute inset-0 bg-black/80 rounded-xl flex flex-col items-center justify-center gap-3 px-4 text-center">
                      <p className="text-white/70 text-[12px]">Up next in {countdown}s</p>
                      <p className="text-white text-[15px] font-semibold line-clamp-2 max-w-[80%]">{nextUp.title}</p>
                      <div className="flex items-center gap-3 mt-1">
                        <button
                          onClick={() => { setNextUp(null); router.push(`/watch/${nextUp.id}`); }}
                          className="px-4 py-2 bg-white text-black text-[13px] font-semibold rounded-full hover:opacity-90"
                        >
                          Play now
                        </button>
                        <button
                          onClick={() => setNextUp(null)}
                          className="px-4 py-2 bg-white/15 text-white text-[13px] font-semibold rounded-full hover:bg-white/25"
                        >
                          Cancel
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              ) : (
                <div className="aspect-video w-full bg-[rgb(var(--color-surface))] rounded-xl flex items-center justify-center">
                  <p className="text-[rgb(var(--color-text-secondary))] text-sm">Video not found</p>
                </div>
              )}
            </div>
          </div>
          {/* ── /Player ── */}

          {/* ── Info area: title, channel, description, comments ── */}
          <div style={{ gridArea: 'info' }} className="min-w-0">

            {/* Hashtags above title (YouTube layout) */}
            {video && video.tags && video.tags.length > 0 && (
              <div className="flex flex-wrap gap-x-2 gap-y-1 mt-3">
                {video.tags.slice(0, 5).map((t) => (
                  <Link
                    key={t}
                    href={`/search?q=%23${encodeURIComponent(t)}`}
                    className="text-[13px] font-medium text-[rgb(var(--color-primary))] hover:underline"
                  >
                    #{t}
                  </Link>
                ))}
              </div>
            )}

            {/* Title */}
            <h1 className="text-[18px] md:text-xl font-semibold text-[rgb(var(--color-text-primary))] mt-2 mb-3 leading-snug">
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
                      {creatorVerified && (
                        <CheckCircle size={14} className="text-[rgb(var(--color-text-secondary))]" fill="currentColor" />
                      )}
                    </div>
                    <p className="text-[12px] text-[rgb(var(--color-text-secondary))]">
                      {subscriberCount > 0 ? `${subscriberCount.toLocaleString()} subscribers` : ''}
                    </p>
                  </div>
                  <SubscribeButton channelId={video.creatorId} />
                  <button
                    onClick={() => setShowMembership(true)}
                    className="px-4 py-2 rounded-full text-[13px] font-semibold border border-[rgb(var(--color-primary))] text-[rgb(var(--color-primary))] hover:bg-[rgb(var(--color-primary))]/10 transition-colors"
                  >
                    Join
                  </button>
                </div>

                {/* Engagement actions */}
                <VideoEngagement video={video} onSuperThanks={() => setShowSuperThanks(true)} />
              </div>
            )}

            {/* Description */}
            {video && (
              <VideoDescription
                videoId={videoId}
                description={video.description}
                viewCount={video.viewCount ?? 0}
                uploadDate={uploadDate}
                categoryName={video.category?.name}
                hasTranscript={(video.subtitles?.length ?? 0) > 0}
                onShowTranscript={() => setShowTranscript(true)}
              />
            )}

            {/* Transcript engagement panel */}
            {video && showTranscript && (video.subtitles?.length ?? 0) > 0 && (
              <TranscriptPanel
                subtitles={video.subtitles ?? []}
                onClose={() => setShowTranscript(false)}
              />
            )}

            {/* Comments */}
            {video && (
              <CommentSection videoId={videoId} commentCount={video.commentCount ?? 0} creatorId={video.creatorId} />
            )}
          </div>

          {/* ── Right column: suggested ── */}
          <aside style={{ gridArea: 'sidebar' }} className="w-full mt-6 lg:mt-0">

            {/* Queue panel */}
            {queue.length > 0 && (
              <div className="mb-4 border border-[rgb(var(--color-border))] rounded-xl overflow-hidden">
                <div className="flex items-center justify-between px-3 py-2.5 bg-[rgb(var(--color-surface))]">
                  <div className="flex items-center gap-2">
                    <ListVideo size={16} className="text-[rgb(var(--color-text-primary))]" />
                    <span className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))]">Queue · {queue.length}</span>
                  </div>
                  <button
                    onClick={clearQueue}
                    className="flex items-center gap-1 text-[12px] text-[rgb(var(--color-text-secondary))] hover:text-[rgb(var(--color-text-primary))]"
                  >
                    <Trash2 size={13} /> Clear
                  </button>
                </div>
                <div className="max-h-[280px] overflow-y-auto">
                  {queue.map((q) => {
                    const isCurrent = q.id === videoId;
                    return (
                      <div key={q.id} className={`flex gap-2 items-center px-2 py-1.5 group ${isCurrent ? 'bg-[rgb(var(--color-surface))]' : 'hover:bg-[rgb(var(--color-surface-hover))]'}`}>
                        <Link href={`/watch/${q.id}`} className="flex gap-2 items-center flex-1 min-w-0">
                          <div className="relative w-[80px] h-[46px] rounded-lg overflow-hidden bg-[rgb(var(--color-surface))] flex-shrink-0">
                            {/* eslint-disable-next-line @next/next/no-img-element */}
                            <img src={q.thumbnailURL} alt={q.title} loading="lazy" className="w-full h-full object-cover" />
                            {isCurrent && (
                              <div className="absolute inset-0 bg-black/50 flex items-center justify-center">
                                <span className="text-white text-[9px] font-bold uppercase tracking-wide">Now playing</span>
                              </div>
                            )}
                          </div>
                          <p className="text-[12px] text-[rgb(var(--color-text-primary))] line-clamp-2 leading-tight">{q.title}</p>
                        </Link>
                        <button
                          onClick={() => removeFromQueue(q.id)}
                          aria-label="Remove from queue"
                          className="p-1 rounded-full text-[rgb(var(--color-text-tertiary))] opacity-0 group-hover:opacity-100 hover:bg-[rgb(var(--color-surface-hover))] transition-opacity flex-shrink-0"
                        >
                          <X size={14} />
                        </button>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
            {/* Autoplay toggle */}
            <div className="flex items-center justify-between mb-3 px-1">
              <h2 className="text-[15px] font-semibold text-[rgb(var(--color-text-primary))]">Up next</h2>
              <label className="flex items-center gap-2 cursor-pointer select-none">
                <span className="text-[12px] text-[rgb(var(--color-text-secondary))]">Autoplay</span>
                <button
                  type="button"
                  role="switch"
                  aria-checked={autoplay}
                  aria-label="Toggle autoplay"
                  onClick={toggleAutoplay}
                  className={`relative w-9 h-5 rounded-full transition-colors ${autoplay ? 'bg-[rgb(var(--color-primary))]' : 'bg-[rgb(var(--color-border))]'}`}
                >
                  <span className={`absolute top-0.5 left-0.5 w-4 h-4 bg-white rounded-full transition-transform ${autoplay ? 'translate-x-4' : ''}`} />
                </button>
              </label>
            </div>

            {/* Filter chips */}
            <div className="flex gap-2 mb-3 overflow-x-auto no-scrollbar px-1">
              {([
                { key: 'all', label: 'All' },
                { key: 'channel', label: 'From this channel' },
                { key: 'recent', label: 'Recently uploaded' },
                { key: 'unwatched', label: 'Unwatched' },
              ] as const).map((chip) => (
                <button
                  key={chip.key}
                  onClick={() => setSideFilter(chip.key)}
                  className={`px-3 py-1.5 rounded-lg text-[12px] font-medium whitespace-nowrap transition-colors ${
                    sideFilter === chip.key
                      ? 'bg-[rgb(var(--color-text-primary))] text-[rgb(var(--color-background))]'
                      : 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]'
                  }`}
                >
                  {chip.label}
                </button>
              ))}
            </div>

            <div className="space-y-2">
              {displayedSuggested.map((v) => (
                <SuggestedVideoRow key={v.id} v={v} channelInfo={channelMap[v.creatorId]} />
              ))}
              {displayedSuggested.length === 0 && !loading && (
                <p className="text-[13px] text-[rgb(var(--color-text-secondary))] py-8 text-center">
                  {sideFilter === 'all' ? 'No suggestions yet' : 'Nothing here for this filter'}
                </p>
              )}
            </div>
          </aside>
        </div>
        </div>
      )}
    </div>
  );
}
