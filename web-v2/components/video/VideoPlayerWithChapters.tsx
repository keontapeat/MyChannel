'use client';

// VideoPlayerWithChapters — wraps VideoPlayer with:
//   • Chapter marker dots on the progress bar
//   • Active chapter name display
//   • End screen overlay in the last 20s
//   • Super Thanks button

import { useEffect, useState } from 'react';
import { collection, getDocs, orderBy, query } from 'firebase/firestore';
import { db } from '@/lib/firebase/config';
import {safeExternalUrl} from '@/lib/video-detail-security';
import VideoPlayer from './VideoPlayer';
import type { PlayerChapter } from './VideoPlayer';
import ClipCreatorModal from './ClipCreatorModal';
import { Heart, ExternalLink, Users, PlayCircle, Scissors } from 'lucide-react';

interface Chapter {
  id: string;
  title: string;
  startTime: number;
}

interface EndScreenElement {
  id: string;
  type: 'video' | 'subscribe' | 'channel' | 'link' | 'playlist';
  startTime: number;
  duration: number;
  targetVideoId?: string;
  channelName?: string;
  linkURL?: string;
  linkTitle?: string;
  posX: number;
  posY: number;
}

interface VideoPlayerWithChaptersProps {
  videoId: string;
  src: string;
  poster?: string;
  duration: number;
  creatorId: string;
  creatorName: string;
  videoTitle?: string;
  subtitles?: import('@/types').SubtitleTrack[];
  startTime?: number;
  onSuperThanks?: () => void;
  onEnded?: () => void;
  onPlay?: () => void;
  onPause?: () => void;
  onTimeUpdate?: (currentTime: number) => void;
}

