'use client';

// Trending — YouTube-parity trending feed (most-viewed videos).

import MainLayout from '@/components/layout/MainLayout';
import VideoFeed from '@/components/video/VideoFeed';
import { TrendingUp } from 'lucide-react';

export default function TrendingPage() {
  return (
    <MainLayout>
      <div className="max-w-[1600px] mx-auto px-4 sm:px-6 py-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="w-12 h-12 rounded-full bg-[rgb(var(--color-primary))] flex items-center justify-center">
            <TrendingUp size={24} className="text-white" />
          </div>
          <h1 className="text-2xl font-bold text-[rgb(var(--color-text-primary))]">Trending</h1>
        </div>
        <VideoFeed category="all" emptyMessage="No trending videos yet." />
      </div>
    </MainLayout>
  );
}
