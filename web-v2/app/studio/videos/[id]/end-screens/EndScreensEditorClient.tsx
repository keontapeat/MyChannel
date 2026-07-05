'use client';

// End Screens & Cards Editor — YouTube Studio parity
// Creators add subscribe buttons, video recommendations, and links
// that appear in the final 20 seconds of a video

import { useState, useEffect } from 'react';
import {
  ChevronLeft, Plus, Trash2, Loader2, Save, Monitor,
  PlayCircle, Users, Link as LinkIcon, AlertCircle, CheckCircle,
} from 'lucide-react';
import Link from 'next/link';
import {
  doc, getDoc, getDocs, collection, setDoc, deleteDoc, serverTimestamp,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

type EndScreenElementType = 'video' | 'subscribe' | 'channel' | 'link' | 'playlist';

interface EndScreenElement {
  id: string;
  type: EndScreenElementType;
  startTime: number; // seconds from start (must be within last 20s)
  duration: number; // seconds visible (min 5, max 20)
  // Video/playlist
  targetVideoId?: string;
  targetVideoTitle?: string;
  // Subscribe / channel
  channelId?: string;
  channelName?: string;
  // External link
  linkURL?: string;
  linkTitle?: string;
  // Position (0-1 relative to player)
  posX: number;
  posY: number;
  isNew?: boolean;
}

const TYPE_CONFIG: Record<EndScreenElementType, { label: string; icon: React.ElementType; color: string; description: string }> = {
  video:     { label: 'Video',     icon: PlayCircle, color: 'text-blue-500',   description: 'Link to a specific video' },
  subscribe: { label: 'Subscribe', icon: Users,      color: 'text-red-500',    description: 'Subscribe button for your channel' },
  channel:   { label: 'Channel',   icon: Users,      color: 'text-purple-500', description: 'Feature another channel' },
  link:      { label: 'Link',      icon: LinkIcon,   color: 'text-green-500',  description: 'External approved website' },
  playlist:  { label: 'Playlist',  icon: PlayCircle, color: 'text-orange-500', description: 'Link to a playlist' },
};

function secondsToTimestamp(secs: number): string {
  const m = Math.floor(secs / 60);
  const s = secs % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}

function ElementCard({
  element,
  index,
  videoDuration,
  onUpdate,
  onDelete,
}: {
  element: EndScreenElement;
  index: number;
  videoDuration: number;
  onUpdate: (id: string, updates: Partial<EndScreenElement>) => void;
  onDelete: (id: string) => void;
}) {
  const cfg = TYPE_CONFIG[element.type];
  const Icon = cfg.icon;
  const maxStart = Math.max(0, videoDuration - 5);
  const minStart = Math.max(0, videoDuration - 20);

  return (
    <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <Icon size={16} className={cfg.color} />
          <span className="text-[14px] font-semibold text-[rgb(var(--color-text-primary))]">
            {cfg.label}
          </span>
          <span className="text-[11px] text-[rgb(var(--color-text-tertiary))] bg-[rgb(var(--color-surface-hover))] px-2 py-0.5 rounded-full">
            {cfg.description}
          </span>
        </div>
        <button
          onClick={() => onDelete(element.id)}
          className="p-1.5 hover:bg-red-50 dark:hover:bg-red-900/10 rounded-full text-[rgb(var(--color-text-tertiary))] hover:text-red-500"
          aria-label="Remove element"
        >
          <Trash2 size={14} />
        </button>
      </div>

      <div className="grid grid-cols-2 gap-3">
        {/* Start time */}
        <div>
          <label className="block text-[11px] text-[rgb(var(--color-text-secondary))] mb-1">Start time</label>
          <input
            type="range"
            min={minStart}
            max={maxStart}
            value={element.startTime}
            onChange={(e) => onUpdate(element.id, { startTime: Number(e.target.value) })}
            className="w-full accent-[rgb(var(--color-primary))]"
          />
          <p className="text-[11px] text-[rgb(var(--color-text-tertiary))] mt-0.5 text-center">
            {secondsToTimestamp(element.startTime)}
          </p>
        </div>

        {/* Duration */}
        <div>
          <label className="block text-[11px] text-[rgb(var(--color-text-secondary))] mb-1">Duration</label>
          <input
            type="range"
            min={5}
            max={20}
            value={element.duration}
            onChange={(e) => onUpdate(element.id, { duration: Number(e.target.value) })}
            className="w-full accent-[rgb(var(--color-primary))]"
          />
          <p className="text-[11px] text-[rgb(var(--color-text-tertiary))] mt-0.5 text-center">
            {element.duration}s
          </p>
        </div>

        {/* Type-specific fields */}
        {(element.type === 'video' || element.type === 'playlist') && (
          <div className="col-span-2">
            <label className="block text-[11px] text-[rgb(var(--color-text-secondary))] mb-1">
              {element.type === 'video' ? 'Video ID' : 'Playlist ID'}
            </label>
            <input
              type="text"
              value={element.targetVideoId ?? ''}
              onChange={(e) => onUpdate(element.id, { targetVideoId: e.target.value })}
              placeholder={element.type === 'video' ? 'e.g. abc123xyz' : 'e.g. PLabc123'}
              className="w-full px-3 py-1.5 bg-[rgb(var(--color-surface-hover))] border border-[rgb(var(--color-border))] rounded-lg text-[13px] text-[rgb(var(--color-text-primary))] outline-none focus:border-[rgb(var(--color-primary))]"
            />
          </div>
        )}

        {element.type === 'channel' && (
          <div className="col-span-2">
            <label className="block text-[11px] text-[rgb(var(--color-text-secondary))] mb-1">Channel name</label>
            <input
              type="text"
              value={element.channelName ?? ''}
              onChange={(e) => onUpdate(element.id, { channelName: e.target.value })}
              placeholder="Channel name"
              className="w-full px-3 py-1.5 bg-[rgb(var(--color-surface-hover))] border border-[rgb(var(--color-border))] rounded-lg text-[13px] text-[rgb(var(--color-text-primary))] outline-none focus:border-[rgb(var(--color-primary))]"
            />
          </div>
        )}

        {element.type === 'link' && (
          <>
            <div>
              <label className="block text-[11px] text-[rgb(var(--color-text-secondary))] mb-1">URL</label>
              <input
                type="url"
                value={element.linkURL ?? ''}
                onChange={(e) => onUpdate(element.id, { linkURL: e.target.value })}
                placeholder="https://..."
                className="w-full px-3 py-1.5 bg-[rgb(var(--color-surface-hover))] border border-[rgb(var(--color-border))] rounded-lg text-[13px] text-[rgb(var(--color-text-primary))] outline-none focus:border-[rgb(var(--color-primary))]"
              />
            </div>
            <div>
              <label className="block text-[11px] text-[rgb(var(--color-text-secondary))] mb-1">Link title</label>
              <input
                type="text"
                value={element.linkTitle ?? ''}
                onChange={(e) => onUpdate(element.id, { linkTitle: e.target.value })}
                placeholder="Visit my site"
                className="w-full px-3 py-1.5 bg-[rgb(var(--color-surface-hover))] border border-[rgb(var(--color-border))] rounded-lg text-[13px] text-[rgb(var(--color-text-primary))] outline-none focus:border-[rgb(var(--color-primary))]"
              />
            </div>
          </>
        )}
      </div>
    </div>
  );
}

export default function EndScreensEditorClient({ videoId }: { videoId: string }) {
  const [elements, setElements] = useState<EndScreenElement[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [videoDuration, setVideoDuration] = useState(300);
  const [videoTitle, setVideoTitle] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    if (!videoId || videoId === '_fallback') { setLoading(false); return; }

    const load = async () => {
      try {
        const videoSnap = await getDoc(doc(db, 'videos', videoId));
        if (videoSnap.exists()) {
          const d = videoSnap.data();
          setVideoDuration(d.duration ?? 300);
          setVideoTitle(d.title ?? 'Untitled');
        }

        const colSnap = await getDocs(collection(db, 'endScreens', videoId, 'elements'));
        setElements(
          colSnap.docs.map((d) => ({ id: d.id, ...d.data() } as EndScreenElement))
        );
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [videoId]);

  const addElement = (type: EndScreenElementType) => {
    if (elements.length >= 4) { setError('Maximum 4 end screen elements allowed'); return; }
    const startTime = Math.max(0, videoDuration - 20);
    const newEl: EndScreenElement = {
      id: `new_${Date.now()}`,
      type,
      startTime,
      duration: 10,
      posX: 0.5,
      posY: 0.5,
      isNew: true,
    };
    if (type === 'subscribe') newEl.channelId = auth?.currentUser?.uid ?? '';
    setElements([...elements, newEl]);
  };

  const updateElement = (id: string, updates: Partial<EndScreenElement>) => {
    setElements((prev) => prev.map((el) => el.id === id ? { ...el, ...updates } : el));
  };

  const deleteElement = (id: string) => {
    setElements((prev) => prev.filter((el) => el.id !== id));
  };

  const save = async () => {
    const uid = auth?.currentUser?.uid;
    if (!uid) { setError('Not signed in'); return; }

    setSaving(true);
    setError('');

    try {
      const colRef = collection(db, 'endScreens', videoId, 'elements');
      const existing = await getDocs(colRef);
      await Promise.all(existing.docs.map((d) => deleteDoc(d.ref)));

      await Promise.all(
        elements.map((el) => {
          const { isNew, id, ...data } = el;
          return setDoc(doc(colRef, id.startsWith('new_') ? undefined as any : id), {
            ...data,
            videoId,
            updatedAt: serverTimestamp(),
          });
        })
      );

      setElements((prev) => prev.map((el) => ({ ...el, isNew: false })));
      setSuccess('End screens saved');
      setTimeout(() => setSuccess(''), 3000);
    } catch (e) {
      console.error(e);
      setError('Failed to save. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-[rgb(var(--color-background))] flex items-center justify-center">
        <Loader2 size={28} className="animate-spin text-[rgb(var(--color-text-tertiary))]" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      <div className="max-w-[640px] mx-auto">
        <header className="sticky top-0 z-50 bg-[rgb(var(--color-background))]/95 backdrop-blur border-b border-[rgb(var(--color-border))] px-4 py-3">
          <div className="flex items-center gap-3">
            <Link href={`/studio/videos/${videoId}/edit`} className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full">
              <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
            </Link>
            <Monitor size={20} className="text-green-500" />
            <div className="flex-1 min-w-0">
              <h1 className="text-[17px] font-bold text-[rgb(var(--color-text-primary))] leading-none">End screens</h1>
              <p className="text-[11px] text-[rgb(var(--color-text-secondary))] truncate">{videoTitle}</p>
            </div>
            <button
              onClick={save}
              disabled={saving}
              className="flex items-center gap-1.5 px-4 py-2 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full hover:opacity-90 disabled:opacity-50"
            >
              {saving ? <Loader2 size={13} className="animate-spin" /> : <Save size={13} />}
              Save
            </button>
          </div>
        </header>

        <main className="px-4 py-5 pb-24 space-y-4">
          <div className="bg-[rgb(var(--color-surface))] rounded-xl p-4 border border-[rgb(var(--color-border))]">
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">
              End screens appear in the <span className="font-semibold text-[rgb(var(--color-text-primary))]">last 20 seconds</span> of your video. Add up to 4 elements.
            </p>
          </div>

          {error && (
            <div className="flex items-center gap-2 p-3 bg-red-500/10 border border-red-500 rounded-xl text-[13px] text-red-500">
              <AlertCircle size={15} /> {error}
            </div>
          )}
          {success && (
            <div className="flex items-center gap-2 p-3 bg-green-500/10 border border-green-500 rounded-xl text-[13px] text-green-500">
              <CheckCircle size={15} /> {success}
            </div>
          )}

          {/* Add element buttons */}
          {elements.length < 4 && (
            <div>
              <p className="text-[12px] font-semibold text-[rgb(var(--color-text-secondary))] mb-2 uppercase tracking-wide">
                Add element
              </p>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {(Object.entries(TYPE_CONFIG) as [EndScreenElementType, typeof TYPE_CONFIG[EndScreenElementType]][]).map(([type, cfg]) => {
                  const Icon = cfg.icon;
                  return (
                    <button
                      key={type}
                      onClick={() => addElement(type)}
                      className="flex items-center gap-2 p-3 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-xl text-[13px] font-medium text-[rgb(var(--color-text-primary))] hover:border-[rgb(var(--color-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-all"
                    >
                      <Icon size={16} className={cfg.color} />
                      {cfg.label}
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* Elements */}
          {elements.length === 0 ? (
            <div className="text-center py-10 text-[13px] text-[rgb(var(--color-text-secondary))]">
              No end screen elements. Add one above.
            </div>
          ) : (
            <div className="space-y-3">
              {elements.map((el, i) => (
                <ElementCard
                  key={el.id}
                  element={el}
                  index={i}
                  videoDuration={videoDuration}
                  onUpdate={updateElement}
                  onDelete={deleteElement}
                />
              ))}
            </div>
          )}
        </main>
      </div>
    </div>
  );
}
