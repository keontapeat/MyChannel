'use client';

// 🏆 CHAMPIONSHIP HUB - OLYMPICS/NBA FINALS LEVEL 🔥
// The most EPIC, professional championship experience ever built!

import { Trophy, TrendingUp, Crown, Star, Medal, Flame, Zap, Target, ChevronRight, ArrowUp, ArrowDown } from 'lucide-react';
import Link from 'next/link';
import Image from 'next/image';
import { useEffect, useState } from 'react';
import {
  MedalDivision,
  getMedalIcon,
  getMedalName,
  getWagerRange,
  RankedCompetitor,
} from '@/types/vs-matches';
import {
  loadChampionshipRankings,
  loadRecentVersusMatches,
  type RecentVSMatchRow,
} from '@/lib/vs-match-medals';

export default function ChampionshipHub() {
  const [selectedDivision, setSelectedDivision] = useState<MedalDivision>(MedalDivision.GOLD);
  const [activeTab, setActiveTab] = useState<'rankings' | 'matches' | 'stats'>('rankings');
  const [animateIn] = useState(true);
  const [rankedCompetitors, setRankedCompetitors] = useState<RankedCompetitor[]>([]);
  const [recentMatches, setRecentMatches] = useState<RecentVSMatchRow[]>([]);
  const [isLoadingRankings, setIsLoadingRankings] = useState(true);

  // Medal divisions with enhanced styling
  const divisions = [
    { 
      division: MedalDivision.BRONZE, 
      gradient: 'from-amber-700 via-amber-600 to-amber-800',
      glow: 'shadow-amber-500/50',
      border: 'border-amber-400/30',
      ring: 'ring-amber-400/50'
    },
    { 
      division: MedalDivision.SILVER, 
      gradient: 'from-gray-300 via-gray-200 to-gray-400',
      glow: 'shadow-gray-400/50',
      border: 'border-gray-300/30',
      ring: 'ring-gray-300/50'
    },
    { 
      division: MedalDivision.GOLD, 
      gradient: 'from-yellow-400 via-yellow-300 to-yellow-600',
      glow: 'shadow-yellow-500/60',
      border: 'border-yellow-400/40',
      ring: 'ring-yellow-400/60'
    },
    { 
      division: MedalDivision.PLATINUM, 
      gradient: 'from-cyan-400 via-cyan-300 to-cyan-600',
      glow: 'shadow-cyan-500/50',
      border: 'border-cyan-400/30',
      ring: 'ring-cyan-400/50'
    },
    { 
      division: MedalDivision.DIAMOND, 
      gradient: 'from-blue-400 via-purple-400 to-purple-600',
      glow: 'shadow-purple-500/60',
      border: 'border-purple-400/40',
      ring: 'ring-purple-400/60'
    },
    { 
      division: MedalDivision.LEGEND, 
      gradient: 'from-purple-600 via-pink-500 to-red-600',
      glow: 'shadow-pink-500/70',
      border: 'border-pink-400/50',
      ring: 'ring-pink-400/70'
    },
  ];

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setIsLoadingRankings(true);
      try {
        const [rankings, matches] = await Promise.all([
          loadChampionshipRankings(selectedDivision),
          loadRecentVersusMatches(5),
        ]);
        if (cancelled) return;
        setRankedCompetitors(rankings);
        setRecentMatches(matches);
      } finally {
        if (!cancelled) setIsLoadingRankings(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [selectedDivision]);

  const selectedDivisionData = divisions.find((d) => d.division === selectedDivision);

  // Division stats
  const divisionStats = {
    totalCompetitors: 156,
    totalMatches: 1247,
    totalPrizePool: 547000,
    avgWager: 2340,
    activeMatches: 23,
    completedToday: 47,
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-950 via-gray-900 to-black text-white overflow-hidden">
      {/* Animated Background Effects */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 left-1/4 w-96 h-96 bg-yellow-500/10 rounded-full blur-3xl animate-pulse" />
        <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl animate-pulse delay-1000" />
        <div className="absolute top-1/2 left-1/2 w-96 h-96 bg-blue-500/10 rounded-full blur-3xl animate-pulse delay-2000" />
      </div>

      {/* Mobile-First Container */}
      <div className="max-w-[768px] mx-auto relative z-10">
        {/* Epic Header with Glass Morphism */}
        <header className="sticky top-0 z-50 bg-gray-900/80 backdrop-blur-2xl border-b border-white/10 shadow-2xl">
          <div className="px-4 py-4">
            <div className="flex items-center gap-3 mb-3">
              <Link 
                href="/" 
                className="p-2 hover:bg-white/10 rounded-full transition-all active:scale-95"
              >
                <svg width="24" height="24" viewBox="0 0 24 24" fill="white">
                  <path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z" />
                </svg>
              </Link>
              <div className="relative">
                <Trophy size={32} className="text-yellow-400 drop-shadow-[0_0_8px_rgba(250,204,21,0.6)]" />
                <div className="absolute -top-1 -right-1 w-3 h-3 bg-red-500 rounded-full animate-ping" />
              </div>
              <div className="flex-1">
                <h1 className="text-2xl font-black bg-gradient-to-r from-yellow-400 via-yellow-300 to-yellow-500 bg-clip-text text-transparent">
                  Championship Hub
                </h1>
                <p className="text-xs text-gray-400 font-medium">
                  6 Divisions • Compete for Glory
                </p>
              </div>
              <div className="text-right">
                <div className="text-lg font-bold text-yellow-400">LIVE</div>
                <div className="text-xs text-gray-400">{divisionStats.activeMatches} matches</div>
              </div>
            </div>

            {/* Quick Stats Bar */}
            <div className="grid grid-cols-3 gap-2 mb-3">
              <div className="bg-white/5 backdrop-blur-sm rounded-lg p-2 border border-white/10">
                <div className="text-xs text-gray-400 mb-0.5">Total Prize Pool</div>
                <div className="text-sm font-bold text-green-400">${(divisionStats.totalPrizePool / 1000).toFixed(0)}K</div>
              </div>
              <div className="bg-white/5 backdrop-blur-sm rounded-lg p-2 border border-white/10">
                <div className="text-xs text-gray-400 mb-0.5">Competitors</div>
                <div className="text-sm font-bold text-blue-400">{divisionStats.totalCompetitors}</div>
              </div>
              <div className="bg-white/5 backdrop-blur-sm rounded-lg p-2 border border-white/10">
                <div className="text-xs text-gray-400 mb-0.5">Matches Today</div>
                <div className="text-sm font-bold text-purple-400">{divisionStats.completedToday}</div>
              </div>
            </div>

            {/* Tab Navigation */}
            <div className="flex gap-2">
              {[
                { id: 'rankings', label: 'Rankings', icon: TrendingUp },
                { id: 'matches', label: 'Matches', icon: Flame },
                { id: 'stats', label: 'Stats', icon: Target },
              ].map((tab) => (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id as 'rankings' | 'matches' | 'stats')}
                  className={`
                    flex-1 flex items-center justify-center gap-2 py-2.5 px-3 rounded-lg font-semibold text-sm transition-all
                    ${activeTab === tab.id 
                      ? 'bg-gradient-to-r from-red-600 to-red-700 text-white shadow-lg shadow-red-500/30' 
                      : 'bg-white/5 text-gray-400 hover:bg-white/10'
                    }
                  `}
                >
                  <tab.icon size={16} />
                  <span>{tab.label}</span>
                </button>
              ))}
            </div>
          </div>
        </header>

        {/* Main Content */}
        <main className="px-4 py-6 pb-24">
          {/* Medal Divisions Selector - Olympics Style */}
          <section className={`mb-6 transition-all duration-700 ${animateIn ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'}`}>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-bold text-white flex items-center gap-2">
                <Medal size={20} className="text-yellow-400" />
                Medal Divisions
              </h2>
              <div className="text-xs text-gray-400">Select to view rankings</div>
            </div>

            {/* Horizontal Scrollable Divisions */}
            <div className="overflow-x-auto scrollbar-hide -mx-4 px-4">
              <div className="flex gap-3 pb-2">
                {divisions.map(({ division, gradient, glow, border, ring }, index) => (
                  <button
                    key={division}
                    onClick={() => setSelectedDivision(division)}
                    style={{ animationDelay: `${index * 100}ms` }}
                    className={`
                      relative flex-shrink-0 w-32 p-4 rounded-2xl transition-all duration-300
                      ${animateIn ? 'animate-fade-in-up' : 'opacity-0'}
                      ${selectedDivision === division
                        ? `bg-gradient-to-br ${gradient} scale-105 shadow-2xl ${glow}`
                        : `bg-gray-800/50 backdrop-blur-sm border ${border} hover:scale-105 hover:bg-gray-800/70`
                      }
                    `}
                  >
                    {/* Medal Icon */}
                    <div className={`text-5xl mb-2 transition-transform ${selectedDivision === division ? 'scale-110' : ''}`}>
                      {getMedalIcon(division)}
                    </div>
                    
                    {/* Division Name */}
                    <div className={`text-xs font-bold mb-1 ${selectedDivision === division ? 'text-white' : 'text-gray-300'}`}>
                      {getMedalName(division).replace(' Medal', '')}
                    </div>
                    
                    {/* Wager Range */}
                    <div className={`text-[10px] ${selectedDivision === division ? 'text-white/90' : 'text-gray-400'}`}>
                      {getWagerRange(division)}
                    </div>

                    {/* Selection Ring */}
                    {selectedDivision === division && (
                      <div className={`absolute inset-0 rounded-2xl ring-4 ${ring} pointer-events-none animate-pulse`} />
                    )}

                    {/* Active Indicator */}
                    {selectedDivision === division && (
                      <div className="absolute -top-1 -right-1 w-3 h-3 bg-green-500 rounded-full border-2 border-white animate-pulse" />
                    )}
                  </button>
                ))}
              </div>
            </div>
          </section>

          {/* Selected Division Hero Card - NBA Finals Style */}
          <section className={`mb-6 transition-all duration-700 delay-200 ${animateIn ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'}`}>
            <div className={`relative overflow-hidden rounded-3xl bg-gradient-to-br ${selectedDivisionData?.gradient} shadow-2xl ${selectedDivisionData?.glow} border ${selectedDivisionData?.border}`}>
              {/* Animated Background Pattern */}
              <div className="absolute inset-0 opacity-20">
                <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_50%,rgba(255,255,255,0.1),transparent_50%)]" />
              </div>

              <div className="relative p-6">
                {/* Division Header */}
                <div className="flex items-center gap-4 mb-6">
                  <div className="text-7xl drop-shadow-2xl animate-bounce-slow">
                    {getMedalIcon(selectedDivision)}
                  </div>
                  <div className="flex-1">
                    <div className="text-xs font-bold text-white/80 mb-1 uppercase tracking-wider">
                      Division
                    </div>
                    <h2 className="text-3xl font-black text-white drop-shadow-lg mb-1">
                      {getMedalName(selectedDivision)}
                    </h2>
                    <p className="text-base text-white/90 font-semibold">
                      {getWagerRange(selectedDivision)} matches
                    </p>
                  </div>
                </div>

                {/* Division Stats Grid */}
                <div className="grid grid-cols-3 gap-3">
                  <div className="bg-black/20 backdrop-blur-sm rounded-xl p-3 text-center border border-white/20">
                    <div className="text-2xl font-black text-white mb-1">
                      {divisionStats.totalCompetitors}
                    </div>
                    <div className="text-[10px] text-white/80 font-semibold uppercase tracking-wide">
                      Competitors
                    </div>
                  </div>
                  <div className="bg-black/20 backdrop-blur-sm rounded-xl p-3 text-center border border-white/20">
                    <div className="text-2xl font-black text-white mb-1">
                      {divisionStats.totalMatches}
                    </div>
                    <div className="text-[10px] text-white/80 font-semibold uppercase tracking-wide">
                      Matches
                    </div>
                  </div>
                  <div className="bg-black/20 backdrop-blur-sm rounded-xl p-3 text-center border border-white/20">
                    <div className="text-2xl font-black text-white mb-1">
                      ${(divisionStats.totalPrizePool / 1000).toFixed(0)}K
                    </div>
                    <div className="text-[10px] text-white/80 font-semibold uppercase tracking-wide">
                      Prize Pool
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </section>

          {/* Content Based on Active Tab */}
          {activeTab === 'rankings' && (
            <>
              {isLoadingRankings && (
                <p className="mb-4 text-sm text-gray-400" role="status">
                  Loading rankings…
                </p>
              )}
              {!isLoadingRankings && rankedCompetitors.length === 0 && (
                <div
                  className="mb-6 rounded-2xl border border-gray-700/50 bg-gray-800/40 p-8 text-center"
                  role="status"
                >
                  <Trophy className="mx-auto mb-3 text-yellow-500/60" size={40} aria-hidden />
                  <p className="text-base font-semibold text-white">No rankings yet</p>
                  <p className="mt-2 text-sm text-gray-400">
                    Compete in a VS Match to appear on this division leaderboard.
                  </p>
                  <Link
                    href="/medals/create-match"
                    className="mt-4 inline-block min-h-[44px] rounded-full bg-red-600 px-6 py-3 text-sm font-bold text-white hover:bg-red-700"
                  >
                    Create your first match
                  </Link>
                </div>
              )}
              {/* Current Champion - Olympics Podium Style */}
              {rankedCompetitors[0] && (
                <section className={`mb-6 transition-all duration-700 delay-300 ${animateIn ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'}`}>
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-lg font-bold text-white flex items-center gap-2">
                      <Crown className="text-yellow-400 drop-shadow-[0_0_8px_rgba(250,204,21,0.6)]" size={24} />
                      Reigning Champion
                    </h3>
                    <div className="text-xs text-gray-400">
                      {rankedCompetitors[0].defenseCount} defenses
                    </div>
                  </div>

                  <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-yellow-500 via-yellow-600 to-orange-600 shadow-2xl shadow-yellow-500/50 border border-yellow-400/30">
                    {/* Animated Rays */}
                    <div className="absolute inset-0 opacity-30">
                      <div className="absolute inset-0 bg-[conic-gradient(from_0deg,transparent_0deg,rgba(255,255,255,0.3)_45deg,transparent_90deg)] animate-spin-slow" />
                    </div>

                    <div className="relative p-6">
                      <div className="flex items-center gap-4 mb-4">
                        {/* Champion Avatar with Glow */}
                        <div className="relative">
                          <div className="absolute inset-0 bg-yellow-400 rounded-full blur-xl animate-pulse" />
                          <Image
                            src={rankedCompetitors[0].photoURL || '/icons/default-avatar.png'}
                            alt={rankedCompetitors[0].displayName}
                            width={96}
                            height={96}
                            className="relative w-24 h-24 rounded-full border-4 border-white shadow-2xl"
                            unoptimized
                          />
                          <div className="absolute -bottom-2 -right-2 bg-white rounded-full p-2 shadow-xl">
                            <Crown size={20} className="text-yellow-600" />
                          </div>
                        </div>

                        {/* Champion Info */}
                        <div className="flex-1">
                          <div className="flex items-center gap-2 mb-1">
                            <h4 className="text-2xl font-black text-white drop-shadow-lg">
                              {rankedCompetitors[0].displayName}
                            </h4>
                            <Zap size={20} className="text-white animate-pulse" />
                          </div>
                          <div className="flex items-center gap-3 text-white/90 text-sm font-semibold mb-2">
                            <span className="flex items-center gap-1">
                              <Trophy size={14} />
                              {rankedCompetitors[0].defenseCount || 0} defenses
                            </span>
                            <span className="flex items-center gap-1">
                              <Flame size={14} />
                              {rankedCompetitors[0].currentStreak} streak
                            </span>
                          </div>
                          <div className="inline-flex items-center gap-2 bg-black/30 backdrop-blur-sm rounded-full px-3 py-1 border border-white/20">
                            <Star size={14} className="text-yellow-300" />
                            <span className="text-xs font-bold text-white">
                              Next defense in 12 days
                            </span>
                          </div>
                        </div>
                      </div>

                      {/* Champion Stats */}
                      <div className="grid grid-cols-3 gap-3">
                        <div className="bg-black/20 backdrop-blur-sm rounded-xl p-3 text-center border border-white/20">
                          <div className="text-2xl font-black text-white mb-1">
                            {rankedCompetitors[0].wins}
                          </div>
                          <div className="text-[10px] text-white/80 font-semibold uppercase">
                            Wins
                          </div>
                        </div>
                        <div className="bg-black/20 backdrop-blur-sm rounded-xl p-3 text-center border border-white/20">
                          <div className="text-2xl font-black text-white mb-1">
                            {rankedCompetitors[0].losses}
                          </div>
                          <div className="text-[10px] text-white/80 font-semibold uppercase">
                            Losses
                          </div>
                        </div>
                        <div className="bg-black/20 backdrop-blur-sm rounded-xl p-3 text-center border border-white/20">
                          <div className="text-2xl font-black text-white mb-1">
                            {rankedCompetitors[0].winRate.toFixed(0)}%
                          </div>
                          <div className="text-[10px] text-white/80 font-semibold uppercase">
                            Win Rate
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </section>
              )}

              {/* Top 15 Rankings - Professional Leaderboard */}
              <section className={`transition-all duration-700 delay-400 ${animateIn ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'}`}>
                <div className="flex items-center justify-between mb-4">
                  <h3 className="text-lg font-bold text-white flex items-center gap-2">
                    <TrendingUp className="text-blue-400" size={24} />
                    Top 15 Rankings
                  </h3>
                  <div className="text-xs text-gray-400">Live updates</div>
                </div>

                <div className="space-y-2">
                  {rankedCompetitors.map((competitor, index) => (
                    <Link
                      key={competitor.userId}
                      href={`/profile/${competitor.userId}`}
                      style={{ animationDelay: `${index * 50}ms` }}
                      className={`
                        block bg-gray-800/50 backdrop-blur-sm hover:bg-gray-800/70 rounded-2xl p-4 
                        transition-all border border-gray-700/50 hover:border-gray-600/50 hover:scale-[1.02]
                        ${animateIn ? 'animate-fade-in-up' : 'opacity-0'}
                      `}
                    >
                      <div className="flex items-center gap-4">
                        {/* Rank Badge - Olympics Style */}
                        <div className="relative flex-shrink-0">
                          <div
                            className={`
                              w-12 h-12 flex items-center justify-center rounded-full font-black text-lg shadow-lg
                              ${competitor.rank === 1 ? 'bg-gradient-to-br from-yellow-400 to-yellow-600 text-white shadow-yellow-500/50' : ''}
                              ${competitor.rank === 2 ? 'bg-gradient-to-br from-gray-300 to-gray-500 text-white shadow-gray-400/50' : ''}
                              ${competitor.rank === 3 ? 'bg-gradient-to-br from-amber-700 to-amber-900 text-white shadow-amber-600/50' : ''}
                              ${competitor.rank > 3 ? 'bg-gray-700/80 text-gray-300 border-2 border-gray-600' : ''}
                            `}
                          >
                            {competitor.rank}
                          </div>
                          
                          {/* Rank Change Indicator */}
                          {competitor.rankChange !== undefined && competitor.rankChange !== 0 && (
                            <div className={`
                              absolute -bottom-1 -right-1 w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold border-2 border-gray-800
                              ${competitor.rankChange > 0 ? 'bg-green-500 text-white' : 'bg-red-500 text-white'}
                            `}>
                              {competitor.rankChange > 0 ? <ArrowUp size={12} /> : <ArrowDown size={12} />}
                            </div>
                          )}
                        </div>

                        {/* Avatar */}
                        <div className="relative flex-shrink-0">
                          <Image
                            src={competitor.photoURL || '/icons/default-avatar.png'}
                            alt={competitor.displayName}
                            width={56}
                            height={56}
                            className="w-14 h-14 rounded-full border-2 border-gray-600"
                            unoptimized
                          />
                          {competitor.isChampion && (
                            <div className="absolute -top-1 -right-1 bg-yellow-500 rounded-full p-1 shadow-lg">
                              <Crown size={12} className="text-white" />
                            </div>
                          )}
                        </div>

                        {/* Competitor Info */}
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 mb-1">
                            <h4 className="font-bold text-white truncate text-base">
                              {competitor.displayName}
                            </h4>
                            {competitor.currentStreak >= 5 && (
                              <Flame size={14} className="text-orange-500 flex-shrink-0" />
                            )}
                          </div>
                          <div className="flex items-center gap-3 text-xs text-gray-400">
                            <span className="font-semibold">
                              {competitor.wins}W-{competitor.losses}L
                            </span>
                            <span className="text-gray-500">•</span>
                            <span className={`font-semibold ${competitor.winRate >= 80 ? 'text-green-400' : 'text-gray-400'}`}>
                              {competitor.winRate.toFixed(0)}% win rate
                            </span>
                          </div>
                        </div>

                        {/* Stats & Arrow */}
                        <div className="flex items-center gap-3">
                          <div className="text-right">
                            <div className="text-base font-bold text-green-400">
                              ${(competitor.totalWinnings / 1000).toFixed(1)}K
                            </div>
                            <div className="text-[10px] text-gray-400 uppercase font-semibold">
                              Winnings
                            </div>
                          </div>
                          <ChevronRight size={20} className="text-gray-600" />
                        </div>
                      </div>
                    </Link>
                  ))}
                </div>
              </section>
            </>
          )}

          {activeTab === 'matches' && (
            <section className={`transition-all duration-700 ${animateIn ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'}`}>
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold text-white flex items-center gap-2">
                  <Flame className="text-orange-500" size={24} />
                  Recent Matches
                </h3>
                <div className="text-xs text-gray-400">Last 24 hours</div>
              </div>

              <div className="space-y-3">
                {!isLoadingRankings && recentMatches.length === 0 && (
                  <p className="text-sm text-gray-400" role="status">
                    No recent matches yet. Create one to get started.
                  </p>
                )}
                {recentMatches.map((match, index) => (
                  <div
                    key={match.id}
                    style={{ animationDelay: `${index * 100}ms` }}
                    className={`
                      bg-gray-800/50 backdrop-blur-sm rounded-2xl p-4 border border-gray-700/50
                      ${animateIn ? 'animate-fade-in-up' : 'opacity-0'}
                    `}
                  >
                    <div className="flex items-center justify-between mb-3">
                      <div className="flex items-center gap-2">
                        <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
                        <span className="text-xs font-semibold text-gray-400 uppercase">
                          {match.category}
                        </span>
                      </div>
                      <div className="text-xs text-gray-400">
                        {match.hoursAgo}h ago
                      </div>
                    </div>

                    <div className="flex items-center justify-between mb-3">
                      <div className="flex-1">
                        <div className={`font-bold text-white mb-1 ${match.winner === 1 ? 'text-green-400' : ''}`}>
                          {match.player1}
                          {match.winner === 1 && <span className="ml-2">🏆</span>}
                        </div>
                        <div className="text-xs text-gray-400">vs</div>
                        <div className={`font-bold text-white mt-1 ${match.winner === 2 ? 'text-green-400' : ''}`}>
                          {match.player2}
                          {match.winner === 2 && <span className="ml-2">🏆</span>}
                        </div>
                      </div>

                      <div className="text-right">
                        <div className="text-xl font-black text-yellow-400">
                          ${(match.wager / 1000).toFixed(1)}K
                        </div>
                        <div className="text-xs text-gray-400 uppercase font-semibold">
                          Wager
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </section>
          )}

          {activeTab === 'stats' && (
            <section className={`transition-all duration-700 ${animateIn ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'}`}>
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold text-white flex items-center gap-2">
                  <Target className="text-purple-400" size={24} />
                  Division Statistics
                </h3>
              </div>

              <div className="space-y-4">
                {/* Total Stats */}
                <div className="bg-gray-800/50 backdrop-blur-sm rounded-2xl p-6 border border-gray-700/50">
                  <h4 className="text-sm font-bold text-gray-400 uppercase mb-4">
                    Overall Performance
                  </h4>
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <div className="text-3xl font-black text-white mb-1">
                        {divisionStats.totalMatches}
                      </div>
                      <div className="text-xs text-gray-400 uppercase font-semibold">
                        Total Matches
                      </div>
                    </div>
                    <div>
                      <div className="text-3xl font-black text-green-400 mb-1">
                        ${(divisionStats.totalPrizePool / 1000).toFixed(0)}K
                      </div>
                      <div className="text-xs text-gray-400 uppercase font-semibold">
                        Prize Pool
                      </div>
                    </div>
                    <div>
                      <div className="text-3xl font-black text-blue-400 mb-1">
                        ${(divisionStats.avgWager / 1000).toFixed(1)}K
                      </div>
                      <div className="text-xs text-gray-400 uppercase font-semibold">
                        Avg Wager
                      </div>
                    </div>
                    <div>
                      <div className="text-3xl font-black text-purple-400 mb-1">
                        {divisionStats.totalCompetitors}
                      </div>
                      <div className="text-xs text-gray-400 uppercase font-semibold">
                        Competitors
                      </div>
                    </div>
                  </div>
                </div>

                {/* Activity Stats */}
                <div className="bg-gray-800/50 backdrop-blur-sm rounded-2xl p-6 border border-gray-700/50">
                  <h4 className="text-sm font-bold text-gray-400 uppercase mb-4">
                    Today&apos;s Activity
                  </h4>
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <span className="text-sm text-gray-300">Active Matches</span>
                      <span className="text-lg font-bold text-orange-400">
                        {divisionStats.activeMatches}
                      </span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-sm text-gray-300">Completed Today</span>
                      <span className="text-lg font-bold text-green-400">
                        {divisionStats.completedToday}
                      </span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-sm text-gray-300">New Competitors</span>
                      <span className="text-lg font-bold text-blue-400">
                        12
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </section>
          )}

          {/* Challenge CTA - Epic Button */}
          <div className={`mt-8 transition-all duration-700 delay-500 ${animateIn ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'}`}>
            <Link
              href="/medals/create-match"
              className="relative block w-full overflow-hidden rounded-2xl group"
            >
              {/* Animated Background */}
              <div className="absolute inset-0 bg-gradient-to-r from-red-600 via-red-700 to-red-600 bg-[length:200%_100%] animate-gradient-x" />
              
              {/* Glow Effect */}
              <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-1000" />

              <div className="relative py-5 px-6">
                <div className="flex items-center justify-center gap-3">
                  <Trophy size={28} className="text-white drop-shadow-lg" />
                  <span className="text-xl font-black text-white drop-shadow-lg">
                    Create Championship Match
                  </span>
                  <Zap size={28} className="text-yellow-300 drop-shadow-lg animate-pulse" />
                </div>
                <div className="text-center text-white/90 text-sm font-semibold mt-2">
                  Compete for glory • Win real money • Climb the rankings
                </div>
              </div>
            </Link>
          </div>
        </main>
      </div>
    </div>
  );
}

