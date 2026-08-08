import {addDoc, collection, serverTimestamp} from 'firebase/firestore';
import {auth, db} from './config';

export type LiveQoEEventType = 'startup' | 'rebuffer' | 'heartbeat' | 'error' | 'end';

export interface LiveQoEMetrics {
  startupMs?: number;
  rebufferMs?: number;
  liveLatencyMs?: number;
  bitrateKbps?: number;
  width?: number;
  height?: number;
  droppedFrames?: number;
  errorCode?: string;
}

const LIMITS: Record<Exclude<keyof LiveQoEMetrics, 'errorCode'>, number> = {
  startupMs: 120_000,
  rebufferMs: 120_000,
  liveLatencyMs: 300_000,
  bitrateKbps: 100_000,
  width: 8_192,
  height: 8_192,
  droppedFrames: 100_000,
};

function boundedMetrics(metrics: LiveQoEMetrics): Record<string, number | string> {
  const result: Record<string, number | string> = {};
  for (const [key, maximum] of Object.entries(LIMITS)) {
    const value = metrics[key as keyof typeof LIMITS];
    if (typeof value === 'number' && Number.isFinite(value)) {
      result[key] = Math.min(maximum, Math.max(0, Math.round(value)));
    }
  }
  const errorCode = metrics.errorCode?.trim().slice(0, 64);
  if (errorCode) result.errorCode = errorCode;
  return result;
}

export async function recordLiveQoE(
  streamId: string,
  sessionId: string,
  eventType: LiveQoEEventType,
  metrics: LiveQoEMetrics = {},
): Promise<void> {
  const user = auth.currentUser;
  if (!user) return;
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(streamId)) return;
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(sessionId)) return;

  await addDoc(collection(db, 'live_streams', streamId, 'qoe_events'), {
    userId: user.uid,
    sessionId,
    eventType,
    createdAt: serverTimestamp(),
    ...boundedMetrics(metrics),
  });
}