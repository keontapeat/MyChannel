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
          thumbnailURL: `https://picsum.photos/seed/flick${i}/1080/1920`,
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
            profileImageURL: `https://i.pravatar.cc/150?img=${i + 1}`,
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

  return (
    <div
      className="fixed inset-0 overflow-y-scroll snap-y snap-mandatory bg-black scrollbar-hide"
      onScroll={handleScroll}
      {...swipeHandlers}
      ref={containerRef}
    >
      {flicks.map((flick, index) => (
        <div key={flick.id} className="snap-start snap-always">
          <FlickCard
            flick={flick}
            isActive={index === currentIndex}
            isVisible={Math.abs(index - currentIndex) <= 1}
          />
        </div>
      ))}

      {/* Scroll Indicator */}
      <div className="fixed right-4 top-1/2 -translate-y-1/2 flex flex-col gap-2 z-20">
        {flicks.map((_, index) => (
          <button
            key={index}
            onClick={() => scrollToFlick(index)}
            className={`w-2 h-2 rounded-full transition-all ${
              index === currentIndex
                ? 'bg-white h-4'
                : 'bg-white/40 hover:bg-white/60'
            }`}
          />
        ))}
      </div>
    </div>
  );
};

export default FlicksPage;

