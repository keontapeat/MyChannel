'use client';

// Clips — user-generated highlight clips from videos and live streams.
// YouTube parity: viewers create short clips from any video.

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { Scissors, Play, Share2, ChevronLeft, Loader2, Plus } from 'lucide-react';
import {
  collection, query, orderBy, limit, getDocs, where,
  startAfter, type QueryDocumentSnapshot, type DocumentData,
} from 'firebase/firestore';
import ClipCreatorModal from '@/components/video/ClipCreatorModal';
import { db, auth } from '@/lib/firebase/config';

interface Clip {
  id: string;
  title: string;
  thumbnailUrl: string;
  sourceVideoId: string;
  sourceVideoTitle: string;
  durationSeconds: number;
  viewCount: number;
  creatorId: string;
  creatorName: string;
  createdAt: Date;
}

const PAGE_SIZE = 24;

function formatDuration(secs: number): string {
  const m = Math.floor(secs / 60);
  const s = secs % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}

function timeAgo(date: Date): string {
  const secs = Math.floor((Date.now() - date.getTime()) / 1000);
  if (secs < 3600) return `${Math.floor(secs / 60)}m ago`;
  if (secs < 86400) return `${Math.floor(secs / 3600)}h ago`;
  return `${Math.floor(secs / 86400)}d ago`;
}

function ClipCard({ clip }: { clip: Clip }) {
  return (
    <div className="group relative rounded-xl overflow-hidden bg-[rgb(var(--color-surface))]">
      <Link href={`/watch/${clip.sourceVideoId}`} className="block">
        <div className="relative aspect-video bg-black overflow-hidden">
          {clip.thumbnailUrl ? (
            <img
              src={clip.thumbnailUrl}
              alt={clip.title}
              className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200"
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center bg-[rgb(var(--color-surface-hover))]">
              <Scissors size={28} className="text-[rgb(var(--color-text-tertiary))]" />
            </div>
          )}

          {/* Duration badge */}
          <div className="absolute bottom-1.5 right-1.5 px-1.5 py-0.5 bg-black/80 text-white text-[11px] font-semibold rounded">
            {formatDuration(clip.durationSeconds)}
          </div>

          {/* Play overlay */}
          <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 bg-black/30 transition-opacity">
            <div className="w-12 h-12 bg-black/70 rounded-full flex items-center justify-center">
              <Play size={20} fill="white" className="text-white ml-0.5" />
            </div>
          </div>

          {/* Clip badge */}
          <div className="absolute top-1.5 left-1.5 flex items-center gap-1 px-2 py-0.5 bg-[rgb(var(--color-primary))] text-white text-[10px] font-bold rounded-full">
            <Scissors size={9} />
            CLIP
          </div>
        </div>
      </Link>

      <div className="p-3">
        <Link href={`/watch/${clip.sourceVideoId}`}>
          <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] line-clamp-2 mb-1 hover:text-[rgb(var(--color-primary))] transition-colors leading-tight">
            {clip.title || 'Untitled clip'}
          </h3>
        </Link>
        <p className="text-[11px] text-[rgb(var(--color-text-secondary))] truncate mb-1">
          From: {clip.sourceVideoTitle}
        </p>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2 text-[11px] text-[rgb(var(--color-text-tertiary))]">
            <span>{clip.viewCount.toLocaleString()} views</span>
            <span>·</span>
            <span>{timeAgo(clip.createdAt)}</span>
          </div>
          <button
            onClick={(e) => {
              e.preventDefault();
              navigator.clipboard?.writeText(`${window.location.origin}/watch/${clip.sourceVideoId}`);
            }}
            className="p-1 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors opacity-0 group-hover:opacity-100"
            aria-label="Share clip"
          >
            <Share2 size={13} className="text-[rgb(var(--color-text-secondary))]" />
          </button>
        </div>
      </div>
    </div>
  );
}

