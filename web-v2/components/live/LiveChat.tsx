'use client';

// Live Chat — real-time chat for live streams (Firestore-backed).
// Messages live at liveStreams/{streamId}/messages, streamed via onSnapshot.
// Replaces the previous mock/simulated implementation.

import { useState, useRef, useEffect } from 'react';
import { Send, CheckCircle, Shield, Star, MessageCircle, DollarSign } from 'lucide-react';
import {
  collection, addDoc, query, orderBy, limit, onSnapshot, serverTimestamp,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import type { ChatMessage } from '@/types/live';

interface LiveChatProps {
  streamId: string;
  chatEnabled: boolean;
  creatorId?: string;
}

const MESSAGE_LIMIT = 150;

// Super Chat amount tiers (cents) → highlight color (matches Super Thanks palette)
const SUPERCHAT_TIERS = [200, 500, 1000, 2000, 5000] as const;
function superChatColor(cents: number): string {
  if (cents >= 5000) return 'bg-red-500';
  if (cents >= 2000) return 'bg-orange-500';
  if (cents >= 1000) return 'bg-yellow-500';
  if (cents >= 500) return 'bg-green-500';
  return 'bg-blue-500';
}

const LiveChat = ({ streamId, chatEnabled, creatorId }: LiveChatProps) => {
  const [messages, setMessages] = useState<(ChatMessage & { superChatCents?: number })[]>([]);
  const [inputMessage, setInputMessage] = useState('');
  const [isConnected, setIsConnected] = useState(false);
  const [sending, setSending] = useState(false);
  const [scAmount, setScAmount] = useState(0); // 0 = normal message; >0 = super chat
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Real-time subscription to the newest messages
  useEffect(() => {
    if (!streamId || !chatEnabled) return;
    const q = query(
      collection(db, 'liveStreams', streamId, 'messages'),
      orderBy('timestamp', 'desc'),
      limit(MESSAGE_LIMIT),
    );
    const unsub = onSnapshot(
      q,
      (snap) => {
        const rows: (ChatMessage & { superChatCents?: number })[] = snap.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            streamId,
            userId: data.userId ?? '',
            username: data.username ?? 'user',
            displayName: data.displayName ?? 'Viewer',
            userProfileImage: data.userProfileImage ?? `https://i.pravatar.cc/150?u=${data.userId ?? d.id}`,
            isVerified: data.isVerified ?? false,
            isModerator: data.isModerator ?? false,
            isStreamer: data.isStreamer ?? false,
            message: data.message ?? '',
            timestamp: data.timestamp?.toDate?.() ?? new Date(),
            badges: data.badges ?? [],
            superChatCents: data.superChatCents ?? 0,
          };
        }).reverse(); // oldest → newest for display
        setMessages(rows);
        setIsConnected(true);
      },
      () => setIsConnected(false),
    );
    return () => unsub();
  }, [streamId, chatEnabled]);

  // Auto-scroll to newest
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    const text = inputMessage.trim();
    if (!text || sending) return;
    const user = auth?.currentUser;
    if (!user) return;

    const amount = scAmount;
    setInputMessage('');
    setScAmount(0);
    setSending(true);
    try {
      // Super Chat: record the payment via the existing (live) tip function first.
      if (amount > 0 && creatorId) {
        const idToken = await user.getIdToken();
        const region = 'us-east1';
        const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'mychannel-ca26d';
        const resp = await fetch(`https://${region}-${projectId}.cloudfunctions.net/send_super_thanks`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${idToken}` },
          body: JSON.stringify({ videoId: streamId, creatorId, amountCents: amount, message: text.slice(0, 200) }),
        });
        if (!resp.ok) throw new Error('payment_failed');
      }

      await addDoc(collection(db, 'liveStreams', streamId, 'messages'), {
        userId: user.uid,
        username: user.displayName ?? 'user',
        displayName: user.displayName ?? 'Viewer',
        userProfileImage: user.photoURL ?? '',
        isVerified: false,
        isModerator: false,
        isStreamer: false,
        message: text.slice(0, 200),
        badges: [],
        superChatCents: amount > 0 ? amount : 0,
        timestamp: serverTimestamp(),
      });
    } catch {
      setInputMessage(text); // restore on failure
      if (amount > 0) setScAmount(amount);
    } finally {
      setSending(false);
    }
  };

  if (!chatEnabled) {
    return (
      <div className="h-full flex flex-col items-center justify-center bg-[rgb(var(--color-background))] border-l border-[rgb(var(--color-border))] p-6 text-center">
        <MessageCircle size={48} className="text-[rgb(var(--color-text-tertiary))] mb-4" />
        <p className="text-sm text-[rgb(var(--color-text-secondary))]">Chat is disabled for this stream</p>
      </div>
    );
  }

  const signedIn = !!auth?.currentUser;

  return (
    <div className="h-full flex flex-col bg-[rgb(var(--color-background))] border-l border-[rgb(var(--color-border))]">
      {/* Header */}
      <div className="p-4 border-b border-[rgb(var(--color-border))]">
        <h3 className="text-lg font-semibold text-[rgb(var(--color-text-primary))] flex items-center gap-2">
          Live Chat
          <span className={`w-2 h-2 rounded-full ${isConnected ? 'bg-green-500 animate-pulse' : 'bg-gray-400'}`} />
        </h3>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-3">
        {messages.length === 0 ? (
          <p className="text-sm text-[rgb(var(--color-text-secondary))] text-center py-8">
            No messages yet. Say hello!
          </p>
        ) : (
          messages.map((msg) => (
            msg.superChatCents && msg.superChatCents > 0 ? (
              <div key={msg.id} className={`rounded-lg overflow-hidden ${superChatColor(msg.superChatCents)}`}>
                <div className="flex items-center justify-between px-3 py-1.5">
                  <div className="flex items-center gap-2 min-w-0">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={msg.userProfileImage} alt={msg.displayName} loading="lazy" className="w-6 h-6 rounded-full flex-shrink-0" />
                    <span className="text-white text-sm font-semibold truncate">{msg.displayName}</span>
                  </div>
                  <span className="text-white text-sm font-bold">${(msg.superChatCents / 100).toFixed(2)}</span>
                </div>
                {msg.message && <p className="px-3 pb-2 text-white text-sm break-words">{msg.message}</p>}
              </div>
            ) : (
              <div key={msg.id} className="flex gap-3">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={msg.userProfileImage} alt={msg.displayName} loading="lazy" className="w-8 h-8 rounded-full flex-shrink-0" />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-1 flex-wrap">
                    {msg.isStreamer && (
                      <span className="px-1.5 py-0.5 bg-red-600 text-white text-[10px] font-semibold uppercase rounded">Streamer</span>
                    )}
                    {msg.isModerator && <Shield size={14} className="text-green-500" />}
                    {msg.badges?.includes('subscriber') && <Star size={14} className="text-yellow-500" />}
                    <span className="text-sm font-medium text-[rgb(var(--color-text-primary))]">{msg.displayName}</span>
                    {msg.isVerified && <CheckCircle size={12} className="text-blue-500" />}
                    <span className="text-xs text-[rgb(var(--color-text-tertiary))]">{formatMessageTime(msg.timestamp)}</span>
                  </div>
                  <p className="text-sm text-[rgb(var(--color-text-primary))] break-words mt-0.5">{msg.message}</p>
                </div>
              </div>
            )
          ))
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <div className="p-4 border-t border-[rgb(var(--color-border))]">
        {/* Super Chat amount picker */}
        {signedIn && creatorId && (
          <div className="flex items-center gap-1.5 mb-2 overflow-x-auto">
            <button
              type="button"
              onClick={() => setScAmount(0)}
              className={`px-2.5 py-1 rounded-full text-[11px] font-semibold whitespace-nowrap ${scAmount === 0 ? 'bg-[rgb(var(--color-text-primary))] text-[rgb(var(--color-background))]' : 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-secondary))]'}`}
            >
              Chat
            </button>
            {SUPERCHAT_TIERS.map((cents) => (
              <button
                key={cents}
                type="button"
                onClick={() => setScAmount(cents)}
                className={`px-2.5 py-1 rounded-full text-[11px] font-bold whitespace-nowrap text-white ${superChatColor(cents)} ${scAmount === cents ? 'ring-2 ring-offset-1 ring-white/60' : 'opacity-80 hover:opacity-100'}`}
              >
                ${cents / 100}
              </button>
            ))}
          </div>
        )}
        <form onSubmit={handleSendMessage} className="flex gap-2">
          <input
            type="text"
            value={inputMessage}
            onChange={(e) => setInputMessage(e.target.value)}
            placeholder={signedIn ? (scAmount > 0 ? `Super Chat $${scAmount / 100}…` : 'Say something…') : 'Sign in to chat'}
            maxLength={200}
            disabled={!signedIn || sending}
            className="flex-1 px-4 py-2 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-full text-sm text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] focus:border-[rgb(var(--color-primary))] outline-none disabled:opacity-60"
          />
          <button
            type="submit"
            disabled={!inputMessage.trim() || !signedIn || sending}
            className={`p-2 rounded-full text-white hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex-shrink-0 ${scAmount > 0 ? superChatColor(scAmount) : 'bg-[rgb(var(--color-primary))]'}`}
            aria-label={scAmount > 0 ? 'Send Super Chat' : 'Send message'}
          >
            {scAmount > 0 ? <DollarSign size={20} /> : <Send size={20} />}
          </button>
        </form>
      </div>
    </div>
  );
};

function formatMessageTime(timestamp: Date): string {
  const seconds = Math.floor((Date.now() - timestamp.getTime()) / 1000);
  if (seconds < 60) return 'just now';
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  return `${Math.floor(seconds / 3600)}h ago`;
}

export default LiveChat;
