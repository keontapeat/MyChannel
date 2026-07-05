'use client';

// VideoPlayerWithChapters — wraps VideoPlayer with:
//   • Chapter marker dots on the progress bar
//   • Active chapter name display
//   • End screen overlay in the last 20s
//   • Super Thanks button

import { useEffect, useRef, useState } from 'react';
import { collection, getDocs, orderBy, query } from 'firebase/firestore';
import { db } from '@/lib/firebase/config';
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
  onTimeUpdate?: (currentTime: number) => void;
}

function secondsToTimestamp(secs: number): string {
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  const s = Math.floor(secs % 60);
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${m}:${String(s).padStart(2, '0')}`;
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
  onTimeUpdate,
}: VideoPlayerWithChaptersProps) {
  const [currentTime, setCurrentTime] = useState(0);
  const [chapters, setChapters] = useState<Chapter[]>([]);
  const [endScreens, setEndScreens] = useState<EndScreenElement[]>([]);
  const [activeChapter, setActiveChapter] = useState<Chapter | null>(null);
  const [showEndScreens, setShowEndScreens] = useState(false);
  const [showClipCreator, setShowClipCreator] = useState(false);

  // Load chapters and end screens
  useEffect(() => {
    if (!videoId || videoId === '_fallback') return;
    let cancelled = false;

    const loadChapters = async () => {
      try {
        const snap = await getDocs(
          query(collection(db, 'videos', videoId, 'chapters'), orderBy('startTime', 'asc'))
        );
        if (!cancelled) {
          setChapters(snap.docs.map((d) => ({
            id: d.id,
            title: d.data().title ?? '',
            startTime: d.data().startTime ?? 0,
          })));
        }
      } catch { /* non-fatal */ }
    };

    const loadEndScreens = async () => {
      try {
        const snap = await getDocs(
          collection(db, 'endScreens', videoId, 'elements')
        );
        if (!cancelled) {
          setEndScreens(snap.docs.map((d) => ({ id: d.id, ...d.data() } as EndScreenElement)));
        }
      } catch { /* non-fatal */ }
    };

    loadChapters();
    loadEndScreens();
    return () => { cancelled = true; };
  }, [videoId]);

  // Track active chapter and end screen visibility
  useEffect(() => {
    if (chapters.length >= 3) {
      const active = [...chapters].reverse().find((c) => currentTime >= c.startTime);
      setActiveChapter(active ?? null);
    }
    if (duration > 0) {
      setShowEndScreens(currentTime >= duration - 20 && currentTime < duration);
    }
  }, [currentTime, chapters, duration]);

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
        onTimeUpdate={(t) => { setCurrentTime(t); onTimeUpdate?.(t); }}
        onEnded={onEnded}
      />

      {/* Active chapter name overlay */}
      {activeChapter && (
        <div className="absolute top-3 left-3 px-2.5 py-1 bg-black/70 text-white text-[12px] font-semibold rounded-full pointer-events-none select-none">
          {activeChapter.title}
        </div>
      )}

      {/* Chapter markers on progress bar */}
      {chapters.length >= 3 && duration > 0 && (
        <div className="absolute bottom-[44px] left-0 right-0 px-[8px] pointer-events-none">
          <div className="relative w-full h-0">
            {chapters.map((chapter, i) => {
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
        <EndScreenCard key={el.id} element={el} creatorName={creatorName} />
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

function EndScreenCard({ element, creatorName }: { element: EndScreenElement; creatorName: string }) {
  const posStyle: React.CSSProperties = {
    position: 'absolute',
    left: `${Math.max(2, Math.min(80, element.posX * 100))}%`,
    top: `${Math.max(5, Math.min(70, element.posY * 100))}%`,
    animation: 'fadeInScale 0.3s ease',
  };

  const baseClass = 'flex items-center gap-1.5 px-3 py-2 rounded-xl text-[12px] font-semibold text-white border border-white/30 backdrop-blur-sm shadow-lg cursor-pointer hover:scale-105 transition-transform';

  switch (element.type) {
    case 'subscribe':
      return (
        <div style={posStyle} className={`${baseClass} bg-red-600/90`}>
          <Users size={13} />
          Subscribe to {creatorName}
        </div>
      );
    case 'video':
    case 'playlist':
      return (
        <a href={element.targetVideoId ? `/watch/${element.targetVideoId}` : '#'} style={posStyle} className={`${baseClass} bg-black/80`}>
          <PlayCircle size={13} />
          Watch next
        </a>
      );
    case 'link':
      return (
        <a href={element.linkURL ?? '#'} target="_blank" rel="noopener noreferrer" style={posStyle} className={`${baseClass} bg-black/80`}>
          <ExternalLink size={13} />
          {element.linkTitle || 'Visit link'}
        </a>
      );
    default:
      return null;
  }
}
