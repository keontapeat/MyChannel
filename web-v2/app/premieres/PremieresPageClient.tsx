'use client';

// Premieres — YouTube parity
// Scheduled video releases with live countdown and live chat before the video starts

import { useState, useEffect, useCallback } from 'react';
import Link from 'next/link';
import { Bell, Calendar, ChevronLeft, Clock, Play, Users, Loader2, Tv } from 'lucide-react';
import {
  collection, query, where, orderBy, limit, getDocs,
  doc, updateDoc, setDoc, deleteDoc, serverTimestamp,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

interface Premiere {
  id: string;
  title: string;
  description: string;
  thumbnailURL: string;
  scheduledAt: Date;
  creatorId: string;
  creatorName: string;
  creatorAvatar: string;
  reminderCount: number;
  hasReminder: boolean;
  isLive: boolean;
  viewerCount: number;
}

function formatCountdown(targetDate: Date): string {
  const diff = targetDate.getTime() - Date.now();
  if (diff <= 0) return 'Starting now';
  const d = Math.floor(diff / 86400000);
  const h = Math.floor((diff % 86400000) / 3600000);
  const m = Math.floor((diff % 3600000) / 60000);
  const s = Math.floor((diff % 60000) / 1000);
  if (d > 0) return `${d}d ${h}h ${m}m`;
  if (h > 0) return `${h}h ${m}m ${s}s`;
  return `${m}m ${s}s`;
}

function CountdownBadge({ scheduledAt }: { scheduledAt: Date }) {
  const [text, setText] = useState(formatCountdown(scheduledAt));

  useEffect(() => {
    const interval = setInterval(() => setText(formatCountdown(scheduledAt)), 1000);
    return () => clearInterval(interval);
  }, [scheduledAt]);

  return (
    <div className="flex items-center gap-1.5 px-2.5 py-1 bg-red-500 text-white text-[11px] font-bold rounded-full">
      <Clock size={11} />
      {text}
    </div>
  );
}

function PremiereCard({ premiere, onReminder }: {
  premiere: Premiere;
  onReminder: (id: string, set: boolean) => void;
}) {
  const isPast = premiere.scheduledAt.getTime() < Date.now();
  const isImminent = !isPast && premiere.scheduledAt.getTime() - Date.now() < 600000; // < 10 min

  return (
    <div className="bg-[rgb(var(--color-surface))] rounded-2xl border border-[rgb(var(--color-border))] overflow-hidden">
      {/* Thumbnail */}
      <div className="relative aspect-video bg-black">
        {premiere.thumbnailURL ? (
          <img src={premiere.thumbnailURL} alt={premiere.title} className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full flex items-center justify-center bg-[rgb(var(--color-surface-hover))]">
            <Tv size={40} className="text-[rgb(var(--color-text-tertiary))]" />
          </div>
        )}

        {/* Overlay badges */}
        <div className="absolute top-2 left-2 flex flex-wrap gap-1.5">
          {premiere.isLive ? (
            <div className="flex items-center gap-1 px-2.5 py-1 bg-red-600 text-white text-[11px] font-bold rounded-full">
              <span className="w-1.5 h-1.5 bg-white rounded-full animate-pulse" />
              LIVE
            </div>
          ) : isPast ? (
            <div className="px-2.5 py-1 bg-black/70 text-white text-[11px] font-bold rounded-full">
              Premiered
            </div>
          ) : (
            <div className="flex items-center gap-1 px-2.5 py-1 bg-black/70 text-white text-[11px] font-semibold rounded-full">
              <Play size={10} fill="currentColor" />
              PREMIERE
            </div>
          )}
          {isImminent && !premiere.isLive && (
            <CountdownBadge scheduledAt={premiere.scheduledAt} />
          )}
        </div>

        {/* Viewer count if live */}
        {premiere.isLive && premiere.viewerCount > 0 && (
          <div className="absolute bottom-2 right-2 flex items-center gap-1 px-2 py-1 bg-black/70 text-white text-[11px] rounded-full">
            <Users size={10} />
            {premiere.viewerCount.toLocaleString()} watching
          </div>
        )}

        {/* Play overlay for past premieres */}
        {isPast && (
          <Link
            href={`/watch/${premiere.id}`}
            className="absolute inset-0 flex items-center justify-center bg-black/30 opacity-0 hover:opacity-100 transition-opacity"
          >
            <div className="w-14 h-14 bg-black/80 rounded-full flex items-center justify-center">
              <Play size={24} fill="white" className="text-white ml-1" />
            </div>
          </Link>
        )}
      </div>

      {/* Info */}
      <div className="p-4">
        {/* Channel */}
        <Link href={`/profile/${premiere.creatorId}`} className="flex items-center gap-2 mb-2">
          <img
            src={premiere.creatorAvatar || `https://i.pravatar.cc/150?u=${premiere.creatorId}`}
            alt={premiere.creatorName}
            className="w-7 h-7 rounded-full"
          />
          <span className="text-[12px] font-medium text-[rgb(var(--color-text-secondary))] hover:text-[rgb(var(--color-text-primary))]">
            {premiere.creatorName}
          </span>
        </Link>

        <h3 className="text-[15px] font-semibold text-[rgb(var(--color-text-primary))] mb-1 line-clamp-2">
          {premiere.title}
        </h3>
        {premiere.description && (
          <p className="text-[12px] text-[rgb(var(--color-text-secondary))] line-clamp-2 mb-3">
            {premiere.description}
          </p>
        )}

        {/* Scheduled time */}
        <div className="flex items-center gap-1.5 text-[12px] text-[rgb(var(--color-text-tertiary))] mb-3">
          <Calendar size={13} />
          {premiere.isLive ? 'Live now' : isPast
            ? `Premiered ${premiere.scheduledAt.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`
            : `${premiere.scheduledAt.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })} at ${premiere.scheduledAt.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}`
          }
        </div>

        {/* Actions */}
        <div className="flex items-center gap-2">
          {premiere.isLive ? (
            <Link
              href={`/watch/${premiere.id}`}
              className="flex-1 flex items-center justify-center gap-2 py-2 bg-red-600 text-white text-[13px] font-semibold rounded-full hover:opacity-90"
            >
              <span className="w-2 h-2 bg-white rounded-full animate-pulse" />
              Watch Live
            </Link>
          ) : isPast ? (
            <Link
              href={`/watch/${premiere.id}`}
              className="flex-1 flex items-center justify-center gap-2 py-2 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full hover:opacity-90"
            >
              <Play size={14} fill="currentColor" />
              Watch
            </Link>
          ) : (
            <>
              <button
                onClick={() => onReminder(premiere.id, !premiere.hasReminder)}
                className={`flex-1 flex items-center justify-center gap-2 py-2 text-[13px] font-semibold rounded-full transition-all ${
                  premiere.hasReminder
                    ? 'bg-[rgb(var(--color-surface-hover))] text-[rgb(var(--color-text-primary))] border border-[rgb(var(--color-border))]'
                    : 'bg-[rgb(var(--color-text-primary))] text-[rgb(var(--color-background))]'
                }`}
              >
                <Bell size={14} fill={premiere.hasReminder ? 'currentColor' : 'none'} />
                {premiere.hasReminder ? 'Reminder set' : 'Set reminder'}
              </button>
              {!isPast && !premiere.isLive && isImminent && (
                <div className="flex-shrink-0">
                  <CountdownBadge scheduledAt={premiere.scheduledAt} />
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}

export default function PremieresPageClient() {
  const [premieres, setPremieres] = useState<Premiere[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'upcoming' | 'live' | 'past'>('upcoming');

  useEffect(() => {
    const load = async () => {
      try {
        // Load scheduled/premier videos — status = 'premiere' or scheduledAt is set
        const now = new Date();
        const q = query(
          collection(db, 'videos'),
          where('isPremiere', '==', true),
          orderBy('scheduledAt', 'asc'),
          limit(50)
        );
        const snap = await getDocs(q);

        const uid = auth?.currentUser?.uid;
        let reminderSet: Set<string> = new Set();

        if (uid) {
          const reminderSnap = await getDocs(
            collection(db, 'users', uid, 'premiereReminders')
          );
          reminderSet = new Set(reminderSnap.docs.map((d) => d.id));
        }

        const items: Premiere[] = snap.docs.map((d) => {
          const data = d.data();
          const scheduledAt = data.scheduledAt?.toDate?.() ?? new Date();
          const isLive = data.status === 'live' || (scheduledAt <= now && scheduledAt > new Date(now.getTime() - 7200000));
          return {
            id: d.id,
            title: data.title ?? 'Untitled',
            description: data.description ?? '',
            thumbnailURL: data.thumbnailURL ?? '',
            scheduledAt,
            creatorId: data.creatorId ?? '',
            creatorName: data.channelName ?? data.creatorName ?? 'Creator',
            creatorAvatar: data.creatorAvatar ?? '',
            reminderCount: data.reminderCount ?? 0,
            hasReminder: reminderSet.has(d.id),
            isLive,
            viewerCount: data.viewerCount ?? 0,
          };
        });

        setPremieres(items);
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  const handleReminder = async (premiereId: string, set: boolean) => {
    const uid = auth?.currentUser?.uid;
    if (!uid) return;

    setPremieres((prev) =>
      prev.map((p) => p.id === premiereId ? { ...p, hasReminder: set } : p)
    );

    try {
      const ref = doc(db, 'users', uid, 'premiereReminders', premiereId);
      if (set) {
        await setDoc(ref, { premiereId, setAt: serverTimestamp() });
        await updateDoc(doc(db, 'videos', premiereId), { reminderCount: (premieres.find((p) => p.id === premiereId)?.reminderCount ?? 0) + 1 });
      } else {
        await deleteDoc(ref);
      }
    } catch (e) {
      console.error(e);
    }
  };

  const now = Date.now();
  const filtered = premieres.filter((p) => {
    const scheduledMs = p.scheduledAt.getTime();
    if (filter === 'live') return p.isLive;
    if (filter === 'upcoming') return !p.isLive && scheduledMs > now;
    if (filter === 'past') return !p.isLive && scheduledMs <= now;
    return true;
  });

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14">
      <div className="max-w-[800px] mx-auto px-4 py-6 pb-24">
        {/* Header */}
        <div className="flex items-center gap-3 mb-5">
          <Link href="/" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full">
            <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
          </Link>
          <div>
            <h1 className="text-[22px] font-bold text-[rgb(var(--color-text-primary))]">Premieres</h1>
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">Scheduled video premieres from creators you follow</p>
          </div>
        </div>

        {/* Filter tabs */}
        <div className="flex gap-2 mb-5 overflow-x-auto scrollbar-hide pb-1">
          {(['upcoming', 'live', 'past'] as const).map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-4 py-2 rounded-full text-[13px] font-semibold whitespace-nowrap capitalize transition-all ${
                filter === f
                  ? 'bg-[rgb(var(--color-text-primary))] text-[rgb(var(--color-background))]'
                  : 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]'
              }`}
            >
              {f === 'live' ? '🔴 Live' : f === 'upcoming' ? '📅 Upcoming' : '📼 Past'}
            </button>
          ))}
        </div>

        {loading ? (
          <div className="flex justify-center py-20">
            <Loader2 size={28} className="animate-spin text-[rgb(var(--color-text-tertiary))]" />
          </div>
        ) : filtered.length === 0 ? (
          <div className="text-center py-20">
            <Tv size={44} className="mx-auto mb-3 text-[rgb(var(--color-text-tertiary))]" />
            <p className="text-[15px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">
              No {filter} premieres
            </p>
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">
              {filter === 'upcoming'
                ? 'Follow more creators to see their scheduled premieres'
                : filter === 'live'
                ? 'No premieres are live right now'
                : 'No past premieres to show'}
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {filtered.map((premiere) => (
              <PremiereCard
                key={premiere.id}
                premiere={premiere}
                onReminder={handleReminder}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
