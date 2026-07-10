// @types/vs-matches.ts

// VS Matches & Championship Medals System Types

import { getMedalDivision as getMedalDivisionFromPolicy } from '../lib/wager-policy';

export interface VersusMatch {
  id: string;
  challengerId: string;
  opponentId: string;
  category: VSMatchCategory;
  wagerAmount: number; // Dollars (display / legacy). Prefer wagerAmountCents for settlement.
  /** Canonical integer cents — mirrors iOS MoneyMath / Firestore amountCents. */
  wagerAmountCents?: number;
  platformFee: number; // Dollars (10% of single-side wager display); prefer platformFeeCents
  platformFeeCents?: number;
  status: VSMatchStatus;
  createdAt: Date;
  expiresAt: Date;
  acceptedAt?: Date;
  completedAt?: Date;
  winnerId?: string;
  loserId?: string;
  judgeId?: string;
  evidenceUrls: string[]; // Video/image proof
  viewCount: number;
  description?: string;
}

export enum VSMatchCategory {
  GAMING = 'gaming',
  VIEWS = 'views',
  LIKES = 'likes',
  COMMENTS = 'comments',
  DONATIONS = 'donations',
  CREATIVE = 'creative',
  COOKING = 'cooking',
  MUSIC = 'music',
  DANCE = 'dance',
  SPORTS = 'sports',
}

export enum VSMatchStatus {
  PENDING = 'pending', // Waiting for opponent to accept
  ACTIVE = 'active', // Match is ongoing
  JUDGING = 'judging', // Waiting for judge decision
  COMPLETED = 'completed', // Winner declared
  CANCELLED = 'cancelled', // Match cancelled
  DECLINED = 'declined', // Opponent declined
  EXPIRED = 'expired', // Match expired
}

// Championship Medals (Olympics-style, NOT UFC belts)
export interface ChampionshipMedal {
  id: string;
  division: MedalDivision;
  holderId: string;
  holderDisplayName: string;
  holderPhotoURL: string | null;
  wonAt: Date;
  defenseCount: number;
  lastDefenseAt?: Date;
  nextDefenseBy: Date; // Must defend within 30 days
  winStreak: number;
  totalWinnings: number;
}

export enum MedalDivision {
  BRONZE = 'bronze', // $1-100
  SILVER = 'silver', // $101-500
  GOLD = 'gold', // $501-1,000
  PLATINUM = 'platinum', // $1,001-5,000
  DIAMOND = 'diamond', // $5,001-10,000
  LEGEND = 'legend', // $10,001+
}

export interface RankedCompetitor {
  userId: string;
  displayName: string;
  photoURL: string | null;
  division: MedalDivision;
  rank: number; // 1-15 (Top 15)
  wins: number;
  losses: number;
  winRate: number;
  totalWagered: number;
  totalWinnings: number;
  currentStreak: number;
  lastMatchDate: Date;
  isChampion: boolean;
  defenseCount?: number; // Title defenses (only for champions)
  rankChange?: number; // Positions gained (+) or lost (-) since last ranking
}

// VS Match Wallet
export interface VSMatchWallet {
  userId: string;
  availableBalance: number; // Available for wagering
  pendingBalance: number; // In escrow for active matches
  totalDeposited: number;
  totalWithdrawn: number;
  totalWon: number;
  totalLost: number;
  createdAt: Date;
  updatedAt: Date;
}

// VS Match Transaction
export interface VSMatchTransaction {
  id: string;
  userId: string;
  type: VSMatchTransactionType;
  amount: number;
  status: VSMatchTransactionStatus;
  matchId?: string;
  stripePaymentIntentId?: string;
  createdAt: Date;
  completedAt?: Date;
  description?: string;
}

export enum VSMatchTransactionType {
  DEPOSIT = 'deposit',
  WITHDRAWAL = 'withdrawal',
  WAGER = 'wager', // Money held in escrow
  WIN = 'win', // Released from escrow to winner
  LOSS = 'loss', // Deducted from escrow
  REFUND = 'refund', // Match cancelled, money returned
  FEE = 'fee', // Platform fee (10%)
}

export enum VSMatchTransactionStatus {
  PENDING = 'pending',
  PROCESSING = 'processing',
  COMPLETED = 'completed',
  FAILED = 'failed',
  CANCELLED = 'cancelled',
}

// Compliance & KYC
export interface ComplianceStatus {
  userId: string;
  isAgeVerified: boolean; // 18+
  kycStatus: KYCStatus;
  kycVerifiedAt?: Date;
  hasAcceptedTerms: boolean;
  termsAcceptedAt?: Date;
  region: string; // e.g., "US", "CA", "UK"
  isRegionAllowed: boolean;
  accountStatus: AccountStatus;
  dailyWagerLimit: number;
  dailyWageredToday: number;
  lastWagerDate: Date;
}

export enum KYCStatus {
  NOT_STARTED = 'not_started',
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
  EXPIRED = 'expired',
}

export enum AccountStatus {
  ACTIVE = 'active',
  SUSPENDED = 'suspended',
  BANNED = 'banned',
  UNDER_REVIEW = 'under_review',
}

// Helper function: Get medal division by wager amount (delegates to wager-policy)
export const getMedalDivision = (wagerAmount: number): MedalDivision =>
  getMedalDivisionFromPolicy(wagerAmount) as MedalDivision;

// Helper function: Get medal icon
export const getMedalIcon = (division: MedalDivision): string => {
  switch (division) {
    case MedalDivision.BRONZE:
      return '🥉';
    case MedalDivision.SILVER:
      return '🥈';
    case MedalDivision.GOLD:
      return '🥇';
    case MedalDivision.PLATINUM:
      return '💎';
    case MedalDivision.DIAMOND:
      return '💠';
    case MedalDivision.LEGEND:
      return '👑';
  }
};

// Helper function: Get medal name
export const getMedalName = (division: MedalDivision): string => {
  switch (division) {
    case MedalDivision.BRONZE:
      return 'Bronze Medal';
    case MedalDivision.SILVER:
      return 'Silver Medal';
    case MedalDivision.GOLD:
      return 'Gold Medal';
    case MedalDivision.PLATINUM:
      return 'Platinum Medal';
    case MedalDivision.DIAMOND:
      return 'Diamond Medal';
    case MedalDivision.LEGEND:
      return 'Legend Medal';
  }
};

// Helper function: Get wager range
export const getWagerRange = (division: MedalDivision): string => {
  switch (division) {
    case MedalDivision.BRONZE:
      return '$1-100';
    case MedalDivision.SILVER:
      return '$101-500';
    case MedalDivision.GOLD:
      return '$501-1K';
    case MedalDivision.PLATINUM:
      return '$1K-5K';
    case MedalDivision.DIAMOND:
      return '$5K-10K';
    case MedalDivision.LEGEND:
      return '$10K+';
  }
};


// Shared wager policy (mirrors iOS WagerPolicy / MoneyMath)
export {
  WAGER_POLICY,
  isOfAge,
  requiresKYC,
  isValidWagerAmount,
  dailyLimitDollars,
  isWithinDailyLimit,
  isRegionAllowed,
  centsFromDollars,
  dollarsFromCents,
  platformFeeCents,
  winnerPayoutCents,
  canWagerClientPreflight,
} from '../lib/wager-policy';
export type { AccountTier as WagerAccountTier } from '../lib/wager-policy';
