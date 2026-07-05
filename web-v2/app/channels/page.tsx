'use client';

// Channels — browse top MyChannel creators (real Firestore data).

import MainLayout from '@/components/layout/MainLayout';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { BadgeCheck, Loader2, Users } from 'lucide-react';
import { userFirestoreService, UserFirestoreService } from '@/lib/firebase/services/UserFirestoreService';
import type { User } from '@/types';

export default function ChannelsPage() {
  const [channels, setChannels] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let mounted = true;
    userFirestoreService
      .fetchUsers(48)
      .then((users) => {
        if (mounted) setChannels(users);
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });
    return () => {
      mounted = false;
    };
  }, []);

  return (
    <MainLayout>
      <div className="max-w-[1600px] mx-auto px-4 sm:px-6 py-6">
        <div className="flex items-center gap-3 mb-6">
          <Users size={24} className="text-[rgb(var(--color-text-primary))]" />
          <h1 className="text-2xl font-bold text-[rgb(var(--color-text-primary))]">Channels</h1>
        </div>

        {loading ? (
          <div className="flex justify-center py-16">
            <Loader2 className="animate-spin text-[rgb(var(--color-text-secondary))]" size={28} />
          </div>
        ) : channels.length === 0 ? (
          <div className="py-16 text-center text-[rgb(var(--color-text-secondary))]">
            <p className="text-sm">No channels to show yet.</p>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6 gap-4">
            {channels.map((channel) => (
              <Link
                key={channel.id}
                href={`/profile/${channel.username}`}
                className="group flex flex-col items-center text-center p-4 rounded-xl hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
              >
                <img
                  src={channel.profileImageURL || `https://i.pravatar.cc/150?u=${channel.id}`}
                  alt={channel.displayName}
                  className="h-20 w-20 rounded-full object-cover"
                />
                <h3 className="mt-3 flex items-center gap-1 text-sm font-semibold text-[rgb(var(--color-text-primary))]">
                  {channel.displayName}
                  {channel.isVerified && <BadgeCheck size={14} className="text-blue-500" />}
                </h3>
                <p className="text-xs text-[rgb(var(--color-text-secondary))]">
                  {UserFirestoreService.formatSubscriberCount(channel.subscriberCount ?? 0)}
                </p>
              </Link>
            ))}
          </div>
        )}
      </div>
    </MainLayout>
  );
}
