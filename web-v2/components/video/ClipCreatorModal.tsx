'use client';

// ClipCreatorModal — YouTube Clips parity
// Viewers drag handles on a timeline to select up to 60s, name the clip, and save.
// A Firestore doc is written immediately; a Cloud Function extracts the bytes server-side.

import { useState, useRef, useCallback } from 'react';
import { X, Scissors, Loader2, Check } from 'lucide-react';
import { addDoc, collection, serverTimestamp } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

interface ClipCreatorModalProps {
  videoId: string;
  videoTitle: string;
  thumbnailUrl: string;
  durationSeconds: number;
  currentTimeSeconds: number;
  onClose: () => void;
}

const MAX_CLIP_SECONDS = 60;

function secondsToTimestamp(secs: number): string {
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  const s = Math.floor(secs % 60);
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${m}:${String(s).padStart(2, '0')}`;
}

export default function ClipCreatorModal({
  videoId,
  videoTitle,
  thumbnailUrl,
  durationSeconds,
  currentTimeSeconds,
  onClose,
}: ClipCreatorModalProps) {
  // Default selection: 30s around current playback position
  const defaultStart = Math.max(0, Math.min(currentTimeSeconds - 15, durationSeconds - MAX_CLIP_SECONDS));
  const defaultEnd = Math.min(defaultStart + 30, durationSeconds);

  const [startSec, setStartSec] = useState(Math.round(defaultStart));
  const [endSec, setEndSec] = useState(Math.round(defaultEnd));
  const [clipTitle, setClipTitle] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState('');

  const trackRef = useRef<HTMLDivElement>(null);

  const clipDuration = endSec - startSec;
  const startPct = durationSeconds > 0 ? (startSec / durationSeconds) * 100 : 0;
  const endPct = durationSeconds > 0 ? (endSec / durationSeconds) * 100 : 100;

  // Drag logic for the range handles
  const handleDrag = useCallback(
    (handle: 'start' | 'end', e: React.MouseEvent<HTMLDivElement>) => {
      const track = trackRef.current;
      if (!track) return;
      e.preventDefault();

      const onMove = (moveEvent: MouseEvent) => {
        const rect = track.getBoundingClientRect();
        const pct = Math.max(0, Math.min(1, (moveEvent.clientX - rect.left) / rect.width));
        const sec = Math.round(pct * durationSeconds);

        if (handle === 'start') {
          const maxStart = Math.max(0, endSec - 1);
          const newStart = Math.max(0, Math.min(maxStart, sec));
          // Don't let clip exceed MAX_CLIP_SECONDS
          if (endSec - newStart > MAX_CLIP_SECONDS) {
            setStartSec(endSec - MAX_CLIP_SECONDS);
          } else {
            setStartSec(newStart);
          }
        } else {
          const minEnd = startSec + 1;
          const maxEnd = Math.min(durationSeconds, startSec + MAX_CLIP_SECONDS);
          setEndSec(Math.max(minEnd, Math.min(maxEnd, sec)));
        }
      };

      const onUp = () => {
        window.removeEventListener('mousemove', onMove);
        window.removeEventListener('mouseup', onUp);
      };

      window.addEventListener('mousemove', onMove);
      window.addEventListener('mouseup', onUp);
    },
    [startSec, endSec, durationSeconds]
  );

  const handleSave = async () => {
    if (!clipTitle.trim()) { setError('Give your clip a title'); return; }
    if (clipDuration <= 0) { setError('Select a valid clip range'); return; }
    if (!auth?.currentUser) { setError('Sign in to create clips'); return; }

    setSubmitting(true);
    setError('');

    try {
      await addDoc(collection(db, 'clips'), {
        sourceVideoId: videoId,
        sourceVideoTitle: videoTitle,
        title: clipTitle.trim(),
        thumbnailUrl: thumbnailUrl,
        startSeconds: startSec,
        endSeconds: endSec,
        durationSeconds: clipDuration,
        creatorId: auth.currentUser.uid,
        creatorName: auth.currentUser.displayName ?? 'Viewer',
        viewCount: 0,
        clipUrl: '',        // Cloud Function fills this in after extraction
        status: 'processing',
        createdAt: serverTimestamp(),
      });
      setDone(true);
    } catch (e: any) {
      setError(e?.message ?? 'Failed to create clip. Try again.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/70 p-4"
      onClick={(e) => e.target === e.currentTarget && onClose()}
      role="dialog"
      aria-modal="true"
      aria-label="Create Clip"
    >
      <div className="bg-[rgb(var(--color-background))] w-full max-w-[540px] rounded-2xl overflow-hidden shadow-2xl">
        {/* Header */}
        <div className="flex items-center justify-between px-5 pt-5 pb-3 border-b border-[rgb(var(--color-border))]">
          <div className="flex items-center gap-2">
            <Scissors size={18} className="text-[rgb(var(--color-primary))]" />
            <h2 className="text-[16px] font-bold text-[rgb(var(--color-text-primary))]">Create clip</h2>
          </div>
          <button onClick={onClose} className="p-1.5 hover:bg-[rgb(var(--color-surface-hover))] rounded-full" aria-label="Close">
            <X size={18} className="text-[rgb(var(--color-text-secondary))]" />
          </button>
        </div>

        {done ? (
          /* Success */
          <div className="px-5 py-10 text-center">
            <div className="w-14 h-14 bg-green-500/10 rounded-full flex items-center justify-center mx-auto mb-4">
              <Check size={28} className="text-green-500" />
            </div>
            <p className="text-[16px] font-bold text-[rgb(var(--color-text-primary))] mb-1">Clip created!</p>
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))] mb-5">
              Your clip is being processed and will appear in the Clips tab shortly.
            </p>
            <button onClick={onClose} className="px-6 py-2.5 bg-[rgb(var(--color-primary))] text-white font-semibold rounded-full hover:opacity-90">
              Done
            </button>
          </div>
        ) : (
          <div className="px-5 py-5 space-y-5">
            {/* Thumbnail preview */}
            <div className="relative rounded-xl overflow-hidden aspect-video bg-black">
              {thumbnailUrl ? (
                <img src={thumbnailUrl} alt={videoTitle} className="w-full h-full object-cover opacity-60" />
              ) : (
                <div className="w-full h-full bg-[rgb(var(--color-surface))]" />
              )}
              {/* Selected range overlay */}
              <div
                className="absolute top-0 bottom-0 bg-[rgb(var(--color-primary))]/30 border-x-2 border-[rgb(var(--color-primary))]"
                style={{ left: `${startPct}%`, right: `${100 - endPct}%` }}
              />
              {/* Duration badge */}
              <div className="absolute bottom-2 left-1/2 -translate-x-1/2 px-2.5 py-1 bg-black/80 text-white text-[12px] font-bold rounded-full">
                {secondsToTimestamp(clipDuration)}
              </div>
            </div>

            {/* Timeline scrubber */}
            <div className="space-y-1">
              <div className="flex items-center justify-between text-[11px] text-[rgb(var(--color-text-tertiary))]">
                <span>{secondsToTimestamp(startSec)}</span>
                <span className="text-[rgb(var(--color-primary))] font-semibold">
                  {clipDuration}s / {MAX_CLIP_SECONDS}s max
                </span>
                <span>{secondsToTimestamp(endSec)}</span>
              </div>

              {/* Track */}
              <div
                ref={trackRef}
                className="relative h-8 bg-[rgb(var(--color-surface))] rounded-full cursor-pointer select-none"
                aria-label="Clip range selector"
              >
                {/* Full track */}
                <div className="absolute inset-y-0 left-0 right-0 rounded-full overflow-hidden">
                  {thumbnailUrl && (
                    <img src={thumbnailUrl} alt="" className="w-full h-full object-cover opacity-30" aria-hidden="true" />
                  )}
                </div>

                {/* Selected range highlight */}
                <div
                  className="absolute inset-y-0 bg-[rgb(var(--color-primary))]/40 rounded-full"
                  style={{ left: `${startPct}%`, right: `${100 - endPct}%` }}
                />

                {/* Start handle */}
                <div
                  className="absolute top-0 bottom-0 w-4 -ml-2 flex items-center justify-center cursor-ew-resize z-10"
                  style={{ left: `${startPct}%` }}
                  onMouseDown={(e) => handleDrag('start', e)}
                  role="slider"
                  aria-label="Clip start"
                  aria-valuenow={startSec}
                  aria-valuemin={0}
                  aria-valuemax={endSec - 1}
                  tabIndex={0}
                  onKeyDown={(e) => {
                    if (e.key === 'ArrowLeft') setStartSec(s => Math.max(0, s - 1));
                    if (e.key === 'ArrowRight') setStartSec(s => Math.min(endSec - 1, s + 1));
                  }}
                >
                  <div className="w-4 h-8 bg-[rgb(var(--color-primary))] rounded-l-full" />
                </div>

                {/* End handle */}
                <div
                  className="absolute top-0 bottom-0 w-4 -mr-2 flex items-center justify-center cursor-ew-resize z-10"
                  style={{ left: `${endPct}%` }}
                  onMouseDown={(e) => handleDrag('end', e)}
                  role="slider"
                  aria-label="Clip end"
                  aria-valuenow={endSec}
                  aria-valuemin={startSec + 1}
                  aria-valuemax={Math.min(durationSeconds, startSec + MAX_CLIP_SECONDS)}
                  tabIndex={0}
                  onKeyDown={(e) => {
                    const maxEnd = Math.min(durationSeconds, startSec + MAX_CLIP_SECONDS);
                    if (e.key === 'ArrowLeft') setEndSec(s => Math.max(startSec + 1, s - 1));
                    if (e.key === 'ArrowRight') setEndSec(s => Math.min(maxEnd, s + 1));
                  }}
                >
                  <div className="w-4 h-8 bg-[rgb(var(--color-primary))] rounded-r-full" />
                </div>
              </div>

              <p className="text-[11px] text-[rgb(var(--color-text-tertiary))] text-center">
                Drag handles to select up to 60 seconds · Use arrow keys for precision
              </p>
            </div>

            {/* Title input */}
            <input
              type="text"
              value={clipTitle}
              onChange={(e) => setClipTitle(e.target.value.slice(0, 60))}
              placeholder="Give your clip a title…"
              className="w-full px-4 py-2.5 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-xl text-[14px] text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] outline-none focus:border-[rgb(var(--color-primary))]"
              maxLength={60}
              aria-label="Clip title"
            />
            <div className="flex justify-end -mt-3">
              <span className="text-[11px] text-[rgb(var(--color-text-tertiary))]">{clipTitle.length}/60</span>
            </div>

            {error && (
              <p className="text-[12px] text-red-500">{error}</p>
            )}

            {/* Actions */}
            <div className="flex gap-3">
              <button
                onClick={onClose}
                className="flex-1 py-2.5 border border-[rgb(var(--color-border))] rounded-full text-[13px] font-semibold text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                disabled={submitting || !clipTitle.trim() || clipDuration <= 0}
                className="flex-1 py-2.5 bg-[rgb(var(--color-primary))] text-white rounded-full text-[13px] font-semibold hover:opacity-90 disabled:opacity-50 flex items-center justify-center gap-2"
              >
                {submitting && <Loader2 size={14} className="animate-spin" />}
                {submitting ? 'Creating…' : `Create clip · ${secondsToTimestamp(clipDuration)}`}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
