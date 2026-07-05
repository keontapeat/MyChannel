'use client';

// Watch History — real per-user history from users/{uid}/watchHistory,
// recorded by WatchPageClient on every video view.

import MainLayout from '@/components/layout/MainLayout';
import SavedVideosFeed from '@/components/video/SavedVideosFeed';
import { History } from 'lucide-react';

export default function HistoryPage() {
  return (
    <MainLayout>
      <div className="max-w-[1600px] mx-auto px-4 sm:px-6 py-6">
        <div className="flex items-center gap-3 mb-6">
          <History size={24} className="text-[rgb(var(--color-text-primary))]" />
          <h1 className="text-2xl font-bold text-[rgb(var(--color-text-primary))]">Watch history</h1>
        </div>
        <SavedVideosFeed
          subcollection="watchHistory"
          orderByField="watchedAt"
          emptyMessage="Your watch history is empty."
          signInMessage="Sign in to see your watch history."
        />
      </div>
    </MainLayout>
  );
}
