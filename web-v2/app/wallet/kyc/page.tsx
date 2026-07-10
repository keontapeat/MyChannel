'use client';

import { ShieldCheck, ArrowLeft } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';
import { MONEY_CONTRACT } from '@/lib/money-contract';

const IDENTITY_SESSION_URL = `${MONEY_CONTRACT.escrow.apiBase.replace('/escrow-payments', '')}/create_stripe_identity_session`;

/**
 * KYC deep link — opens Stripe Identity web flow via backend session.
 * Mirrors iOS startKYCVerification; session id stays server-side after approval.
 */
export default function WalletKYCPage() {
  const [message, setMessage] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  async function startIdentity() {
    setIsLoading(true);
    setMessage(null);
    try {
      const { authService } = await import('@/lib/firebase/auth');
      const token = await authService.getIdToken();
      if (!token) {
        setMessage('Sign in to verify identity.');
        return;
      }
      const res = await fetch(IDENTITY_SESSION_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ platform: 'web' }),
      });
      const json = (await res.json()) as { url?: string; error?: string };
      if (!res.ok || !json.url) {
        setMessage(json.error ?? 'Could not start identity verification.');
        return;
      }
      window.location.href = json.url;
    } catch {
      setMessage('Network error — try again.');
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-[#0d0e11] text-white">
      <div className="mx-auto max-w-[768px] px-4 py-6">
        <header className="mb-6 flex items-center gap-3">
          <Link href="/wallet" className="rounded-full p-2 hover:bg-gray-800">
            <ArrowLeft size={24} />
          </Link>
          <ShieldCheck className="text-green-400" size={28} />
          <div>
            <h1 className="text-2xl font-bold">Identity verification</h1>
            <p className="text-sm text-gray-400">Required for wagers over $500</p>
          </div>
        </header>
        <p className="mb-6 text-gray-300">
          Verify with Stripe Identity. Your session id is stored only while verification is pending.
        </p>
        <button
          type="button"
          onClick={startIdentity}
          disabled={isLoading}
          className="min-h-[44px] w-full rounded-xl bg-green-600 py-3 font-bold hover:bg-green-500 disabled:opacity-50"
        >
          {isLoading ? 'Starting…' : 'Continue to Stripe Identity'}
        </button>
        {message && <p className="mt-4 text-sm text-amber-300">{message}</p>}
      </div>
    </div>
  );
}
