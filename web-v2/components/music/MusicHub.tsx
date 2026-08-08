'use client';

import Link from 'next/link';
import { useEffect, useRef, useState } from 'react';
import { AlertCircle, ArrowRight, Headphones, Music2, RefreshCw, Sparkles } from 'lucide-react';
import MainLayout from '@/components/layout/MainLayout';
import MusicTrackCard from '@/components/music/MusicTrackCard';
import { getPublishedMusicTracks } from '@/services/music.service';
import type { MusicTrack } from '@/types/music';

type LoadState = 'loading' | 'ready' | 'error';

function TrackGridSkeleton() {
  return (
    <div className="grid gap-4 lg:grid-cols-2" aria-hidden="true">
      {Array.from({ length: 6 }, (_, index) => (
        <div
          key={index}
          className="flex gap-4 rounded-2xl border border-[rgb(var(--color-border))] bg-[rgb(var(--color-surface))] p-4 sm:p-5"
        >
          <div className="skeleton h-24 w-24 shrink-0 rounded-xl sm:h-28 sm:w-28" />
          <div className="flex flex-1 flex-col justify-center gap-3">
            <div className="skeleton h-5 w-3/4 rounded" />
            <div className="skeleton h-4 w-1/2 rounded" />
            <div className="skeleton h-10 w-full rounded-lg" />
          </div>
        </div>
      ))}
    </div>
  );
}

function StudioLink({ compact = false }: { compact?: boolean }) {
  return (
    <Link
      href="/studio"
      className={`inline-flex items-center justify-center gap-2 rounded-full bg-white font-bold text-neutral-950 shadow-lg transition hover:bg-white/90 active:scale-[0.98] ${
        compact ? 'px-5 py-2.5 text-sm' : 'px-6 py-3 text-sm sm:text-base'
      }`}
    >
      Go to Creator Studio
      <ArrowRight size={17} aria-hidden="true" />
    </Link>
  );
}

