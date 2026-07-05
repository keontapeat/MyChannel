'use client';

// SubscriptionsFeed — latest videos from channels the user actually follows,
// read from users/{uid}/subscriptions (written by SubscribeButton).

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { collection, getDocs } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import { videoService, type Video } from '@/lib/firebase/services/video-service';
import VideoCard from './VideoCard';

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

export default function SubscriptionsFeed() {
  const [uid, setUid] = useState<string | null>(auth?.currentUser?.uid ?? null);
  const [authResolved, setAuthResolved] = useState(!!auth?.currentUser);
  const [videos, setVideos] = useState<Video[]>([]);
  const [subscriptionCount, setSubscriptionCount] = useState(0);
  const [loading, setLoading] = useState(true);

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
        const subsSnap = await getDocs(collection(db, 'users', uid, 'subscriptions'));
        if (cancelled) return;
        const channelIds = subsSnap.docs.map((d) => d.id);
        setSubscriptionCount(channelIds.length);

        if (channelIds.length === 0) { setVideos([]); return; }
        const feed = await videoService.fetchVideosByCreators(channelIds, 48);
        if (!cancelled) setVideos(feed);
      } catch (err) {
        console.error(err);
        if (!cancelled) setVideos([]);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    load();
    return () => { cancelled = true; };
  }, [uid, authResolved]);

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
        <p className="text-sm text-[rgb(var(--color-text-secondary))] mb-4">Sign in to see videos from channels you follow.</p>
        <Link href="/login" className="inline-block px-5 py-2.5 bg-[rgb(var(--color-primary))] text-white text-sm font-semibold rounded-full hover:opacity-90">
          Sign in
        </Link>
      </div>
    );
  }

  if (subscriptionCount === 0) {
    return (
      <div className="py-16 text-center text-[rgb(var(--color-text-secondary))]">
        <p className="text-sm">You&apos;re not subscribed to any channels yet.</p>
        <Link href="/channels" className="inline-block mt-3 px-5 py-2.5 bg-[rgb(var(--color-primary))] text-white text-sm font-semibold rounded-full hover:opacity-90">
          Discover channels
        </Link>
      </div>
    );
  }

  if (videos.length === 0) {
    return (
      <div className="py-16 text-center text-[rgb(var(--color-text-secondary))]">
        <p className="text-sm">Subscribe to channels to see their latest videos here.</p>
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
