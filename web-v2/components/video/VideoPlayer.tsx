'use client';

// Video Player Component — Video.js with HLS support + native chapter menu
//
// Chapters are injected as a WebVTT <track kind="chapters"> blob URL so that:
//   • Video.js chaptersButton in the control bar lists chapters natively
//   • The chapter name appears as a tooltip when hovering the progress bar
//   • Consumers can also render their own overlay (VideoPlayerWithChapters does this)

import { useEffect, useRef, useState } from 'react';
import videojs from 'video.js';
import 'video.js/dist/video-js.css';
import type Player from 'video.js/dist/types/player';
import type { SubtitleTrack } from '@/types';

export interface PlayerChapter {
  startTime: number; // seconds
  endTime: number;   // seconds
  title: string;
}

interface VideoPlayerProps {
  src: string;
  poster?: string;
  autoplay?: boolean;
  controls?: boolean;
  chapters?: PlayerChapter[];
  subtitles?: SubtitleTrack[];
  enableShortcuts?: boolean;
  startTime?: number;   // seconds to start at (e.g. ?t= deep link)
  resumeKey?: string;   // localStorage key suffix for resume-position
  onTimeUpdate?: (currentTime: number) => void;
  onEnded?: () => void;
  onPlay?: () => void;
  onPause?: () => void;
}

/** Converts a seconds value to WebVTT timestamp format: HH:MM:SS.mmm */
function toVTTTimestamp(secs: number): string {
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  const s = secs % 60;
  const ms = Math.round((s % 1) * 1000);
  return [
    String(h).padStart(2, '0'),
    String(m).padStart(2, '0'),
    `${String(Math.floor(s)).padStart(2, '0')}.${String(ms).padStart(3, '0')}`,
  ].join(':');
}

/**
 * Builds a WebVTT chapters blob URL from an array of chapter objects.
 * Video.js loads this as a text track of kind "chapters" and populates the
 * chaptersButton menu in the control bar automatically.
 */
function buildChaptersVTT(chapters: PlayerChapter[]): string {
  if (chapters.length < 2) return '';
  const cues = chapters.map((ch) =>
    `${toVTTTimestamp(ch.startTime)} --> ${toVTTTimestamp(ch.endTime)}\n${ch.title}`
  );
  const vtt = `WEBVTT\n\n${cues.join('\n\n')}`;
  const blob = new Blob([vtt], { type: 'text/vtt' });
  return URL.createObjectURL(blob);
}

