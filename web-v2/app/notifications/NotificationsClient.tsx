'use client';

import { useState, useEffect, useCallback } from 'react';
import Link from 'next/link';
import { Bell, Check, CheckCheck, Trash2, Video, Heart, MessageCircle, UserPlus, DollarSign, Trophy, AlertCircle } from 'lucide-react';
import {
  collection,
  query,
  where,
  orderBy,
  limit,
  onSnapshot,
  doc,
  updateDoc,
  deleteDoc,
  writeBatch,
  type QueryDocumentSnapshot,
  type DocumentData,
} from 'firebase/firestore';
import { onAuthStateChanged, type User } from 'firebase/auth';
import { db, auth } from '@/lib/firebase/config';

interface NotificationDoc {
  id: string;
  userId: string;
  type: string;
  title: string;
  body: string;
  link: string;
  thumbnailURL: string;
  isRead: boolean;
  createdAt: Date | null;
}

const PAGE_SIZE = 50;

function timeAgo(date: Date | null): string {
  if (!date) return '';
  const secs = Math.floor((Date.now() - date.getTime()) / 1000);
  if (secs < 60) return `${Math.max(1, secs)}s ago`;
  if (secs < 3600) return `${Math.floor(secs / 60)}m ago`;
  if (secs < 86400) return `${Math.floor(secs / 3600)}h ago`;
  if (secs < 604800) return `${Math.floor(secs / 86400)}d ago`;
  return date.toLocaleDateString();
}

function iconForType(type: string) {
  switch (type) {
    case 'new_video':
    case 'upload':
    case 'video_ready':
      return <Video className="h-5 w-5 text-blue-400" />;
    case 'like':
      return <Heart className="h-5 w-5 text-pink-400" />;
    case 'comment':
    case 'reply':
      return <MessageCircle className="h-5 w-5 text-green-400" />;
    case 'subscribe':
    case 'new_subscriber':
      return <UserPlus className="h-5 w-5 text-purple-400" />;
    case 'tip':
    case 'super_chat':
    case 'membership':
      return <DollarSign className="h-5 w-5 text-emerald-400" />;
    case 'milestone':
    case 'vs_match':
      return <Trophy className="h-5 w-5 text-yellow-400" />;
    case 'account_suspended':
    case 'strike':
      return <AlertCircle className="h-5 w-5 text-red-400" />;
    default:
      return <Bell className="h-5 w-5 text-gray-400" />;
  }
}

function mapDoc(d: QueryDocumentSnapshot<DocumentData>): NotificationDoc {
  const data = d.data();
  const ts = data.createdAt;
  return {
    id: d.id,
    userId: data.userId ?? '',
    type: data.type ?? 'general',
    title: data.title ?? '',
    body: data.message ?? data.body ?? '',
    link: data.link ?? data.deepLink ?? '',
    thumbnailURL: data.thumbnailURL ?? data.thumbnail ?? '',
    isRead: data.isRead ?? data.read ?? false,
    createdAt: ts && typeof ts.toDate === 'function' ? ts.toDate() : null,
  };
}

// Convert mychannel:// deep links to web routes; pass through web paths.
function resolveHref(link: string): string {
  if (!link) return '';
  if (link.startsWith('mychannel://video/')) return `/watch/${link.replace('mychannel://video/', '')}`;
  if (link.startsWith('mychannel://channel/')) return `/channels/${link.replace('mychannel://channel/', '')}`;
  if (link.startsWith('mychannel://home')) return '/';
  if (link.startsWith('http') || link.startsWith('/')) return link;
  return '';
}

