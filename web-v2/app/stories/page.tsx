'use client';

import { useState, useEffect, useCallback } from 'react';
import { X, ChevronLeft, ChevronRight, Loader2 } from 'lucide-react';
import {
  collection, query, where, orderBy, limit, getDocs,
  doc, getDoc, Timestamp,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import Sidebar from '@/components/layout/Sidebar';
import TopNav from '@/components/layout/TopNav';

interface Story {
  id: string;
  mediaUrl: string;
  caption: string;
  createdAt: Date;
  expiresAt: Date;
}

interface StoryGroup {
  channelId: string;
  channelName: string;
  channelAvatar: string;
  stories: Story[];
  hasUnread: boolean;
}

const STORY_DURATION_MS = 5000;

/**
 * Stories feed — ephemeral 24h content from subscribed creators.
 * YouTube Stories parity: channel bubble tray + full-screen viewer with
 * auto-advance, tap-to-advance, tap-left-to-previous, progress bars.
 */
export default function StoriesPage() {
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false);
  const [groups, setGroups] = useState<StoryGroup[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeGroupIdx, setActiveGroupIdx] = useState<number | null>(null);
  const [activeStoryIdx, setActiveStoryIdx] = useState(0);
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      try {
        const uid = auth?.currentUser?.uid;
        // Fetch stories from Firestore: stories collection, not expired
        const now = Timestamp.now();
        const q = query(
          collection(db, 'stories'),
          where('expiresAt', '>', now),
          orderBy('expiresAt', 'asc'),
          limit(100)
        );
        const snap = await getDocs(q);
        if (cancelled) return;

        // Group by channelId
        const groupMap = new Map<string, StoryGroup>();
        for (const d of snap.docs) {
          const data = d.data();
          const channelId: string = data.creatorId ?? data.channelId ?? '';
          if (!channelId) continue;

          if (!groupMap.has(channelId)) {
            // Fetch channel info
            let channelName = 'Creator';
            let channelAvatar = `https://i.pravatar.cc/150?u=${channelId}`;
            try {
              const userSnap = await getDoc(doc(db, 'users', channelId));
              if (userSnap.exists()) {
                const u = userSnap.data();
                channelName = u.displayName ?? u.username ?? channelName;
                channelAvatar = u.profileImageURL ?? channelAvatar;
              }
            } catch { /* non-fatal */ }

            groupMap.set(channelId, {
              channelId,
              channelName,
              channelAvatar,
              stories: [],
              hasUnread: true,
            });
          }

          groupMap.get(channelId)!.stories.push({
            id: d.id,
            mediaUrl: data.mediaUrl ?? data.imageUrl ?? '',
            caption: data.caption ?? data.text ?? '',
            createdAt: data.createdAt?.toDate?.() ?? new Date(),
            expiresAt: data.expiresAt?.toDate?.() ?? new Date(),
          });
        }

        if (!cancelled) setGroups(Array.from(groupMap.values()));
      } catch (e) {
        console.error(e);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    load();
    return () => { cancelled = true; };
  }, []);

  // Auto-advance timer
  useEffect(() => {
    if (activeGroupIdx === null) return;
    setProgress(0);
    const interval = setInterval(() => {
      setProgress((p) => {
        if (p >= 100) {
          advanceStory();
          return 0;
        }
        return p + (100 / (STORY_DURATION_MS / 100));
      });
    }, 100);
    return () => clearInterval(interval);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeGroupIdx, activeStoryIdx]);

  const advanceStory = useCallback(() => {
    if (activeGroupIdx === null) return;
    const group = groups[activeGroupIdx];
    if (!group) return;
    if (activeStoryIdx < group.stories.length - 1) {
      setActiveStoryIdx((i) => i + 1);
    } else if (activeGroupIdx < groups.length - 1) {
      setActiveGroupIdx((i) => (i ?? 0) + 1);
      setActiveStoryIdx(0);
    } else {
      setActiveGroupIdx(null);
    }
  }, [activeGroupIdx, activeStoryIdx, groups]);

  const prevStory = useCallback(() => {
    if (activeGroupIdx === null) return;
    if (activeStoryIdx > 0) {
      setActiveStoryIdx((i) => i - 1);
    } else if (activeGroupIdx > 0) {
      const prevGroup = groups[activeGroupIdx - 1];
      setActiveGroupIdx((i) => (i ?? 1) - 1);
      setActiveStoryIdx(prevGroup.stories.length - 1);
    }
  }, [activeGroupIdx, activeStoryIdx, groups]);

  const activeGroup = activeGroupIdx !== null ? groups[activeGroupIdx] : null;
  const activeStory = activeGroup?.stories[activeStoryIdx];

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      <TopNav onToggleSidebar={() => setIsSidebarCollapsed(!isSidebarCollapsed)} />
      <Sidebar isCollapsed={isSidebarCollapsed} />

      <main className={`pt-14 transition-all duration-200 ${isSidebarCollapsed ? 'pl-16' : 'pl-56'}`}>
        <div className="max-w-[1800px] mx-auto px-6 py-6">
          <h1 className="text-[22px] font-bold text-[rgb(var(--color-text-primary))] mb-6">Stories</h1>

          {loading ? (
            <div className="flex justify-center py-24">
              <Loader2 size={32} className="animate-spin text-[rgb(var(--color-text-secondary))]" />
            </div>
          ) : groups.length === 0 ? (
            <div className="text-center py-24">
              <p className="text-[rgb(var(--color-text-secondary))] text-lg mb-2">No stories yet</p>
              <p className="text-[rgb(var(--color-text-tertiary))] text-sm">
                Subscribe to creators to see their stories here
              </p>
            </div>
          ) : (
            /* Channel bubbles tray */
            <div className="flex gap-6 overflow-x-auto scrollbar-hide pb-4">
              {groups.map((group, idx) => (
                <button
                  key={group.channelId}
                  onClick={() => { setActiveGroupIdx(idx); setActiveStoryIdx(0); }}
                  className="flex flex-col items-center gap-2 flex-shrink-0"
                >
                  <div className={`p-[3px] rounded-full ${group.hasUnread ? 'bg-gradient-to-tr from-[rgb(var(--color-primary))] to-pink-500' : 'bg-[rgb(var(--color-border))]'}`}>
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={group.channelAvatar}
                      alt={group.channelName}
                      className="w-16 h-16 rounded-full object-cover border-2 border-[rgb(var(--color-background))]"
                    />
                  </div>
                  <span className="text-[11px] text-[rgb(var(--color-text-primary))] font-medium max-w-[72px] text-center truncate">
                    {group.channelName}
                  </span>
                </button>
              ))}
            </div>
          )}
        </div>
      </main>

      {/* Full-screen story viewer */}
      {activeGroup && activeStory && (
        <div className="fixed inset-0 z-50 bg-black flex items-center justify-center">

          {/* Progress bars */}
          <div className="absolute top-4 left-4 right-4 flex gap-1 z-10">
            {activeGroup.stories.map((_, i) => (
              <div key={i} className="flex-1 h-[2px] bg-white/30 rounded-full overflow-hidden">
                <div
                  className="h-full bg-white rounded-full transition-none"
                  style={{
                    width: `${i < activeStoryIdx ? 100 : i === activeStoryIdx ? progress : 0}%`,
                  }}
                />
              </div>
            ))}
          </div>

          {/* Channel header */}
          <div className="absolute top-8 left-4 right-4 flex items-center gap-3 z-10">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={activeGroup.channelAvatar}
              alt={activeGroup.channelName}
              className="w-9 h-9 rounded-full object-cover border-2 border-white"
            />
            <span className="text-white font-semibold text-[14px] flex-1">{activeGroup.channelName}</span>
            <button
              onClick={() => setActiveGroupIdx(null)}
              className="p-2 text-white hover:bg-white/10 rounded-full transition-colors"
              aria-label="Close"
            >
              <X size={20} />
            </button>
          </div>

          {/* Story media */}
          <div className="w-full max-w-sm h-full relative">
            {activeStory.mediaUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={activeStory.mediaUrl}
                alt={activeStory.caption}
                className="w-full h-full object-contain"
              />
            ) : (
              <div className="w-full h-full bg-gradient-to-br from-purple-900 to-blue-900 flex items-center justify-center">
                <p className="text-white text-[18px] font-semibold px-8 text-center">{activeStory.caption}</p>
              </div>
            )}

            {/* Tap zones: left = prev, right = next */}
            <div className="absolute inset-0 flex">
              <button
                className="flex-1 flex items-center justify-start pl-2 opacity-0 hover:opacity-100 transition-opacity"
                onClick={prevStory}
                aria-label="Previous story"
              >
                <ChevronLeft size={32} className="text-white drop-shadow" />
              </button>
              <button
                className="flex-1 flex items-center justify-end pr-2 opacity-0 hover:opacity-100 transition-opacity"
                onClick={advanceStory}
                aria-label="Next story"
              >
                <ChevronRight size={32} className="text-white drop-shadow" />
              </button>
            </div>
          </div>

          {/* Caption */}
          {activeStory.caption && (
            <div className="absolute bottom-8 left-0 right-0 px-8">
              <p className="text-white text-[15px] text-center bg-black/50 rounded-xl px-4 py-3">
                {activeStory.caption}
              </p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
