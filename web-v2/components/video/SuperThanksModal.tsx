'use client';

// Super Thanks — one-time paid appreciation from viewers to creators.
// Amounts: $2, $5, $10, $20, $50, $100
// Money note: actual payment flow goes through the existing escrow/tips backend.
// This component only collects the intent and triggers the Cloud Function callable.

import { useState } from 'react';
import { X, Heart, Loader2 } from 'lucide-react';
import { auth } from '@/lib/firebase/config';
import { getFunctions } from 'firebase/functions';

const AMOUNTS = [2, 5, 10, 20, 50, 100];

const COLORS: Record<number, string> = {
  2:   'bg-blue-500',
  5:   'bg-cyan-500',
  10:  'bg-green-500',
  20:  'bg-yellow-500',
  50:  'bg-orange-500',
  100: 'bg-red-500',
};

interface SuperThanksModalProps {
  videoId: string;
  creatorId: string;
  creatorName: string;
  onClose: () => void;
}

export default function SuperThanksModal({
  videoId,
  creatorId,
  creatorName,
  onClose,
}: SuperThanksModalProps) {
  const [selectedAmount, setSelectedAmount] = useState(5);
  const [message, setMessage] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState('');

  const handleSend = async () => {
    if (!auth?.currentUser) {
      setError('Sign in to send Super Thanks');
      return;
    }
    setSubmitting(true);
    setError('');
    try {
      // MONEY NOTE: send_super_thanks is a Python HTTPS function (not a callable)
      // It validates auth server-side via the Authorization header.
      const functions = getFunctions();
      const idToken = await auth.currentUser!.getIdToken();
      const region = 'us-east1';
      const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'mychannel-ca26d';
      const url = `https://${region}-${projectId}.cloudfunctions.net/send_super_thanks`;
      
      const resp = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${idToken}`,
        },
        body: JSON.stringify({
          videoId,
          creatorId,
          amountCents: selectedAmount * 100,
          message: message.trim(),
        }),
      });
      
      if (!resp.ok) {
        const errData = await resp.json().catch(() => ({}));
        throw new Error(errData?.error ?? `HTTP ${resp.status}`);
      }
      setSent(true);
    } catch (e: any) {
      setError(e?.message ?? 'Payment failed. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 p-4"
      onClick={(e) => e.target === e.currentTarget && onClose()}
      role="dialog"
      aria-modal="true"
      aria-label="Super Thanks"
    >
      <div className="bg-[rgb(var(--color-background))] w-full max-w-[420px] rounded-2xl overflow-hidden shadow-2xl">
        {/* Header */}
        <div className="flex items-center justify-between px-5 pt-5 pb-3">
          <div className="flex items-center gap-2">
            <Heart size={20} fill="currentColor" className="text-red-500" />
            <h2 className="text-[17px] font-bold text-[rgb(var(--color-text-primary))]">Super Thanks</h2>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 hover:bg-[rgb(var(--color-surface-hover))] rounded-full"
            aria-label="Close"
          >
            <X size={18} className="text-[rgb(var(--color-text-secondary))]" />
          </button>
        </div>

        {sent ? (
          // Success state
          <div className="px-5 pb-8 text-center">
            <div className="text-5xl mb-3">🎉</div>
            <p className="text-[16px] font-bold text-[rgb(var(--color-text-primary))] mb-1">
              Super Thanks sent!
            </p>
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">
              You sent ${selectedAmount} to {creatorName}
            </p>
            {message && (
              <div className={`mt-3 px-4 py-3 rounded-xl text-white text-[13px] ${COLORS[selectedAmount]}`}>
                {message}
              </div>
            )}
            <button
              onClick={onClose}
              className="mt-5 px-6 py-2.5 bg-[rgb(var(--color-primary))] text-white font-semibold rounded-full hover:opacity-90"
            >
              Done
            </button>
          </div>
        ) : (
          <div className="px-5 pb-5 space-y-4">
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">
              Show your appreciation for {creatorName} with a one-time payment.
            </p>

            {/* Amount picker */}
            <div className="grid grid-cols-3 gap-2">
              {AMOUNTS.map((amt) => (
                <button
                  key={amt}
                  onClick={() => setSelectedAmount(amt)}
                  className={`py-2.5 rounded-xl text-[14px] font-bold transition-all ${
                    selectedAmount === amt
                      ? `${COLORS[amt]} text-white scale-105 shadow-lg`
                      : 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]'
                  }`}
                >
                  ${amt}
                </button>
              ))}
            </div>

            {/* Message (optional) */}
            <div>
              <textarea
                value={message}
                onChange={(e) => setMessage(e.target.value.slice(0, 150))}
                placeholder="Add a message (optional)…"
                rows={3}
                maxLength={150}
                className="w-full px-3 py-2 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-xl text-[13px] text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] outline-none focus:border-[rgb(var(--color-primary))] resize-none"
              />
              <p className="text-[11px] text-[rgb(var(--color-text-tertiary))] text-right mt-0.5">
                {message.length}/150
              </p>
            </div>

            {/* Preview */}
            {message && (
              <div className={`px-4 py-3 rounded-xl text-white text-[13px] ${COLORS[selectedAmount]}`}>
                <p className="font-bold mb-0.5">{auth?.currentUser?.displayName ?? 'You'} · ${selectedAmount}</p>
                {message}
              </div>
            )}

            {error && (
              <p className="text-[12px] text-red-500">{error}</p>
            )}

            <button
              onClick={handleSend}
              disabled={submitting}
              className="w-full py-3 bg-[rgb(var(--color-primary))] text-white font-semibold rounded-full hover:opacity-90 disabled:opacity-50 flex items-center justify-center gap-2"
            >
              {submitting && <Loader2 size={16} className="animate-spin" />}
              {submitting ? 'Processing…' : `Send $${selectedAmount} Super Thanks`}
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