function secondsToTimestamp(secs: number): string {
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  const s = Math.floor(secs % 60);
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${m}:${String(s).padStart(2, '0')}`;
}

function sanitizeChapter(id: string, value: Record<string, unknown>, videoDuration: number): Chapter | null {
  const title = typeof value.title === 'string' ? value.title.trim().slice(0, 200) : '';
  const startTime = Number(value.startTime);
  if (!title || !Number.isFinite(startTime) || startTime < 0 ||
      (videoDuration > 0 && startTime >= videoDuration)) return null;
  return {id, title, startTime};
}

function sanitizeEndScreen(
  id: string,
  value: Record<string, unknown>,
  videoDuration: number,
): EndScreenElement | null {
  const allowedTypes = new Set(['video', 'subscribe', 'channel', 'link', 'playlist']);
  const type = typeof value.type === 'string' ? value.type : '';
  const startTime = Number(value.startTime);
  const elementDuration = Number(value.duration);
  const posX = Number(value.posX);
  const posY = Number(value.posY);
  if (!allowedTypes.has(type) || !Number.isFinite(startTime) || startTime < 0 ||
      !Number.isFinite(elementDuration) || elementDuration <= 0 || elementDuration > 300 ||
      !Number.isFinite(posX) || !Number.isFinite(posY) ||
      (videoDuration > 0 && startTime >= videoDuration)) return null;

  return {
    id,
    type: type as EndScreenElement['type'],
    startTime,
    duration: elementDuration,
    posX: Math.max(0, Math.min(1, posX)),
    posY: Math.max(0, Math.min(1, posY)),
    targetVideoId: typeof value.targetVideoId === 'string' ? value.targetVideoId.slice(0, 128) : undefined,
    channelName: typeof value.channelName === 'string' ? value.channelName.slice(0, 100) : undefined,
    linkURL: typeof value.linkURL === 'string' ? value.linkURL.slice(0, 2048) : undefined,
    linkTitle: typeof value.linkTitle === 'string' ? value.linkTitle.slice(0, 100) : undefined,
  };
}

export default function VideoPlayerWithChapters({
  videoId,
  src,
  poster,
  duration,
  creatorId,
  creatorName,
  videoTitle = '',
  subtitles,
  startTime,
  onSuperThanks,
  onEnded,
  onPlay,
  onPause,
  onTimeUpdate,
}: VideoPlayerWithChaptersProps) {
  const [playbackClock, setPlaybackClock] = useState({videoId, time: 0});
  const [chapterState, setChapterState] = useState<{videoId: string; items: Chapter[]}>(
    {videoId, items: []},
  );
  const [endScreenState, setEndScreenState] = useState<{
    videoId: string;
    items: EndScreenElement[];
  }>({videoId, items: []});
  const [showClipCreator, setShowClipCreator] = useState(false);
  const currentTime = playbackClock.videoId === videoId ? playbackClock.time : 0;
  const chapters = chapterState.videoId === videoId ? chapterState.items : [];
  const endScreens = endScreenState.videoId === videoId ? endScreenState.items : [];

  // Load and validate untrusted chapter/end-screen documents. Keying the data
  // by video ID makes stale state invisible immediately without effect resets.
  useEffect(() => {
    if (!videoId || videoId === '_fallback') return;
    let cancelled = false;

    const loadChapters = async () => {
      try {
        const snap = await getDocs(
          query(collection(db, 'videos', videoId, 'chapters'), orderBy('startTime', 'asc'))
        );
        if (!cancelled) {
          const sanitized = snap.docs
            .map((chapterDoc) => sanitizeChapter(
              chapterDoc.id,
              chapterDoc.data() as Record<string, unknown>,
              duration,
            ))
            .filter((chapter): chapter is Chapter => chapter !== null)
            .sort((left, right) => left.startTime - right.startTime);
          setChapterState({videoId, items: sanitized});
        }
      } catch { /* non-fatal */ }
    };

    const loadEndScreens = async () => {
      try {
        const snap = await getDocs(
          collection(db, 'endScreens', videoId, 'elements')
        );
        if (!cancelled) {
          const sanitized = snap.docs
            .map((elementDoc) => sanitizeEndScreen(
              elementDoc.id,
              elementDoc.data() as Record<string, unknown>,
              duration,
            ))
            .filter((element): element is EndScreenElement => element !== null);
          setEndScreenState({videoId, items: sanitized});
        }
      } catch { /* non-fatal */ }
    };

    void loadChapters();
    void loadEndScreens();
    return () => { cancelled = true; };
  }, [videoId, duration]);

  const activeChapter = chapters.length >= 2
    ? [...chapters].reverse().find((chapter) => currentTime >= chapter.startTime) ?? null
    : null;
  const showEndScreens = duration > 0 && currentTime >= duration - 20 && currentTime < duration;
  const visibleEndScreens = showEndScreens
    ? endScreens.filter((el) => currentTime >= el.startTime && currentTime <= el.startTime + el.duration)
    : [];

  // Build PlayerChapter[] for Video.js native chapter menu (requires endTime)
  const playerChapters: PlayerChapter[] = chapters.length >= 2
    ? chapters.map((ch, i) => ({
        startTime: ch.startTime,
        endTime: i < chapters.length - 1 ? chapters[i + 1].startTime : (duration || ch.startTime + 60),
        title: ch.title,
      }))
    : [];

  return (
    <div className="relative">
      {/* Video player — chapters injected as WebVTT track for native chapter menu */}
      <VideoPlayer
        src={src}
        poster={poster}
        controls
        chapters={playerChapters.length >= 2 ? playerChapters : undefined}
        subtitles={subtitles}
        enableShortcuts
        startTime={startTime}
        resumeKey={videoId}
        onTimeUpdate={(time) => {
          setPlaybackClock({videoId, time});
          onTimeUpdate?.(time);
        }}
        onPlay={onPlay}
        onPause={onPause}
        onEnded={onEnded}
      />

      {/* Active chapter name overlay */}
      {activeChapter && (
        <div
          role="status"
          aria-live="polite"
          className="absolute top-3 left-3 px-2.5 py-1 bg-black/70 text-white text-[12px] font-semibold rounded-full pointer-events-none select-none"
        >
          {activeChapter.title}
        </div>
      )}

      {/* Chapter markers on progress bar */}
      {chapters.length >= 3 && duration > 0 && (
        <div aria-hidden="true" className="absolute bottom-[44px] left-0 right-0 px-[8px] pointer-events-none">
          <div className="relative w-full h-0">
            {chapters.map((chapter) => {
              if (chapter.startTime === 0) return null; // skip first
              const pct = (chapter.startTime / duration) * 100;
              return (
                <div
                  key={chapter.id}
                  className="absolute top-0 w-[2px] h-[4px] bg-white/80 rounded-full -translate-y-1/2"
                  style={{ left: `${pct}%` }}
                  title={`${chapter.title} — ${secondsToTimestamp(chapter.startTime)}`}
                />
              );
            })}
          </div>
        </div>
      )}

      {/* End screen elements overlay */}
      {visibleEndScreens.map((el) => (
        <EndScreenCard
          key={el.id}
          element={el}
          creatorId={creatorId}
          creatorName={creatorName}
        />
      ))}

      {/* Super Thanks button */}
      {onSuperThanks && (
        <button
          onClick={onSuperThanks}
          className="absolute bottom-3 right-3 flex items-center gap-1.5 px-3 py-1.5 bg-black/70 hover:bg-black/90 text-white text-[12px] font-semibold rounded-full transition-colors border border-white/20"
          aria-label="Send Super Thanks"
        >
          <Heart size={13} fill="currentColor" className="text-red-400" />
          Super Thanks
        </button>
      )}

      {/* Clip button */}
      <button
        onClick={() => setShowClipCreator(true)}
        className="absolute bottom-3 left-3 flex items-center gap-1.5 px-3 py-1.5 bg-black/70 hover:bg-black/90 text-white text-[12px] font-semibold rounded-full transition-colors border border-white/20"
        aria-label="Create clip"
      >
        <Scissors size={13} />
        Clip
      </button>

      {/* Clip creator modal */}
      {showClipCreator && (
        <ClipCreatorModal
          videoId={videoId}
          videoTitle={videoTitle}
          thumbnailUrl={poster ?? ''}
          durationSeconds={duration}
          currentTimeSeconds={currentTime}
          onClose={() => setShowClipCreator(false)}
        />
      )}
    </div>
  );
}

function EndScreenCard({
  element,
  creatorId,
  creatorName,
}: {
  element: EndScreenElement;
  creatorId: string;
  creatorName: string;
}) {
  const posStyle: React.CSSProperties = {
    position: 'absolute',
    left: `${Math.max(2, Math.min(80, element.posX * 100))}%`,
    top: `${Math.max(5, Math.min(70, element.posY * 100))}%`,
    animation: 'fadeInScale 0.3s ease',
  };
  const baseClass = 'flex items-center gap-1.5 px-3 py-2 rounded-xl text-[12px] font-semibold text-white border border-white/30 backdrop-blur-sm shadow-lg hover:scale-105 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white transition-transform';
  const validTargetId = typeof element.targetVideoId === 'string' &&
    /^[A-Za-z0-9_-]{1,128}$/.test(element.targetVideoId)
    ? element.targetVideoId
    : null;

  switch (element.type) {
    case 'subscribe':
      return /^[A-Za-z0-9_-]{1,128}$/.test(creatorId) ? (
        <a href={`/profile/${encodeURIComponent(creatorId)}`} style={posStyle} className={`${baseClass} bg-red-600/90`}>
          <Users size={13} />
          Subscribe to {creatorName}
        </a>
      ) : null;
    case 'video':
    case 'playlist':
      return validTargetId ? (
        <a href={`/watch/${encodeURIComponent(validTargetId)}`} style={posStyle} className={`${baseClass} bg-black/80`}>
          <PlayCircle size={13} />
          Watch next
        </a>
      ) : null;
    case 'link': {
      const safeLink = safeExternalUrl(element.linkURL);
      return safeLink ? (
        <a href={safeLink} target="_blank" rel="noopener noreferrer" style={posStyle} className={`${baseClass} bg-black/80`}>
          <ExternalLink size={13} />
          {element.linkTitle || 'Visit link'}
        </a>
      ) : null;
    }
    default:
      return null;
  }
}
