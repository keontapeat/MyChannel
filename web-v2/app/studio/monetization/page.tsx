'use client';

// Creator Studio - Monetization

import { DollarSign, TrendingUp, Video, Users, Eye, CheckCircle, XCircle, AlertCircle } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';

export default function MonetizationPage() {
  const [isMonetized, setIsMonetized] = useState(true);

  // Sample monetization data
  const [monetization] = useState({
    eligibility: {
      subscribers: { current: 59500, required: 1000, met: true },
      watchHours: { current: 5200, required: 4000, met: true },
      communityGuidelines: { met: true },
      twoStepVerification: { met: true },
    },
    earnings: {
      estimated: 8420.50,
      lastPayout: 7250.00,
      nextPayout: new Date('2024-02-01'),
      ytm: 1.85, // revenue per 1000 views
    },
    revenueStreams: [
      {
        name: 'Ad Revenue',
        amount: 5200.00,
        percentage: 61.7,
        enabled: true,
      },
      {
        name: 'Channel Memberships',
        amount: 2100.00,
        percentage: 24.9,
        enabled: true,
      },
      {
        name: 'Super Chat',
        amount: 820.50,
        percentage: 9.7,
        enabled: true,
      },
      {
        name: 'VS Match Winnings',
        amount: 300.00,
        percentage: 3.6,
        enabled: true,
      },
    ],
  });

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Mobile-First Container */}
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

        {/* Main Content */}
        <main className="px-4 py-6 pb-24">
          {/* Monetization Status */}
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
                  <p className="text-green-100 text-sm mb-1">Estimated Earnings (Last 30 days)</p>
                  <h3 className="text-4xl font-bold text-white mb-2">
                    ${monetization.earnings.estimated.toFixed(2)}
                  </h3>
                  <p className="text-green-100 text-sm">
                    Next payout: {monetization.earnings.nextPayout.toLocaleDateString()}
                  </p>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div className="bg-white/10 backdrop-blur-lg p-3 rounded-xl">
                    <p className="text-green-100 text-xs mb-1">Last Payout</p>
                    <p className="text-white font-bold">${monetization.earnings.lastPayout.toFixed(2)}</p>
                  </div>
                  <div className="bg-white/10 backdrop-blur-lg p-3 rounded-xl">
                    <p className="text-green-100 text-xs mb-1">RPM (per 1K views)</p>
                    <p className="text-white font-bold">${monetization.earnings.ytm.toFixed(2)}</p>
                  </div>
                </div>
              </div>
            ) : (
              <div className="bg-gradient-to-br from-gray-700 via-gray-800 to-gray-900 p-6 rounded-2xl shadow-2xl">
                <div className="flex items-center gap-3 mb-4">
                  <AlertCircle size={32} className="text-yellow-500" />
                  <div>
                    <h2 className="text-2xl font-bold text-white">Monetization Disabled</h2>
                    <p className="text-gray-300">Meet requirements to earn revenue</p>
                  </div>
                </div>
                <Link
                  href="#eligibility"
                  className="block w-full py-3 bg-white text-gray-900 text-center font-bold rounded-xl hover:bg-gray-100 transition-colors"
                >
                  View Eligibility
                </Link>
              </div>
            )}
          </section>

          {/* Revenue Streams */}
          {isMonetized && (
            <section className="mb-8">
              <h2 className="text-lg font-bold text-black mb-4">Revenue Streams</h2>
              <div className="space-y-3">
                {monetization.revenueStreams.map((stream) => (
                  <div key={stream.name} className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm">
                    <div className="flex items-center justify-between mb-3">
                      <div className="flex items-center gap-2">
                        <h3 className="font-bold text-black">{stream.name}</h3>
                        {stream.enabled ? (
                          <CheckCircle size={16} className="text-green-600" />
                        ) : (
                          <XCircle size={16} className="text-gray-400" />
                        )}
                      </div>
                      <div className="text-right">
                        <p className="text-lg font-bold text-green-600">${stream.amount.toFixed(2)}</p>
                        <p className="text-xs text-gray-600">{stream.percentage}%</p>
                      </div>
                    </div>

                    <div className="h-2 bg-gray-200 rounded-full overflow-hidden">
                      <div
                        className="h-full bg-gradient-to-r from-green-500 to-green-600"
                        style={{ width: `${stream.percentage}%` }}
                      />
                    </div>
                  </div>
                ))}
              </div>
            </section>
          )}

          {/* Eligibility Requirements */}
          <section id="eligibility" className="mb-8">
            <h2 className="text-lg font-bold text-black mb-4">Eligibility Requirements</h2>
            <div className="space-y-3">
              <div
                className={`p-4 rounded-xl border ${
                  monetization.eligibility.subscribers.met
                    ? 'bg-green-50 border-green-200'
                    : 'bg-gray-50 border-gray-200'
                }`}
              >
                <div className="flex items-center justify-between mb-2">
                  <span className="font-medium text-black">Subscribers</span>
                  {monetization.eligibility.subscribers.met ? (
                    <CheckCircle size={20} className="text-green-600" />
                  ) : (
                    <XCircle size={20} className="text-gray-400" />
                  )}
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-600">
                    {monetization.eligibility.subscribers.current.toLocaleString()} /{' '}
                    {monetization.eligibility.subscribers.required.toLocaleString()}
                  </span>
                  <span
                    className={
                      monetization.eligibility.subscribers.met ? 'text-green-600 font-bold' : 'text-gray-600'
                    }
                  >
                    {monetization.eligibility.subscribers.met ? 'Met ✓' : 'Not Met'}
                  </span>
                </div>
              </div>

              <div
                className={`p-4 rounded-xl border ${
                  monetization.eligibility.watchHours.met
                    ? 'bg-green-50 border-green-200'
                    : 'bg-gray-50 border-gray-200'
                }`}
              >
                <div className="flex items-center justify-between mb-2">
                  <span className="font-medium text-black">Watch Hours (Last 12 months)</span>
                  {monetization.eligibility.watchHours.met ? (
                    <CheckCircle size={20} className="text-green-600" />
                  ) : (
                    <XCircle size={20} className="text-gray-400" />
                  )}
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-600">
                    {monetization.eligibility.watchHours.current.toLocaleString()} /{' '}
                    {monetization.eligibility.watchHours.required.toLocaleString()}
                  </span>
                  <span
                    className={monetization.eligibility.watchHours.met ? 'text-green-600 font-bold' : 'text-gray-600'}
                  >
                    {monetization.eligibility.watchHours.met ? 'Met ✓' : 'Not Met'}
                  </span>
                </div>
              </div>

              <div className="p-4 rounded-xl border bg-green-50 border-green-200">
                <div className="flex items-center justify-between mb-2">
                  <span className="font-medium text-black">Community Guidelines</span>
                  <CheckCircle size={20} className="text-green-600" />
                </div>
                <p className="text-sm text-gray-600">No active strikes</p>
              </div>

              <div className="p-4 rounded-xl border bg-green-50 border-green-200">
                <div className="flex items-center justify-between mb-2">
                  <span className="font-medium text-black">2-Step Verification</span>
                  <CheckCircle size={20} className="text-green-600" />
                </div>
                <p className="text-sm text-gray-600">Account secured</p>
              </div>
            </div>
          </section>

          {/* Payment Settings */}
          {isMonetized && (
            <section>
              <h2 className="text-lg font-bold text-black mb-4">Payment Settings</h2>
              <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm">
                <div className="mb-4">
                  <p className="text-sm text-gray-600 mb-1">Payment Method</p>
                  <p className="font-bold text-black">Bank Account ••••1234</p>
                </div>

                <div className="mb-4">
                  <p className="text-sm text-gray-600 mb-1">Payment Schedule</p>
                  <p className="font-bold text-black">Monthly (1st of each month)</p>
                </div>

                <Link
                  href="/settings/payments"
                  className="block w-full py-3 text-center text-blue-600 font-medium hover:bg-blue-50 rounded-lg transition-colors"
                >
                  Update Payment Settings
                </Link>
              </div>
            </section>
          )}
        </main>
      </div>
    </div>
  );
}

