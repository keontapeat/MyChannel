'use client';

// Flicks Page - Short-Form Vertical Video Feed (TikTok/YouTube Shorts style)

import { useEffect, useRef, useState, useCallback } from 'react';
import FlickCard from '@/components/flicks/FlickCard';
import { useSwipeable } from 'react-swipeable';
import type { Flick } from '@/types/flick';
import { collection, query, orderBy, limit, getDocs, where } from 'firebase/firestore';
import { db } from '@/lib/firebase/config';

const FlicksPage = () => {
  const [flicks, setFlicks] = useState<Flick[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [activeFeed, setActiveFeed] = useState<'Flicks' | 'Following'>('Flicks');
  const [isLoading, setIsLoading] = useState(true);
  const containerRef = useRef<HTMLDivElement>(null);

  // Load Flicks from Firestore (falls back to mock if empty)
  const loadFlicks = useCallback(async () => {
    setIsLoading(true);
    try {
      const snap = await getDocs(
        query(
          collection(db, 'flicks'),
          where('isPublic', '==', true),
          orderBy('viewCount', 'desc'),
          limit(20)
        )
      );
      if (!snap.empty) {
        const loaded: Flick[] = snap.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            videoURL: data.videoURL ?? '',
            thumbnailURL: data.thumbnailURL ?? '',
            title: data.title ?? '',
            description: data.description ?? '',
            duration: data.duration ?? 30,
            viewCount: data.viewCount ?? 0,
            likeCount: data.likeCount ?? 0,
            commentCount: data.commentCount ?? 0,
            shareCount: data.shareCount ?? 0,
            createdAt: data.createdAt?.toDate?.() ?? new Date(),
            creator: {
              id: data.creatorId ?? '',
              username: data.creatorName ?? '',
              displayName: data.creatorName ?? 'Creator',
              profileImageURL: data.creatorAvatar ?? '',
              isVerified: false,
            },
            tags: data.tags ?? [],
            musicTrack: data.musicTrack ?? undefined,
          } as Flick;
        });
        setFlicks(loaded);
      } else {
        // Fallback seed data while Firestore collection populates
        setFlicks(Array.from({ length: 10 }, (_, i) => ({
          id: `seed-${i}`,
          videoURL: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
          thumbnailURL: 'https://i.ytimg.com/vi/aqz-KE-bpKQ/maxresdefault.jpg',
          title: `Flick #${i + 1}`,
          description: 'Short video',
          duration: 30,
          viewCount: 0,
          likeCount: 0,
          commentCount: 0,
          shareCount: 0,
          createdAt: new Date(),
          creator: {
            id: `creator-${i}`,
            username: `creator${i}`,
            displayName: `Creator ${i + 1}`,
            profileImageURL: 'https://i.ytimg.com/vi/aqz-KE-bpKQ/hqdefault.jpg',
            isVerified: false,
          },
          tags: [],
          musicTrack: undefined,
        } as Flick)));
      }
    } catch {
      // Network error — show empty state
      setFlicks([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadFlicks();
  }, [loadFlicks]);

  // Scroll to next/previous flick
  const scrollToFlick = (index: number) => {
    if (containerRef.current) {
      const flickHeight = window.innerHeight;
      containerRef.current.scrollTo({
        top: index * flickHeight,
        behavior: 'smooth',
      });
      setCurrentIndex(index);
    }
  };

  // Handle keyboard navigation
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'ArrowUp' && currentIndex > 0) {
        scrollToFlick(currentIndex - 1);
      } else if (e.key === 'ArrowDown' && currentIndex < flicks.length - 1) {
        scrollToFlick(currentIndex + 1);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [currentIndex, flicks.length]);

  // Swipe handlers
  const swipeHandlers = useSwipeable({
    onSwipedUp: () => {
      if (currentIndex < flicks.length - 1) {
        scrollToFlick(currentIndex + 1);
      }
    },
    onSwipedDown: () => {
      if (currentIndex > 0) {
        scrollToFlick(currentIndex - 1);
      }
    },
    trackMouse: false,
  });

  // Handle scroll events
  const handleScroll = () => {
    if (containerRef.current) {
      const scrollTop = containerRef.current.scrollTop;
      const flickHeight = window.innerHeight;
      const newIndex = Math.round(scrollTop / flickHeight);
      
      if (newIndex !== currentIndex && newIndex >= 0 && newIndex < flicks.length) {
        setCurrentIndex(newIndex);
      }
    }
  };

  if (isLoading) {
    return (
      <div className="fixed inset-0 flex items-center justify-center bg-black">
        <div className="text-white text-lg">Loading Flicks...</div>
      </div>
    );
  }

  const topCreators = Array.from(
    new Map(flicks.map((flick) => [flick.creator.id, flick.creator])).values()
  ).slice(0, 3);

  return (
    <>
      <header className="pointer-events-none fixed inset-x-0 top-0 z-40 flex items-center justify-center px-4 pt-[calc(env(safe-area-inset-top)+0.75rem)]">
        <div className="pointer-events-auto flex items-center gap-4 rounded-full bg-black/15 px-3 py-2 backdrop-blur-sm">
          {(['Flicks', 'Following'] as const).map((feed) => (
            <button
              key={feed}
              type="button"
              onClick={() => setActiveFeed(feed)}
              aria-pressed={activeFeed === feed}
              className={`relative py-1 text-[17px] font-semibold tracking-tight transition-colors ${
                activeFeed === feed ? 'text-white' : 'text-white/60'
              }`}
            >
              {feed}
              {activeFeed === feed && (
                <span className="absolute inset-x-2 -bottom-1 h-0.5 rounded-full bg-white" />
              )}
            </button>
          ))}
          <div className="flex -space-x-2" aria-label="Creators in your feed">
            {topCreators.map((creator) => (
              <img
                key={creator.id}
                src={creator.profileImageURL}
                alt={creator.displayName}
                className="h-7 w-7 rounded-full border-2 border-white/90 object-cover"
              />
            ))}
          </div>
        </div>
      </header>

      <div
        className="fixed inset-0 overflow-y-scroll snap-y snap-mandatory bg-black scrollbar-hide"
        onScroll={handleScroll}
        {...swipeHandlers}
        ref={containerRef}
      >
        {flicks.map((flick, index) => (
          <div key={flick.id} className="h-dvh snap-start snap-always">
            <FlickCard
              flick={flick}
              isActive={index === currentIndex}
              isVisible={Math.abs(index - currentIndex) <= 1}
            />
          </div>
        ))}
      </div>
    </>
  );
};

export default FlicksPage;