export default function ClipsPageClient() {
  const [clips, setClips] = useState<Clip[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [lastDoc, setLastDoc] = useState<QueryDocumentSnapshot<DocumentData> | null>(null);
  const [filter, setFilter] = useState<'all' | 'mine'>('all');
  const [showCreateModal, setShowCreateModal] = useState(false);

  const uid = auth?.currentUser?.uid;

  const toClip = (d: any, id: string): Clip => ({
    id,
    title: d.title ?? '',
    thumbnailUrl: d.thumbnailUrl ?? d.thumbnailURL ?? '',
    sourceVideoId: d.sourceVideoId ?? d.videoId ?? '',
    sourceVideoTitle: d.sourceVideoTitle ?? '',
    durationSeconds: d.durationSeconds ?? 30,
    viewCount: d.viewCount ?? 0,
    creatorId: d.creatorId ?? '',
    creatorName: d.creatorName ?? 'Creator',
    createdAt: d.createdAt?.toDate?.() ?? new Date(),
  });

  useEffect(() => {
    setLoading(true);
    setClips([]);
    setLastDoc(null);
    setHasMore(true);

    const load = async () => {
      try {
        let q = query(
          collection(db, 'clips'),
          orderBy('createdAt', 'desc'),
          limit(PAGE_SIZE)
        );
        if (filter === 'mine' && uid) {
          q = query(
            collection(db, 'clips'),
            where('creatorId', '==', uid),
            orderBy('createdAt', 'desc'),
            limit(PAGE_SIZE)
          );
        }
        const snap = await getDocs(q);
        setClips(snap.docs.map((d) => toClip(d.data(), d.id)));
        setLastDoc(snap.docs[snap.docs.length - 1] ?? null);
        setHasMore(snap.docs.length === PAGE_SIZE);
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [filter, uid]);

  const loadMore = async () => {
    if (!lastDoc || loadingMore) return;
    setLoadingMore(true);
    try {
      const q = query(
        collection(db, 'clips'),
        orderBy('createdAt', 'desc'),
        startAfter(lastDoc),
        limit(PAGE_SIZE)
      );
      const snap = await getDocs(q);
      setClips((prev) => [...prev, ...snap.docs.map((d) => toClip(d.data(), d.id))]);
      setLastDoc(snap.docs[snap.docs.length - 1] ?? null);
      setHasMore(snap.docs.length === PAGE_SIZE);
    } finally {
      setLoadingMore(false);
    }
  };

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14">
      <div className="max-w-[1400px] mx-auto px-4 py-6 pb-24">
        {/* Create clip modal */}
        {showCreateModal && (
          <ClipCreatorModal
            videoId=""
            videoTitle="Create a clip"
            thumbnailUrl=""
            durationSeconds={300}
            currentTimeSeconds={0}
            onClose={() => setShowCreateModal(false)}
          />
        )}

        {/* Header */}
        <div className="flex items-center gap-3 mb-5">
          <Link href="/" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full">
            <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
          </Link>
          <div className="flex items-center gap-2.5 flex-1">
            <Scissors size={22} className="text-[rgb(var(--color-primary))]" />
            <div>
              <h1 className="text-[20px] font-bold text-[rgb(var(--color-text-primary))]">Clips</h1>
              <p className="text-[12px] text-[rgb(var(--color-text-secondary))]">Short highlights from videos and live streams</p>
            </div>
          </div>
          <button
            onClick={() => setShowCreateModal(true)}
            className="flex items-center gap-1.5 px-4 py-2 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full hover:opacity-90 transition-opacity"
          >
            <Plus size={15} />
            Create clip
          </button>
        </div>

        {/* Filter tabs */}
        <div className="flex gap-2 mb-5">
          {(['all', 'mine'] as const).map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-4 py-2 rounded-full text-[13px] font-semibold capitalize transition-all ${
                filter === f
                  ? 'bg-[rgb(var(--color-text-primary))] text-[rgb(var(--color-background))]'
                  : 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]'
              }`}
            >
              {f === 'all' ? 'All clips' : 'My clips'}
            </button>
          ))}
        </div>

        {/* Grid */}
        {loading ? (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
            {[...Array(12)].map((_, i) => (
              <div key={i} className="aspect-video bg-[rgb(var(--color-surface))] rounded-xl animate-pulse" />
            ))}
          </div>
        ) : clips.length === 0 ? (
          <div className="flex flex-col items-center py-24 gap-4">
            <Scissors size={48} className="text-[rgb(var(--color-text-tertiary))]" />
            <p className="text-[15px] font-semibold text-[rgb(var(--color-text-primary))]">No clips yet</p>
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">
              {filter === 'mine'
                ? 'You haven\'t created any clips yet. Clip moments from any video.'
                : 'No clips have been created yet. Be the first!'}
            </p>
          </div>
        ) : (
          <>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
              {clips.map((clip) => (
                <ClipCard key={clip.id} clip={clip} />
              ))}
            </div>
            {hasMore && (
              <div className="flex justify-center mt-8">
                <button
                  onClick={loadMore}
                  disabled={loadingMore}
                  className="flex items-center gap-2 px-6 py-3 bg-[rgb(var(--color-surface))] rounded-full text-[13px] font-semibold text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] disabled:opacity-50"
                >
                  {loadingMore && <Loader2 size={14} className="animate-spin" />}
                  {loadingMore ? 'Loading…' : 'Load more'}
                </button>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
