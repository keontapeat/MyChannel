'use client';

import { useRef, useState } from 'react';
import { Disc3, Music2 } from 'lucide-react';
import { submitQualifiedMusicPlay } from '@/services/music.service';
import type { MusicTrack } from '@/types/music';

const QUALIFIED_PLAY_SECONDS = 30;

interface MusicTrackCardProps {
  track: MusicTrack;
}

export default function MusicTrackCard({ track }: MusicTrackCardProps) {
  const playbackLabel = `Play ${track.title} by ${track.artistName}`;
  const [telemetryError, setTelemetryError] = useState<string | null>(null);
  const sessionIdRef = useRef<string | null>(null);
  const listenedSecondsRef = useRef(0);
  const lastPositionRef = useRef<number | null>(null);
  const lastTickMsRef = useRef<number | null>(null);
  const submissionAttemptedRef = useRef(false);

  const resetSession = () => {
    sessionIdRef.current = null;
    listenedSecondsRef.current = 0;
    lastPositionRef.current = null;
    lastTickMsRef.current = null;
    submissionAttemptedRef.current = false;
  };

  const startSession = (audio: HTMLAudioElement) => {
    if (!sessionIdRef.current) {
      sessionIdRef.current = crypto.randomUUID().toLowerCase();
      listenedSecondsRef.current = 0;
      submissionAttemptedRef.current = false;
      setTelemetryError(null);
    }
    lastPositionRef.current = audio.currentTime;
    lastTickMsRef.current = performance.now();
  };

  const submitIfQualified = () => {
    const sessionId = sessionIdRef.current;
    if (
      listenedSecondsRef.current < QUALIFIED_PLAY_SECONDS ||
      submissionAttemptedRef.current ||
      !sessionId
    ) return;

    // Mark before the request: retries reuse the server-idempotent session, but this
    // playback session must never emit more than one accounting request.
    submissionAttemptedRef.current = true;
    void submitQualifiedMusicPlay(track.id, sessionId).catch((error: unknown) => {
      console.warn('Qualified music play was not recorded:', error);
      setTelemetryError('Playback continues, but play activity could not be recorded.');
    });
  };

  const recordPlaybackProgress = (audio: HTMLAudioElement) => {
    if (audio.seeking || !sessionIdRef.current) return;

    const nowMs = performance.now();
    const previousPosition = lastPositionRef.current;
    const previousTickMs = lastTickMsRef.current;
    if (previousPosition !== null && previousTickMs !== null) {
      const mediaDeltaSeconds = audio.currentTime - previousPosition;
      const wallDeltaSeconds = Math.max(0, (nowMs - previousTickMs) / 1000);
      const playbackRate = audio.playbackRate > 0 ? audio.playbackRate : 1;

      if (mediaDeltaSeconds > 0 && wallDeltaSeconds > 0) {
        listenedSecondsRef.current += Math.min(
          wallDeltaSeconds,
          mediaDeltaSeconds / playbackRate,
        );
      }
    }

    lastPositionRef.current = audio.currentTime;
    lastTickMsRef.current = nowMs;
    submitIfQualified();
  };

  const handleTimeUpdate = (audio: HTMLAudioElement) => {
    if (audio.paused || audio.seeking) return;
    if (!sessionIdRef.current) startSession(audio);
    recordPlaybackProgress(audio);
  };

  return (
    <article className="group overflow-hidden rounded-2xl border border-[rgb(var(--color-border))] bg-[rgb(var(--color-surface))] shadow-sm transition duration-200 hover:-translate-y-0.5 hover:shadow-lg">
      <div className="flex gap-4 p-4 sm:p-5">
        <div className="relative h-24 w-24 shrink-0 overflow-hidden rounded-xl bg-gradient-to-br from-fuchsia-600 via-red-500 to-amber-400 shadow-md sm:h-28 sm:w-28">
          {track.artworkUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={track.artworkUrl}
              alt={`${track.title} artwork`}
              loading="lazy"
              className="h-full w-full object-cover transition duration-300 group-hover:scale-105"
            />
          ) : (
            <div className="flex h-full w-full items-center justify-center" aria-hidden="true">
              <Music2 className="text-white/90" size={38} strokeWidth={1.6} />
            </div>
          )}
        </div>

        <div className="min-w-0 flex-1 py-0.5">
          <div className="flex items-start justify-between gap-2">
            <div className="min-w-0">
              <h2 className="truncate text-base font-bold text-[rgb(var(--color-text-primary))] sm:text-lg">
                {track.title}
              </h2>
              <p className="mt-0.5 truncate text-sm font-medium text-[rgb(var(--color-text-secondary))]">
                {track.artistName}
              </p>
            </div>
            {track.isExplicit && (
              <span className="shrink-0 rounded-md border border-[rgb(var(--color-border))] bg-[rgb(var(--color-background))] px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide text-[rgb(var(--color-text-secondary))]">
                Explicit
              </span>
            )}
          </div>

          <div className="mt-3 flex flex-wrap items-center gap-2 text-xs text-[rgb(var(--color-text-secondary))]">
            {track.albumName && (
              <span className="inline-flex min-w-0 items-center gap-1 truncate" title={track.albumName}>
                <Disc3 size={13} aria-hidden="true" />
                {track.albumName}
              </span>
            )}
            {track.albumName && track.genre && <span aria-hidden="true">•</span>}
            {track.genre && (
              <span className="rounded-full bg-[rgb(var(--color-background))] px-2 py-1 font-medium">
                {track.genre}
              </span>
            )}
          </div>
        </div>
      </div>

      <div className="border-t border-[rgb(var(--color-border))] bg-[rgb(var(--color-background))]/70 px-4 py-3 sm:px-5">
        <audio
          controls
          preload="none"
          src={track.audioUrl}
          aria-label={playbackLabel}
          className="h-10 w-full"
          onPlay={(event) => startSession(event.currentTarget)}
          onPause={(event) => {
            recordPlaybackProgress(event.currentTarget);
            lastPositionRef.current = null;
            lastTickMsRef.current = null;
          }}
          onSeeking={() => {
            // Seeking is not a new playback session, but the jump itself must
            // never count toward actual listened time.
            lastPositionRef.current = null;
            lastTickMsRef.current = null;
          }}
          onSeeked={(event) => {
            if (!event.currentTarget.paused) startSession(event.currentTarget);
          }}
          onRateChange={(event) => {
            lastPositionRef.current = event.currentTarget.currentTime;
            lastTickMsRef.current = performance.now();
          }}
          onTimeUpdate={(event) => handleTimeUpdate(event.currentTarget)}
          onLoadStart={resetSession}
          onEnded={resetSession}
          onError={resetSession}
        >
          Your browser does not support audio playback.
        </audio>
        {telemetryError && (
          <p
            className="mt-2 text-xs text-amber-700 dark:text-amber-300"
            role="status"
            aria-live="polite"
          >
            {telemetryError}
          </p>
        )}
      </div>
    </article>
  );
}
