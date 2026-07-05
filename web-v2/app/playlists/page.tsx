'use client';

// Playlists — user-curated video collections, backed by
// users/{uid}/playlists/{playlistId} (+ .../videos/{videoId} membership),
// the same store SaveToPlaylistModal writes to.

import { useEffect, useState } from 'react';
import Link from 'next/link';
import MainLayout from '@/components/layout/MainLayout';
import { PlaySquare, Plus, Loader2 } from 'lucide-react';
import {
  collection, query, orderBy, getDocs, addDoc, serverTimestamp,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

interface PlaylistRow {
  id: string;
  title: string;
  videoCount: number;
  thumbnailURL: string;
}

export default function PlaylistsPage() {
  const [uid, setUid] = useState<string | null>(auth?.currentUser?.uid ?? null);
  const [authResolved, setAuthResolved] = useState(!!auth?.currentUser);
  const [playlists, setPlaylists] = useState<PlaylistRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [creating, setCreating] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const unsub = auth?.onAuthStateChanged?.((u) => { setUid(u?.uid ?? null); setAuthResolved(true); });
    return () => { if (typeof unsub === 'function') unsub(); };
  }, []);

  useEffect(() => {
    if (!authResolved) return;
    if (!uid) { setLoading(false); return; }
    let cancelled = false;

    const load = async () => {
      setLoading(true);
      try {
        const snap = await getDocs(
          query(collection(db, 'users', uid, 'playlists'), orderBy('updatedAt', 'desc'))
        );
        if (cancelled) return;
        setPlaylists(snap.docs.map((d) => ({
          id: d.id,
          title: (d.data()?.title as string) ?? 'Untitled',
          videoCount: (d.data()?.videoCount as number) ?? 0,
          thumbnailURL: (d.data()?.thumbnailURL as string) ?? '',
        })));
      } catch (err) {
        console.error(err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    load();
    return () => { cancelled = true; };
  }, [uid, authResolved]);

  const createPlaylist = async () => {
    const title = newTitle.trim();
    if (!uid || !title || saving) return;
    setSaving(true);
    try {
      const ref = await addDoc(collection(db, 'users', uid, 'playlists'), {
        title,
        videoCount: 0,
        thumbnailURL: '',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      setPlaylists((prev) => [{ id: ref.id, title, videoCount: 0, thumbnailURL: '' }, ...prev]);
      setNewTitle('');
      setCreating(false);
    } catch (err) {
      console.error(err);
    } finally {
      setSaving(false);
    }
  };

  return (
    <MainLayout>
      <div className="max-w-[1600px] mx-auto px-4 sm:px-6 py-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <PlaySquare size={24} className="text-[rgb(var(--color-text-primary))]" />
            <h1 className="text-2xl font-bold text-[rgb(var(--color-text-primary))]">Playlists</h1>
          </div>
          {uid && (
            <button
              onClick={() => setCreating(true)}
              className="inline-flex items-center gap-2 rounded-full bg-[rgb(var(--color-primary))] px-4 py-2 text-sm font-semibold text-white hover:opacity-90 transition-opacity"
            >
              <Plus size={16} /> New playlist
            </button>
          )}
        </div>

        {creating && (
          <div className="mb-6 flex items-center gap-2 max-w-md">
            <input
              autoFocus
              value={newTitle}
              onChange={(e) => setNewTitle(e.target.value.slice(0, 80))}
              onKeyDown={(e) => e.key === 'Enter' && createPlaylist()}
              placeholder="Playlist name"
              className="flex-1 px-4 py-2 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-full text-sm text-[rgb(var(--color-text-primary))] outline-none focus:border-[rgb(var(--color-primary))]"
            />
            <button
              onClick={() => { setCreating(false); setNewTitle(''); }}
              className="px-3 py-2 text-sm font-medium text-[rgb(var(--color-text-secondary))] hover:bg-[rgb(var(--color-surface-hover))] rounded-full"
            >
              Cancel
            </button>
            <button
              onClick={createPlaylist}
              disabled={!newTitle.trim() || saving}
              className="px-4 py-2 text-sm font-semibold bg-[rgb(var(--color-primary))] text-white rounded-full hover:opacity-90 disabled:opacity-50 flex items-center gap-1.5"
            >
              {saving && <Loader2 size={14} className="animate-spin" />}
              Create
            </button>
          </div>
        )}

        {!authResolved || loading ? (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
            {Array.from({ length: 8 }).map((_, i) => (
              <div key={i} className="aspect-video rounded-xl bg-[rgb(var(--color-surface))] animate-pulse" />
            ))}
          </div>
        ) : !uid ? (
          <div className="py-16 text-center">
            <PlaySquare size={48} className="mx-auto mb-4 text-[rgb(var(--color-text-tertiary))]" />
            <p className="text-sm text-[rgb(var(--color-text-secondary))] mb-4">Sign in to create and view playlists.</p>
            <Link href="/login" className="inline-block px-5 py-2.5 bg-[rgb(var(--color-primary))] text-white text-sm font-semibold rounded-full hover:opacity-90">
              Sign in
            </Link>
          </div>
        ) : playlists.length === 0 ? (
          <div className="py-16 text-center text-[rgb(var(--color-text-secondary))]">
            <PlaySquare size={48} className="mx-auto mb-4 text-[rgb(var(--color-text-tertiary))]" />
            <p className="text-sm">You haven&apos;t created any playlists yet.</p>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
            {playlists.map((p) => (
              <Link key={p.id} href={`/playlists/${p.id}`} className="group block">
                <div className="relative aspect-video rounded-xl overflow-hidden bg-[rgb(var(--color-surface))]">
                  {p.thumbnailURL ? (
                    <img src={p.thumbnailURL} alt={p.title} className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center">
                      <PlaySquare size={32} className="text-[rgb(var(--color-text-tertiary))]" />
                    </div>
                  )}
                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                    <span className="text-white text-sm font-semibold">Play all</span>
                  </div>
                  <div className="absolute bottom-2 right-2 bg-black/80 text-white text-xs px-2 py-0.5 rounded">
                    {p.videoCount} {p.videoCount === 1 ? 'video' : 'videos'}
                  </div>
                </div>
                <h3 className="mt-2 text-sm font-semibold text-[rgb(var(--color-text-primary))] line-clamp-2">
                  {p.title}
                </h3>
              </Link>
            ))}
          </div>
        )}
      </div>
    </MainLayout>
  );
}
