'use client';

// Video Chapters Editor — YouTube Studio parity
// Creators add timestamped chapters to their videos (0:00 Intro, 1:23 Main content, etc.)

import { useState, useEffect } from 'react';
import { Plus, Trash2, ChevronLeft, Save, Loader2, GripVertical, Clock } from 'lucide-react';
import Link from 'next/link';
import {
  collection, doc, getDoc, getDocs, addDoc, updateDoc, deleteDoc,
  serverTimestamp, orderBy, query,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

interface Chapter {
  id?: string;
  title: string;
  startTime: number; // seconds
  isNew?: boolean;
}

function secondsToTimestamp(secs: number): string {
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  const s = secs % 60;
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${m}:${String(s).padStart(2, '0')}`;
}

function timestampToSeconds(ts: string): number | null {
  const parts = ts.split(':').map(Number);
  if (parts.some(isNaN)) return null;
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  return null;
}

export default function ChaptersEditorClient({ videoId: initialVideoId }: { videoId: string }) {
  const [videoId, setVideoId] = useState(initialVideoId === '_fallback' ? '' : initialVideoId);
  const [chapters, setChapters] = useState<Chapter[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [videoDuration, setVideoDuration] = useState(0);
  const [videoTitle, setVideoTitle] = useState('');

  useEffect(() => {
    if (initialVideoId !== '_fallback') return;
    const segments = window.location.pathname.split('/').filter(Boolean);
    const videosIndex = segments.indexOf('videos');
    const pathId = videosIndex >= 0 ? segments[videosIndex + 1] : '';
    if (pathId && pathId !== '_fallback') setVideoId(decodeURIComponent(pathId));
  }, [initialVideoId]);

  useEffect(() => {
    if (!videoId) return;

    const load = async () => {
      try {
        const videoSnap = await getDoc(doc(db, 'videos', videoId));
        if (videoSnap.exists()) {
          const data = videoSnap.data();
          setVideoDuration(data.duration ?? 0);
          setVideoTitle(data.title ?? 'Untitled');
        }

        const chaptersSnap = await getDocs(
          query(collection(db, 'videos', videoId, 'chapters'), orderBy('startTime', 'asc'))
        );

        if (chaptersSnap.empty) {
          // Also check top-level chapters collection
          const topSnap = await getDocs(
            query(collection(db, 'chapters'), orderBy('startTime', 'asc'))
          );
          const filtered = topSnap.docs
            .filter((d) => d.data().videoId === videoId)
            .map((d) => ({ id: d.id, title: d.data().title ?? '', startTime: d.data().startTime ?? 0 }));
          setChapters(filtered);
        } else {
          setChapters(
            chaptersSnap.docs.map((d) => ({
              id: d.id,
              title: d.data().title ?? '',
              startTime: d.data().startTime ?? 0,
            }))
          );
        }
      } catch (e) {
        console.error(e);
        setError('Failed to load chapters.');
      } finally {
        setLoading(false);
      }
    };

    load();
  }, [videoId]);

  const addChapter = () => {
    const lastTime = chapters.length > 0 ? chapters[chapters.length - 1].startTime + 60 : 0;
    setChapters([
      ...chapters,
      { title: '', startTime: Math.min(lastTime, videoDuration > 0 ? videoDuration - 1 : lastTime), isNew: true },
    ]);
  };

  const updateChapter = (index: number, field: keyof Chapter, value: string | number) => {
    setChapters((prev) =>
      prev.map((c, i) => (i === index ? { ...c, [field]: value } : c))
    );
  };

  const updateTimestamp = (index: number, ts: string) => {
    const secs = timestampToSeconds(ts);
    if (secs !== null) updateChapter(index, 'startTime', secs);
  };

  const removeChapter = (index: number) => {
    setChapters((prev) => prev.filter((_, i) => i !== index));
  };

  const validate = (): string | null => {
    if (chapters.length === 0) return null;
    if (chapters[0].startTime !== 0) return 'First chapter must start at 0:00';
    for (const c of chapters) {
      if (!c.title.trim()) return 'All chapters must have a title';
      if (c.startTime < 0) return 'Chapter times must be positive';
    }
    const sorted = [...chapters].sort((a, b) => a.startTime - b.startTime);
    for (let i = 1; i < sorted.length; i++) {
      if (sorted[i].startTime === sorted[i - 1].startTime)
        return 'Two chapters cannot start at the same time';
    }
    return null;
  };

  const save = async () => {
    const validationError = validate();
    if (validationError) { setError(validationError); return; }

    const uid = auth?.currentUser?.uid;
    if (!uid) { setError('Not signed in'); return; }

    setSaving(true);
    setError('');
    setSuccess('');

    try {
      const colRef = collection(db, 'videos', videoId, 'chapters');
      const existingSnap = await getDocs(colRef);

      // Delete existing
      await Promise.all(existingSnap.docs.map((d) => deleteDoc(d.ref)));

      // Write new sorted chapters
      const sorted = [...chapters].sort((a, b) => a.startTime - b.startTime);
      await Promise.all(
        sorted.map((c) =>
          addDoc(colRef, {
            title: c.title.trim(),
            startTime: c.startTime,
            videoId,
            createdBy: uid,
            updatedAt: serverTimestamp(),
          })
        )
      );

      // Update video doc to flag chapters exist
      await updateDoc(doc(db, 'videos', videoId), {
        hasChapters: sorted.length > 0,
        chapterCount: sorted.length,
        updatedAt: serverTimestamp(),
      });

      setChapters(sorted.map((c) => ({ ...c, isNew: false })));
      setSuccess(`${sorted.length} chapter${sorted.length !== 1 ? 's' : ''} saved`);
      setTimeout(() => setSuccess(''), 3000);
    } catch (e) {
      console.error(e);
      setError('Failed to save chapters. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-[rgb(var(--color-background))] flex items-center justify-center">
        <Loader2 size={28} className="animate-spin text-[rgb(var(--color-text-tertiary))]" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      <div className="max-w-[640px] mx-auto">
        {/* Header */}
        <header className="sticky top-0 z-50 bg-[rgb(var(--color-background))]/95 backdrop-blur border-b border-[rgb(var(--color-border))] px-4 py-3">
          <div className="flex items-center gap-3">
            <Link href={`/studio/videos/${videoId}/edit`} className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
              <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
            </Link>
            <Clock size={20} className="text-orange-500" />
            <div className="flex-1 min-w-0">
              <h1 className="text-[17px] font-bold text-[rgb(var(--color-text-primary))] leading-none">Chapters</h1>
              <p className="text-[11px] text-[rgb(var(--color-text-secondary))] truncate">{videoTitle}</p>
            </div>
            <button
              onClick={save}
              disabled={saving}
              className="flex items-center gap-1.5 px-4 py-2 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full hover:opacity-90 disabled:opacity-50"
            >
              {saving ? <Loader2 size={13} className="animate-spin" /> : <Save size={13} />}
              Save
            </button>
          </div>
        </header>

        <main className="px-4 py-5 pb-24 space-y-4">
          {/* Info banner */}
          <div className="bg-[rgb(var(--color-surface))] rounded-xl p-4 border border-[rgb(var(--color-border))]">
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">
              Chapters let viewers navigate your video. The first chapter must start at{' '}
              <span className="font-semibold text-[rgb(var(--color-text-primary))]">0:00</span> and you need at least{' '}
              <span className="font-semibold text-[rgb(var(--color-text-primary))]">3 chapters</span> for them to appear in the player.
            </p>
            {videoDuration > 0 && (
              <p className="text-[12px] text-[rgb(var(--color-text-tertiary))] mt-1">
                Video duration: {secondsToTimestamp(videoDuration)}
              </p>
            )}
          </div>

          {/* Error / success */}
          {error && (
            <div className="p-3 bg-red-500/10 border border-red-500 rounded-xl text-[13px] text-red-500">
              {error}
            </div>
          )}
          {success && (
            <div className="p-3 bg-green-500/10 border border-green-500 rounded-xl text-[13px] text-green-500">
              ✓ {success}
            </div>
          )}

          {/* Chapters list */}
          <div className="space-y-2">
            {chapters.length === 0 && (
              <div className="text-center py-10 text-[rgb(var(--color-text-secondary))] text-[13px]">
                No chapters yet. Add your first chapter below.
              </div>
            )}
            {chapters.map((chapter, i) => (
              <div
                key={i}
                className="flex items-center gap-3 p-3 bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))]"
              >
                <GripVertical size={16} className="text-[rgb(var(--color-text-tertiary))] flex-shrink-0" />

                {/* Timestamp input */}
                <div className="flex-shrink-0">
                  <input
                    type="text"
                    defaultValue={secondsToTimestamp(chapter.startTime)}
                    onBlur={(e) => updateTimestamp(i, e.target.value)}
                    placeholder="0:00"
                    className="w-[72px] px-2 py-1.5 bg-[rgb(var(--color-surface-hover))] border border-[rgb(var(--color-border))] rounded-lg text-[13px] font-mono text-[rgb(var(--color-text-primary))] text-center outline-none focus:border-[rgb(var(--color-primary))]"
                    aria-label="Chapter start time"
                  />
                </div>

                {/* Title input */}
                <input
                  type="text"
                  value={chapter.title}
                  onChange={(e) => updateChapter(i, 'title', e.target.value)}
                  placeholder="Chapter title"
                  className="flex-1 px-3 py-1.5 bg-[rgb(var(--color-surface-hover))] border border-[rgb(var(--color-border))] rounded-lg text-[13px] text-[rgb(var(--color-text-primary))] outline-none focus:border-[rgb(var(--color-primary))]"
                />

                <button
                  onClick={() => removeChapter(i)}
                  className="p-1.5 hover:bg-red-50 dark:hover:bg-red-900/10 rounded-full transition-colors text-[rgb(var(--color-text-tertiary))] hover:text-red-500 flex-shrink-0"
                  aria-label="Remove chapter"
                >
                  <Trash2 size={15} />
                </button>
              </div>
            ))}
          </div>

          {/* Add chapter button */}
          <button
            onClick={addChapter}
            className="flex items-center gap-2 w-full py-3 border-2 border-dashed border-[rgb(var(--color-border))] rounded-xl text-[13px] font-medium text-[rgb(var(--color-text-secondary))] hover:border-[rgb(var(--color-primary))] hover:text-[rgb(var(--color-primary))] transition-colors justify-center"
          >
            <Plus size={16} /> Add chapter
          </button>

          {/* Preview */}
          {chapters.length >= 3 && (
            <div className="bg-[rgb(var(--color-surface))] rounded-xl p-4 border border-[rgb(var(--color-border))]">
              <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-3">Preview</h3>
              <div className="space-y-1">
                {[...chapters]
                  .sort((a, b) => a.startTime - b.startTime)
                  .map((c, i) => (
                    <div key={i} className="flex items-center gap-3 text-[13px]">
                      <span className="font-mono text-[rgb(var(--color-primary))] w-12 text-right flex-shrink-0">
                        {secondsToTimestamp(c.startTime)}
                      </span>
                      <span className="text-[rgb(var(--color-text-primary))]">{c.title || '(no title)'}</span>
                    </div>
                  ))}
              </div>
            </div>
          )}
        </main>
      </div>
    </div>
  );
}
