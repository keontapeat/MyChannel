'use client';

// Watch Party — synchronized video playback with real-time group chat.
// Host controls playback; guests follow automatically via Firebase Realtime DB.

import { useState, useEffect, useRef, useCallback } from 'react';
import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import {
  Users, Play, Pause, ChevronLeft, Send, Copy, Check,
  Loader2, Crown, UserPlus,
} from 'lucide-react';
import { ref, onValue, set, push, serverTimestamp as rtdbTimestamp, off } from 'firebase/database';
import { doc, getDoc, addDoc, collection, serverTimestamp } from 'firebase/firestore';
import { db, auth, rtdb } from '@/lib/firebase/config';
import VideoPlayer from '@/components/video/VideoPlayer';

interface ChatMessage {
  id: string;
  uid: string;
  username: string;
  text: string;
  timestamp: number;
}

interface PartyState {
  videoId: string;
  videoUrl: string;
  videoTitle: string;
  isPlaying: boolean;
  seekPositionMs: number;
  hostId: string;
  guestCount: number;
}

export default function WatchPartyPageClient() {
  const searchParams = useSearchParams();
  const partyId = searchParams?.get('id') ?? '';
  const videoId = searchParams?.get('video') ?? '';

  const [partyState, setPartyState] = useState<PartyState | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [messageText, setMessageText] = useState('');
  const [loading, setLoading] = useState(true);
  const [isHost, setIsHost] = useState(false);
  const [copied, setCopied] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const chatEndRef = useRef<HTMLDivElement>(null);
  const uid = auth?.currentUser?.uid;

  // Create or join party
  useEffect(() => {
    if (!uid) { setLoading(false); return; }

    const init = async () => {
      try {
        if (partyId) {
          // Join existing party
          const guestRef = ref(rtdb!, `watch_parties/${partyId}/guests/${uid}`);
          await set(guestRef, { uid, joinedAt: Date.now() });
          setIsHost(false);
        } else if (videoId) {
          // Create new party
          const videoSnap = await getDoc(doc(db, 'videos', videoId));
          const videoData = videoSnap.data();
          const videoUrl = videoData?.hlsURL ?? videoData?.videoURL ?? '';

          const partyRef = ref(rtdb!, `watch_parties`);
          const newPartyRef = push(partyRef);
          const newPartyId = newPartyRef.key!;

          await set(ref(rtdb!, `watch_parties/${newPartyId}/state`), {
            videoId,
            videoUrl,
            videoTitle: videoData?.title ?? 'Video',
            isPlaying: false,
            seekPositionMs: 0,
            hostId: uid,
            guestCount: 1,
          });

          await set(ref(rtdb!, `watch_parties/${newPartyId}/guests/${uid}`), {
            uid, joinedAt: Date.now()
          });

          // Update URL without reloading
          window.history.replaceState(null, '', `/watch-party?id=${newPartyId}`);
          setIsHost(true);

          // Also write to Firestore for discoverability
          await addDoc(collection(db, 'watch_parties'), {
            rtdbId: newPartyId,
            videoId,
            hostId: uid,
            guestCount: 1,
            isActive: true,
            createdAt: serverTimestamp(),
          });
        }
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };
    init();
  }, [partyId, videoId, uid]);

  // Listen to party state
  useEffect(() => {
    const id = partyId || (window.location.search.match(/id=([^&]+)/)?.[1] ?? '');
    if (!id || !rtdb) return;

    const stateRef = ref(rtdb, `watch_parties/${id}/state`);
    const unsub = onValue(stateRef, (snap) => {
      if (snap.exists()) setPartyState(snap.val() as PartyState);
    });

    const chatRef = ref(rtdb, `watch_parties/${id}/chat`);
    const chatUnsub = onValue(chatRef, (snap) => {
      if (!snap.exists()) return;
      const msgs: ChatMessage[] = [];
      snap.forEach((child) => {
        msgs.push({ id: child.key!, ...child.val() });
      });
      setMessages(msgs.slice(-100));
      setTimeout(() => chatEndRef.current?.scrollIntoView({ behavior: 'smooth' }), 50);
    });

    return () => {
      off(stateRef);
      off(chatRef);
      // Leave party on unmount
      if (uid) {
        set(ref(rtdb, `watch_parties/${id}/guests/${uid}`), null);
      }
    };
  }, [partyId, uid]);

  const getPartyId = () => partyId || (window.location.search.match(/id=([^&]+)/)?.[1] ?? '');

  const broadcastPlay = async () => {
    const id = getPartyId();
    if (!isHost || !id || !rtdb) return;
    await set(ref(rtdb, `watch_parties/${id}/state/isPlaying`), true);
    await set(ref(rtdb, `watch_parties/${id}/state/seekPositionMs`), currentTime * 1000);
  };

  const broadcastPause = async () => {
    const id = getPartyId();
    if (!isHost || !id || !rtdb) return;
    await set(ref(rtdb, `watch_parties/${id}/state/isPlaying`), false);
    await set(ref(rtdb, `watch_parties/${id}/state/seekPositionMs`), currentTime * 1000);
  };

  const sendMessage = async () => {
    if (!messageText.trim() || !uid) return;
    const id = getPartyId();
    if (!id || !rtdb) return;

    await push(ref(rtdb, `watch_parties/${id}/chat`), {
      uid,
      username: auth?.currentUser?.displayName ?? 'Viewer',
      text: messageText.trim(),
      timestamp: Date.now(),
    });
    setMessageText('');
  };

  const copyInviteLink = () => {
    const id = getPartyId();
    navigator.clipboard?.writeText(`${window.location.origin}/watch-party?id=${id}`);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  if (!uid) {
    return (
      <div className="min-h-screen bg-[rgb(var(--color-background))] flex items-center justify-center">
        <div className="text-center">
          <Users size={48} className="mx-auto mb-4 text-[rgb(var(--color-text-tertiary))]" />
          <h2 className="text-[20px] font-bold text-[rgb(var(--color-text-primary))] mb-2">Sign in to watch together</h2>
          <Link href="/login" className="px-6 py-3 bg-[rgb(var(--color-primary))] text-white font-semibold rounded-full hover:opacity-90">
            Sign in
          </Link>
        </div>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-[rgb(var(--color-background))] flex items-center justify-center">
        <Loader2 size={32} className="animate-spin text-[rgb(var(--color-text-tertiary))]" />
      </div>
    );
  }

  if (!partyState && !videoId) {
    return (
      <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14">
        <div className="max-w-[640px] mx-auto px-4 py-20 text-center">
          <Users size={48} className="mx-auto mb-4 text-[rgb(var(--color-primary))]" />
          <h1 className="text-[24px] font-bold text-[rgb(var(--color-text-primary))] mb-2">Watch Party</h1>
          <p className="text-[14px] text-[rgb(var(--color-text-secondary))] mb-6">
            Start watching videos together. Open a Watch Party from any video page.
          </p>
          <Link href="/" className="px-6 py-3 bg-[rgb(var(--color-primary))] text-white font-semibold rounded-full hover:opacity-90">
            Browse videos
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14">
      <div className="max-w-[1400px] mx-auto px-4 py-4">
        {/* Header */}
        <div className="flex items-center gap-3 mb-4">
          <Link href="/" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full">
            <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
          </Link>
          <div className="flex items-center gap-2">
            <Users size={18} className="text-[rgb(var(--color-primary))]" />
            <span className="text-[15px] font-bold text-[rgb(var(--color-text-primary))]">Watch Party</span>
            {isHost && (
              <span className="flex items-center gap-1 text-[11px] font-semibold text-yellow-500">
                <Crown size={12} /> Host
              </span>
            )}
          </div>
          <div className="ml-auto flex items-center gap-2">
            <span className="text-[12px] text-[rgb(var(--color-text-secondary))]">
              {partyState?.guestCount ?? 1} watching
            </span>
            <button
              onClick={copyInviteLink}
              className="flex items-center gap-1.5 px-3 py-1.5 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-full text-[12px] font-medium text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]"
            >
              {copied ? <><Check size={13} /> Copied!</> : <><Copy size={13} /> Invite</>}
            </button>
          </div>
        </div>

        <div className="flex flex-col lg:flex-row gap-4">
          {/* Video + host controls */}
          <div className="flex-1 min-w-0">
            {partyState?.videoUrl ? (
              <div className="aspect-video w-full bg-black rounded-xl overflow-hidden">
                <VideoPlayer
                  src={partyState.videoUrl}
                  autoplay={partyState.isPlaying}
                  controls={isHost}
                  onTimeUpdate={setCurrentTime}
                />
              </div>
            ) : (
              <div className="aspect-video w-full bg-[rgb(var(--color-surface))] rounded-xl flex items-center justify-center">
                <Loader2 size={28} className="animate-spin text-[rgb(var(--color-text-tertiary))]" />
              </div>
            )}

            {partyState?.videoTitle && (
              <h2 className="text-[16px] font-semibold text-[rgb(var(--color-text-primary))] mt-3">
                {partyState.videoTitle}
              </h2>
            )}

            {/* Host-only playback controls */}
            {isHost && (
              <div className="flex items-center gap-3 mt-3">
                <button
                  onClick={partyState?.isPlaying ? broadcastPause : broadcastPlay}
                  className="flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full hover:opacity-90"
                >
                  {partyState?.isPlaying
                    ? <><Pause size={15} /> Pause for everyone</>
                    : <><Play size={15} /> Play for everyone</>
                  }
                </button>
                <p className="text-[12px] text-[rgb(var(--color-text-tertiary))]">
                  As host, your play/pause controls sync for all guests
                </p>
              </div>
            )}
          </div>

          {/* Chat */}
          <div className="w-full lg:w-[340px] flex flex-col bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] overflow-hidden" style={{ height: 'calc(100vh - 180px)', minHeight: 400 }}>
            <div className="px-4 py-3 border-b border-[rgb(var(--color-border))]">
              <p className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))]">Party chat</p>
            </div>

            {/* Messages */}
            <div className="flex-1 overflow-y-auto p-3 space-y-2">
              {messages.length === 0 ? (
                <p className="text-[12px] text-[rgb(var(--color-text-tertiary))] text-center py-8">
                  Say hi to the party!
                </p>
              ) : (
                messages.map((msg) => (
                  <div key={msg.id} className={`flex gap-2 ${msg.uid === uid ? 'justify-end' : 'justify-start'}`}>
                    <div className={`max-w-[80%] px-3 py-2 rounded-xl text-[12px] ${
                      msg.uid === uid
                        ? 'bg-[rgb(var(--color-primary))] text-white rounded-br-sm'
                        : 'bg-[rgb(var(--color-surface-hover))] text-[rgb(var(--color-text-primary))] rounded-bl-sm'
                    }`}>
                      {msg.uid !== uid && (
                        <p className="font-semibold text-[10px] mb-0.5 opacity-75">{msg.username}</p>
                      )}
                      <p>{msg.text}</p>
                    </div>
                  </div>
                ))
              )}
              <div ref={chatEndRef} />
            </div>

            {/* Input */}
            <div className="flex items-center gap-2 px-3 py-3 border-t border-[rgb(var(--color-border))]">
              <input
                type="text"
                value={messageText}
                onChange={(e) => setMessageText(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && sendMessage()}
                placeholder="Send a message…"
                className="flex-1 px-3 py-2 bg-[rgb(var(--color-surface-hover))] border border-[rgb(var(--color-border))] rounded-full text-[13px] text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] outline-none focus:border-[rgb(var(--color-primary))]"
              />
              <button
                onClick={sendMessage}
                disabled={!messageText.trim()}
                className="p-2 bg-[rgb(var(--color-primary))] text-white rounded-full hover:opacity-90 disabled:opacity-40"
              >
                <Send size={15} />
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
