'use client';

// SavedVideosFeed — generic feed for any per-user "saved video" subcollection
// (watch history, watch later, liked videos, single-playlist contents).
//
// Reads `users/{uid}/{subcollection}` ordered by a timestamp field, resolves
// the referenced video docs, and renders them as a YouTube-style grid while
// preserving the subcollection's own ordering (most-recent-first).

import { useEffect, useState } from 'react';
import Link from 'next/link';
import {
  collection, query, orderBy, limit, getDocs, type DocumentData, type QueryDocumentSnapshot,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import { videoService, type Video } from '@/lib/firebase/services/video-service';
import VideoCard from './VideoCard';

interface SavedVideosFeedProps {
  /** Subcollection under users/{uid}/... holding video references. */
  subcollection: string;
  /** Timestamp field to sort the subcollection by (most recent first). */
  orderByField: string;
  /** Optional client-side filter over the raw subcollection doc data. */
  filter?: (data: DocumentData) => boolean;
  /** Field on the subcollection doc holding the referenced video id (defaults to doc id). */
  videoIdField?: string;
  emptyMessage: string;
  signInMessage: string;
  maxItems?: number;
}

function toCardVideo(video: Video, index: number) {
  return {
    id: video.id,
    title: video.title,
    thumbnailURL: video.thumbnailURL,
    duration: videoService.formatDuration(video.duration),
    channel: video.creator?.displayName ?? 'Unknown',
    channelIcon: video.creator?.profileImageURL ?? '',
    views: videoService.formatViewCount(video.viewCount),
    timeAgo: videoService.formatTimeAgo(video.createdAt),
    isVerified: video.creator?.isVerified ?? false,
    channelId: video.creator?.id,
    index,
  };
}

export default function SavedVideosFeed({
  subcollection,
  orderByField,
  filter,
  videoIdField = 'videoId',
  emptyMessage,
  signInMessage,
  maxItems = 100,
}: SavedVideosFeedProps) {
  const [uid, setUid] = useState<string | null>(auth?.currentUser?.uid ?? null);
  const [authResolved, setAuthResolved] = useState(!!auth?.currentUser);
  const [videos, setVideos] = useState<Video[]>([]);
  const [loading, setLoading] = useState(true);

  // Wait for Firebase auth to resolve before deciding the user is signed out.
  useEffect(() => {
    const unsub = auth?.onAuthStateChanged?.((u) => { setUid(u?.uid ?? null); setAuthResolved(true); });
    return () => { if (typeof unsub === 'function') unsub(); };
  }, []);

  useEffect(() => {
    if (!authResolved) return;
    if (!uid) { setLoading(false); return; }
    let cancelled = false;

    const load = async () => {
      setLoading(true);
      try {
        const snap = await getDocs(
          query(collection(db, 'users', uid, subcollection), orderBy(orderByField, 'desc'), limit(maxItems))
        );
        if (cancelled) return;

        const rows = snap.docs
          .filter((d) => (filter ? filter(d.data()) : true))
          .map((d: QueryDocumentSnapshot<DocumentData>) => (d.data()[videoIdField] as string | undefined) ?? d.id);

        const ids = rows.filter(Boolean);
        if (ids.length === 0) { setVideos([]); return; }

        const fetched = await videoService.fetchVideosByIds(ids);
        const orderIndex = new Map(ids.map((id, i) => [id, i]));
        fetched.sort((a, b) => (orderIndex.get(a.id) ?? 0) - (orderIndex.get(b.id) ?? 0));

        if (!cancelled) setVideos(fetched);
      } catch (err) {
        console.error(err);
        if (!cancelled) setVideos([]);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    load();
    return () => { cancelled = true; };
  }, [uid, authResolved, subcollection, orderByField, videoIdField, maxItems]); // eslint-disable-line react-hooks/exhaustive-deps

  if (!authResolved || loading) {
    return (
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-3 2xl:grid-cols-4 gap-x-4 gap-y-9">
        {Array.from({ length: 8 }).map((_, i) => (
          <div key={i} className="animate-pulse">
            <div className="aspect-video bg-[rgb(var(--color-surface))] rounded-xl mb-3" />
            <div className="flex gap-3">
              <div className="w-9 h-9 rounded-full bg-[rgb(var(--color-surface))]" />
              <div className="flex-1 space-y-2">
                <div className="h-4 bg-[rgb(var(--color-surface))] rounded w-3/4" />
                <div className="h-3 bg-[rgb(var(--color-surface))] rounded w-1/2" />
              </div>
            </div>
          </div>
        ))}
      </div>
    );
  }

  if (!uid) {
    return (
      <div className="py-16 text-center">
        <p className="text-sm text-[rgb(var(--color-text-secondary))] mb-4">{signInMessage}</p>
        <Link href="/login" className="inline-block px-5 py-2.5 bg-[rgb(var(--color-primary))] text-white text-sm font-semibold rounded-full hover:opacity-90">
          Sign in
        </Link>
      </div>
    );
  }

  if (videos.length === 0) {
    return (
      <div className="py-16 text-center text-[rgb(var(--color-text-secondary))]">
        <p className="text-sm">{emptyMessage}</p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-3 2xl:grid-cols-4 gap-x-4 gap-y-9">
      {videos.map((video, i) => (
        <VideoCard key={video.id} video={toCardVideo(video, i)} index={i} />
      ))}
    </div>
  );
}