export default function MusicHub() {
  const [tracks, setTracks] = useState<MusicTrack[]>([]);
  const [loadState, setLoadState] = useState<LoadState>('loading');
  const requestId = useRef(0);

  useEffect(() => {
    const currentRequest = ++requestId.current;
    getPublishedMusicTracks()
      .then((publishedTracks) => {
        if (requestId.current !== currentRequest) return;
        setTracks(publishedTracks);
        setLoadState('ready');
      })
      .catch((error: unknown) => {
        if (requestId.current !== currentRequest) return;
        console.error('Unable to load published music tracks:', error);
        setTracks([]);
        setLoadState('error');
      });

    return () => {
      requestId.current += 1;
    };
  }, []);

  const retryTracks = async () => {
    const currentRequest = ++requestId.current;
    setLoadState('loading');

    try {
      const publishedTracks = await getPublishedMusicTracks();
      if (requestId.current !== currentRequest) return;
      setTracks(publishedTracks);
      setLoadState('ready');
    } catch (error) {
      if (requestId.current !== currentRequest) return;
      console.error('Unable to load published music tracks:', error);
      setTracks([]);
      setLoadState('error');
    }
  };

  return (
    <MainLayout>
      <div className="min-h-[calc(100dvh-3.5rem)] bg-[rgb(var(--color-background))]">
        <section className="relative isolate overflow-hidden border-b border-[rgb(var(--color-border))] bg-neutral-950 text-white">
          <div className="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_top_left,rgba(217,70,239,0.35),transparent_38%),radial-gradient(circle_at_80%_30%,rgba(239,68,68,0.35),transparent_35%),linear-gradient(135deg,#09090b,#18181b)]" />
          <div className="mx-auto flex max-w-[1600px] flex-col gap-8 px-4 py-10 sm:px-6 sm:py-14 lg:flex-row lg:items-center lg:justify-between lg:py-16">
            <div className="max-w-3xl">
              <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.16em] text-white/80 backdrop-blur">
                <Sparkles size={14} aria-hidden="true" />
                Creator sound, front and center
              </div>
              <h1 className="text-4xl font-black tracking-tight sm:text-5xl lg:text-6xl">
                Music Hub
              </h1>
              <p className="mt-4 max-w-2xl text-base leading-7 text-white/70 sm:text-lg">
                Discover published tracks from independent artists and listen instantly with accessible, native playback.
              </p>
            </div>

            <div className="rounded-2xl border border-white/10 bg-white/10 p-5 shadow-2xl backdrop-blur-md sm:p-6 lg:max-w-sm">
              <div className="flex items-center gap-3">
                <div className="rounded-xl bg-white/10 p-3" aria-hidden="true">
                  <Music2 size={24} />
                </div>
                <div>
                  <p className="font-bold">Ready to share your sound?</p>
                  <p className="mt-0.5 text-sm text-white/65">Start from your creator workspace.</p>
                </div>
              </div>
              <div className="mt-5">
                <StudioLink />
              </div>
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-[1600px] px-4 py-8 sm:px-6 sm:py-10">
          <div className="mb-6 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <div className="flex items-center gap-2 text-[rgb(var(--color-text-primary))]">
                <Headphones size={22} aria-hidden="true" />
                <h2 className="text-2xl font-extrabold tracking-tight">Published tracks</h2>
              </div>
              <p className="mt-1 text-sm text-[rgb(var(--color-text-secondary))]">
                Fresh sounds from the MyChannel creator community.
              </p>
            </div>
            {loadState === 'ready' && tracks.length > 0 && (
              <p className="text-sm font-medium text-[rgb(var(--color-text-secondary))]" aria-live="polite">
                {tracks.length} {tracks.length === 1 ? 'track' : 'tracks'}
              </p>
            )}
          </div>

          {loadState === 'loading' && (
            <div role="status" aria-live="polite">
              <span className="sr-only">Loading published music tracks</span>
              <TrackGridSkeleton />
            </div>
          )}

          {loadState === 'error' && (
            <div className="rounded-2xl border border-red-500/20 bg-red-500/5 px-5 py-12 text-center" role="alert">
              <AlertCircle className="mx-auto text-red-500" size={34} aria-hidden="true" />
              <h2 className="mt-3 text-lg font-bold text-[rgb(var(--color-text-primary))]">
                Music is taking a beat
              </h2>
              <p className="mx-auto mt-2 max-w-md text-sm text-[rgb(var(--color-text-secondary))]">
                We could not load the catalog right now. Check your connection and try again.
              </p>
              <button
                type="button"
                onClick={() => void retryTracks()}
                className="mt-5 inline-flex items-center gap-2 rounded-full bg-[rgb(var(--color-text-primary))] px-5 py-2.5 text-sm font-bold text-[rgb(var(--color-background))] transition hover:opacity-85 active:scale-[0.98]"
              >
                <RefreshCw size={16} aria-hidden="true" />
                Try again
              </button>
            </div>
          )}

          {loadState === 'ready' && tracks.length === 0 && (
            <div className="rounded-2xl border border-[rgb(var(--color-border))] bg-[rgb(var(--color-surface))] px-5 py-14 text-center">
              <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-[rgb(var(--color-background))] text-[rgb(var(--color-text-secondary))]" aria-hidden="true">
                <Music2 size={28} />
              </div>
              <h2 className="mt-4 text-xl font-bold text-[rgb(var(--color-text-primary))]">
                The stage is ready
              </h2>
              <p className="mx-auto mt-2 max-w-md text-sm leading-6 text-[rgb(var(--color-text-secondary))]">
                No published music is available yet. Creators can manage their content from Studio.
              </p>
              <div className="mt-5 inline-block rounded-full bg-neutral-950 p-px dark:bg-white">
                <StudioLink compact />
              </div>
            </div>
          )}

          {loadState === 'ready' && tracks.length > 0 && (
            <div className="grid gap-4 lg:grid-cols-2">
              {tracks.map((track) => (
                <MusicTrackCard key={track.id} track={track} />
              ))}
            </div>
          )}
        </section>
      </div>
    </MainLayout>
  );
}
