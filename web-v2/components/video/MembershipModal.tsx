'use client';

// MembershipModal — "Join" a creator's channel membership.
//
// MONEY NOTE: mirrors SuperThanksModal. Tiers + prices come from Firestore
// (channels/{channelId}/membershipTiers), never from the client. The backend
// (create_membership_checkout) enforces the compliance gate and refuses unless
// memberships are explicitly enabled server-side — this UI degrades gracefully
// to "not available yet" in that case.

import { useEffect, useState } from 'react';
import { X, Star, Loader2 } from 'lucide-react';
import { collection, getDocs, orderBy, query } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

interface Tier {
  id: string;
  name: string;
  priceCents: number;
  perks?: string[];
}

interface MembershipModalProps {
  channelId: string;
  channelName: string;
  onClose: () => void;
}

export default function MembershipModal({ channelId, channelName, onClose }: MembershipModalProps) {
  const [tiers, setTiers] = useState<Tier[]>([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose]);

  // Load server-defined tiers
  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      try {
        const snap = await getDocs(query(
          collection(db, 'channels', channelId, 'membershipTiers'),
          orderBy('priceCents', 'asc'),
        ));
        if (cancelled) return;
        const rows = snap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<Tier, 'id'>) }));
        setTiers(rows);
        setSelected(rows[0]?.id ?? null);
      } catch {
        // non-fatal
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    load();
    return () => { cancelled = true; };
  }, [channelId]);

  const handleJoin = async () => {
    if (!selected) return;
    if (!auth?.currentUser) { setError('Sign in to join'); return; }
    setSubmitting(true);
    setError('');
    try {
      const idToken = await auth.currentUser.getIdToken();
      const region = 'us-east1';
      const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'mychannel-ca26d';
      const url = `https://${region}-${projectId}.cloudfunctions.net/create_membership_checkout`;
      const resp = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${idToken}` },
        body: JSON.stringify({ channelId, tierId: selected }),
      });
      if (!resp.ok) {
        const data = await resp.json().catch(() => ({}));
        const code = data?.error ?? `HTTP ${resp.status}`;
        // Friendly messages for the compliance gates
        if (code === 'memberships_disabled') throw new Error('Memberships aren’t available yet.');
        if (code === 'terms_not_accepted') throw new Error('Please accept the current terms to join.');
        if (code === 'tier_not_found' || code === 'tier_price_invalid') throw new Error('This tier is unavailable.');
        throw new Error(String(code));
      }
      setSent(true);
    } catch (e: any) {
      setError(e?.message ?? 'Could not complete. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  const selectedTier = tiers.find((t) => t.id === selected);

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 p-4"
      onClick={(e) => e.target === e.currentTarget && onClose()}
      role="dialog"
      aria-modal="true"
      aria-label={`Join ${channelName}`}
    >
      <div className="bg-[rgb(var(--color-background))] w-full max-w-[440px] rounded-2xl overflow-hidden shadow-2xl">
        <div className="flex items-center justify-between px-5 pt-5 pb-3">
          <div className="flex items-center gap-2">
            <Star size={20} className="text-[rgb(var(--color-primary))]" fill="currentColor" />
            <h2 className="text-[17px] font-bold text-[rgb(var(--color-text-primary))]">Join {channelName}</h2>
          </div>
          <button onClick={onClose} aria-label="Close" className="p-1.5 hover:bg-[rgb(var(--color-surface-hover))] rounded-full">
            <X size={18} className="text-[rgb(var(--color-text-secondary))]" />
          </button>
        </div>

        {loading ? (
          <div className="px-5 pb-8 flex justify-center">
            <Loader2 size={22} className="animate-spin text-[rgb(var(--color-text-secondary))]" />
          </div>
        ) : sent ? (
          <div className="px-5 pb-8 text-center">
            <div className="text-5xl mb-3">🎉</div>
            <p className="text-[16px] font-bold text-[rgb(var(--color-text-primary))] mb-1">You’re a member!</p>
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">Welcome to {channelName}.</p>
            <button onClick={onClose} className="mt-5 px-6 py-2.5 bg-[rgb(var(--color-primary))] text-white font-semibold rounded-full hover:opacity-90">Done</button>
          </div>
        ) : tiers.length === 0 ? (
          <div className="px-5 pb-8 text-center">
            <p className="text-[14px] text-[rgb(var(--color-text-secondary))]">This channel doesn’t offer memberships yet.</p>
          </div>
        ) : (
          <div className="px-5 pb-5 space-y-3">
            {tiers.map((tier) => (
              <button
                key={tier.id}
                onClick={() => setSelected(tier.id)}
                className={`w-full text-left p-4 rounded-xl border transition-all ${
                  selected === tier.id
                    ? 'border-[rgb(var(--color-primary))] bg-[rgb(var(--color-surface))]'
                    : 'border-[rgb(var(--color-border))] hover:bg-[rgb(var(--color-surface-hover))]'
                }`}
              >
                <div className="flex items-center justify-between">
                  <span className="text-[15px] font-semibold text-[rgb(var(--color-text-primary))]">{tier.name}</span>
                  <span className="text-[15px] font-bold text-[rgb(var(--color-text-primary))]">${(tier.priceCents / 100).toFixed(2)}/mo</span>
                </div>
                {tier.perks && tier.perks.length > 0 && (
                  <ul className="mt-2 space-y-1">
                    {tier.perks.slice(0, 5).map((p, i) => (
                      <li key={i} className="text-[12px] text-[rgb(var(--color-text-secondary))]">• {p}</li>
                    ))}
                  </ul>
                )}
              </button>
            ))}

            {error && <p className="text-[12px] text-red-500">{error}</p>}

            <button
              onClick={handleJoin}
              disabled={submitting || !selected}
              className="w-full py-3 bg-[rgb(var(--color-primary))] text-white font-semibold rounded-full hover:opacity-90 disabled:opacity-50 flex items-center justify-center gap-2"
            >
              {submitting && <Loader2 size={16} className="animate-spin" />}
              {submitting ? 'Processing…' : selectedTier ? `Join for $${(selectedTier.priceCents / 100).toFixed(2)}/mo` : 'Join'}
            </button>
            <p className="text-[10px] text-[rgb(var(--color-text-tertiary))] text-center">
              Payments are processed securely. Platform fee of 10% applies.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
