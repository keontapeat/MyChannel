'use client';

// Live Chat Component - Real-time Chat for Live Streams

import { useState, useRef, useEffect } from 'react';
import { Send, CheckCircle, Shield, Star, MessageCircle } from 'lucide-react';
import type { ChatMessage } from '@/types/live';

interface LiveChatProps {
  streamId: string;
  chatEnabled: boolean;
}

const LiveChat = ({ streamId, chatEnabled }: LiveChatProps) => {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputMessage, setInputMessage] = useState('');
  const [isConnected, setIsConnected] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const chatContainerRef = useRef<HTMLDivElement>(null);

  // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Mock: Simulate real-time messages
  useEffect(() => {
    setIsConnected(true);

    // Add initial messages
    const initialMessages: ChatMessage[] = [
      {
        id: '1',
        streamId,
        userId: 'user-1',
        username: 'viewer1',
        displayName: 'Viewer One',
        userProfileImage: 'https://i.pravatar.cc/150?img=2',
        isVerified: false,
        isModerator: false,
        isStreamer: false,
        message: 'Hey everyone! 👋',
        timestamp: new Date(Date.now() - 5000),
        badges: [],
      },
      {
        id: '2',
        streamId,
        userId: 'user-2',
        username: 'viewer2',
        displayName: 'Cool Viewer',
        userProfileImage: 'https://i.pravatar.cc/150?img=3',
        isVerified: true,
        isModerator: false,
        isStreamer: false,
        message: 'This stream is awesome! 🔥',
        timestamp: new Date(Date.now() - 3000),
        badges: ['subscriber'],
      },
      {
        id: '3',
        streamId,
        userId: 'mod-1',
        username: 'moderator1',
        displayName: 'Chat Mod',
        userProfileImage: 'https://i.pravatar.cc/150?img=4',
        isVerified: false,
        isModerator: true,
        isStreamer: false,
        message: 'Welcome everyone! Please follow chat rules 📜',
        timestamp: new Date(Date.now() - 2000),
        badges: ['moderator'],
      },
    ];

    setMessages(initialMessages);

    // Simulate incoming messages
    const interval = setInterval(() => {
      const randomMessages = [
        'Great stream!',
        'What game is this?',
        'Love your content! 💖',
        'Can you check chat?',
        'First time watching, this is cool!',
        'Subscribed! ⭐',
      ];

      const newMessage: ChatMessage = {
        id: `msg-${Date.now()}`,
        streamId,
        userId: `user-${Math.random()}`,
        username: `viewer${Math.floor(Math.random() * 1000)}`,
        displayName: `Viewer ${Math.floor(Math.random() * 1000)}`,
        userProfileImage: `https://i.pravatar.cc/150?img=${Math.floor(Math.random() * 70)}`,
        isVerified: Math.random() > 0.8,
        isModerator: false,
        isStreamer: false,
        message: randomMessages[Math.floor(Math.random() * randomMessages.length)],
        timestamp: new Date(),
        badges: Math.random() > 0.7 ? ['subscriber'] : [],
      };

      setMessages((prev) => [...prev, newMessage]);
    }, 3000);

    return () => clearInterval(interval);
  }, [streamId]);

  const handleSendMessage = (e: React.FormEvent) => {
    e.preventDefault();

    if (!inputMessage.trim()) return;

    const newMessage: ChatMessage = {
      id: `my-msg-${Date.now()}`,
      streamId,
      userId: 'current-user',
      username: 'you',
      displayName: 'You',
      userProfileImage: 'https://i.pravatar.cc/150?img=1',
      isVerified: false,
      isModerator: false,
      isStreamer: false,
      message: inputMessage,
      timestamp: new Date(),
      badges: [],
    };

    setMessages([...messages, newMessage]);
    setInputMessage('');
  };

  if (!chatEnabled) {
    return (
      <div className="h-full flex flex-col items-center justify-center bg-[rgb(var(--color-background))] border-l border-[rgb(var(--color-border))] p-6 text-center">
        <MessageCircle size={48} className="text-[rgb(var(--color-text-tertiary))] mb-4" />
        <p className="text-sm text-[rgb(var(--color-text-secondary))]">
          Chat is disabled for this stream
        </p>
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col bg-[rgb(var(--color-background))] border-l border-[rgb(var(--color-border))]">
      {/* Chat Header */}
      <div className="p-4 border-b border-[rgb(var(--color-border))]">
        <h3 className="text-lg font-semibold text-[rgb(var(--color-text-primary))] flex items-center gap-2">
          Live Chat
          {isConnected && (
            <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
          )}
        </h3>
      </div>

      {/* Messages Container */}
      <div
        ref={chatContainerRef}
        className="flex-1 overflow-y-auto p-4 space-y-3 scrollbar-thin scrollbar-thumb-[rgba(255,255,255,0.2)] scrollbar-track-transparent"
      >
        {messages.map((msg) => (
          <div key={msg.id} className="flex gap-3">
            <img
              src={msg.userProfileImage}
              alt={msg.displayName}
              className="w-8 h-8 rounded-full flex-shrink-0"
            />

            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-1 flex-wrap">
                {/* Badges */}
                {msg.isStreamer && (
                  <span className="px-1.5 py-0.5 bg-red-600 text-white text-[10px] font-semibold uppercase rounded">
                    Streamer
                  </span>
                )}
                {msg.isModerator && (
                  <Shield size={14} className="text-green-500" />
                )}
                {msg.badges?.includes('subscriber') && (
                  <Star size={14} className="text-yellow-500" />
                )}

                {/* Display Name */}
                <span className="text-sm font-medium text-[rgb(var(--color-text-primary))]">
                  {msg.displayName}
                </span>

                {/* Verified Badge */}
                {msg.isVerified && (
                  <CheckCircle size={12} className="text-blue-500" />
                )}

                {/* Timestamp */}
                <span className="text-xs text-[rgb(var(--color-text-tertiary))]">
                  {formatMessageTime(msg.timestamp)}
                </span>
              </div>

              {/* Message Text */}
              <p className="text-sm text-[rgb(var(--color-text-primary))] break-words mt-0.5">
                {msg.message}
              </p>
            </div>
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>

      {/* Input Area */}
      <div className="p-4 border-t border-[rgb(var(--color-border))]">
        <form onSubmit={handleSendMessage} className="flex gap-2">
          <input
            type="text"
            value={inputMessage}
            onChange={(e) => setInputMessage(e.target.value)}
            placeholder="Say something..."
            maxLength={200}
            className="flex-1 px-4 py-2 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-full text-sm text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] focus:border-[rgb(var(--color-primary))] outline-none"
          />
          <button
            type="submit"
            disabled={!inputMessage.trim()}
            className="p-2 bg-[rgb(var(--color-primary))] text-white rounded-full hover:bg-[rgb(var(--color-primary-hover))] disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex-shrink-0"
          >
            <Send size={20} />
          </button>
        </form>
      </div>
    </div>
  );
};

function formatMessageTime(timestamp: Date): string {
  const now = Date.now();
  const diff = now - timestamp.getTime();
  const seconds = Math.floor(diff / 1000);

  if (seconds < 60) return 'just now';
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  return `${Math.floor(seconds / 3600)}h ago`;
}

export default LiveChat;

