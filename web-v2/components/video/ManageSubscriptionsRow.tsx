'use client';

// Horizontal row of subscribed channel avatars — YouTube subscriptions-page parity.
// Click an avatar to jump straight to that channel.

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { collection, getDocs, doc, getDoc } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

interface SubscribedChannel {
  id: string;
  username: string;
  displayName: string;
  profileImageURL: string;
  isVerified: boolean;
}

export default function ManageSubscriptionsRow() {
  const [channels, setChannels] = useState<SubscribedChannel[]>([]);
  const [loading, setLoading] = useState(true);
  const [uid, setUid] = useState<string | null>(auth?.currentUser?.uid ?? null);

  useEffect(() => {
    const unsub = auth?.onAuthStateChanged?.((u) => setUid(u?.uid ?? null));
    return () => { if (typeof unsub === 'function') unsub(); };
  }, []);

  useEffect(() => {
    if (!uid) { setLoading(false); return; }
    let cancelled = false;

    (async () => {
      try {
        const subsSnap = await getDocs(collection(db, 'users', uid, 'subscriptions'));
        const channelIds = subsSnap.docs.map((d) => d.id);
        if (channelIds.length === 0) {
          if (!cancelled) { setChannels([]); setLoading(false); }
          return;
        }

        const results = await Promise.all(
          channelIds.slice(0, 30).map(async (id) => {
            try {
              const snap = await getDoc(doc(db, 'users', id));
              if (!snap.exists()) return null;
              const d = snap.data();
              return {
                id,
                username: d.username ?? id,
                displayName: d.displayName ?? d.username ?? 'Creator',
                profileImageURL: d.profileImageURL ?? '',
                isVerified: d.isVerified === true,
              } as SubscribedChannel;
            } catch {
              return null;
            }
          })
        );

        if (!cancelled) {
          setChannels(results.filter((c): c is SubscribedChannel => c !== null));
          setLoading(false);
        }
      } catch {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => { cancelled = true; };
  }, [uid]);

  if (!uid || (!loading && channels.length === 0)) return null;

  return (
    <div className="border-b border-[rgb(var(--color-border))] py-4">
      <div className="flex gap-4 overflow-x-auto scrollbar-hide px-4 sm:px-6">
        {loading
          ? Array.from({ length: 8 }).map((_, i) => (
              <div key={i} className="flex flex-col items-center gap-1.5 flex-shrink-0 w-16 animate-pulse">
                <div className="w-12 h-12 rounded-full bg-[rgb(var(--color-surface))]" />
                <div className="h-2.5 w-10 bg-[rgb(var(--color-surface))] rounded" />
              </div>
            ))
          : channels.map((channel) => (
              <Link
                key={channel.id}
                href={`/profile/${channel.username}`}
                className="flex flex-col items-center gap-1.5 flex-shrink-0 w-16 group"
              >
                <div className="relative">
                  <img
                    src={channel.profileImageURL || `https://i.pravatar.cc/150?u=${channel.id}`}
                    alt={channel.displayName}
                    className="w-12 h-12 rounded-full object-cover ring-2 ring-transparent group-hover:ring-[rgb(var(--color-primary))] transition-all"
                  />
                </div>
                <span className="text-[11px] text-[rgb(var(--color-text-secondary))] group-hover:text-[rgb(var(--color-text-primary))] truncate w-full text-center transition-colors">
                  {channel.displayName}
                </span>
              </Link>
            ))}
      </div>
    </div>
  );
}
