'use client';

import { ArrowLeft, DollarSign, Info } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';
import { MONEY_CONTRACT, centsFromDollars } from '@/lib/money-contract';
import { authService } from '@/lib/firebase/auth';

const ESCROW_CREATE_URL = `${MONEY_CONTRACT.escrow.apiBase}${MONEY_CONTRACT.escrow.endpoints.createPayment}`;

export default function WalletDepositPage() {
  const [amount, setAmount] = useState(50);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function handleDeposit() {
    setMessage(null);
    setIsSubmitting(true);
    try {
      const token = await authService.getIdToken();
      if (!token) {
        setMessage('Sign in to deposit funds into your VS Match wallet.');
        return;
      }

      const amountCents = centsFromDollars(amount);
      if (amountCents < 100 || amountCents > 10_000_000) {
        setMessage('Deposit must be between $1 and $100,000.');
        return;
      }

      const res = await fetch(ESCROW_CREATE_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          amount: amountCents,
          matchId: MONEY_CONTRACT.escrow.walletDepositMatchId,
          captureMethod: MONEY_CONTRACT.escrow.captureMethod.walletDeposit,
        }),
      });

      const json = (await res.json().catch(() => ({}))) as {
        error?: string;
        paymentIntentId?: string;
        clientSecret?: string;
      };

      if (!res.ok) {
        setMessage(json.error || `Deposit failed (${res.status})`);
        return;
      }

      setMessage(
        json.paymentIntentId
          ? `Payment intent ${json.paymentIntentId} created. Complete checkout with Stripe Elements using the client secret.`
          : 'Deposit intent created. Complete payment to credit your wallet.'
      );
    } catch {
      setMessage('Could not start deposit. Try again.');
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
            <DollarSign size={28} className="text-green-500" />
            <div>
              <h1 className="text-2xl font-bold">Deposit</h1>
              <p className="text-sm text-gray-400">Add funds to your VS Match wallet</p>
            </div>
          </div>
        </header>

        <main className="px-4 py-6 pb-24">
          <section className="mb-6 rounded-xl border border-blue-500/30 bg-blue-900/20 p-4">
            <div className="flex items-start gap-3 text-sm text-blue-100">
              <Info className="mt-0.5 shrink-0 text-blue-400" size={20} />
              <p>
                Deposits create a Stripe PaymentIntent via the escrow service. Your wallet balance
                is credited server-side after Stripe confirms payment — never from the client.
              </p>
            </div>
          </section>

          <section className="mb-6 rounded-xl bg-gray-800 p-6">
            <label className="mb-4 block text-lg font-bold">Amount (USD)</label>
            <div className="mb-4 flex items-center gap-2">
              <DollarSign size={28} className="text-green-500" />
              <input
                type="number"
                min={1}
                max={100000}
                value={amount}
                onChange={(e) => setAmount(Number(e.target.value))}
                className="flex-1 rounded-lg bg-gray-700 px-4 py-3 text-3xl font-bold text-white focus:outline-none focus:ring-2 focus:ring-green-500"
              />
            </div>

            <div className="grid grid-cols-4 gap-2">
              {[25, 50, 100, 500].map((preset) => (
                <button
                  key={preset}
                  type="button"
                  onClick={() => setAmount(preset)}
                  className={`rounded-lg py-2 text-sm font-bold transition-all ${
                    amount === preset
                      ? 'bg-green-600 text-white'
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
              void handleDeposit();
            }}
            className="w-full rounded-full bg-gradient-to-r from-green-600 to-green-700 py-4 text-lg font-bold text-white shadow-xl transition-all hover:from-green-700 hover:to-green-800 disabled:cursor-not-allowed disabled:opacity-40"
          >
            {isSubmitting ? 'Starting deposit…' : `Deposit $${amount.toFixed(2)}`}
          </button>

          <p className="mt-4 text-center text-xs text-gray-500">
            Stub page — wire Stripe Elements with clientSecret for production checkout.
          </p>
        </main>
      </div>
    </div>
  );
}
