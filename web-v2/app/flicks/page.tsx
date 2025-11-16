'use client';

// Flicks Page - Short-Form Vertical Video Feed (TikTok/YouTube Shorts style)

import { useEffect, useRef, useState } from 'react';
import FlickCard from '@/components/flicks/FlickCard';
import { useSwipeable } from 'react-swipeable';
import type { Flick } from '@/types/flick';

const FlicksPage = () => {
  const [flicks, setFlicks] = useState<Flick[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  const containerRef = useRef<HTMLDivElement>(null);

  // Mock data - replace with actual API call
  useEffect(() => {
    const mockFlicks: Flick[] = Array.from({ length: 10 }, (_, i) => ({
      id: `flick-${i + 1}`,
      videoURL: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      thumbnailURL: `https://picsum.photos/seed/flick${i}/1080/1920`,
      title: `Amazing Flick #${i + 1}`,
      description: 'This is an amazing short video! Check it out 🔥',
      duration: 15 + Math.random() * 45, // 15-60 seconds
      viewCount: Math.floor(Math.random() * 1000000),
      likeCount: Math.floor(Math.random() * 50000),
      commentCount: Math.floor(Math.random() * 1000),
      shareCount: Math.floor(Math.random() * 500),
      createdAt: new Date(Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000),
      creator: {
        id: `creator-${i + 1}`,
        username: `creator${i + 1}`,
        displayName: `Creator ${i + 1}`,
        profileImageURL: `https://i.pravatar.cc/150?img=${i + 1}`,
        isVerified: Math.random() > 0.5,
      },
      tags: ['flicks', 'trending', 'viral'],
      musicTrack: {
        title: `Track ${i + 1}`,
        artist: 'Artist Name',
        albumArt: `https://picsum.photos/seed/music${i}/300/300`,
      },
    }));

    setFlicks(mockFlicks);
    setIsLoading(false);
  }, []);

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

