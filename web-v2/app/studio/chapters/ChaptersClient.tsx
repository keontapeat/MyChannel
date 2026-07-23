'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { ChevronLeft, Plus, Trash2, Save, Loader2, GripVertical } from 'lucide-react';
import { doc, getDoc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '@/lib/firebase/config';

interface Chapter {
  id: string;
  title: string;
  startSeconds: number;
}

function secondsToTimestamp(s: number): string {
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`;
  return `${m}:${String(sec).padStart(2, '0')}`;
}

function timestampToSeconds(ts: string): number {
  const parts = ts.split(':').map(Number);
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  return 0;
}

/**
 * Studio Chapters Editor — YouTube parity.
 * Add timestamped chapters so viewers can jump to sections.
 * First chapter must start at 0:00. Minimum 3 chapters required for YouTube to show them.
 */
export default function ChaptersClient() {
  const router = useRouter();
  const [videoId, setVideoId] = useState('');
  const [videoTitle, setVideoTitle] = useState('');
  const [chapters, setChapters] = useState<Chapter[]>([
    { id: '1', title: 'Intro', startSeconds: 0 },
  ]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const vid = params.get('videoId') || '';
    setVideoId(vid);
    if (!vid) return;
    setLoading(true);
    getDoc(doc(db, 'videos', vid)).then((snap) => {
      if (!snap.exists()) { setError('Video not found'); return; }
      const d = snap.data();
      setVideoTitle(d.title ?? '');
      const saved: Chapter[] = (d.chapters ?? []).map((c: any, i: number) => ({
        id: String(i),
        title: c.title ?? '',
        startSeconds: c.startSeconds ?? 0,
      }));
      if (saved.length > 0) setChapters(saved);
    }).catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, []);

  const addChapter = () => {
    const lastStart = chapters[chapters.length - 1]?.startSeconds ?? 0;
    setChapters((prev) => [
      ...prev,
      { id: String(Date.now()), title: '', startSeconds: lastStart + 60 },
    ]);
  };

  const updateChapter = (id: string, field: keyof Chapter, value: string | number) => {
    setChapters((prev) =>
      prev.map((c) => c.id === id ? { ...c, [field]: value } : c)
    );
  };

  const removeChapter = (id: string) => {
    if (chapters.length <= 1) return;
    setChapters((prev) => prev.filter((c) => c.id !== id));
  };

  const handleSave = async () => {
    if (!videoId) return;
    // Validate: first chapter must start at 0
    const sorted = [...chapters].sort((a, b) => a.startSeconds - b.startSeconds);
    if (sorted[0]?.startSeconds !== 0) {
      setError('First chapter must start at 0:00');
      return;
    }
    if (sorted.length < 3) {
      setError('You need at least 3 chapters');
      return;
    }
    setSaving(true);
    setError('');
    try {
      await updateDoc(doc(db, 'videos', videoId), {
        chapters: sorted.map(({ title, startSeconds }) => ({ title, startSeconds })),
        updatedAt: serverTimestamp(),
      });
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setSaving(false);
    }
  };

  const sortedChapters = [...chapters].sort((a, b) => a.startSeconds - b.startSeconds);

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      <div className="max-w-[720px] mx-auto">

        {/* Header */}
        <header className="sticky top-0 z-50 bg-[rgb(var(--color-background))]/95 backdrop-blur border-b border-[rgb(var(--color-border))] px-4 py-3">
          <div className="flex items-center gap-3">
            <button onClick={() => router.back()} className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
              <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
            </button>
            <div className="flex-1">
              <h1 className="text-[17px] font-bold text-[rgb(var(--color-text-primary))] leading-none">Video chapters</h1>
              {videoTitle && <p className="text-[11px] text-[rgb(var(--color-text-secondary))] line-clamp-1">{videoTitle}</p>}
            </div>
            <button
              onClick={handleSave}
              disabled={saving || !videoId}
              className="flex items-center gap-1.5 px-4 py-1.5 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full hover:opacity-90 disabled:opacity-50 transition-all"
            >
              {saving ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
              {saved ? 'Saved!' : saving ? 'Saving…' : 'Save'}
            </button>
          </div>
        </header>

        {loading ? (
          <div className="flex justify-center py-24"><Loader2 size={28} className="animate-spin text-[rgb(var(--color-text-secondary))]" /></div>
        ) : (
          <main className="px-4 py-5 pb-24 space-y-4">

            <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
              <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">
                Add at least <strong>3 chapters</strong>. The first must start at <strong>0:00</strong>. Each chapter should be at least 10 seconds long.
              </p>
            </div>

            {sortedChapters.map((chapter, i) => (
              <div
                key={chapter.id}
                className="flex items-center gap-3 p-3 bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))]"
              >
                <GripVertical size={16} className="text-[rgb(var(--color-text-tertiary))] flex-shrink-0 cursor-grab" />
                <span className="text-[12px] font-bold text-[rgb(var(--color-text-tertiary))] w-5 text-center flex-shrink-0">{i + 1}</span>

                {/* Timestamp */}
                <input
                  type="text"
                  value={secondsToTimestamp(chapter.startSeconds)}
                  onChange={(e) => {
                    const s = timestampToSeconds(e.target.value);
                    if (!isNaN(s)) updateChapter(chapter.id, 'startSeconds', s);
                  }}
                  className="w-[72px] bg-[rgb(var(--color-background))] text-[rgb(var(--color-text-primary))] px-2 py-1.5 text-[13px] rounded-lg border border-[rgb(var(--color-border))] focus:outline-none focus:border-[rgb(var(--color-primary))] font-mono text-center flex-shrink-0"
                  placeholder="0:00"
                  aria-label={`Chapter ${i + 1} start time`}
                />

                {/* Title */}
                <input
                  type="text"
                  value={chapter.title}
                  onChange={(e) => updateChapter(chapter.id, 'title', e.target.value)}
                  placeholder="Chapter title"
                  maxLength={60}
                  className="flex-1 bg-[rgb(var(--color-background))] text-[rgb(var(--color-text-primary))] px-3 py-1.5 text-[13px] rounded-lg border border-[rgb(var(--color-border))] focus:outline-none focus:border-[rgb(var(--color-primary))] transition-colors"
                  aria-label={`Chapter ${i + 1} title`}
                />

                <button
                  onClick={() => removeChapter(chapter.id)}
                  disabled={chapters.length <= 1}
                  className="p-1.5 text-[rgb(var(--color-text-tertiary))] hover:text-red-500 disabled:opacity-30 transition-colors flex-shrink-0"
                  aria-label="Remove chapter"
                >
                  <Trash2 size={15} />
                </button>
              </div>
            ))}

            <button
              onClick={addChapter}
              className="flex items-center gap-2 w-full p-3 bg-[rgb(var(--color-surface))] rounded-xl border border-dashed border-[rgb(var(--color-border))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors text-[13px] text-[rgb(var(--color-text-secondary))] font-medium justify-center"
            >
              <Plus size={16} /> Add chapter
            </button>

            {error && <p className="text-red-500 text-[13px]">{error}</p>}
          </main>
        )}
      </div>
    </div>
  );
}
