'use client';

import React from 'react';
import Link from 'next/link';

interface ContentItem {
  id: string;
  title: string;
  thumbnail: string;
  subtitle?: string;
  badge?: string;
}

interface HorizontalSectionProps {
  title: string;
  items: ContentItem[];
  onSeeAll?: () => void;
  aspectRatio?: 'video' | 'portrait' | 'square';
}

export function HorizontalSection({ title, items, onSeeAll, aspectRatio = 'video' }: HorizontalSectionProps) {
  return (
    <section className="py-4 bg-white">
      <div className="flex items-center justify-between px-4 mb-3">
        <h2 className="text-lg font-bold text-gray-900">{title}</h2>
        {onSeeAll && (
          <button onClick={onSeeAll} className="text-sm font-medium text-red-600 hover:text-red-500">
            See all
          </button>
        )}
      </div>

      <div className="flex gap-3 overflow-x-auto scrollbar-hide px-4 pb-4">
        {items.map((item) => (
          <div key={item.id} className="flex flex-col flex-shrink-0 w-40 sm:w-48 group cursor-pointer">
            <div className={`relative bg-gray-200 rounded-lg overflow-hidden mb-2 ${
              aspectRatio === 'video' ? 'aspect-video' : 
              aspectRatio === 'portrait' ? 'aspect-[2/3]' : 'aspect-square'
            }`}>
              <img
                src={item.thumbnail}
                alt={item.title}
                className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
              />
              {item.badge && (
                <div className="absolute top-1 left-1 bg-red-600 text-white text-[10px] font-bold px-1.5 py-0.5 rounded">
                  {item.badge}
                </div>
              )}
            </div>
            <h3 className="text-sm font-medium text-gray-900 line-clamp-2 leading-snug">
              {item.title}
            </h3>
            {item.subtitle && (
              <p className="text-xs text-gray-500 mt-0.5 line-clamp-1">
                {item.subtitle}
              </p>
            )}
          </div>
        ))}
      </div>
    </section>
  );
}

// Pre-defined mocked sections for the Home page
const dummyMovies = Array.from({ length: 6 }).map((_, i) => ({
  id: `movie-${i}`,
  title: `Free Movie ${i + 1}`,
  subtitle: 'Action • 2024',
  thumbnail: `https://picsum.photos/seed/movie${i}/400/600`,
}));

const dummyTrending = Array.from({ length: 6 }).map((_, i) => ({
  id: `trend-${i}`,
  title: `Trending Hit ${i + 1}`,
  subtitle: '1M views • 2 days ago',
  thumbnail: `https://picsum.photos/seed/trend${i}/640/360`,
}));

const dummyLive = Array.from({ length: 6 }).map((_, i) => ({
  id: `live-${i}`,
  title: `Live Stream ${i + 1}`,
  subtitle: 'News Channel',
  badge: 'LIVE',
  thumbnail: `https://picsum.photos/seed/live${i}/640/360`,
}));

export function MinimalContentSections() {
  return (
    <div className="flex flex-col space-y-2 pb-8">
      <HorizontalSection 
        title="Trending Now" 
        items={dummyTrending} 
        onSeeAll={() => {}} 
        aspectRatio="video" 
      />
      <HorizontalSection 
        title="Free Movies" 
        items={dummyMovies} 
        onSeeAll={() => {}} 
        aspectRatio="portrait" 
      />
      <HorizontalSection 
        title="Live TV" 
        items={dummyLive} 
        onSeeAll={() => {}} 
        aspectRatio="video" 
      />
    </div>
  );
}
