'use client';

// SubscribeButton — YouTube-parity subscribe control.
//   • Toggles subscription (users/{uid}/subscriptions/{channelId})
//   • When subscribed, shows a notification-bell dropdown: All / Personalized / None
//   • Optimistic UI with rollback on failure
//
// Notification level is persisted on the subscription doc as `notificationLevel`.

import { useEffect, useRef, useState } from 'react';
import { Bell, BellRing, BellOff, ChevronDown, Check } from 'lucide-react';
import {
  doc, getDoc, setDoc, deleteDoc, updateDoc, serverTimestamp,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

type NotificationLevel = 'all' | 'personalized' | 'none';

interface SubscribeButtonProps {
  channelId: string;
}

const LEVELS: { value: NotificationLevel; label: string; icon: typeof Bell }[] = [
  { value: 'all', label: 'All', icon: BellRing },
  { value: 'personalized', label: 'Personalized', icon: Bell },
  { value: 'none', label: 'None', icon: BellOff },
];

export default function SubscribeButton({ channelId }: SubscribeButtonProps) {
  const [isSubscribed, setIsSubscribed] = useState(false);
  const [level, setLevel] = useState<NotificationLevel>('personalized');
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  // Load subscription state
  useEffect(() => {
    if (!channelId) return;
    const uid = auth?.currentUser?.uid;
    if (!uid) return;
    let cancelled = false;
    getDoc(doc(db, 'users', uid, 'subscriptions', channelId))
      .then((snap) => {
        if (cancelled) return;
        setIsSubscribed(snap.exists());
        const lvl = snap.data()?.notificationLevel as NotificationLevel | undefined;
        if (lvl) setLevel(lvl);
      })
      .catch(() => {});
    return () => { cancelled = true; };
  }, [channelId]);

  // Close menu on outside click
  useEffect(() => {
    if (!menuOpen) return;
    const onClick = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) setMenuOpen(false);
    };
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, [menuOpen]);

  const toggleSubscribe = async () => {
    const uid = auth?.currentUser?.uid;
    const next = !isSubscribed;
    setIsSubscribed(next);
    if (!next) setMenuOpen(false);
    if (!uid) return;
    try {
      const ref = doc(db, 'users', uid, 'subscriptions', channelId);
      if (next) {
        await setDoc(ref, {
          channelId,
          notificationLevel: 'personalized',
          subscribedAt: serverTimestamp(),
        });
        setLevel('personalized');
      } else {
        await deleteDoc(ref);
      }
    } catch {
      setIsSubscribed(!next); // rollback
    }
  };

  const changeLevel = async (value: NotificationLevel) => {
    const uid = auth?.currentUser?.uid;
    const prev = level;
    setLevel(value);
    setMenuOpen(false);
    if (!uid) return;
    try {
      await updateDoc(doc(db, 'users', uid, 'subscriptions', channelId), { notificationLevel: value });
    } catch {
      setLevel(prev); // rollback
    }
  };

  if (!isSubscribed) {
    return (
      <button
        onClick={toggleSubscribe}
        className="px-4 py-2 rounded-full text-[13px] font-semibold bg-[rgb(var(--color-text-primary))] text-[rgb(var(--color-background))] hover:opacity-90 transition-opacity"
      >
        Subscribe
      </button>
    );
  }

  const ActiveIcon = LEVELS.find((l) => l.value === level)?.icon ?? Bell;

  return (
    <div className="relative" ref={menuRef}>
      <div className="flex items-center bg-[rgb(var(--color-surface))] rounded-full overflow-hidden">
        <button
          onClick={() => setMenuOpen((v) => !v)}
          aria-haspopup="menu"
          aria-expanded={menuOpen}
          className="flex items-center gap-1.5 px-4 py-2 text-[13px] font-medium text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
        >
          <ActiveIcon size={15} />
          Subscribed
          <ChevronDown size={14} className={`transition-transform ${menuOpen ? 'rotate-180' : ''}`} />
        </button>
      </div>

      {menuOpen && (
        <div
          role="menu"
          className="absolute right-0 top-full mt-2 w-56 bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] rounded-xl shadow-xl py-2 z-50"
        >
          {LEVELS.map(({ value, label, icon: Icon }) => (
            <button
              key={value}
              role="menuitemradio"
              aria-checked={level === value}
              onClick={() => changeLevel(value)}
              className="w-full flex items-center gap-3 px-4 py-2.5 text-[13px] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
            >
              <Icon size={16} className="text-[rgb(var(--color-text-secondary))]" />
              <span className="flex-1 text-left">{label}</span>
              {level === value && <Check size={15} className="text-[rgb(var(--color-primary))]" />}
            </button>
          ))}
          <div className="my-1 h-px bg-[rgb(var(--color-border))]" />
          <button
            onClick={toggleSubscribe}
            className="w-full flex items-center gap-3 px-4 py-2.5 text-[13px] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
          >
            <BellOff size={16} className="text-[rgb(var(--color-text-secondary))]" />
            <span className="flex-1 text-left">Unsubscribe</span>
          </button>
        </div>
      )}
    </div>
  );
}
