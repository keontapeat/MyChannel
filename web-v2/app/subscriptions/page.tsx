'use client';

// Subscriptions — latest videos from channels the user follows, resolved
// from users/{uid}/subscriptions (SubscribeButton) rather than the general feed.

import MainLayout from '@/components/layout/MainLayout';
import SubscriptionsFeed from '@/components/video/SubscriptionsFeed';
import ManageSubscriptionsRow from '@/components/video/ManageSubscriptionsRow';
import { Users } from 'lucide-react';

export default function SubscriptionsPage() {
  return (
    <MainLayout>
      <div className="max-w-[1600px] mx-auto">
        {/* Header */}
        <div className="flex items-center justify-between gap-3 px-4 sm:px-6 py-4 sm:py-5 border-b border-[rgb(var(--color-border))]">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-full bg-[rgb(var(--color-surface))] flex items-center justify-center flex-shrink-0">
              <Users size={18} className="text-[rgb(var(--color-text-primary))]" />
            </div>
            <h1 className="text-xl sm:text-2xl font-bold text-[rgb(var(--color-text-primary))]">Subscriptions</h1>
          </div>
        </div>

        {/* Subscribed channels row (avatars) */}
        <ManageSubscriptionsRow />

        {/* Latest videos feed */}
        <div className="px-4 sm:px-6 py-6">
          <SubscriptionsFeed />
        </div>
      </div>
    </MainLayout>
  );
}
