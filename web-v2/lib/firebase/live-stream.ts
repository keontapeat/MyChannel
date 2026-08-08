import {doc, onSnapshot, type DocumentData, type Unsubscribe} from 'firebase/firestore';
import type {LiveStream} from '@/types/live';
import {db} from './config';

type UnknownRecord = Record<string, unknown>;

function record(value: unknown): UnknownRecord {
  return value && typeof value === 'object' ? value as UnknownRecord : {};
}

function text(value: unknown, fallback = ''): string {
  return typeof value === 'string' ? value.trim() : fallback;
}

function count(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.max(0, Math.round(parsed)) : 0;
}

function date(value: unknown, fallback = new Date()): Date {
  if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
  if (value && typeof value === 'object' && 'toDate' in value) {
    const converted = (value as {toDate: () => Date}).toDate();
    if (!Number.isNaN(converted.getTime())) return converted;
  }
  if (typeof value === 'string' || typeof value === 'number') {
    const converted = new Date(value);
    if (!Number.isNaN(converted.getTime())) return converted;
  }
  return fallback;
}

function httpsURL(value: unknown): string {
  const candidate = text(value);
  if (!candidate) return '';
  try {
    const parsed = new URL(candidate);
    return parsed.protocol === 'https:' ? parsed.toString() : '';
  } catch {
    return '';
  }
}

function streamStatus(value: unknown): LiveStream['status'] {
  const status = text(value).toLowerCase();
  if (['scheduled', 'connecting', 'live', 'degraded', 'ended', 'archived'].includes(status)) {
    return status as LiveStream['status'];
  }
  return 'scheduled';
}

export function mapLiveStream(id: string, data: DocumentData): LiveStream {
  const raw = record(data);
  const embeddedStreamer = record(raw.streamer);
  const embeddedCreator = record(raw.creator);
  const status = streamStatus(raw.status);
  const streamerId = text(
    embeddedStreamer.id ?? embeddedCreator.id ?? raw.streamerId ?? raw.creatorId ?? raw.userId,
  );
  const tags = Array.isArray(raw.tags)
    ? raw.tags.filter((tag): tag is string => typeof tag === 'string').map(tag => tag.trim()).filter(Boolean).slice(0, 20)
    : [];

  return {
    id,
    title: text(raw.title, 'Untitled live stream').slice(0, 200),
    description: text(raw.description).slice(0, 5_000),
    thumbnailURL: httpsURL(raw.thumbnailURL ?? raw.thumbnailUrl),
    hlsURL: httpsURL(raw.hlsURL ?? raw.hlsUrl ?? raw.playbackURL ?? raw.playbackUrl),
    isLive: status === 'live' || status === 'degraded',
    startedAt: date(raw.startedAt ?? raw.actualStartAt ?? raw.scheduledFor),
    endedAt: raw.endedAt ? date(raw.endedAt) : undefined,
    scheduledFor: raw.scheduledFor ? date(raw.scheduledFor) : undefined,
    viewerCount: count(raw.viewerCount),
    peakViewerCount: count(raw.peakViewerCount),
    likeCount: count(raw.likeCount),
    streamer: {
      id: streamerId,
      username: text(embeddedStreamer.username ?? embeddedCreator.username ?? raw.username, 'creator'),
      displayName: text(embeddedStreamer.displayName ?? embeddedCreator.displayName ?? raw.creatorName, 'Creator'),
      profileImageURL: httpsURL(
        embeddedStreamer.profileImageURL ?? embeddedCreator.profileImageURL ?? raw.creatorAvatarURL,
      ),
      isVerified: embeddedStreamer.isVerified === true || embeddedCreator.isVerified === true,
      subscriberCount: count(embeddedStreamer.subscriberCount ?? embeddedCreator.subscriberCount),
    },
    category: text(raw.category, 'Live'),
    tags,
    chatEnabled: raw.chatEnabled !== false,
    donationsEnabled: raw.donationsEnabled === true,
    status,
  };
}

export function subscribeToLiveStream(
  streamId: string,
  onValue: (stream: LiveStream | null) => void,
  onError: () => void,
): Unsubscribe {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(streamId)) {
    queueMicrotask(onError);
    return () => undefined;
  }
  return onSnapshot(doc(db, 'live_streams', streamId), snapshot => {
    onValue(snapshot.exists() ? mapLiveStream(snapshot.id, snapshot.data()) : null);
  }, onError);
}