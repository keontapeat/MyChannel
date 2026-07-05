'use client';

// Creator Studio - Monetization
// Earnings are read from the real `creator-earnings/{uid}` store (integer cents).
// This screen only DISPLAYS money — it never moves it. Payouts run server-side only.

import { DollarSign, CheckCircle, XCircle, AlertCircle, Wallet, Clock } from 'lucide-react';
import Link from 'next/link';
import { useState, useEffect } from 'react';
import { doc, getDoc } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import MembershipTiersManager from '@/components/studio/MembershipTiersManager';

interface Earnings {
  totalRevenueCents: number;
  availableCents: number;
  pendingCents: number;
  lastPayoutCents: number;
  lastPayoutAt: Date | null;
}

const SUBS_REQUIRED = 1000;
const WATCH_HOURS_REQUIRED = 4000;

function fmtCents(cents: number): string {
  return `$${(cents / 100).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function fmtNum(n: number): string {
  return n.toLocaleString('en-US');
}

export default function MonetizationPage() {
  const [uid, setUid] = useState<string | null>(auth?.currentUser?.uid ?? null);
  const [loading, setLoading] = useState(true);
  const [earnings, setEarnings] = useState<Earnings | null>(null);
  const [subscribers, setSubscribers] = useState(0);
  const [watchHours, setWatchHours] = useState(0);

  // Wait for Firebase auth to resolve before deciding the user is signed out.
  useEffect(() => {
    const unsub = auth?.onAuthStateChanged?.((u) => setUid(u?.uid ?? null));
    return () => { if (typeof unsub === 'function') unsub(); };
  }, []);

  useEffect(() => {
    if (!uid) { setLoading(false); return; }
    let cancelled = false;

    const load = async () => {
      try {
        const [userSnap, earnSnap] = await Promise.all([
          getDoc(doc(db, 'users', uid)),
          getDoc(doc(db, 'creator-earnings', uid)),
        ]);
        if (cancelled) return;

        if (userSnap.exists()) {
          const d = userSnap.data();
          setSubscribers(d.subscriberCount ?? 0);
          // Watch hours are not tracked directly on web yet — estimate from views.
          setWatchHours(Math.round(((d.totalViewCount ?? 0) * 7) / 60)); // ~7 min avg per view
        }

        if (earnSnap.exists()) {
          const e = earnSnap.data();
          setEarnings({
            totalRevenueCents: e.totalRevenue ?? 0,
            availableCents: e.availableBalance ?? 0,
            pendingCents: e.pendingBalance ?? 0,
            lastPayoutCents: e.lastPayoutAmount ?? 0,
            lastPayoutAt: e.lastPayoutAt?.toDate?.() ?? null,
          });
        } else {
          setEarnings({ totalRevenueCents: 0, availableCents: 0, pendingCents: 0, lastPayoutCents: 0, lastPayoutAt: null });
        }
      } catch (err) {
        console.error('Monetization load error:', err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    load();
    return () => { cancelled = true; };
  }, [uid]);

  const subsMet = subscribers >= SUBS_REQUIRED;
  const watchMet = watchHours >= WATCH_HOURS_REQUIRED;
  const isMonetized = subsMet && watchMet;
  const e = earnings;

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-[768px] mx-auto">
        {/* Header */}
        <header className="sticky top-0 z-50 bg-white border-b border-gray-200 px-4 py-4">
          <div className="flex items-center gap-3">
            <Link href="/studio" className="p-2 hover:bg-gray-100 rounded-full transition-colors">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="black">
                <path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z" />
              </svg>
            </Link>
            <DollarSign size={28} className="text-green-600" />
            <div>
              <h1 className="text-xl font-bold text-black">Monetization</h1>
              <p className="text-sm text-gray-600">Manage your earnings</p>
            </div>
          </div>
        </header>

        <main className="px-4 py-6 pb-24">
          {!uid && !loading ? (
            <div className="p-8 bg-white rounded-2xl border border-gray-200 text-center">
              <AlertCircle size={32} className="mx-auto mb-3 text-gray-400" />
              <p className="text-gray-700 font-medium mb-4">Sign in to view your monetization</p>
              <Link href="/login" className="inline-block px-5 py-2.5 bg-green-600 text-white font-semibold rounded-full">Sign in</Link>
            </div>
          ) : loading ? (
            <div className="space-y-4">
              <div className="h-48 bg-white rounded-2xl border border-gray-200 animate-pulse" />
              <div className="h-32 bg-white rounded-2xl border border-gray-200 animate-pulse" />
            </div>
          ) : (
            <>
              {/* Earnings status */}
              <section className="mb-8">
                {isMonetized ? (
                  <div className="bg-gradient-to-br from-green-600 via-green-700 to-emerald-800 p-6 rounded-2xl shadow-2xl">
                    <div className="flex items-center gap-3 mb-4">
                      <CheckCircle size={32} className="text-white" />
                      <div>
                        <h2 className="text-2xl font-bold text-white">Monetization Active</h2>
                        <p className="text-green-100">Your channel is earning revenue</p>
                      </div>
                    </div>

                    <div className="bg-white/10 backdrop-blur-lg p-4 rounded-xl mb-4">
                      <p className="text-green-100 text-sm mb-1">Available to withdraw</p>
                      <h3 className="text-4xl font-bold text-white mb-2">{fmtCents(e?.availableCents ?? 0)}</h3>
                      {e?.lastPayoutAt && (
                        <p className="text-green-100 text-sm">
                          Last payout: {fmtCents(e.lastPayoutCents)} on {e.lastPayoutAt.toLocaleDateString()}
                        </p>
                      )}
                    </div>

                    <div className="grid grid-cols-2 gap-3">
                      <div className="bg-white/10 backdrop-blur-lg p-3 rounded-xl">
                        <p className="text-green-100 text-xs mb-1 flex items-center gap-1"><Clock size={11} /> Pending</p>
                        <p className="text-white font-bold">{fmtCents(e?.pendingCents ?? 0)}</p>
                      </div>
                      <div className="bg-white/10 backdrop-blur-lg p-3 rounded-xl">
                        <p className="text-green-100 text-xs mb-1 flex items-center gap-1"><Wallet size={11} /> Lifetime</p>
                        <p className="text-white font-bold">{fmtCents(e?.totalRevenueCents ?? 0)}</p>
                      </div>
                    </div>
                  </div>
                ) : (
                  <div className="bg-gradient-to-br from-gray-700 via-gray-800 to-gray-900 p-6 rounded-2xl shadow-2xl">
                    <div className="flex items-center gap-3 mb-4">
                      <AlertCircle size={32} className="text-yellow-500" />
                      <div>
                        <h2 className="text-2xl font-bold text-white">Not Yet Eligible</h2>
                        <p className="text-gray-300">Meet the requirements below to start earning</p>
                      </div>
                    </div>
                    {(e?.totalRevenueCents ?? 0) > 0 && (
                      <div className="bg-white/10 backdrop-blur-lg p-4 rounded-xl">
                        <p className="text-gray-300 text-sm mb-1">Balance so far</p>
                        <p className="text-2xl font-bold text-white">{fmtCents(e?.availableCents ?? 0)}</p>
                      </div>
                    )}
                  </div>
                )}
              </section>

              {/* Membership Tiers (real, config-only) */}
              <section className="mb-8">
                <h2 className="text-lg font-bold text-black mb-4">Channel Memberships</h2>
                <MembershipTiersManager />
              </section>

              {/* Eligibility Requirements (computed from real stats) */}
              <section id="eligibility" className="mb-8">
                <h2 className="text-lg font-bold text-black mb-4">Eligibility Requirements</h2>
                <div className="space-y-3">
                  <div className={`p-4 rounded-xl border ${subsMet ? 'bg-green-50 border-green-200' : 'bg-gray-50 border-gray-200'}`}>
                    <div className="flex items-center justify-between mb-2">
                      <span className="font-medium text-black">Subscribers</span>
                      {subsMet ? <CheckCircle size={20} className="text-green-600" /> : <XCircle size={20} className="text-gray-400" />}
                    </div>
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-gray-600">{fmtNum(subscribers)} / {fmtNum(SUBS_REQUIRED)}</span>
                      <span className={subsMet ? 'text-green-600 font-bold' : 'text-gray-600'}>{subsMet ? 'Met ✓' : 'Not Met'}</span>
                    </div>
                  </div>

                  <div className={`p-4 rounded-xl border ${watchMet ? 'bg-green-50 border-green-200' : 'bg-gray-50 border-gray-200'}`}>
                    <div className="flex items-center justify-between mb-2">
                      <span className="font-medium text-black">Watch Hours <span className="text-xs text-gray-400 font-normal">(estimated)</span></span>
                      {watchMet ? <CheckCircle size={20} className="text-green-600" /> : <XCircle size={20} className="text-gray-400" />}
                    </div>
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-gray-600">{fmtNum(watchHours)} / {fmtNum(WATCH_HOURS_REQUIRED)}</span>
                      <span className={watchMet ? 'text-green-600 font-bold' : 'text-gray-600'}>{watchMet ? 'Met ✓' : 'Not Met'}</span>
                    </div>
                  </div>
                </div>
              </section>

              {/* Payment settings link (no hardcoded account details) */}
              <section>
                <h2 className="text-lg font-bold text-black mb-4">Payment Settings</h2>
                <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm">
                  <p className="text-sm text-gray-600 mb-4">
                    Connect or update your payout account to receive payments. Payouts are processed securely and never handled on this screen.
                  </p>
                  <Link
                    href="/settings/payments"
                    className="block w-full py-3 text-center bg-green-600 text-white font-semibold rounded-lg hover:opacity-90 transition-opacity"
                  >
                    Manage payout account
                  </Link>
                </div>
              </section>
            </>
          )}
        </main>
      </div>
    </div>
  );
}
