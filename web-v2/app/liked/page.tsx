'use client';

// Liked Videos — real per-user likes from users/{uid}/videoLikes
// (value === 'like'), written by VideoEngagement's like/dislike handlers.

import MainLayout from '@/components/layout/MainLayout';
import SavedVideosFeed from '@/components/video/SavedVideosFeed';
import { ThumbsUp } from 'lucide-react';

export default function LikedPage() {
  return (
    <MainLayout>
      <div className="max-w-[1600px] mx-auto px-4 sm:px-6 py-6">
        <div className="flex items-center gap-3 mb-6">
          <ThumbsUp size={24} className="text-[rgb(var(--color-text-primary))]" />
          <h1 className="text-2xl font-bold text-[rgb(var(--color-text-primary))]">Liked videos</h1>
        </div>
        <SavedVideosFeed
          subcollection="videoLikes"
          orderByField="createdAt"
          filter={(data) => data.value === 'like'}
          emptyMessage="Videos you like will show up here."
          signInMessage="Sign in to see your liked videos."
        />
      </div>
    </MainLayout>
  );
}
