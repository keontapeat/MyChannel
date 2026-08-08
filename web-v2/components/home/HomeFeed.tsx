'use client';

// 🔥 Clean YouTube-style home feed.
// Thin sidebar + top nav (via MainLayout) + sticky category chips + a
// spacious grid of rounded thumbnails. Mirrors youtube.com/ layout and
// breathing room. Backed by the real VideoFeed (Firestore) data layer.

import { useState } from 'react';
import MainLayout from '@/components/layout/MainLayout';
import VideoFeed from '@/components/video/VideoFeed';
import type { VideoCategory } from '@/lib/firebase/services/video-service';

// Chip label -> video-service category. 'All' means no filter.
const CHIPS: { label: string; category: VideoCategory | 'all' }[] = [
  { label: 'All', category: 'all' },
  { label: 'Music', category: 'music' },
  { label: 'Gaming', category: 'gaming' },
  { label: 'News', category: 'news' },
  { label: 'Sports', category: 'sports' },
  { label: 'Education', category: 'education' },
  { label: 'Technology', category: 'technology' },
  { label: 'Comedy', category: 'comedy' },
  { label: 'Lifestyle', category: 'lifestyle' },
  { label: 'Entertainment', category: 'entertainment' },
];

export default function HomeFeed() {
  const [active, setActive] = useState(0);
  const selected = CHIPS[active];

  return (
    <MainLayout>
      {/* Sticky category chips — flush under the fixed TopNav */}
      <div className="sticky top-0 z-20 border-b border-[rgb(var(--color-border))] bg-[rgb(var(--color-background))]/95 backdrop-blur">
        <div
          className="scrollbar-hide flex snap-x gap-2 overflow-x-auto px-3 py-2.5 sm:px-4"
          role="toolbar"
          aria-label="Filter videos by category"
        >
          {CHIPS.map((chip, i) => {
            const isActive = i === active;
            return (
              <button
                key={chip.label}
                onClick={() => setActive(i)}
                aria-pressed={isActive}
                className={`min-h-9 flex-shrink-0 snap-start rounded-lg px-3 text-[13px] font-medium transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-500 ${
                  isActive
                    ? 'bg-[rgb(var(--color-text-primary))] text-[rgb(var(--color-background))]'
                    : 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]'
                }`}
              >
                {chip.label}
              </button>
            );
          })}
        </div>
      </div>

      {/* Grid */}
      <div className="px-0 py-3 sm:px-4 sm:py-5">
        <VideoFeed
          key={selected.category}
          category={selected.category}
          emptyMessage="No videos here yet. Be the first to upload."
        />
      </div>
    </MainLayout>
  );
}
