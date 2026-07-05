'use client';

import { useState, useEffect } from 'react';
import {
  Video, Search, Eye, ThumbsUp, MessageSquare, Pencil,
  Trash2, MoreVertical, Globe, Lock, Link2, ChevronLeft,
  Upload, Filter, CheckSquare, Square, X,
} from 'lucide-react';
import Link from 'next/link';
import {
  collection, query, where, orderBy, limit, getDocs, deleteDoc, doc,
  updateDoc, serverTimestamp,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

type Status = 'all' | 'public' | 'unlisted' | 'private';
type SortBy = 'date' | 'views' | 'likes' | 'comments';

interface VideoRow {
  id: string;
  title: string;
  thumbnailURL: string;
  status: 'public' | 'unlisted' | 'private';
  views: number;
  likes: number;
  comments: number;
  duration: number;
  uploadDate: Date;
}

function formatNum(n: number): string {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'K';
  return String(n);
}

function formatDuration(s: number): string {
  const m = Math.floor(s / 60);
  const ss = s % 60;
  return `${m}:${String(ss).padStart(2, '0')}`;
}

function StatusBadge({ status }: { status: VideoRow['status'] }) {
  const cfg = {
    public:   { icon: Globe,  label: 'Public',   cls: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' },
    unlisted: { icon: Link2,  label: 'Unlisted', cls: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400' },
    private:  { icon: Lock,   label: 'Private',  cls: 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-secondary))]' },
  }[status];
  const Icon = cfg.icon;
  return (
    <span className={`inline-flex items-center gap-1 text-[11px] font-medium px-2 py-0.5 rounded-full ${cfg.cls}`}>
      <Icon size={10} /> {cfg.label}
    </span>
  );
}

export default function VideoManagerPage() {
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState<Status>('all');
  const [sortBy, setSortBy] = useState<SortBy>('date');
  const [videos, setVideos] = useState<VideoRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [menuOpen, setMenuOpen] = useState<string | null>(null);
  const [deleting, setDeleting] = useState<string | null>(null);
  const [uid, setUid] = useState<string | null>(auth?.currentUser?.uid ?? null);

  // Wait for Firebase auth to resolve before deciding the user is signed out.
  useEffect(() => {
    const unsub = auth?.onAuthStateChanged?.((u) => setUid(u?.uid ?? null));
    return () => { if (typeof unsub === 'function') unsub(); };
  }, []);

  useEffect(() => {
    if (!uid) { setLoading(false); return; }
    let cancelled = false;

    const load = async () => {
      try {
        const q = query(
          collection(db, 'videos'),
          where('creatorId', '==', uid),
          orderBy('createdAt', 'desc'),
          limit(100)
        );
        const snap = await getDocs(q);
        if (cancelled) return;

        const rows: VideoRow[] = snap.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            title: data.title ?? 'Untitled',
            thumbnailURL: data.thumbnailURL ?? '',
            status: data.isPublic === false ? 'private' : data.status ?? 'public',
            views: data.viewCount ?? 0,
            likes: data.likeCount ?? 0,
            comments: data.commentCount ?? 0,
            duration: data.duration ?? 0,
            uploadDate: data.createdAt?.toDate?.() ?? new Date(),
          };
        });
        setVideos(rows);
      } catch (e) {
        console.error(e);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    load();
    return () => { cancelled = true; };
  }, [uid]);

  const filtered = videos
    .filter((v) => {
      const matchSearch = v.title.toLowerCase().includes(search.toLowerCase());
      const matchStatus = filterStatus === 'all' || v.status === filterStatus;
      return matchSearch && matchStatus;
    })
    .sort((a, b) => {
      if (sortBy === 'date')    return b.uploadDate.getTime() - a.uploadDate.getTime();
      if (sortBy === 'views')   return b.views - a.views;
      if (sortBy === 'likes')   return b.likes - a.likes;
      if (sortBy === 'comments') return b.comments - a.comments;
      return 0;
    });

  const toggleSelect = (id: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  };

  const selectAll = () => {
    if (selected.size === filtered.length) setSelected(new Set());
    else setSelected(new Set(filtered.map((v) => v.id)));
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this video? This cannot be undone.')) return;
    setDeleting(id);
    try {
      await deleteDoc(doc(db, 'videos', id));
      setVideos((prev) => prev.filter((v) => v.id !== id));
    } catch (e) {
      console.error(e);
    } finally {
      setDeleting(null);
      setMenuOpen(null);
    }
  };

  const handleBulkDelete = async () => {
    if (!confirm(`Delete ${selected.size} video(s)?`)) return;
    try {
      await Promise.all([...selected].map((id) => deleteDoc(doc(db, 'videos', id))));
      setVideos((prev) => prev.filter((v) => !selected.has(v.id)));
      setSelected(new Set());
    } catch (e) {
      console.error(e);
    }
  };

  const handleVisibilityChange = async (id: string, newStatus: 'public' | 'unlisted' | 'private') => {
    try {
      await updateDoc(doc(db, 'videos', id), {
        isPublic: newStatus === 'public',
        status: newStatus,
        updatedAt: serverTimestamp(),
      });
      setVideos((prev) => prev.map((v) => v.id === id ? { ...v, status: newStatus } : v));
    } catch (e) {
      console.error(e);
    }
    setMenuOpen(null);
  };

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      <div className="max-w-[900px] mx-auto">

        {/* Header */}
        <header className="sticky top-0 z-50 bg-[rgb(var(--color-background))]/95 backdrop-blur border-b border-[rgb(var(--color-border))] px-4 py-3 space-y-3">
          <div className="flex items-center gap-3">
            <Link href="/studio" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
              <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
            </Link>
            <Video size={20} className="text-purple-500" />
            <div className="flex-1">
              <h1 className="text-[17px] font-bold text-[rgb(var(--color-text-primary))] leading-none">Content</h1>
              <p className="text-[11px] text-[rgb(var(--color-text-secondary))]">{videos.length} video{videos.length !== 1 ? 's' : ''}</p>
            </div>
            <Link href="/upload" className="flex items-center gap-1.5 px-3 py-1.5 bg-[rgb(var(--color-primary))] text-white text-[12px] font-semibold rounded-full hover:opacity-90 transition-opacity">
              <Upload size={14} /> Upload
            </Link>
          </div>

          {/* Search */}
          <div className="relative">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[rgb(var(--color-text-tertiary))]" />
            <input
              type="text"
              placeholder="Filter videos"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] pl-9 pr-4 py-2 text-[13px] rounded-xl border border-[rgb(var(--color-border))] focus:outline-none focus:border-[rgb(var(--color-primary))]"
            />
            {search && (
              <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2">
                <X size={14} className="text-[rgb(var(--color-text-tertiary))]" />
              </button>
            )}
          </div>

          {/* Filter + sort row */}
          <div className="flex items-center gap-2 overflow-x-auto scrollbar-hide">
            {(['all', 'public', 'unlisted', 'private'] as Status[]).map((s) => (
              <button
                key={s}
                onClick={() => setFilterStatus(s)}
                className={`px-3 py-1.5 rounded-full text-[12px] font-medium whitespace-nowrap capitalize transition-all ${
                  filterStatus === s
                    ? 'bg-[rgb(var(--color-text-primary))] text-[rgb(var(--color-background))]'
                    : 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]'
                }`}
              >
                {s}
              </button>
            ))}
            <div className="ml-auto flex items-center gap-1 flex-shrink-0">
              <Filter size={13} className="text-[rgb(var(--color-text-tertiary))]" />
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value as SortBy)}
                className="text-[12px] bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] border border-[rgb(var(--color-border))] rounded-lg px-2 py-1 outline-none"
              >
                <option value="date">Date</option>
                <option value="views">Views</option>
                <option value="likes">Likes</option>
                <option value="comments">Comments</option>
              </select>
            </div>
          </div>

          {/* Bulk select bar */}
          {selected.size > 0 && (
            <div className="flex items-center gap-3 p-2 bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))]">
              <span className="text-[12px] font-semibold text-[rgb(var(--color-text-primary))]">{selected.size} selected</span>
              <button onClick={handleBulkDelete} className="ml-auto text-[12px] text-red-500 font-semibold hover:underline">Delete all</button>
              <button onClick={() => setSelected(new Set())} className="text-[12px] text-[rgb(var(--color-text-secondary))] hover:underline">Cancel</button>
            </div>
          )}
        </header>

        <main className="px-4 py-4 pb-24">
          {loading ? (
            <div className="space-y-3">
              {[...Array(5)].map((_, i) => (
                <div key={i} className="h-[84px] bg-[rgb(var(--color-surface))] rounded-xl animate-pulse" />
              ))}
            </div>
          ) : filtered.length === 0 ? (
            <div className="text-center py-16">
              <Video size={40} className="mx-auto mb-3 text-[rgb(var(--color-text-tertiary))]" />
              <p className="text-[14px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">No videos found</p>
              <p className="text-[12px] text-[rgb(var(--color-text-secondary))] mb-5">
                {search ? 'Try a different search term' : 'Upload your first video'}
              </p>
              <Link href="/upload" className="inline-flex items-center gap-2 px-5 py-2.5 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full">
                <Upload size={16} /> Upload
              </Link>
            </div>
          ) : (
            <>
              {/* Select all toggle */}
              <button
                onClick={selectAll}
                className="flex items-center gap-2 mb-3 text-[12px] text-[rgb(var(--color-text-secondary))] hover:text-[rgb(var(--color-text-primary))] transition-colors"
              >
                {selected.size === filtered.length ? <CheckSquare size={14} /> : <Square size={14} />}
                Select all
              </button>

              <div className="space-y-2">
                {filtered.map((v) => (
                  <div
                    key={v.id}
                    className={`flex items-start gap-3 p-3 rounded-xl border transition-colors ${
                      selected.has(v.id)
                        ? 'bg-blue-50 border-blue-200 dark:bg-blue-900/10 dark:border-blue-800'
                        : 'bg-[rgb(var(--color-surface))] border-[rgb(var(--color-border))]'
                    }`}
                  >
                    {/* Checkbox */}
                    <button onClick={() => toggleSelect(v.id)} className="mt-0.5 flex-shrink-0">
                      {selected.has(v.id)
                        ? <CheckSquare size={16} className="text-blue-500" />
                        : <Square size={16} className="text-[rgb(var(--color-text-tertiary))]" />
                      }
                    </button>

                    {/* Thumbnail */}
                    <Link href={`/watch/${v.id}`} className="flex-shrink-0">
                      <div className="relative w-[108px] h-[61px] rounded-lg overflow-hidden bg-[rgb(var(--color-surface-hover))]">
                        {v.thumbnailURL
                          ? <img src={v.thumbnailURL} alt={v.title} className="w-full h-full object-cover" />
                          : <div className="w-full h-full flex items-center justify-center"><Video size={18} className="text-[rgb(var(--color-text-tertiary))]" /></div>
                        }
                        {v.duration > 0 && (
                          <span className="absolute bottom-1 right-1 text-[9px] bg-black/80 text-white px-1 py-0.5 rounded">
                            {formatDuration(v.duration)}
                          </span>
                        )}
                      </div>
                    </Link>

                    {/* Info */}
                    <div className="flex-1 min-w-0">
                      <Link href={`/studio/videos/${v.id}/edit`}>
                        <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] line-clamp-2 mb-1 hover:text-[rgb(var(--color-primary))] transition-colors">
                          {v.title}
                        </h3>
                      </Link>
                      <div className="flex items-center gap-2 mb-1.5 flex-wrap">
                        <StatusBadge status={v.status} />
                        <span className="text-[11px] text-[rgb(var(--color-text-tertiary))]">
                          {v.uploadDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                        </span>
                      </div>
                      <div className="flex items-center gap-3 text-[11px] text-[rgb(var(--color-text-tertiary))]">
                        <span className="flex items-center gap-0.5"><Eye size={10} /> {formatNum(v.views)}</span>
                        <span className="flex items-center gap-0.5"><ThumbsUp size={10} /> {formatNum(v.likes)}</span>
                        <span className="flex items-center gap-0.5"><MessageSquare size={10} /> {v.comments}</span>
                      </div>
                    </div>

                    {/* Actions menu */}
                    <div className="relative flex-shrink-0">
                      <button
                        onClick={() => setMenuOpen(menuOpen === v.id ? null : v.id)}
                        className="p-1.5 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors"
                      >
                        <MoreVertical size={16} className="text-[rgb(var(--color-text-secondary))]" />
                      </button>

                      {menuOpen === v.id && (
                        <div className="absolute right-0 top-8 z-30 w-44 bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] rounded-xl shadow-xl overflow-hidden">
                          <Link
                            href={`/studio/videos/${v.id}/edit`}
                            className="flex items-center gap-2 px-3 py-2.5 text-[13px] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
                            onClick={() => setMenuOpen(null)}
                          >
                            <Pencil size={14} /> Edit details
                          </Link>
                          <Link
                            href={`/studio/analytics?videoId=${v.id}`}
                            className="flex items-center gap-2 px-3 py-2.5 text-[13px] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
                            onClick={() => setMenuOpen(null)}
                          >
                            <Eye size={14} /> Analytics
                          </Link>
                          <div className="border-t border-[rgb(var(--color-border))] my-1" />
                          {/* Visibility options */}
                          {(['public', 'unlisted', 'private'] as const).map((s) => (
                            <button
                              key={s}
                              onClick={() => handleVisibilityChange(v.id, s)}
                              className={`flex items-center gap-2 w-full px-3 py-2 text-[12px] hover:bg-[rgb(var(--color-surface-hover))] transition-colors capitalize ${
                                v.status === s ? 'text-[rgb(var(--color-primary))] font-semibold' : 'text-[rgb(var(--color-text-primary))]'
                              }`}
                            >
                              {s === 'public' ? <Globe size={13} /> : s === 'unlisted' ? <Link2 size={13} /> : <Lock size={13} />}
                              {s}
                              {v.status === s && ' ✓'}
                            </button>
                          ))}
                          <div className="border-t border-[rgb(var(--color-border))] my-1" />
                          <button
                            onClick={() => handleDelete(v.id)}
                            disabled={deleting === v.id}
                            className="flex items-center gap-2 w-full px-3 py-2.5 text-[13px] text-red-500 hover:bg-red-50 dark:hover:bg-red-900/10 transition-colors disabled:opacity-50"
                          >
                            <Trash2 size={14} /> {deleting === v.id ? 'Deleting…' : 'Delete'}
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </>
          )}
        </main>
      </div>

      {/* Close menu on backdrop click */}
      {menuOpen && (
        <div className="fixed inset-0 z-20" onClick={() => setMenuOpen(null)} />
      )}
    </div>
  );
}