const VideoPlayer = ({
  src,
  poster,
  autoplay = false,
  controls = true,
  chapters,
  subtitles,
  enableShortcuts = false,
  startTime,
  resumeKey,
  onTimeUpdate,
  onEnded,
  onPlay,
  onPause,
}: VideoPlayerProps) => {
  const videoRef = useRef<HTMLDivElement>(null);
  const playerRef = useRef<Player | null>(null);
  const chapterBlobRef = useRef<string>(''); // track blob URL for cleanup
  const lastTimePulseRef = useRef<number>(-1); // throttle for mychannel:player-time
  const didInitialSeekRef = useRef<boolean>(false);
  const lastTapRef = useRef<{ t: number; x: number }>({ t: 0, x: 0 });
  const [isReady, setIsReady] = useState(false);
  const [seekRipple, setSeekRipple] = useState<null | 'fwd' | 'back'>(null);
  const [statsOpen, setStatsOpen] = useState(false);
  const [stats, setStats] = useState<Record<string, string>>({});

  // Initialize player once
  useEffect(() => {
    if (playerRef.current || !videoRef.current) return;

    const videoElement = document.createElement('video-js');
    videoElement.classList.add('vjs-big-play-centered');
    videoRef.current.appendChild(videoElement);

    const player = (playerRef.current = videojs(videoElement, {
      autoplay,
      controls,
      responsive: true,
      fluid: true,
      preload: 'auto',
      poster,
      sources: [{
        src,
        type: src.includes('.m3u8') ? 'application/x-mpegURL' : 'video/mp4',
      }],
      controlBar: {
        children: [
          'playToggle',
          'volumePanel',
          'currentTimeDisplay',
          'timeDivider',
          'durationDisplay',
          'progressControl',
          'liveDisplay',
          'seekToLive',
          'remainingTimeDisplay',
          'customControlSpacer',
          'playbackRateMenuButton',
          'chaptersButton',
          'descriptionsButton',
          'subsCapsButton',
          'audioTrackButton',
          'qualitySelector',
          'fullscreenToggle',
          'pictureInPictureToggle',
        ],
      },
    }));

    player.on('ready', () => {
      setIsReady(true);
      // Restore persisted volume / muted / playback rate (YouTube remembers these)
      try {
        const vol = localStorage.getItem('player:volume');
        const muted = localStorage.getItem('player:muted');
        const rate = localStorage.getItem('player:rate');
        if (vol !== null) player.volume(Math.min(1, Math.max(0, parseFloat(vol))));
        if (muted !== null) player.muted(muted === '1');
        if (rate !== null) player.playbackRate(parseFloat(rate) || 1);
      } catch { /* ignore */ }
    });
    player.on('volumechange', () => {
      try {
        localStorage.setItem('player:volume', String(player.volume() ?? 1));
        localStorage.setItem('player:muted', player.muted() ? '1' : '0');
      } catch { /* ignore */ }
    });
    player.on('ratechange', () => {
      try { localStorage.setItem('player:rate', String(player.playbackRate() ?? 1)); } catch { /* ignore */ }
    });
    player.on('loadedmetadata', () => {
      // Apply initial seek once: explicit ?t= start wins, else saved resume position.
      if (didInitialSeekRef.current) return;
      didInitialSeekRef.current = true;
      const dur = player.duration() || 0;
      let target = 0;
      if (typeof startTime === 'number' && startTime > 0) {
        target = startTime;
      } else if (resumeKey) {
        try {
          const saved = parseFloat(localStorage.getItem(`player:resume:${resumeKey}`) || '0');
          // Only resume if meaningfully into the video and not near the end
          if (saved > 5 && (dur === 0 || saved < dur - 15)) target = saved;
        } catch { /* ignore */ }
      }
      if (target > 0) player.currentTime(target);
    });
    player.on('timeupdate', () => {
      const t = player.currentTime() || 0;
      onTimeUpdate?.(t);
      // Throttled global time pulse (once per ~0.5s) for sibling panels
      // (transcript highlight) without prop-drilling or re-rendering the page.
      const nowSec = Math.floor(t * 2);
      if (nowSec !== lastTimePulseRef.current) {
        lastTimePulseRef.current = nowSec;
        window.dispatchEvent(new CustomEvent('mychannel:player-time', { detail: { time: t } }));
        // Persist resume position (skip the final stretch so finished videos restart)
        if (resumeKey) {
          const dur = player.duration() || 0;
          try {
            if (dur === 0 || t < dur - 15) localStorage.setItem(`player:resume:${resumeKey}`, String(t));
            else localStorage.removeItem(`player:resume:${resumeKey}`);
          } catch { /* ignore */ }
        }
      }
    });
    player.on('ended', () => onEnded?.());
    player.on('play', () => onPlay?.());
    player.on('pause', () => onPause?.());
    player.on('error', (error: any) => console.error('🚨 Video player error:', error));
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // Cross-component seeking: clickable timestamps in the description (and any
  // other sibling component) dispatch a window event with a target time. This
  // avoids prop-drilling a seek handle up through wrapper components.
  useEffect(() => {
    const handleSeek = (e: Event) => {
      const time = (e as CustomEvent<{ time: number }>).detail?.time;
      const player = playerRef.current;
      if (player && typeof time === 'number' && !Number.isNaN(time)) {
        player.currentTime(Math.max(0, time));
        if (player.paused()) void player.play();
      }
    };
    window.addEventListener('mychannel:player-seek', handleSeek as EventListener);
    return () => window.removeEventListener('mychannel:player-seek', handleSeek as EventListener);
  }, []);

  // Update source when it changes
  useEffect(() => {
    if (playerRef.current && isReady) {
      playerRef.current.src({
        src,
        type: src.includes('.m3u8') ? 'application/x-mpegURL' : 'video/mp4',
      });
    }
  }, [src, isReady]);

  // Inject / update the WebVTT chapters track whenever chapters change
  useEffect(() => {
    const player = playerRef.current;
    if (!player || !isReady || !chapters || chapters.length < 2) return;

    // Revoke any previous blob to avoid memory leaks
    if (chapterBlobRef.current) {
      URL.revokeObjectURL(chapterBlobRef.current);
      chapterBlobRef.current = '';
    }

    const blobUrl = buildChaptersVTT(chapters);
    if (!blobUrl) return;
    chapterBlobRef.current = blobUrl;

    // Remove existing chapter tracks before adding the new one
    // Video.js TextTrackList supports length/index access at runtime; its types don't.
    const existing = player.remoteTextTracks() as any;
    for (let i = existing.length - 1; i >= 0; i--) {
      if (existing[i].kind === 'chapters') {
        player.removeRemoteTextTrack(existing[i] as any);
      }
    }

    // Add the new chapters track — Video.js detects kind="chapters" and
    // automatically populates the chaptersButton in the control bar.
    player.addRemoteTextTrack(
      {
        kind: 'chapters',
        src: blobUrl,
        srclang: 'en',
        label: 'Chapters',
        default: true,
      },
      /* manualCleanup */ false
    );
  }, [chapters, isReady]);

  // Inject caption / subtitle text tracks so the subsCapsButton works
  useEffect(() => {
    const player = playerRef.current;
    if (!player || !isReady || !subtitles || subtitles.length === 0) return;

    // Remove existing caption/subtitle tracks before re-adding
    // Video.js TextTrackList supports length/index access at runtime; its types don't.
    const existing = player.remoteTextTracks() as any;
    for (let i = existing.length - 1; i >= 0; i--) {
      const k = existing[i].kind;
      if (k === 'captions' || k === 'subtitles') {
        player.removeRemoteTextTrack(existing[i] as any);
      }
    }

    subtitles.forEach((track, idx) => {
      if (!track.url) return;
      player.addRemoteTextTrack(
        {
          kind: track.isAutoGenerated ? 'captions' : 'subtitles',
          src: track.url,
          srclang: track.languageCode || `lang${idx}`,
          label: track.languageName || track.languageCode || `Track ${idx + 1}`,
        },
        /* manualCleanup */ false
      );
    });
  }, [subtitles, isReady]);

  // Keyboard shortcuts (YouTube parity). Active only when enabled and not typing.
  useEffect(() => {
    if (!enableShortcuts) return;
    const onKey = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null;
      if (target && (target.isContentEditable
        || ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName))) return;
      const player = playerRef.current;
      if (!player) return;
      const dur = player.duration() || 0;
      const cur = player.currentTime() || 0;

      switch (e.key) {
        case ' ':
        case 'k':
          e.preventDefault();
          if (player.paused()) void player.play(); else player.pause();
          break;
        case 'j': player.currentTime(Math.max(0, cur - 10)); break;
        case 'l': player.currentTime(Math.min(dur, cur + 10)); break;
        case 'ArrowLeft': player.currentTime(Math.max(0, cur - 5)); break;
        case 'ArrowRight': player.currentTime(Math.min(dur, cur + 5)); break;
        case 'ArrowUp': e.preventDefault(); player.volume(Math.min(1, (player.volume() || 0) + 0.05)); break;
        case 'ArrowDown': e.preventDefault(); player.volume(Math.max(0, (player.volume() || 0) - 0.05)); break;
        case 'm': player.muted(!player.muted()); break;
        case 'f': if (player.isFullscreen()) void player.exitFullscreen(); else void player.requestFullscreen(); break;
        case 'c': {
          const tracks = player.textTracks() as any;
          for (let i = 0; i < tracks.length; i++) {
            const t = tracks[i];
            if (t.kind === 'captions' || t.kind === 'subtitles') {
              t.mode = t.mode === 'showing' ? 'disabled' : 'showing';
              break;
            }
          }
          break;
        }
        case '>': case '.': if (e.shiftKey) player.playbackRate(Math.min(2, (player.playbackRate() || 1) + 0.25)); break;
        case '<': case ',': if (e.shiftKey) player.playbackRate(Math.max(0.25, (player.playbackRate() || 1) - 0.25)); break;
        default:
          if (/^[0-9]$/.test(e.key) && dur > 0) {
            player.currentTime((parseInt(e.key, 10) / 10) * dur);
          }
      }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [enableShortcuts]);

  // Loop toggle via window event (decoupled from the page-level control)
  useEffect(() => {
    const onLoop = (e: Event) => {
      const enabled = (e as CustomEvent<{ enabled: boolean }>).detail?.enabled;
      const player = playerRef.current;
      if (player && typeof enabled === 'boolean') player.loop(enabled);
    };
    window.addEventListener('mychannel:player-loop', onLoop as EventListener);
    return () => window.removeEventListener('mychannel:player-loop', onLoop as EventListener);
  }, []);

  // "Stats for nerds" toggle
  useEffect(() => {
    const onToggle = () => setStatsOpen((v) => !v);
    window.addEventListener('mychannel:player-stats-toggle', onToggle);
    return () => window.removeEventListener('mychannel:player-stats-toggle', onToggle);
  }, []);

  // Poll player stats while the overlay is open
  useEffect(() => {
    if (!statsOpen) return;
    const compute = () => {
      const p = playerRef.current as any;
      if (!p) return;
      try {
        const vw = p.videoWidth?.() ?? 0;
        const vh = p.videoHeight?.() ?? 0;
        const cur = p.currentTime?.() ?? 0;
        const dur = p.duration?.() ?? 0;
        const buffered = p.bufferedEnd?.() ?? 0;
        const q = p.getVideoPlaybackQuality?.() ?? {};
        setStats({
          Resolution: vw && vh ? `${vw}×${vh}` : '—',
          Viewport: `${Math.round(p.currentWidth?.() ?? 0)}×${Math.round(p.currentHeight?.() ?? 0)}`,
          Time: `${cur.toFixed(1)}s / ${dur.toFixed(1)}s`,
          'Buffer health': `${Math.max(0, buffered - cur).toFixed(1)}s`,
          Speed: `${(p.playbackRate?.() ?? 1).toFixed(2)}×`,
          Volume: `${Math.round((p.muted?.() ? 0 : (p.volume?.() ?? 1)) * 100)}%`,
          'Dropped frames': `${q.droppedVideoFrames ?? 0}`,
        });
      } catch { /* ignore */ }
    };
    compute();
    const id = setInterval(compute, 1000);
    return () => clearInterval(id);
  }, [statsOpen]);

  // Double-tap to seek (mobile): left third −10s, right third +10s
  const handleTouchEnd = (e: React.TouchEvent<HTMLDivElement>) => {
    const touch = e.changedTouches[0];
    if (!touch) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const x = touch.clientX - rect.left;
    const now = Date.now();
    const prev = lastTapRef.current;
    const player = playerRef.current;
    if (player && now - prev.t < 300 && Math.abs(x - prev.x) < 60) {
      const cur = player.currentTime() || 0;
      const dur = player.duration() || 0;
      if (x < rect.width / 3) {
        player.currentTime(Math.max(0, cur - 10));
        setSeekRipple('back');
      } else if (x > (rect.width * 2) / 3) {
        player.currentTime(Math.min(dur, cur + 10));
        setSeekRipple('fwd');
      } else {
        lastTapRef.current = { t: now, x };
        return;
      }
      setTimeout(() => setSeekRipple(null), 500);
      lastTapRef.current = { t: 0, x: 0 };
    } else {
      lastTapRef.current = { t: now, x };
    }
  };

  // Dispose player and clean up blob on unmount
  useEffect(() => {
    return () => {
      if (chapterBlobRef.current) URL.revokeObjectURL(chapterBlobRef.current);
      const player = playerRef.current;
      if (player && !player.isDisposed()) {
        player.dispose();
        playerRef.current = null;
      }
    };
  }, []);

  return (
    <div data-vjs-player className="relative" onTouchEnd={handleTouchEnd}>
      <div ref={videoRef} className="rounded-lg overflow-hidden" />
      {/* Stats for nerds */}
      {statsOpen && (
        <div className="absolute top-2 left-2 bg-black/80 text-white/90 text-[11px] font-mono rounded-lg p-3 space-y-0.5 pointer-events-none max-w-[240px]">
          <div className="flex items-center justify-between gap-4 mb-1">
            <span className="font-semibold">Stats for nerds</span>
          </div>
          {Object.entries(stats).map(([k, v]) => (
            <div key={k} className="flex items-center justify-between gap-4">
              <span className="text-white/60">{k}</span>
              <span>{v}</span>
            </div>
          ))}
        </div>
      )}
      {/* Double-tap seek ripple */}
      {seekRipple && (
        <div
          className={`absolute inset-y-0 ${seekRipple === 'back' ? 'left-0' : 'right-0'} w-1/3 flex items-center justify-center pointer-events-none`}
        >
          <div className="bg-black/55 text-white text-[13px] font-semibold rounded-full px-3 py-2">
            {seekRipple === 'back' ? '« 10s' : '10s »'}
          </div>
        </div>
      )}
    </div>
  );
};

export default VideoPlayer;
