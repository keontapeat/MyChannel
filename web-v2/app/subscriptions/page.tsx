'use client';

// Subscriptions — latest videos from channels the user follows, resolved
// from users/{uid}/subscriptions (SubscribeButton) rather than the general feed.

import MainLayout from '@/components/layout/MainLayout';
import SubscriptionsFeed from '@/components/video/SubscriptionsFeed';
import { Users } from 'lucide-react';

export default function SubscriptionsPage() {
  return (
    <MainLayout>
      <div className="max-w-[1600px] mx-auto px-4 sm:px-6 py-6">
        <div className="flex items-center gap-3 mb-6">
          <Users size={24} className="text-[rgb(var(--color-text-primary))]" />
          <h1 className="text-2xl font-bold text-[rgb(var(--color-text-primary))]">Subscriptions</h1>
        </div>
        <SubscriptionsFeed />
      </div>
    </MainLayout>
  );
}
