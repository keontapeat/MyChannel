'use client';

// SaveToPlaylistModal — YouTube-parity "Save to…" popup.
//   • Watch Later toggle (users/{uid}/watchLater/{videoId})
//   • User playlists with checkbox membership
//       playlist:   users/{uid}/playlists/{playlistId}
//       membership: users/{uid}/playlists/{playlistId}/videos/{videoId}
//   • Create new playlist inline
//
// Requires sign-in. Signed-out users are prompted to sign in.

import { useEffect, useState } from 'react';
import { X, Check, Plus, Clock, Loader2 } from 'lucide-react';
import Link from 'next/link';
import {
  doc, getDoc, setDoc, deleteDoc, collection, getDocs, addDoc,
  updateDoc, increment, serverTimestamp, orderBy, query,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import type { Video } from '@/types';

interface SaveToPlaylistModalProps {
  video: Pick<Video, 'id' | 'title' | 'thumbnailURL'>;
  onClose: () => void;
}

interface PlaylistRow {
  id: string;
  title: string;
  contains: boolean;
}

export default function SaveToPlaylistModal({ video, onClose }: SaveToPlaylistModalProps) {
  const [loading, setLoading] = useState(true);
  const [inWatchLater, setInWatchLater] = useState(false);
  const [playlists, setPlaylists] = useState<PlaylistRow[]>([]);
  const [creating, setCreating] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [savingNew, setSavingNew] = useState(false);

  const uid = auth?.currentUser?.uid;

  // Close on Escape
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose]);

  useEffect(() => {
    if (!uid) { setLoading(false); return; }
    let cancelled = false;

    const load = async () => {
      try {
        const [wlSnap, plSnap] = await Promise.all([
          getDoc(doc(db, 'users', uid, 'watchLater', video.id)),
          getDocs(query(collection(db, 'users', uid, 'playlists'), orderBy('updatedAt', 'desc'))),
        ]);
        if (cancelled) return;
        setInWatchLater(wlSnap.exists());

        const rows = await Promise.all(
          plSnap.docs.map(async (d) => {
            const memberSnap = await getDoc(doc(db, 'users', uid, 'playlists', d.id, 'videos', video.id));
            return {
              id: d.id,
              title: (d.data()?.title as string) ?? 'Untitled',
              contains: memberSnap.exists(),
            };
          })
        );
        if (!cancelled) setPlaylists(rows);
      } catch {
        // non-fatal
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    load();
    return () => { cancelled = true; };
  }, [uid, video.id]);

  const toggleWatchLater = async () => {
    if (!uid) return;
    const next = !inWatchLater;
    setInWatchLater(next);
    try {
      const ref = doc(db, 'users', uid, 'watchLater', video.id);
      if (next) {
        await setDoc(ref, {
          videoId: video.id,
          title: video.title,
          thumbnailURL: video.thumbnailURL,
          addedAt: serverTimestamp(),
        });
      } else {
        await deleteDoc(ref);
      }
    } catch {
      setInWatchLater(!next);
    }
  };

  const togglePlaylist = async (playlistId: string) => {
    if (!uid) return;
    const target = playlists.find((p) => p.id === playlistId);
    if (!target) return;
    const next = !target.contains;
    setPlaylists((prev) => prev.map((p) => (p.id === playlistId ? { ...p, contains: next } : p)));
    try {
      const memberRef = doc(db, 'users', uid, 'playlists', playlistId, 'videos', video.id);
      const playlistRef = doc(db, 'users', uid, 'playlists', playlistId);
      if (next) {
        await setDoc(memberRef, {
          videoId: video.id,
          title: video.title,
          thumbnailURL: video.thumbnailURL,
          addedAt: serverTimestamp(),
        });
        await updateDoc(playlistRef, { videoCount: increment(1), thumbnailURL: video.thumbnailURL, updatedAt: serverTimestamp() });
      } else {
        await deleteDoc(memberRef);
        await updateDoc(playlistRef, { videoCount: increment(-1), updatedAt: serverTimestamp() });
      }
    } catch {
      setPlaylists((prev) => prev.map((p) => (p.id === playlistId ? { ...p, contains: !next } : p)));
    }
  };

  const createPlaylist = async () => {
    const title = newTitle.trim();
    if (!uid || !title) return;
    setSavingNew(true);
    try {
      const ref = await addDoc(collection(db, 'users', uid, 'playlists'), {
        title,
        videoCount: 1,
        thumbnailURL: video.thumbnailURL,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      await setDoc(doc(db, 'users', uid, 'playlists', ref.id, 'videos', video.id), {
        videoId: video.id,
        title: video.title,
        thumbnailURL: video.thumbnailURL,
        addedAt: serverTimestamp(),
      });
      setPlaylists((prev) => [{ id: ref.id, title, contains: true }, ...prev]);
      setNewTitle('');
      setCreating(false);
    } catch {
      // non-fatal
    } finally {
      setSavingNew(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 p-4"
      onClick={(e) => e.target === e.currentTarget && onClose()}
      role="dialog"
      aria-modal="true"
      aria-label="Save video to playlist"
    >
      <div className="bg-[rgb(var(--color-background))] w-full max-w-[360px] rounded-2xl overflow-hidden shadow-2xl">
        <div className="flex items-center justify-between px-5 pt-5 pb-3">
          <h2 className="text-[16px] font-bold text-[rgb(var(--color-text-primary))]">Save to…</h2>
          <button onClick={onClose} className="p-1.5 hover:bg-[rgb(var(--color-surface-hover))] rounded-full" aria-label="Close">
            <X size={18} className="text-[rgb(var(--color-text-secondary))]" />
          </button>
        </div>

        {!uid ? (
          <div className="px-5 pb-6 text-center">
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))] mb-4">
              Sign in to save videos to your playlists.
            </p>
            <Link href="/login" className="inline-block px-6 py-2.5 bg-[rgb(var(--color-primary))] text-white font-semibold rounded-full hover:opacity-90">
              Sign in
            </Link>
          </div>
        ) : loading ? (
          <div className="px-5 pb-8 flex justify-center">
            <Loader2 size={22} className="animate-spin text-[rgb(var(--color-text-secondary))]" />
          </div>
        ) : (
          <div className="px-3 pb-3">
            {/* Watch Later */}
            <button
              onClick={toggleWatchLater}
              className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
            >
              <span className={`w-5 h-5 rounded flex items-center justify-center border ${inWatchLater ? 'bg-[rgb(var(--color-primary))] border-[rgb(var(--color-primary))]' : 'border-[rgb(var(--color-border))]'}`}>
                {inWatchLater && <Check size={14} className="text-white" />}
              </span>
              <Clock size={16} className="text-[rgb(var(--color-text-secondary))]" />
              <span className="text-[14px] text-[rgb(var(--color-text-primary))]">Watch Later</span>
            </button>

            {/* User playlists */}
            <div className="max-h-[240px] overflow-y-auto">
              {playlists.map((p) => (
                <button
                  key={p.id}
                  onClick={() => togglePlaylist(p.id)}
                  className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
                >
                  <span className={`w-5 h-5 rounded flex items-center justify-center border ${p.contains ? 'bg-[rgb(var(--color-primary))] border-[rgb(var(--color-primary))]' : 'border-[rgb(var(--color-border))]'}`}>
                    {p.contains && <Check size={14} className="text-white" />}
                  </span>
                  <span className="text-[14px] text-[rgb(var(--color-text-primary))] truncate">{p.title}</span>
                </button>
              ))}
            </div>

            {/* Create new playlist */}
            <div className="mt-1 px-3 pt-2 border-t border-[rgb(var(--color-border))]">
              {creating ? (
                <div className="py-2 space-y-2">
                  <input
                    autoFocus
                    value={newTitle}
                    onChange={(e) => setNewTitle(e.target.value.slice(0, 80))}
                    onKeyDown={(e) => e.key === 'Enter' && createPlaylist()}
                    placeholder="Playlist name"
                    className="w-full px-3 py-2 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-lg text-[13px] text-[rgb(var(--color-text-primary))] outline-none focus:border-[rgb(var(--color-primary))]"
                  />
                  <div className="flex justify-end gap-2">
                    <button onClick={() => { setCreating(false); setNewTitle(''); }} className="px-3 py-1.5 text-[13px] font-medium text-[rgb(var(--color-text-secondary))] hover:bg-[rgb(var(--color-surface-hover))] rounded-full">
                      Cancel
                    </button>
                    <button
                      onClick={createPlaylist}
                      disabled={!newTitle.trim() || savingNew}
                      className="px-4 py-1.5 text-[13px] font-semibold bg-[rgb(var(--color-primary))] text-white rounded-full hover:opacity-90 disabled:opacity-50 flex items-center gap-1.5"
                    >
                      {savingNew && <Loader2 size={13} className="animate-spin" />}
                      Create
                    </button>
                  </div>
                </div>
              ) : (
                <button
                  onClick={() => setCreating(true)}
                  className="w-full flex items-center gap-3 px-0 py-2.5 text-[14px] font-medium text-[rgb(var(--color-text-primary))]"
                >
                  <Plus size={18} className="text-[rgb(var(--color-text-secondary))]" />
                  New playlist
                </button>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
