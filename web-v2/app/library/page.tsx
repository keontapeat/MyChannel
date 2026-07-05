'use client';

// Library — YouTube-style hub linking History, Watch Later, Liked, Playlists,
// plus a recent-videos feed.

import MainLayout from '@/components/layout/MainLayout';
import VideoFeed from '@/components/video/VideoFeed';
import Link from 'next/link';
import { History, Clock, ThumbsUp, PlaySquare, ChevronRight, Library as LibraryIcon } from 'lucide-react';

const SHORTCUTS = [
  { icon: History, label: 'History', href: '/history' },
  { icon: Clock, label: 'Watch later', href: '/watch-later' },
  { icon: ThumbsUp, label: 'Liked videos', href: '/liked' },
  { icon: PlaySquare, label: 'Playlists', href: '/playlists' },
];

export default function LibraryPage() {
  return (
    <MainLayout>
      <div className="max-w-[1600px] mx-auto px-4 sm:px-6 py-6">
        <div className="flex items-center gap-3 mb-6">
          <LibraryIcon size={24} className="text-[rgb(var(--color-text-primary))]" />
          <h1 className="text-2xl font-bold text-[rgb(var(--color-text-primary))]">Library</h1>
        </div>

        {/* Shortcuts */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-8">
          {SHORTCUTS.map(({ icon: Icon, label, href }) => (
            <Link
              key={href}
              href={href}
              className="flex items-center justify-between gap-3 p-4 rounded-xl border border-[rgb(var(--color-border))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
            >
              <span className="flex items-center gap-3">
                <Icon size={20} className="text-[rgb(var(--color-text-secondary))]" />
                <span className="text-sm font-medium text-[rgb(var(--color-text-primary))]">{label}</span>
              </span>
              <ChevronRight size={16} className="text-[rgb(var(--color-text-tertiary))]" />
            </Link>
          ))}
        </div>

        <h2 className="text-lg font-bold text-[rgb(var(--color-text-primary))] mb-4">Recent</h2>
        <VideoFeed category="all" emptyMessage="Your library is empty." />
      </div>
    </MainLayout>
  );
}
