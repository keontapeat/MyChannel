'use client';

// Create VS Match - Challenge a Competitor

import { Trophy, DollarSign, Users, Gamepad2, Eye, Heart, MessageCircle, Wallet, Palette, ChefHat, Music, Sparkles, Trophy as SportsIcon } from 'lucide-react';
import Link from 'next/link';
import { useMemo, useState } from 'react';
import {
  VSMatchCategory,
  getMedalIcon,
  getMedalName,
  type MedalDivision,
} from '@/types/vs-matches';
import {
  WAGER_POLICY,
  canWagerClientPreflight,
  centsFromDollars,
  dollarsFromCents,
  getMedalDivision,
  isValidWagerAmount,
  platformFeeCents,
  winnerPayoutCents,
} from '@/lib/wager-policy';
import { createVersusMatchWithEscrow } from '@/lib/vs-match-create';
import { ComplianceStatusBanner } from '@/components/compliance/ComplianceStatusBanner';
import { AgeGateModal } from '@/components/compliance/AgeGateModal';

export default function CreateMatchPage() {
  const [wagerAmount, setWagerAmount] = useState(500);
  const [selectedCategory, setSelectedCategory] = useState<VSMatchCategory>(VSMatchCategory.GAMING);
  const [opponentUsername, setOpponentUsername] = useState('');
  const [description, setDescription] = useState('');
  // Client preflight inputs — replace with live profile when auth is wired.
  const [age, setAge] = useState(21);
  const [showAgeGate, setShowAgeGate] = useState(false);
  const [kycApproved] = useState(false);
  const [region] = useState('US-CA');
  const [alreadyWageredToday] = useState(0);
  const [termsAcceptedVersion] = useState<string | null>(WAGER_POLICY.currentTermsVersion);
  const [preflightReasons, setPreflightReasons] = useState<string[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitMessage, setSubmitMessage] = useState<string | null>(null);

  const categories = [
    { value: VSMatchCategory.GAMING, label: 'Gaming', icon: '🎮', LucideIcon: Gamepad2 },
    { value: VSMatchCategory.VIEWS, label: 'Views', icon: '👀', LucideIcon: Eye },
    { value: VSMatchCategory.LIKES, label: 'Likes', icon: '❤️', LucideIcon: Heart },
    { value: VSMatchCategory.COMMENTS, label: 'Comments', icon: '💬', LucideIcon: MessageCircle },
    { value: VSMatchCategory.DONATIONS, label: 'Donations', icon: '💰', LucideIcon: Wallet },
    { value: VSMatchCategory.CREATIVE, label: 'Creative', icon: '🎨', LucideIcon: Palette },
    { value: VSMatchCategory.COOKING, label: 'Cooking', icon: '🍳', LucideIcon: ChefHat },
    { value: VSMatchCategory.MUSIC, label: 'Music', icon: '🎵', LucideIcon: Music },
    { value: VSMatchCategory.DANCE, label: 'Dance', icon: '💃', LucideIcon: Sparkles },
    { value: VSMatchCategory.SPORTS, label: 'Sports', icon: '⚽', LucideIcon: SportsIcon },
  ];

  const { platformFee, potentialWinnings, wagerValid, preflightOk, liveReasons } = useMemo(() => {
    const potCents = centsFromDollars(wagerAmount) * 2;
    const preflight = canWagerClientPreflight({
      age,
      kycApproved,
      amountDollars: wagerAmount,
      region,
      alreadyWageredToday,
      tier: kycApproved ? 'verified' : 'new',
      termsAcceptedVersion,
    });
    return {
      platformFee: dollarsFromCents(platformFeeCents(potCents)),
      potentialWinnings: dollarsFromCents(winnerPayoutCents(potCents)),
      wagerValid: isValidWagerAmount(wagerAmount),
      preflightOk: preflight.ok,
      liveReasons: preflight.ok ? [] : preflight.reasons,
    };
  }, [wagerAmount, age, kycApproved, region, alreadyWageredToday, termsAcceptedVersion]);
  const medal = getMedalDivision(wagerAmount) as MedalDivision;

  const canCreate = wagerValid && preflightOk && !isSubmitting;
  const shownReasons = preflightReasons.length > 0 ? preflightReasons : liveReasons;

  async function handleCreateMatch() {
    const result = canWagerClientPreflight({
      age,
      kycApproved,
      amountDollars: wagerAmount,
      region,
      alreadyWageredToday,
      tier: kycApproved ? 'verified' : 'new',
      termsAcceptedVersion,
    });
    if (!result.ok) {
      setPreflightReasons(result.reasons);
      const hasAgeBlock = result.reasons.some((r) => r.includes('18+'));
      if (hasAgeBlock) setShowAgeGate(true);
      setSubmitMessage(
        `Compliance check failed: ${result.reasons.join(' · ')}. Fix the items above before creating a match.`
      );
      return;
    }
    setPreflightReasons([]);
    setSubmitMessage(null);
    setIsSubmitting(true);
    try {
      const created = await createVersusMatchWithEscrow({
        wagerAmountDollars: wagerAmount,
        category: selectedCategory,
        opponentUsername: opponentUsername || undefined,
        description: description || undefined,
      });
      if (!created.ok) {
        setSubmitMessage(created.error);
        return;
      }
      setSubmitMessage(
        created.paymentIntentId
          ? `Match ${created.matchId} created — escrow held (${created.paymentIntentId}).`
          : `Match ${created.matchId} created.`
      );
    } finally {
      setIsSubmitting(false);
    }
  }

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
            <label htmlFor="wager-amount" className="block text-lg font-bold mb-4">
              Wager Amount
            </label>
            <div className="bg-gray-800 p-6 rounded-xl">
              <div className="flex items-center gap-2 mb-4">
                <DollarSign size={32} className="text-green-500" aria-hidden />
                <input
                  id="wager-amount"
                  type="number"
                  min="1"
                  max="100000"
                  value={wagerAmount}
                  onChange={(e) => setWagerAmount(Number(e.target.value))}
                  aria-label="Wager amount in US dollars"
                  aria-describedby="wager-fee-breakdown"
                  className="flex-1 bg-gray-700 text-white text-3xl font-bold px-4 py-3 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500"
                />
              </div>

              <div id="wager-fee-breakdown" className="space-y-2 text-sm">
                <div className="flex justify-between text-gray-400">
                  <span>Platform Fee ({Math.round(WAGER_POLICY.platformFeePercent * 100)}%)</span>
                  <span className="text-white font-bold">-${platformFee.toFixed(2)}</span>
                </div>
                <div className="flex justify-between text-gray-400">
                  <span>Potential Winnings</span>
                  <span className="text-green-500 font-bold">${potentialWinnings.toFixed(2)}</span>
                </div>
                {!wagerValid && (
                  <p className="text-red-400 text-xs pt-1">
                    Wager must be ${WAGER_POLICY.minWagerDollars}–${WAGER_POLICY.maxWagerDollars.toLocaleString()}
                  </p>
                )}
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
                  <div className="text-3xl mb-2 flex items-center justify-center gap-1">
                    <category.LucideIcon size={22} className="opacity-80" aria-hidden />
                    <span aria-hidden>{category.icon}</span>
                  </div>
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

          {/* Compliance preflight — KYC / region / daily / terms */}
          <ComplianceStatusBanner
            className="mb-8"
            preflight={{
              age,
              kycApproved,
              region,
              alreadyWageredToday,
              tier: kycApproved ? 'verified' : 'new',
              termsAcceptedVersion,
              wagerAmountDollars: wagerAmount,
            }}
          />

          {shownReasons.length > 0 && (
            <section
              className="mb-4 rounded-xl border border-red-500/40 bg-red-950/30 p-4"
              role="alert"
              aria-live="assertive"
            >
              <p className="mb-2 text-sm font-semibold text-red-200">Compliance requirements not met</p>
              <ul className="text-sm text-red-400 space-y-1">
                {shownReasons.map((reason) => (
                  <li key={reason}>• {reason}</li>
                ))}
              </ul>
            </section>
          )}

          {submitMessage && (
            <p className="mb-4 text-sm text-gray-200" role="status">
              {submitMessage}
            </p>
          )}

          {/* Create Match Button — disabled until wager + compliance preflight pass */}
          <button
            type="button"
            disabled={!canCreate}
            onClick={() => {
              void handleCreateMatch();
            }}
            className="min-h-[44px] w-full py-4 bg-gradient-to-r from-green-600 to-green-700 text-white text-lg font-bold rounded-full hover:from-green-700 hover:to-green-800 transition-all shadow-xl disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {isSubmitting
              ? 'Creating…'
              : `Create Match • $${wagerAmount.toFixed(2)}`}
          </button>

          {/* Cancel Button */}
          <Link
            href="/medals"
            className="block w-full py-4 text-center text-gray-400 hover:text-white transition-colors mt-3"
          >
            Cancel
          </Link>
        </main>

        <AgeGateModal
          isOpen={showAgeGate}
          onClose={() => setShowAgeGate(false)}
          onConfirmAge={(confirmedAge) => {
            setAge(confirmedAge);
            setShowAgeGate(false);
            if (confirmedAge < WAGER_POLICY.minimumAge) {
              setSubmitMessage('You must be 18+ to create real-money VS Matches.');
            }
          }}
        />
      </div>
    </div>
  );
}

