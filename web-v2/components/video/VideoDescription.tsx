'use client';

// VideoDescription — YouTube-parity description block.
//   • Views • upload date header
//   • Collapsible body with rich text: clickable timestamps, URLs, @mentions, #hashtags
//   • "Key moments" chapters list (from videos/{id}/chapters) synced to seek
//   • "Show transcript" button (opens the transcript engagement panel)
//   • Category footer

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { ChevronDown, ListVideo, FileText } from 'lucide-react';
import { collection, getDocs, orderBy, query } from 'firebase/firestore';
import { db } from '@/lib/firebase/config';

interface VideoDescriptionProps {
  videoId: string;
  description: string;
  viewCount: number;
  uploadDate: string;
  categoryName?: string;
  hasTranscript?: boolean;
  onShowTranscript?: () => void;
}

interface Chapter {
  id: string;
  title: string;
  startTime: number;
}

function seekTo(seconds: number) {
  window.dispatchEvent(new CustomEvent('mychannel:player-seek', { detail: { time: seconds } }));
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function timestampToSeconds(ts: string): number {
  const parts = ts.split(':').map(Number);
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  return 0;
}

function secondsToTimestamp(secs: number): string {
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  const s = Math.floor(secs % 60);
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${m}:${String(s).padStart(2, '0')}`;
}

// Matches URLs, @mentions, #hashtags, and H:MM:SS / M:SS timestamps.
const RICH_RE = /(https?:\/\/[^\s]+)|(\B@[A-Za-z0-9_.]{2,})|(\B#[A-Za-z0-9_]+)|(\b(?:\d{1,2}:)?[0-5]?\d:[0-5]\d\b)/g;

/** Tokenizes description text into plain strings + clickable rich nodes. */
function renderRichText(text: string): React.ReactNode[] {
  const nodes: React.ReactNode[] = [];
  let lastIndex = 0;
  let match: RegExpExecArray | null;
  let key = 0;

  RICH_RE.lastIndex = 0;
  while ((match = RICH_RE.exec(text)) !== null) {
    const [full, url, mention, hashtag, timestamp] = match;
    const start = match.index;
    if (start > lastIndex) nodes.push(text.slice(lastIndex, start));

    if (url) {
      nodes.push(
        <a key={`u-${key++}`} href={url} target="_blank" rel="noopener noreferrer"
          className="text-[rgb(var(--color-primary))] hover:underline break-all">{url}</a>
      );
    } else if (mention) {
      nodes.push(
        <Link key={`m-${key++}`} href={`/search?q=${encodeURIComponent(mention)}`}
          className="text-[rgb(var(--color-primary))] hover:underline">{mention}</Link>
      );
    } else if (hashtag) {
      nodes.push(
        <Link key={`h-${key++}`} href={`/search?q=${encodeURIComponent(hashtag)}`}
          className="text-[rgb(var(--color-primary))] hover:underline">{hashtag}</Link>
      );
    } else if (timestamp) {
      const seconds = timestampToSeconds(timestamp);
      nodes.push(
        <button key={`t-${key++}`} onClick={() => seekTo(seconds)}
          className="text-[rgb(var(--color-primary))] hover:underline font-medium">{timestamp}</button>
      );
    }
    lastIndex = start + full.length;
  }
  if (lastIndex < text.length) nodes.push(text.slice(lastIndex));
  return nodes;
}

export default function VideoDescription({
  videoId, description, viewCount, uploadDate, categoryName, hasTranscript, onShowTranscript,
}: VideoDescriptionProps) {
  const [expanded, setExpanded] = useState(false);
  const [chapters, setChapters] = useState<Chapter[]>([]);
  const [showChapters, setShowChapters] = useState(false);

  const body = description || 'No description provided.';
  const rendered = useMemo(() => renderRichText(body), [body]);

  // Load chapters for the "Key moments" list
  useEffect(() => {
    if (!videoId || videoId === '_fallback') return;
    let cancelled = false;
    getDocs(query(collection(db, 'videos', videoId, 'chapters'), orderBy('startTime', 'asc')))
      .then((snap) => {
        if (cancelled) return;
        setChapters(snap.docs.map((d) => ({
          id: d.id,
          title: d.data().title ?? '',
          startTime: d.data().startTime ?? 0,
        })));
      })
      .catch(() => {});
    return () => { cancelled = true; };
  }, [videoId]);

  return (
    <div className="bg-[rgb(var(--color-surface))] rounded-xl p-4 mb-6">
      <div className="flex items-center gap-2 text-[13px] font-medium text-[rgb(var(--color-text-primary))] mb-2 flex-wrap">
        <span>{viewCount.toLocaleString()} views</span>
        {uploadDate && <><span>•</span><span>{uploadDate}</span></>}
      </div>

      <div
        className={`text-[13.5px] text-[rgb(var(--color-text-primary))] whitespace-pre-wrap leading-relaxed ${
          !expanded ? 'line-clamp-3' : ''
        }`}
      >
        {rendered}
      </div>

      {/* Action chips: transcript + chapters */}
      {expanded && (hasTranscript || chapters.length >= 2) && (
        <div className="flex flex-wrap gap-2 mt-3">
          {hasTranscript && (
            <button
              onClick={onShowTranscript}
              className="flex items-center gap-1.5 px-3 py-1.5 text-[12px] font-medium text-[rgb(var(--color-text-primary))] bg-[rgb(var(--color-background))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
            >
              <FileText size={14} /> Show transcript
            </button>
          )}
          {chapters.length >= 2 && (
            <button
              onClick={() => setShowChapters((v) => !v)}
              className="flex items-center gap-1.5 px-3 py-1.5 text-[12px] font-medium text-[rgb(var(--color-text-primary))] bg-[rgb(var(--color-background))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
            >
              <ListVideo size={14} /> {showChapters ? 'Hide' : 'Show'} chapters ({chapters.length})
            </button>
          )}
        </div>
      )}

      {/* Key moments / chapters list */}
      {expanded && showChapters && chapters.length >= 2 && (
        <div className="mt-3 space-y-0.5 border-t border-[rgb(var(--color-border))] pt-3">
          {chapters.map((c) => (
            <button
              key={c.id}
              onClick={() => seekTo(c.startTime)}
              className="w-full flex items-center gap-3 px-2 py-1.5 rounded-lg hover:bg-[rgb(var(--color-surface-hover))] transition-colors text-left"
            >
              <span className="text-[12px] font-medium text-[rgb(var(--color-primary))] tabular-nums w-14 flex-shrink-0">
                {secondsToTimestamp(c.startTime)}
              </span>
              <span className="text-[13px] text-[rgb(var(--color-text-primary))] truncate">{c.title}</span>
            </button>
          ))}
        </div>
      )}

      {/* Category footer */}
      {expanded && categoryName && (
        <p className="text-[12px] text-[rgb(var(--color-text-secondary))] mt-3 border-t border-[rgb(var(--color-border))] pt-3">
          Category: <span className="text-[rgb(var(--color-text-primary))]">{categoryName}</span>
        </p>
      )}

      <button
        onClick={() => setExpanded((v) => !v)}
        className="flex items-center gap-1 text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mt-2 hover:text-[rgb(var(--color-text-secondary))] transition-colors"
      >
        {expanded ? 'Show less' : 'Show more'}
        <ChevronDown size={15} className={`transition-transform ${expanded ? 'rotate-180' : ''}`} />
      </button>
    </div>
  );
}
