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
      <div className="sticky top-0 z-20 bg-[rgb(var(--color-background))]/95 backdrop-blur border-b border-[rgb(var(--color-border))]">
        <div className="flex gap-2 overflow-x-auto scrollbar-hide px-4 py-2.5">
          {CHIPS.map((chip, i) => {
            const isActive = i === active;
            return (
              <button
                key={chip.label}
                onClick={() => setActive(i)}
                className={`flex-shrink-0 rounded-lg px-3 py-[7px] text-[13px] font-medium transition-colors ${
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
      <div className="px-4 py-5">
        <VideoFeed
          key={selected.category}
          category={selected.category}
          emptyMessage="No videos here yet. Be the first to upload."
        />
      </div>
    </MainLayout>
  );
}
