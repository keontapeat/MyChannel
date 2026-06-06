'use client';

import { useState, useEffect } from 'react';
import {
  MessageSquare, ThumbsUp, Trash2, CheckCircle, Flag, ChevronLeft,
  Search, Filter, Pin, Reply, X,
} from 'lucide-react';
import Link from 'next/link';
import {
  collection, query, where, orderBy, limit, getDocs, deleteDoc,
  doc, updateDoc, serverTimestamp, collectionGroup,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

type CommentFilter = 'all' | 'held' | 'likely_spam' | 'published';

interface StudioComment {
  id: string;
  videoId: string;
  videoTitle: string;
  videoThumb: string;
  userId: string;
  displayName: string;
  avatarURL: string;
  text: string;
  likeCount: number;
  createdAt: Date;
  isPinned: boolean;
  isHeld: boolean;
}

function timeAgo(d: Date) {
  const s = Math.floor((Date.now() - d.getTime()) / 1000);
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
}

export default function StudioCommentsClient() {
  const [comments, setComments] = useState<StudioComment[]>([]);
  const [filter, setFilter] = useState<CommentFilter>('all');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [replyingTo, setReplyingTo] = useState<string | null>(null);
  const [replyText, setReplyText] = useState('');

  useEffect(() => {
    const uid = auth?.currentUser?.uid;
    if (!uid) { setLoading(false); return; }
    let cancelled = false;

    const load = async () => {
      try {
        // Fetch creator's videos first
        const videosSnap = await getDocs(query(
          collection(db, 'videos'),
          where('creatorId', '==', uid),
          orderBy('createdAt', 'desc'),
          limit(20)
        ));

        const videoMeta: Record<string, { title: string; thumb: string }> = {};
        videosSnap.docs.forEach((d) => {
          const data = d.data();
          videoMeta[d.id] = { title: data.title ?? 'Untitled', thumb: data.thumbnailURL ?? '' };
        });

        // Fetch comments on each video
        const all: StudioComment[] = [];
        await Promise.all(videosSnap.docs.slice(0, 10).map(async (vd) => {
          try {
            const cSnap = await getDocs(query(
              collection(db, 'videos', vd.id, 'comments'),
              orderBy('createdAt', 'desc'),
              limit(30)
            ));
            cSnap.docs.forEach((cd) => {
              const d = cd.data();
              all.push({
                id: cd.id,
                videoId: vd.id,
                videoTitle: videoMeta[vd.id]?.title ?? '',
                videoThumb: videoMeta[vd.id]?.thumb ?? '',
                userId: d.userId ?? '',
                displayName: d.displayName ?? 'Anonymous',
                avatarURL: d.avatarURL ?? '',
                text: d.text ?? '',
                likeCount: d.likeCount ?? 0,
                createdAt: d.createdAt?.toDate?.() ?? new Date(),
                isPinned: d.isPinned ?? false,
                isHeld: false,
              });
            });
          } catch { /* skip */ }
        }));

        all.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
        if (!cancelled) setComments(all);
      } catch (e) {
        console.error(e);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    load();
    return () => { cancelled = true; };
  }, []);

  const handleDelete = async (c: StudioComment) => {
    try {
      await deleteDoc(doc(db, 'videos', c.videoId, 'comments', c.id));
      setComments((prev) => prev.filter((x) => x.id !== c.id));
    } catch (e) { console.error(e); }
  };

  const handlePin = async (c: StudioComment) => {
    try {
      await updateDoc(doc(db, 'videos', c.videoId, 'comments', c.id), {
        isPinned: !c.isPinned,
      });
      setComments((prev) => prev.map((x) => x.id === c.id ? { ...x, isPinned: !x.isPinned } : x));
    } catch (e) { console.error(e); }
  };

  const handleReplySubmit = async (c: StudioComment) => {
    if (!replyText.trim()) return;
    const uid = auth?.currentUser?.uid;
    const displayName = auth?.currentUser?.displayName ?? 'Creator';
    const avatarURL = auth?.currentUser?.photoURL ?? '';
    try {
      const { addDoc } = await import('firebase/firestore');
      await addDoc(collection(db, 'videos', c.videoId, 'comments'), {
        userId: uid,
        displayName,
        avatarURL,
        text: replyText.trim(),
        parentCommentId: c.id,
        createdAt: serverTimestamp(),
        likeCount: 0,
        replyCount: 0,
        isPinned: false,
      });
      setReplyText('');
      setReplyingTo(null);
    } catch (e) { console.error(e); }
  };

  const filtered = comments.filter((c) => {
    const matchSearch = c.text.toLowerCase().includes(search.toLowerCase()) ||
                        c.displayName.toLowerCase().includes(search.toLowerCase());
    const matchFilter = filter === 'all' || (filter === 'published' && !c.isHeld);
    return matchSearch && matchFilter;
  });

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      <div className="max-w-[900px] mx-auto">

        {/* Header */}
        <header className="sticky top-0 z-50 bg-[rgb(var(--color-background))]/95 backdrop-blur border-b border-[rgb(var(--color-border))] px-4 py-3 space-y-3">
          <div className="flex items-center gap-3">
            <Link href="/studio" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
              <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
            </Link>
            <MessageSquare size={20} className="text-yellow-500" />
            <div className="flex-1">
              <h1 className="text-[17px] font-bold text-[rgb(var(--color-text-primary))] leading-none">Comments</h1>
              <p className="text-[11px] text-[rgb(var(--color-text-secondary))]">{comments.length} total</p>
            </div>
          </div>

          {/* Search */}
          <div className="relative">
            <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[rgb(var(--color-text-tertiary))]" />
            <input
              placeholder="Search comments"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] pl-9 pr-8 py-2 text-[13px] rounded-xl border border-[rgb(var(--color-border))] focus:outline-none focus:border-[rgb(var(--color-primary))]"
            />
            {search && <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2"><X size={13} className="text-[rgb(var(--color-text-tertiary))]" /></button>}
          </div>

          {/* Filter tabs */}
          <div className="flex gap-2 overflow-x-auto scrollbar-hide">
            {(['all', 'published', 'held', 'likely_spam'] as CommentFilter[]).map((f) => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`px-3 py-1.5 rounded-full text-[12px] font-medium whitespace-nowrap capitalize transition-all ${
                  filter === f
                    ? 'bg-[rgb(var(--color-text-primary))] text-[rgb(var(--color-background))]'
                    : 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]'
                }`}
              >
                {f.replace('_', ' ')}
              </button>
            ))}
          </div>
        </header>

        <main className="px-4 py-4 pb-24 space-y-3">
          {loading ? (
            [...Array(5)].map((_, i) => (
              <div key={i} className="h-[110px] bg-[rgb(var(--color-surface))] rounded-xl animate-pulse" />
            ))
          ) : filtered.length === 0 ? (
            <div className="text-center py-16">
              <MessageSquare size={36} className="mx-auto mb-3 text-[rgb(var(--color-text-tertiary))]" />
              <p className="text-[14px] font-semibold text-[rgb(var(--color-text-primary))]">No comments yet</p>
              <p className="text-[12px] text-[rgb(var(--color-text-secondary))] mt-1">Comments on your videos will appear here</p>
            </div>
          ) : (
            filtered.map((c) => (
              <div key={c.id} className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-3 space-y-2">
                {/* Video context */}
                <Link href={`/watch/${c.videoId}`} className="flex items-center gap-2 pb-2 border-b border-[rgb(var(--color-border))] hover:opacity-80 transition-opacity">
                  <div className="w-10 h-6 rounded overflow-hidden bg-[rgb(var(--color-surface-hover))] flex-shrink-0">
                    {c.videoThumb && <img src={c.videoThumb} alt="" className="w-full h-full object-cover" />}
                  </div>
                  <span className="text-[11px] text-[rgb(var(--color-text-tertiary))] line-clamp-1">{c.videoTitle}</span>
                </Link>

                {/* Comment */}
                <div className="flex gap-2.5">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={c.avatarURL || `https://i.pravatar.cc/36?u=${c.id}`}
                    alt={c.displayName}
                    className="w-8 h-8 rounded-full flex-shrink-0"
                  />
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-0.5">
                      <span className="text-[12px] font-semibold text-[rgb(var(--color-text-primary))]">{c.displayName}</span>
                      {c.isPinned && <span className="text-[10px] text-[rgb(var(--color-primary))] font-medium flex items-center gap-0.5"><Pin size={9} /> Pinned</span>}
                      <span className="text-[11px] text-[rgb(var(--color-text-tertiary))] ml-auto">{timeAgo(c.createdAt)}</span>
                    </div>
                    <p className="text-[13px] text-[rgb(var(--color-text-primary))] leading-snug">{c.text}</p>
                    {c.likeCount > 0 && (
                      <span className="flex items-center gap-1 text-[11px] text-[rgb(var(--color-text-tertiary))] mt-1">
                        <ThumbsUp size={10} /> {c.likeCount}
                      </span>
                    )}
                  </div>
                </div>

                {/* Reply composer */}
                {replyingTo === c.id && (
                  <div className="pl-10 space-y-2">
                    <textarea
                      value={replyText}
                      onChange={(e) => setReplyText(e.target.value)}
                      placeholder="Reply as creator…"
                      rows={2}
                      className="w-full px-3 py-2 bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] rounded-xl text-[13px] text-[rgb(var(--color-text-primary))] resize-none focus:outline-none focus:border-[rgb(var(--color-primary))]"
                    />
                    <div className="flex justify-end gap-2">
                      <button onClick={() => { setReplyingTo(null); setReplyText(''); }} className="px-3 py-1.5 text-[12px] font-medium text-[rgb(var(--color-text-secondary))] hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
                        Cancel
                      </button>
                      <button
                        onClick={() => handleReplySubmit(c)}
                        disabled={!replyText.trim()}
                        className="px-3 py-1.5 text-[12px] font-semibold bg-[rgb(var(--color-primary))] text-white rounded-full disabled:opacity-50 hover:opacity-90 transition-opacity"
                      >
                        Reply
                      </button>
                    </div>
                  </div>
                )}

                {/* Action row */}
                <div className="flex items-center gap-1 pl-10">
                  <button
                    onClick={() => { setReplyingTo(c.id); setReplyText(''); }}
                    className="flex items-center gap-1 px-2 py-1 text-[11px] text-[rgb(var(--color-text-secondary))] hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors"
                  >
                    <Reply size={12} /> Reply
                  </button>
                  <button
                    onClick={() => handlePin(c)}
                    className={`flex items-center gap-1 px-2 py-1 text-[11px] hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors ${
                      c.isPinned ? 'text-[rgb(var(--color-primary))]' : 'text-[rgb(var(--color-text-secondary))]'
                    }`}
                  >
                    <Pin size={12} /> {c.isPinned ? 'Unpin' : 'Pin'}
                  </button>
                  <button
                    onClick={() => handleDelete(c)}
                    className="flex items-center gap-1 px-2 py-1 text-[11px] text-red-500 hover:bg-red-50 dark:hover:bg-red-900/10 rounded-full transition-colors ml-auto"
                  >
                    <Trash2 size={12} /> Remove
                  </button>
                </div>
              </div>
            ))
          )}
        </main>
      </div>
    </div>
  );
}
