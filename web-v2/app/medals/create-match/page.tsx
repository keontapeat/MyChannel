'use client';

// Create VS Match - Challenge a Competitor

import { Trophy, DollarSign, Users, Calendar, Info } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';
import {
  VSMatchCategory,
  MedalDivision,
  getMedalIcon,
  getMedalName,
  getMedalDivision,
} from '@/types/vs-matches';

export default function CreateMatchPage() {
  const [wagerAmount, setWagerAmount] = useState(500);
  const [selectedCategory, setSelectedCategory] = useState<VSMatchCategory>(VSMatchCategory.GAMING);
  const [opponentUsername, setOpponentUsername] = useState('');
  const [description, setDescription] = useState('');

  const categories = [
    { value: VSMatchCategory.GAMING, label: 'Gaming', icon: '🎮' },
    { value: VSMatchCategory.VIEWS, label: 'Views', icon: '👀' },
    { value: VSMatchCategory.LIKES, label: 'Likes', icon: '❤️' },
    { value: VSMatchCategory.COMMENTS, label: 'Comments', icon: '💬' },
    { value: VSMatchCategory.DONATIONS, label: 'Donations', icon: '💰' },
    { value: VSMatchCategory.CREATIVE, label: 'Creative', icon: '🎨' },
    { value: VSMatchCategory.COOKING, label: 'Cooking', icon: '🍳' },
    { value: VSMatchCategory.MUSIC, label: 'Music', icon: '🎵' },
    { value: VSMatchCategory.DANCE, label: 'Dance', icon: '💃' },
    { value: VSMatchCategory.SPORTS, label: 'Sports', icon: '⚽' },
  ];

  const platformFee = wagerAmount * 0.1; // 10% fee
  const potentialWinnings = wagerAmount * 2 - platformFee;
  const medal = getMedalDivision(wagerAmount);

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black text-white">
      {/* Mobile-First Container */}
      <div className="max-w-[768px] mx-auto">
        {/* Header */}
        <header className="sticky top-0 z-50 bg-gray-900/95 backdrop-blur-lg border-b border-gray-700 px-4 py-4">
          <div className="flex items-center gap-3">
            <Link href="/medals" className="p-2 hover:bg-gray-800 rounded-full transition-colors">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="white">
                <path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z" />
              </svg>
            </Link>
            <Trophy size={28} className="text-yellow-500" />
            <div>
              <h1 className="text-2xl font-bold">Create VS Match</h1>
              <p className="text-sm text-gray-400">Challenge a competitor</p>
            </div>
          </div>
        </header>

        {/* Main Content */}
        <main className="px-4 py-6 pb-24">
          {/* Medal Division Display */}
          <section className="mb-8">
            <div className="bg-gradient-to-br from-yellow-600 via-yellow-700 to-orange-600 p-6 rounded-2xl shadow-2xl">
              <div className="flex items-center gap-4">
                <div className="text-6xl">{getMedalIcon(medal)}</div>
                <div>
                  <h2 className="text-3xl font-bold text-white">{getMedalName(medal)}</h2>
                  <p className="text-white/80">Compete for this medal!</p>
                </div>
              </div>
            </div>
          </section>

          {/* Wager Amount */}
          <section className="mb-8">
            <label className="block text-lg font-bold mb-4">Wager Amount</label>
            <div className="bg-gray-800 p-6 rounded-xl">
              <div className="flex items-center gap-2 mb-4">
                <DollarSign size={32} className="text-green-500" />
                <input
                  type="number"
                  min="1"
                  max="100000"
                  value={wagerAmount}
                  onChange={(e) => setWagerAmount(Number(e.target.value))}
                  className="flex-1 bg-gray-700 text-white text-3xl font-bold px-4 py-3 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500"
                />
              </div>

              <div className="space-y-2 text-sm">
                <div className="flex justify-between text-gray-400">
                  <span>Platform Fee (10%)</span>
                  <span className="text-white font-bold">-${platformFee.toFixed(2)}</span>
                </div>
                <div className="flex justify-between text-gray-400">
                  <span>Potential Winnings</span>
                  <span className="text-green-500 font-bold">${potentialWinnings.toFixed(2)}</span>
                </div>
              </div>

              {/* Wager Range Presets */}
              <div className="grid grid-cols-4 gap-2 mt-4">
                {[100, 500, 1000, 5000].map((amount) => (
                  <button
                    key={amount}
                    onClick={() => setWagerAmount(amount)}
                    className={`py-2 px-3 rounded-lg font-bold text-sm transition-all ${
                      wagerAmount === amount
                        ? 'bg-green-600 text-white'
                        : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                    }`}
                  >
                    ${amount}
                  </button>
                ))}
              </div>
            </div>
          </section>

          {/* Category Selection */}
          <section className="mb-8">
            <label className="block text-lg font-bold mb-4">Match Category</label>
            <div className="grid grid-cols-2 gap-3">
              {categories.map((category) => (
                <button
                  key={category.value}
                  onClick={() => setSelectedCategory(category.value)}
                  className={`p-4 rounded-xl transition-all ${
                    selectedCategory === category.value
                      ? 'bg-gradient-to-br from-blue-600 to-purple-600 text-white scale-105 shadow-xl'
                      : 'bg-gray-800 text-gray-300 hover:bg-gray-700'
                  }`}
                >
                  <div className="text-3xl mb-2">{category.icon}</div>
                  <div className="font-bold text-sm">{category.label}</div>
                </button>
              ))}
            </div>
          </section>

          {/* Opponent Username */}
          <section className="mb-8">
            <label className="block text-lg font-bold mb-4">Opponent Username</label>
            <div className="relative">
              <Users className="absolute left-4 top-1/2 transform -translate-y-1/2 text-gray-400" size={20} />
              <input
                type="text"
                placeholder="@username"
                value={opponentUsername}
                onChange={(e) => setOpponentUsername(e.target.value)}
                className="w-full bg-gray-800 text-white pl-12 pr-4 py-4 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <p className="text-xs text-gray-400 mt-2">
              Leave blank to create an open challenge
            </p>
          </section>

          {/* Description */}
          <section className="mb-8">
            <label className="block text-lg font-bold mb-4">Description (Optional)</label>
            <textarea
              placeholder="Add match details, rules, or conditions..."
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={4}
              className="w-full bg-gray-800 text-white px-4 py-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none"
            />
          </section>

          {/* Compliance Notice */}
          <section className="mb-8">
            <div className="bg-blue-900/30 border border-blue-500/30 p-4 rounded-xl">
              <div className="flex items-start gap-3">
                <Info className="text-blue-400 flex-shrink-0 mt-1" size={20} />
                <div className="text-sm text-blue-100">
                  <p className="font-bold mb-2">Compliance Requirements:</p>
                  <ul className="space-y-1 text-blue-200">
                    <li>• Must be 18+ years old</li>
                    <li>• KYC required for wagers over $500</li>
                    <li>• Daily wager limits apply</li>
                    <li>• Funds will be held in escrow</li>
                  </ul>
                </div>
              </div>
            </div>
          </section>

          {/* Create Match Button */}
          <button
            className="w-full py-4 bg-gradient-to-r from-green-600 to-green-700 text-white text-lg font-bold rounded-full hover:from-green-700 hover:to-green-800 transition-all shadow-xl"
          >
            Create Match • ${wagerAmount.toFixed(2)}
          </button>

          {/* Cancel Button */}
          <Link
            href="/medals"
            className="block w-full py-4 text-center text-gray-400 hover:text-white transition-colors mt-3"
          >
            Cancel
          </Link>
        </main>
      </div>
    </div>
  );
}