export default function NotificationsClient() {
  const [user, setUser] = useState<User | null>(null);
  const [authReady, setAuthReady] = useState(false);
  const [items, setItems] = useState<NotificationDoc[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!auth) {
      setAuthReady(true);
      setLoading(false);
      return;
    }
    const unsub = onAuthStateChanged(auth, (u) => {
      setUser(u);
      setAuthReady(true);
    });
    return () => unsub();
  }, []);

  useEffect(() => {
    if (!authReady) return;
    if (!user || !db) {
      setLoading(false);
      setItems([]);
      return;
    }
    const q = query(
      collection(db, 'notifications'),
      where('userId', '==', user.uid),
      orderBy('createdAt', 'desc'),
      limit(PAGE_SIZE),
    );
    const unsub = onSnapshot(
      q,
      (snap) => {
        setItems(snap.docs.map(mapDoc));
        setLoading(false);
      },
      (err) => {
        console.error('[notifications] snapshot error', err);
        setLoading(false);
      },
    );
    return () => unsub();
  }, [authReady, user]);

  const markRead = useCallback(async (id: string) => {
    if (!db) return;
    try {
      await updateDoc(doc(db, 'notifications', id), { isRead: true });
    } catch (e) {
      console.error('[notifications] markRead failed', e);
    }
  }, []);

  const remove = useCallback(async (id: string) => {
    if (!db) return;
    try {
      await deleteDoc(doc(db, 'notifications', id));
    } catch (e) {
      console.error('[notifications] delete failed', e);
    }
  }, []);

  const markAllRead = useCallback(async () => {
    if (!db) return;
    const unread = items.filter((n) => !n.isRead);
    if (unread.length === 0) return;
    setBusy(true);
    try {
      const batch = writeBatch(db);
      unread.forEach((n) => batch.update(doc(db, 'notifications', n.id), { isRead: true }));
      await batch.commit();
    } catch (e) {
      console.error('[notifications] markAllRead failed', e);
    } finally {
      setBusy(false);
    }
  }, [items]);

  const unreadCount = items.filter((n) => !n.isRead).length;

  if (authReady && !user) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-16 text-center">
        <Bell className="mx-auto mb-4 h-12 w-12 text-gray-500" />
        <h1 className="mb-2 text-xl font-semibold">Notifications</h1>
        <p className="mb-6 text-gray-400">Sign in to see your notifications.</p>
        <Link
          href="/login"
          className="inline-block rounded-full bg-white px-6 py-2 font-medium text-black transition hover:bg-gray-200"
        >
          Sign in
        </Link>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-2xl px-4 py-6">
      <header className="mb-4 flex items-center justify-between">
        <h1 className="flex items-center gap-2 text-xl font-semibold">
          <Bell className="h-6 w-6" />
          Notifications
          {unreadCount > 0 && (
            <span className="rounded-full bg-red-500 px-2 py-0.5 text-xs font-bold text-white">
              {unreadCount}
            </span>
          )}
        </h1>
        {unreadCount > 0 && (
          <button
            onClick={markAllRead}
            disabled={busy}
            className="flex items-center gap-1 rounded-full px-3 py-1.5 text-sm text-gray-300 transition hover:bg-white/10 disabled:opacity-50"
          >
            <CheckCheck className="h-4 w-4" />
            Mark all read
          </button>
        )}
      </header>

      {loading ? (
        <div className="space-y-3" aria-busy="true">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="flex animate-pulse gap-3 rounded-xl bg-white/5 p-4">
              <div className="h-10 w-10 rounded-full bg-white/10" />
              <div className="flex-1 space-y-2">
                <div className="h-3 w-3/4 rounded bg-white/10" />
                <div className="h-3 w-1/2 rounded bg-white/10" />
              </div>
            </div>
          ))}
        </div>
      ) : items.length === 0 ? (
        <div className="py-16 text-center">
          <Bell className="mx-auto mb-4 h-12 w-12 text-gray-500" />
          <p className="text-gray-400">You&apos;re all caught up. No notifications yet.</p>
        </div>
      ) : (
        <ul className="space-y-2">
          {items.map((n) => {
            const href = resolveHref(n.link);
            const Inner = (
              <div
                className={`flex items-start gap-3 rounded-xl p-4 transition ${
                  n.isRead ? 'bg-transparent hover:bg-white/5' : 'bg-white/[0.07] hover:bg-white/10'
                }`}
              >
                <div className="mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-white/10">
                  {iconForType(n.type)}
                </div>
                <div className="min-w-0 flex-1">
                  {n.title && <p className="truncate font-medium">{n.title}</p>}
                  {n.body && <p className="line-clamp-2 text-sm text-gray-400">{n.body}</p>}
                  <p className="mt-1 text-xs text-gray-500">{timeAgo(n.createdAt)}</p>
                </div>
                {n.thumbnailURL && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={n.thumbnailURL}
                    alt=""
                    className="h-12 w-20 shrink-0 rounded object-cover"
                    loading="lazy"
                  />
                )}
                <div className="flex shrink-0 flex-col gap-1">
                  {!n.isRead && (
                    <button
                      onClick={(e) => {
                        e.preventDefault();
                        markRead(n.id);
                      }}
                      title="Mark as read"
                      className="rounded-full p-1.5 text-gray-400 transition hover:bg-white/10 hover:text-white"
                    >
                      <Check className="h-4 w-4" />
                    </button>
                  )}
                  <button
                    onClick={(e) => {
                      e.preventDefault();
                      remove(n.id);
                    }}
                    title="Delete"
                    className="rounded-full p-1.5 text-gray-400 transition hover:bg-white/10 hover:text-red-400"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              </div>
            );

            return (
              <li key={n.id}>
                {href ? (
                  <Link href={href} onClick={() => !n.isRead && markRead(n.id)} className="block">
                    {Inner}
                  </Link>
                ) : (
                  Inner
                )}
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
