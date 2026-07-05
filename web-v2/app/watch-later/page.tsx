'use client';

// Watch Later — real per-user saved queue from users/{uid}/watchLater,
// written by SaveToPlaylistModal / VideoEngagement.

import MainLayout from '@/components/layout/MainLayout';
import SavedVideosFeed from '@/components/video/SavedVideosFeed';
import { Clock } from 'lucide-react';

export default function WatchLaterPage() {
  return (
    <MainLayout>
      <div className="max-w-[1600px] mx-auto px-4 sm:px-6 py-6">
        <div className="flex items-center gap-3 mb-6">
          <Clock size={24} className="text-[rgb(var(--color-text-primary))]" />
          <h1 className="text-2xl font-bold text-[rgb(var(--color-text-primary))]">Watch later</h1>
        </div>
        <SavedVideosFeed
          subcollection="watchLater"
          orderByField="addedAt"
          emptyMessage="You haven't saved any videos to watch later."
          signInMessage="Sign in to see your Watch Later queue."
        />
      </div>
    </MainLayout>
  );
}
