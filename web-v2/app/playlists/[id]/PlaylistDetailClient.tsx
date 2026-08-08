'use client';

// Playlist detail — lists videos in users/{uid}/playlists/{playlistId}/videos,
// ordered by addedAt (most recently added first, matching SaveToPlaylistModal).
// Owner-only: playlists are private per-user documents, so only the signed-in
// owner can view/edit their own playlist.

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import {
  ChevronLeft, PlaySquare, Trash2, Play, MoreVertical, Pencil, Check, X,
} from 'lucide-react';
import {
  collection, query, orderBy, getDocs, doc, getDoc, deleteDoc, updateDoc, serverTimestamp, increment,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import { videoService, type Video } from '@/lib/firebase/services/video-service';

interface PlaylistDetailClientProps {
  playlistId: string;
}

export default function PlaylistDetailClient({ playlistId: initialPlaylistId }: PlaylistDetailClientProps) {
  const router = useRouter();
  const [playlistId, setPlaylistId] = useState(initialPlaylistId === '_fallback' ? '' : initialPlaylistId);
  const [uid, setUid] = useState<string | null>(auth?.currentUser?.uid ?? null);
  const [authResolved, setAuthResolved] = useState(!!auth?.currentUser);
  const [title, setTitle] = useState('');
  const [editingTitle, setEditingTitle] = useState(false);
  const [titleInput, setTitleInput] = useState('');
  const [videos, setVideos] = useState<Video[]>([]);
  const [loading, setLoading] = useState(true);
  const [notFound, setNotFound] = useState(false);
  const [menuOpenFor, setMenuOpenFor] = useState<string | null>(null);

  useEffect(() => {
    if (initialPlaylistId !== '_fallback') return;
    const segments = window.location.pathname.split('/').filter(Boolean);
    const playlistsIndex = segments.indexOf('playlists');
    const pathId = playlistsIndex >= 0 ? segments[playlistsIndex + 1] : '';
    if (pathId && pathId !== '_fallback') setPlaylistId(decodeURIComponent(pathId));
  }, [initialPlaylistId]);

  useEffect(() => {
    const unsub = auth?.onAuthStateChanged?.((u) => { setUid(u?.uid ?? null); setAuthResolved(true); });
    return () => { if (typeof unsub === 'function') unsub(); };
  }, []);

  useEffect(() => {
    if (!authResolved || playlistId === '_fallback') return;
    if (!uid) { setLoading(false); return; }
    let cancelled = false;

    const load = async () => {
      setLoading(true);
      try {
        const playlistSnap = await getDoc(doc(db, 'users', uid, 'playlists', playlistId));
        if (cancelled) return;
        if (!playlistSnap.exists()) { setNotFound(true); return; }
        setTitle((playlistSnap.data()?.title as string) ?? 'Untitled');

        const videosSnap = await getDocs(
          query(collection(db, 'users', uid, 'playlists', playlistId, 'videos'), orderBy('addedAt', 'desc'))
        );
        const ids = videosSnap.docs.map((d) => d.id);
        if (ids.length === 0) { setVideos([]); return; }

        const fetched = await videoService.fetchVideosByIds(ids);
        const orderIndex = new Map(ids.map((id, i) => [id, i]));
        fetched.sort((a, b) => (orderIndex.get(a.id) ?? 0) - (orderIndex.get(b.id) ?? 0));
        if (!cancelled) setVideos(fetched);
      } catch (err) {
        console.error(err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    load();
    return () => { cancelled = true; };
  }, [uid, authResolved, playlistId]);

  const saveTitle = async () => {
    const next = titleInput.trim();
    if (!uid || !next || next === title) { setEditingTitle(false); return; }
    setTitle(next);
    setEditingTitle(false);
    try {
      await updateDoc(doc(db, 'users', uid, 'playlists', playlistId), { title: next, updatedAt: serverTimestamp() });
    } catch (err) {
      console.error(err);
    }
  };

  const removeVideo = async (videoId: string) => {
    if (!uid) return;
    setVideos((prev) => prev.filter((v) => v.id !== videoId));
    setMenuOpenFor(null);
    try {
      await deleteDoc(doc(db, 'users', uid, 'playlists', playlistId, 'videos', videoId));
      await updateDoc(doc(db, 'users', uid, 'playlists', playlistId), { videoCount: increment(-1), updatedAt: serverTimestamp() });
    } catch (err) {
      console.error(err);
    }
  };

  const deletePlaylist = async () => {
    if (!uid) return;
    if (!confirm(`Delete playlist "${title}"? This can't be undone.`)) return;
    try {
      // Remove membership docs, then the playlist itself.
      const videosSnap = await getDocs(collection(db, 'users', uid, 'playlists', playlistId, 'videos'));
      await Promise.all(videosSnap.docs.map((d) => deleteDoc(d.ref)));
      await deleteDoc(doc(db, 'users', uid, 'playlists', playlistId));
      router.push('/playlists');
    } catch (err) {
      console.error(err);
    }
  };

  if (!authResolved || loading) {
    return (
      <div className="max-w-[1000px] mx-auto px-4 sm:px-6 py-6">
        <div className="h-8 w-40 bg-[rgb(var(--color-surface))] rounded animate-pulse mb-6" />
        <div className="space-y-3">
          {Array.from({ length: 5 }).map((_, i) => (
            <div key={i} className="h-24 bg-[rgb(var(--color-surface))] rounded-xl animate-pulse" />
          ))}
        </div>
      </div>
    );
  }

  if (!uid) {
    return (
      <div className="max-w-[600px] mx-auto px-4 py-16 text-center">
        <PlaySquare size={48} className="mx-auto mb-4 text-[rgb(var(--color-text-tertiary))]" />
        <p className="text-sm text-[rgb(var(--color-text-secondary))] mb-4">Sign in to view this playlist.</p>
        <Link href="/login" className="inline-block px-5 py-2.5 bg-[rgb(var(--color-primary))] text-white text-sm font-semibold rounded-full hover:opacity-90">
          Sign in
        </Link>
      </div>
    );
  }

  if (notFound) {
    return (
      <div className="max-w-[600px] mx-auto px-4 py-16 text-center">
        <PlaySquare size={48} className="mx-auto mb-4 text-[rgb(var(--color-text-tertiary))]" />
        <p className="text-sm text-[rgb(var(--color-text-secondary))] mb-4">Playlist not found.</p>
        <Link href="/playlists" className="inline-block px-5 py-2.5 bg-[rgb(var(--color-primary))] text-white text-sm font-semibold rounded-full hover:opacity-90">
          Back to playlists
        </Link>
      </div>
    );
  }

  return (
    <div className="max-w-[1000px] mx-auto px-4 sm:px-6 py-6">
      <div className="flex items-center gap-3 mb-2">
        <Link href="/playlists" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
          <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
        </Link>
        {editingTitle ? (
          <div className="flex items-center gap-2 flex-1">
            <input
              autoFocus
              value={titleInput}
              onChange={(e) => setTitleInput(e.target.value.slice(0, 80))}
              onKeyDown={(e) => e.key === 'Enter' && saveTitle()}
              className="flex-1 px-3 py-1.5 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-lg text-xl font-bold text-[rgb(var(--color-text-primary))] outline-none focus:border-[rgb(var(--color-primary))]"
            />
            <button onClick={saveTitle} className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full"><Check size={18} className="text-green-500" /></button>
            <button onClick={() => setEditingTitle(false)} className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full"><X size={18} className="text-[rgb(var(--color-text-secondary))]" /></button>
          </div>
        ) : (
          <>
            <h1 className="text-2xl font-bold text-[rgb(var(--color-text-primary))] flex-1 truncate">{title}</h1>
            <button
              onClick={() => { setTitleInput(title); setEditingTitle(true); }}
              className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors"
              aria-label="Rename playlist"
            >
              <Pencil size={16} className="text-[rgb(var(--color-text-secondary))]" />
            </button>
            <button
              onClick={deletePlaylist}
              className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors"
              aria-label="Delete playlist"
            >
              <Trash2 size={16} className="text-[rgb(var(--color-text-secondary))]" />
            </button>
          </>
        )}
      </div>
      <p className="text-sm text-[rgb(var(--color-text-secondary))] mb-6">
        {videos.length} {videos.length === 1 ? 'video' : 'videos'}
      </p>

      {videos.length > 0 && (
        <Link
          href={`/watch/${videos[0].id}`}
          className="inline-flex items-center gap-2 mb-6 px-5 py-2.5 bg-[rgb(var(--color-primary))] text-white text-sm font-semibold rounded-full hover:opacity-90 transition-opacity"
        >
          <Play size={16} fill="currentColor" /> Play all
        </Link>
      )}

      {videos.length === 0 ? (
        <div className="py-16 text-center text-[rgb(var(--color-text-secondary))]">
          <p className="text-sm">This playlist is empty. Use &quot;Save to playlist&quot; on any video to add it here.</p>
        </div>
      ) : (
        <div className="space-y-2">
          {videos.map((video, i) => (
            <div key={video.id} className="group flex items-center gap-3 p-2 rounded-xl hover:bg-[rgb(var(--color-surface-hover))] transition-colors relative">
              <span className="w-5 text-center text-[13px] text-[rgb(var(--color-text-tertiary))] flex-shrink-0">{i + 1}</span>
              <Link href={`/watch/${video.id}`} className="flex items-center gap-3 flex-1 min-w-0">
                <div className="relative w-32 sm:w-40 aspect-video rounded-lg overflow-hidden bg-[rgb(var(--color-surface))] flex-shrink-0">
                  <img src={video.thumbnailURL} alt={video.title} className="w-full h-full object-cover" />
                  <span className="absolute bottom-1 right-1 bg-black/80 text-white text-[10px] px-1 py-0.5 rounded">
                    {videoService.formatDuration(video.duration)}
                  </span>
                </div>
                <div className="min-w-0">
                  <h3 className="text-[14px] font-semibold text-[rgb(var(--color-text-primary))] line-clamp-2">{video.title}</h3>
                  <p className="text-[12px] text-[rgb(var(--color-text-secondary))] mt-0.5">{video.creator?.displayName}</p>
                  <p className="text-[12px] text-[rgb(var(--color-text-tertiary))]">
                    {videoService.formatViewCount(video.viewCount)} views
                  </p>
                </div>
              </Link>
              <button
                onClick={() => setMenuOpenFor(menuOpenFor === video.id ? null : video.id)}
                className="p-2 rounded-full hover:bg-[rgb(var(--color-surface))] transition-colors flex-shrink-0"
                aria-label="More options"
              >
                <MoreVertical size={16} className="text-[rgb(var(--color-text-secondary))]" />
              </button>
              {menuOpenFor === video.id && (
                <>
                  <div className="fixed inset-0 z-40" onClick={() => setMenuOpenFor(null)} />
                  <div className="absolute right-2 top-12 w-48 bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] rounded-xl shadow-xl py-1.5 z-50">
                    <button
                      onClick={() => removeVideo(video.id)}
                      className="w-full flex items-center gap-2 px-4 py-2.5 text-[13px] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]"
                    >
                      <Trash2 size={14} /> Remove from playlist
                    </button>
                  </div>
                </>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
