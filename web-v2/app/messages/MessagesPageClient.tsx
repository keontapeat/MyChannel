'use client';

import { useState, useEffect, useRef } from 'react';
import { ChevronLeft, Send, Search, Loader2, MessageSquare } from 'lucide-react';
import Link from 'next/link';
import {
  collection, query, orderBy, limit, onSnapshot, addDoc, serverTimestamp,
  where, getDocs, doc, getDoc,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

interface Conversation {
  id: string;
  participantIds: string[];
  participantNames: string[];
  participantAvatars: string[];
  lastMessage: string;
  lastMessageAt: Date;
  unreadCount: number;
}

interface Message {
  id: string;
  senderId: string;
  senderName: string;
  senderAvatar: string;
  text: string;
  createdAt: Date;
}

export default function MessagesPageClient() {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [selectedConvo, setSelectedConvo] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const uid = auth?.currentUser?.uid;

  useEffect(() => {
    if (!uid) { setLoading(false); return; }
    const q = query(
      collection(db, 'conversations'),
      where('participantIds', 'array-contains', uid),
      orderBy('lastMessageAt', 'desc'),
      limit(50)
    );
    const unsub = onSnapshot(q, (snap) => {
      const convos = snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          participantIds: data.participantIds ?? [],
          participantNames: data.participantNames ?? [],
          participantAvatars: data.participantAvatars ?? [],
          lastMessage: data.lastMessage ?? '',
          lastMessageAt: data.lastMessageAt?.toDate?.() ?? new Date(),
          unreadCount: data.unreadCount?.[uid] ?? 0,
        } as Conversation;
      });
      setConversations(convos);
      setLoading(false);
    });
    return () => unsub();
  }, [uid]);

  useEffect(() => {
    if (!selectedConvo) return;
    const q = query(
      collection(db, 'conversations', selectedConvo.id, 'messages'),
      orderBy('createdAt', 'asc'),
      limit(100)
    );
    const unsub = onSnapshot(q, (snap) => {
      const msgs = snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          senderId: data.senderId ?? '',
          senderName: data.senderName ?? '',
          senderAvatar: data.senderAvatar ?? '',
          text: data.text ?? '',
          createdAt: data.createdAt?.toDate?.() ?? new Date(),
        } as Message;
      });
      setMessages(msgs);
      setTimeout(() => messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' }), 100);
    });
    return () => unsub();
  }, [selectedConvo]);

  const handleSend = async () => {
    if (!newMessage.trim() || !selectedConvo || !uid || sending) return;
    setSending(true);
    try {
      const user = auth?.currentUser;
      await addDoc(collection(db, 'conversations', selectedConvo.id, 'messages'), {
        senderId: uid,
        senderName: user?.displayName ?? 'You',
        senderAvatar: user?.photoURL ?? '',
        text: newMessage.trim(),
        createdAt: serverTimestamp(),
      });
      setNewMessage('');
    } finally {
      setSending(false);
    }
  };

  const getOtherName = (convo: Conversation) => {
    const idx = convo.participantIds.indexOf(uid ?? '');
    const otherIdx = idx === 0 ? 1 : 0;
    return convo.participantNames[otherIdx] ?? 'User';
  };

  const getOtherAvatar = (convo: Conversation) => {
    const idx = convo.participantIds.indexOf(uid ?? '');
    const otherIdx = idx === 0 ? 1 : 0;
    return convo.participantAvatars[otherIdx] ?? '';
  };

  if (!uid) {
    return (
      <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14 flex items-center justify-center">
        <div className="text-center">
          <MessageSquare size={48} className="mx-auto mb-4 text-[rgb(var(--color-text-tertiary))]" />
          <p className="text-[15px] font-semibold text-[rgb(var(--color-text-primary))] mb-2">Sign in to view messages</p>
          <Link href="/login" className="px-4 py-2 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full">
            Sign in
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14">
      <div className="max-w-[1000px] mx-auto h-[calc(100vh-56px)] flex">
        {/* Sidebar */}
        <div className={`w-full md:w-80 border-r border-[rgb(var(--color-border))] flex flex-col ${selectedConvo ? 'hidden md:flex' : ''}`}>
          <div className="p-4 border-b border-[rgb(var(--color-border))]">
            <div className="flex items-center gap-3">
              <Link href="/" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full">
                <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
              </Link>
              <h1 className="text-[18px] font-bold text-[rgb(var(--color-text-primary))]">Messages</h1>
            </div>
          </div>
          <div className="flex-1 overflow-y-auto">
            {loading ? (
              <div className="flex items-center justify-center py-12">
                <Loader2 size={24} className="animate-spin text-[rgb(var(--color-text-tertiary))]" />
              </div>
            ) : conversations.length === 0 ? (
              <div className="text-center py-12 px-4">
                <MessageSquare size={36} className="mx-auto mb-3 text-[rgb(var(--color-text-tertiary))]" />
                <p className="text-[14px] text-[rgb(var(--color-text-secondary))]">No conversations yet</p>
              </div>
            ) : (
              conversations.map((convo) => (
                <button
                  key={convo.id}
                  onClick={() => setSelectedConvo(convo)}
                  className={`w-full flex items-center gap-3 px-4 py-3 hover:bg-[rgb(var(--color-surface-hover))] transition-colors text-left ${selectedConvo?.id === convo.id ? 'bg-[rgb(var(--color-surface))]' : ''}`}
                >
                  <img
                    src={getOtherAvatar(convo) || `https://i.pravatar.cc/150?u=${convo.id}`}
                    alt=""
                    className="w-10 h-10 rounded-full"
                  />
                  <div className="flex-1 min-w-0">
                    <p className="text-[14px] font-semibold text-[rgb(var(--color-text-primary))] truncate">{getOtherName(convo)}</p>
                    <p className="text-[12px] text-[rgb(var(--color-text-tertiary))] truncate">{convo.lastMessage}</p>
                  </div>
                  {convo.unreadCount > 0 && (
                    <span className="w-5 h-5 bg-[rgb(var(--color-primary))] text-white text-[11px] font-bold rounded-full flex items-center justify-center">
                      {convo.unreadCount}
                    </span>
                  )}
                </button>
              ))
            )}
          </div>
        </div>

        {/* Chat Area */}
        <div className={`flex-1 flex flex-col ${!selectedConvo ? 'hidden md:flex' : ''}`}>
          {selectedConvo ? (
            <>
              <div className="p-4 border-b border-[rgb(var(--color-border))] flex items-center gap-3">
                <button onClick={() => setSelectedConvo(null)} className="md:hidden p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full">
                  <ChevronLeft size={20} />
                </button>
                <img
                  src={getOtherAvatar(selectedConvo) || `https://i.pravatar.cc/150?u=${selectedConvo.id}`}
                  alt=""
                  className="w-8 h-8 rounded-full"
                />
                <span className="text-[15px] font-semibold text-[rgb(var(--color-text-primary))]">{getOtherName(selectedConvo)}</span>
              </div>
              <div className="flex-1 overflow-y-auto p-4 space-y-3">
                {messages.map((msg) => (
                  <div key={msg.id} className={`flex ${msg.senderId === uid ? 'justify-end' : 'justify-start'}`}>
                    <div className={`max-w-[70%] px-4 py-2.5 rounded-2xl text-[14px] ${
                      msg.senderId === uid
                        ? 'bg-[rgb(var(--color-primary))] text-white rounded-br-sm'
                        : 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] border border-[rgb(var(--color-border))] rounded-bl-sm'
                    }`}>
                      {msg.text}
                    </div>
                  </div>
                ))}
                <div ref={messagesEndRef} />
              </div>
              <div className="p-4 border-t border-[rgb(var(--color-border))]">
                <div className="flex items-center gap-2">
                  <input
                    type="text"
                    value={newMessage}
                    onChange={(e) => setNewMessage(e.target.value)}
                    onKeyDown={(e) => e.key === 'Enter' && !e.shiftKey && handleSend()}
                    placeholder="Type a message…"
                    className="flex-1 px-4 py-2.5 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-full text-[14px] text-[rgb(var(--color-text-primary))] outline-none focus:border-[rgb(var(--color-primary))]"
                  />
                  <button
                    onClick={handleSend}
                    disabled={!newMessage.trim() || sending}
                    className="p-2.5 bg-[rgb(var(--color-primary))] text-white rounded-full hover:opacity-90 disabled:opacity-50"
                  >
                    <Send size={18} />
                  </button>
                </div>
              </div>
            </>
          ) : (
            <div className="flex-1 flex items-center justify-center">
              <div className="text-center">
                <MessageSquare size={48} className="mx-auto mb-3 text-[rgb(var(--color-text-tertiary))]" />
                <p className="text-[15px] text-[rgb(var(--color-text-secondary))]">Select a conversation to start messaging</p>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
