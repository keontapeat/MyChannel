'use client';

// useQueue — session video queue (YouTube "Add to queue" parity).
// Backed by localStorage so it survives watch-page navigations (each route
// change remounts the page) and reloads. Changes broadcast via a window event
// so every mounted consumer stays in sync.

import { useCallback, useEffect, useState } from 'react';

export interface QueueItem {
  id: string;
  title: string;
  thumbnailURL: string;
  channelName?: string;
  duration?: number;
}

const KEY = 'watch:queue';
const EVENT = 'mychannel:queue-changed';

function read(): QueueItem[] {
  if (typeof window === 'undefined') return [];
  try {
    const raw = localStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as QueueItem[]) : [];
  } catch {
    return [];
  }
}

function write(q: QueueItem[]) {
  if (typeof window === 'undefined') return;
  try {
    localStorage.setItem(KEY, JSON.stringify(q));
    window.dispatchEvent(new Event(EVENT));
  } catch {
    /* ignore quota / serialization errors */
  }
}

/** Append an item to the queue (no duplicates). Usable outside React. */
export function addToQueue(item: QueueItem): boolean {
  const q = read();
  if (q.some((x) => x.id === item.id)) return false;
  write([...q, item]);
  return true;
}

export function useQueue() {
  const [queue, setQueue] = useState<QueueItem[]>([]);

  useEffect(() => {
    setQueue(read());
    const onChange = () => setQueue(read());
    window.addEventListener(EVENT, onChange);
    window.addEventListener('storage', onChange);
    return () => {
      window.removeEventListener(EVENT, onChange);
      window.removeEventListener('storage', onChange);
    };
  }, []);

  const add = useCallback((item: QueueItem) => addToQueue(item), []);
  const remove = useCallback((id: string) => write(read().filter((x) => x.id !== id)), []);
  const clear = useCallback(() => write([]), []);

  /** The id to play after `currentId` finishes, or null. */
  const nextAfter = useCallback((currentId: string): string | null => {
    const q = read();
    if (q.length === 0) return null;
    const idx = q.findIndex((x) => x.id === currentId);
    if (idx >= 0) return q[idx + 1]?.id ?? null;
    // Current video isn't in the queue — start the queue from the top
    return q[0]?.id !== currentId ? q[0]?.id ?? null : null;
  }, []);

  return { queue, add, remove, clear, nextAfter };
}
