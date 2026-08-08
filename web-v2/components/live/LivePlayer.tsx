'use client';

import {useEffect, useRef, useState} from 'react';
import videojs from 'video.js';
import 'video.js/dist/video-js.css';
import type Player from 'video.js/dist/types/player';
import type {LiveStream} from '@/types/live';
import {recordLiveQoE, type LiveQoEEventType, type LiveQoEMetrics} from '@/lib/firebase/live-qoe';
import {Radio} from 'lucide-react';

interface LivePlayerProps {
  stream: LiveStream;
}

interface VideoJsInternals {
  liveTracker?: {liveCurrentTime: () => number};
  tech?: (unsafeAccess?: boolean) => {
    el?: () => Element;
    vhs?: {playlists?: {media?: () => {attributes?: {BANDWIDTH?: number}}}};
  };
}

function playbackMetrics(player: Player): LiveQoEMetrics {
  const internalPlayer = player as unknown as VideoJsInternals;
  const liveTracker = internalPlayer.liveTracker;
  const currentTime = player.currentTime() ?? 0;
  const liveLatencyMs = liveTracker
    ? Math.max(0, Math.round((liveTracker.liveCurrentTime() - currentTime) * 1_000))
    : undefined;
  const tech = internalPlayer.tech?.(true);
  const element = tech?.el?.();
  const video = element instanceof HTMLVideoElement ? element : undefined;
  const playbackQuality = video?.getVideoPlaybackQuality?.();
  const playlist = tech?.vhs?.playlists?.media?.();
  const bandwidth = Number(playlist?.attributes?.BANDWIDTH ?? 0);

  return {
    ...(liveLatencyMs !== undefined && {liveLatencyMs}),
    ...(bandwidth > 0 && {bitrateKbps: Math.round(bandwidth / 1_000)}),
    ...(video?.videoWidth && {width: video.videoWidth}),
    ...(video?.videoHeight && {height: video.videoHeight}),
    ...(playbackQuality && {droppedFrames: playbackQuality.droppedVideoFrames}),
  };
}

const LivePlayer = ({stream}: LivePlayerProps) => {
  const videoRef = useRef<HTMLDivElement>(null);
  const playerRef = useRef<Player | null>(null);
  const [isReady, setIsReady] = useState(false);
  const [latency, setLatency] = useState(0);

  useEffect(() => {
    if (!videoRef.current || playerRef.current) return;

    const videoElement = document.createElement('video-js');
    videoElement.classList.add('vjs-big-play-centered');
    videoRef.current.appendChild(videoElement);

    const sessionId = crypto.randomUUID();
    const startedAt = performance.now();
    let waitingAt: number | null = null;
    let hasStarted = false;
    let hasEnded = false;
    let lastUiSampleAt = 0;
    let lastHeartbeatAt = 0;
    let previousDroppedFrames = 0;

    const player = playerRef.current = videojs(videoElement, {
      autoplay: true,
      controls: true,
      responsive: true,
      fluid: true,
      liveui: true,
      preload: 'auto',
      html5: {
        vhs: {overrideNative: true},
        nativeAudioTracks: false,
        nativeVideoTracks: false,
      },
      sources: [{src: stream.hlsURL, type: 'application/x-mpegURL'}],
      controlBar: {
        children: [
          'playToggle', 'volumePanel', 'currentTimeDisplay', 'timeDivider',
          'durationDisplay', 'progressControl', 'liveDisplay', 'seekToLive',
          'customControlSpacer', 'playbackRateMenuButton', 'qualitySelector',
          'fullscreenToggle', 'pictureInPictureToggle',
        ],
      },
    });

    const emit = (eventType: LiveQoEEventType, extra: LiveQoEMetrics = {}) => {
      const metrics = playbackMetrics(player);
      const totalDroppedFrames = metrics.droppedFrames ?? previousDroppedFrames;
      const droppedFrames = Math.max(0, totalDroppedFrames - previousDroppedFrames);
      previousDroppedFrames = totalDroppedFrames;
      void recordLiveQoE(stream.id, sessionId, eventType, {
        ...metrics,
        droppedFrames,
        ...extra,
      }).catch(() => undefined);
    };

    const emitEnd = () => {
      if (hasEnded) return;
      hasEnded = true;
      emit('end');
    };

    player.on('ready', () => setIsReady(true));
    player.on('playing', () => {
      if (!hasStarted) {
        hasStarted = true;
        emit('startup', {startupMs: Math.round(performance.now() - startedAt)});
      }
      if (waitingAt !== null) {
        emit('rebuffer', {rebufferMs: Math.round(performance.now() - waitingAt)});
        waitingAt = null;
      }
    });
    player.on('waiting', () => {
      if (hasStarted && waitingAt === null) waitingAt = performance.now();
    });
    player.on('stalled', () => {
      if (hasStarted && waitingAt === null) waitingAt = performance.now();
    });
    player.on('timeupdate', () => {
      const now = performance.now();
      if (now - lastUiSampleAt >= 1_000) {
        const latencyMs = playbackMetrics(player).liveLatencyMs;
        if (latencyMs !== undefined) setLatency(Math.round(latencyMs / 1_000));
        lastUiSampleAt = now;
      }
      if (hasStarted && now - lastHeartbeatAt >= 30_000) {
        emit('heartbeat');
        lastHeartbeatAt = now;
      }
    });
    player.on('error', () => {
      const code = player.error()?.code;
      emit('error', {errorCode: code ? `videojs_${code}` : 'videojs_unknown'});
    });
    player.on('ended', emitEnd);

    return () => {
      emitEnd();
      if (!player.isDisposed()) player.dispose();
      playerRef.current = null;
    };
  }, [stream.hlsURL, stream.id]);

  return (
    <div className="relative bg-black">
      {stream.isLive && (
        <div className="absolute left-4 top-4 z-20 flex items-center gap-2 rounded-full bg-red-600 px-3 py-1.5">
          <Radio size={14} className="animate-pulse text-white" />
          <span className="text-sm font-semibold uppercase text-white">Live</span>
        </div>
      )}
      {stream.isLive && (
        <div className="absolute right-4 top-4 z-20 rounded-full bg-black/70 px-3 py-1.5 backdrop-blur">
          <span className="text-sm font-medium text-white">{stream.viewerCount.toLocaleString()} watching</span>
        </div>
      )}
      {isReady && latency > 0 && (
        <div className="absolute right-4 top-16 z-20 rounded bg-black/50 px-2 py-1 text-xs text-white/70 backdrop-blur">
          {latency}s latency
        </div>
      )}
      <div data-vjs-player><div ref={videoRef} /></div>
    </div>
  );
};

export default LivePlayer;

