'use client';

import {useEffect, useState} from 'react';
import LivePlayer from '@/components/live/LivePlayer';
import LiveChat from '@/components/live/LiveChat';
import LiveInfo from '@/components/live/LiveInfo';
import {subscribeToLiveStream} from '@/lib/firebase/live-stream';
import {
  connectLiveViewerPresence,
  subscribeToLiveViewerCount,
} from '@/lib/firebase/live-presence';
import type {LiveStream} from '@/types/live';

type LoadState = 'loading' | 'ready' | 'missing' | 'error';

function resolveStreamId(initialStreamId: string): string {
  if (initialStreamId !== '_fallback') return initialStreamId;
  const segments = window.location.pathname.split('/').filter(Boolean);
  const liveIndex = segments.indexOf('live');
  const encodedId = liveIndex >= 0 ? segments[liveIndex + 1] : '';
  if (!encodedId || encodedId === '_fallback') return '';
  try {
    return decodeURIComponent(encodedId);
  } catch {
    return '';
  }
}

function StreamState({title, detail}: {title: string; detail: string}) {
  return (
    <main className="flex min-h-screen items-center justify-center bg-[rgb(var(--color-background))] px-6">
      <section className="w-full max-w-xl rounded-2xl border border-white/10 bg-[rgb(var(--color-surface))] p-8 text-center">
        <h1 className="text-xl font-semibold text-[rgb(var(--color-text-primary))]">{title}</h1>
        <p className="mt-2 text-sm text-[rgb(var(--color-text-secondary))]">{detail}</p>
      </section>
    </main>
  );
}

function playbackMessage(stream: LiveStream): string {
  switch (stream.status) {
    case 'scheduled':
      return 'This stream has not started yet.';
    case 'connecting':
      return 'The creator is connecting to the live ingest service.';
    case 'ended':
    case 'archived':
      return 'This live stream has ended and no replay is available yet.';
    case 'degraded':
      return 'Playback is temporarily unavailable while the stream recovers.';
    default:
      return 'Live playback is temporarily unavailable.';
  }
}

export default function LiveStreamPageClient({initialStreamId}: {initialStreamId: string}) {
  const [streamId, setStreamId] = useState(initialStreamId === '_fallback' ? '' : initialStreamId);
  const [stream, setStream] = useState<LiveStream | null>(null);
  const [viewerCount, setViewerCount] = useState<number | null>(null);
  const [loadState, setLoadState] = useState<LoadState>('loading');

  useEffect(() => {
    setStreamId(resolveStreamId(initialStreamId));
  }, [initialStreamId]);

  useEffect(() => {
    if (!streamId) return;
    setLoadState('loading');
    return subscribeToLiveStream(streamId, value => {
      setStream(value);
      setLoadState(value ? 'ready' : 'missing');
    }, () => {
      setStream(null);
      setLoadState('error');
    });
  }, [streamId]);

  useEffect(() => {
    if (!streamId) return;
    const unsubscribeCount = subscribeToLiveViewerCount(streamId, setViewerCount);
    const disconnectPresence = connectLiveViewerPresence(streamId);
    return () => {
      unsubscribeCount();
      disconnectPresence();
    };
  }, [streamId]);

  if (!streamId || loadState === 'loading') {
    return <StreamState title="Loading live stream" detail="Connecting to the MyChannel live control plane…" />;
  }
  if (loadState === 'missing') {
    return <StreamState title="Stream not found" detail="This stream does not exist or is no longer available." />;
  }
  if (loadState === 'error' || !stream) {
    return <StreamState title="Live stream unavailable" detail="The stream could not be loaded. Try again shortly." />;
  }

  const displayedStream = viewerCount === null ? stream : {...stream, viewerCount};

  return (
    <main className="min-h-screen bg-[rgb(var(--color-background))]">
      <div className="mx-auto max-w-[1920px]">
        <div className="grid grid-cols-1 lg:grid-cols-[1fr_400px]">
          <div>
            <div className="relative">
              {displayedStream.hlsURL ? (
                <LivePlayer stream={displayedStream} />
              ) : (
                <div className="flex aspect-video items-center justify-center bg-black px-6 text-center text-sm text-white/70">
                  {playbackMessage(displayedStream)}
                </div>
              )}
            </div>
            <div className="p-6"><LiveInfo stream={displayedStream} /></div>
          </div>
          <aside className="h-screen lg:sticky lg:top-0">
            <LiveChat
              streamId={displayedStream.id}
              chatEnabled={displayedStream.chatEnabled}
              creatorId={displayedStream.streamer.id}
            />
          </aside>
        </div>
      </div>
    </main>
  );
}
