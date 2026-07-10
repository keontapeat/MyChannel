'use client';

import { ArrowLeft, ArrowDownRight, Info } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';
import { MONEY_CONTRACT, centsFromDollars } from '@/lib/money-contract';
import { authService } from '@/lib/firebase/auth';

const ESCROW_TRANSFER_URL = `${MONEY_CONTRACT.escrow.apiBase}${MONEY_CONTRACT.escrow.endpoints.transfer}`;

export default function WalletWithdrawPage() {
  const [amount, setAmount] = useState(50);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function handleWithdraw() {
    setMessage(null);
    setIsSubmitting(true);
    try {
      const token = await authService.getIdToken();
      if (!token) {
        setMessage('Sign in to withdraw funds from your VS Match wallet.');
        return;
      }

      const amountCents = centsFromDollars(amount);
      if (amountCents < 100 || amountCents > 10_000_000) {
        setMessage('Withdrawal must be between $1 and $100,000.');
        return;
      }

      // Stub: production routes through Stripe Connect payout after server balance check.
      const res = await fetch(ESCROW_TRANSFER_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          amount: amountCents,
          matchId: 'wallet_withdraw',
        }),
      });

      const json = (await res.json().catch(() => ({}))) as { error?: string; transferId?: string };

      if (!res.ok) {
        setMessage(json.error || `Withdrawal failed (${res.status})`);
        return;
      }

      setMessage(
        json.transferId
          ? `Withdrawal ${json.transferId} initiated. Funds settle via Stripe Connect.`
          : 'Withdrawal request submitted. Server will verify balance before payout.'
      );
    } catch {
      setMessage('Could not start withdrawal. Try again.');
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black text-white">
      <div className="mx-auto max-w-[768px]">
        <header className="sticky top-0 z-50 border-b border-gray-700 bg-gray-900/95 px-4 py-4 backdrop-blur-lg">
          <div className="flex items-center gap-3">
            <Link href="/wallet" className="rounded-full p-2 transition-colors hover:bg-gray-800">
              <ArrowLeft size={24} />
            </Link>
            <ArrowDownRight size={28} className="text-red-400" />
            <div>
              <h1 className="text-2xl font-bold">Withdraw</h1>
              <p className="text-sm text-gray-400">Transfer VS Match winnings to your bank</p>
            </div>
          </div>
        </header>

        <main className="px-4 py-6 pb-24">
          <section className="mb-6 rounded-xl border border-amber-500/30 bg-amber-900/20 p-4">
            <div className="flex items-start gap-3 text-sm text-amber-100">
              <Info className="mt-0.5 shrink-0 text-amber-400" size={20} />
              <p>
                Withdrawals are processed server-side via Stripe Connect. Available balance is
                checked on the backend — the client never credits or debits wallet funds.
              </p>
            </div>
          </section>

          <section className="mb-6 rounded-xl bg-gray-800 p-6">
            <label htmlFor="withdraw-amount" className="mb-4 block text-lg font-bold">
              Amount (USD)
            </label>
            <div className="mb-4 flex items-center gap-2">
              <span className="text-2xl font-bold text-red-400" aria-hidden>
                $
              </span>
              <input
                id="withdraw-amount"
                type="number"
                min={1}
                max={100000}
                value={amount}
                onChange={(e) => setAmount(Number(e.target.value))}
                aria-label="Withdrawal amount in US dollars"
                className="flex-1 rounded-lg bg-gray-700 px-4 py-3 text-3xl font-bold text-white focus:outline-none focus:ring-2 focus:ring-red-500"
              />
            </div>

            <div className="grid grid-cols-4 gap-2">
              {[25, 50, 100, 500].map((preset) => (
                <button
                  key={preset}
                  type="button"
                  onClick={() => setAmount(preset)}
                  className={`min-h-[44px] rounded-lg py-2 text-sm font-bold transition-all ${
                    amount === preset
                      ? 'bg-red-600 text-white'
                      : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                  }`}
                >
                  ${preset}
                </button>
              ))}
            </div>
          </section>

          {message && (
            <p className="mb-4 text-sm text-gray-200" role="status">
              {message}
            </p>
          )}

          <button
            type="button"
            disabled={isSubmitting}
            onClick={() => {
              void handleWithdraw();
            }}
            className="min-h-[44px] w-full rounded-full bg-gradient-to-r from-red-600 to-red-700 py-4 text-lg font-bold text-white shadow-xl transition-all hover:from-red-700 hover:to-red-800 disabled:cursor-not-allowed disabled:opacity-40"
          >
            {isSubmitting ? 'Starting withdrawal…' : `Withdraw $${amount.toFixed(2)}`}
          </button>

          <p className="mt-4 text-center text-xs text-gray-500">
            Stub page — wire Stripe Connect payout confirmation for production.
          </p>
        </main>
      </div>
    </div>
  );
}
