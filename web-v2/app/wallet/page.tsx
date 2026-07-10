'use client';

// VS Match Wallet - Manage Your Funds

import { DollarSign, TrendingUp, TrendingDown, Plus, ArrowUpRight, ArrowDownRight, Clock, CheckCircle, XCircle } from 'lucide-react';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import {
  VSMatchWallet,
  VSMatchTransaction,
  VSMatchTransactionType,
  VSMatchTransactionStatus,
} from '@/types/vs-matches';
import { loadVSMatchWallet } from '@/lib/vs-match-wallet';

export default function WalletPage() {
  const [wallet, setWallet] = useState<VSMatchWallet>({
    userId: '',
    availableBalance: 0,
    pendingBalance: 0,
    totalDeposited: 0,
    totalWithdrawn: 0,
    totalWon: 0,
    totalLost: 0,
    createdAt: new Date(),
    updatedAt: new Date(),
  });
  const [transactions, setTransactions] = useState<VSMatchTransaction[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [signedIn, setSignedIn] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setIsLoading(true);
      try {
        const result = await loadVSMatchWallet();
        if (cancelled) return;
        setWallet(result.wallet);
        setTransactions(result.transactions);
        setSignedIn(result.signedIn);
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const getTransactionIcon = (type: VSMatchTransactionType) => {
    switch (type) {
      case VSMatchTransactionType.DEPOSIT:
        return <Plus size={20} className="text-green-500" />;
      case VSMatchTransactionType.WITHDRAWAL:
        return <ArrowDownRight size={20} className="text-red-500" />;
      case VSMatchTransactionType.WIN:
        return <TrendingUp size={20} className="text-green-500" />;
      case VSMatchTransactionType.LOSS:
        return <TrendingDown size={20} className="text-red-500" />;
      case VSMatchTransactionType.WAGER:
        return <Clock size={20} className="text-yellow-500" />;
      case VSMatchTransactionType.REFUND:
        return <ArrowUpRight size={20} className="text-blue-500" />;
      case VSMatchTransactionType.FEE:
        return <DollarSign size={20} className="text-gray-500" />;
    }
  };

  const getStatusIcon = (status: VSMatchTransactionStatus) => {
    switch (status) {
      case VSMatchTransactionStatus.COMPLETED:
        return <CheckCircle size={16} className="text-green-500" />;
      case VSMatchTransactionStatus.PENDING:
      case VSMatchTransactionStatus.PROCESSING:
        return <Clock size={16} className="text-yellow-500" />;
      case VSMatchTransactionStatus.FAILED:
      case VSMatchTransactionStatus.CANCELLED:
        return <XCircle size={16} className="text-red-500" />;
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black text-white">
      {/* Mobile-First Container */}
      <div className="max-w-[768px] mx-auto">
        {/* Header */}
        <header className="sticky top-0 z-50 bg-gray-900/95 backdrop-blur-lg border-b border-gray-700 px-4 py-4">
          <div className="flex items-center gap-3">
            <Link href="/" className="p-2 hover:bg-gray-800 rounded-full transition-colors">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="white">
                <path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z" />
              </svg>
            </Link>
            <DollarSign size={28} className="text-green-500" />
            <div>
              <h1 className="text-2xl font-bold">Wallet</h1>
              <p className="text-sm text-gray-400">Manage your VS Match funds</p>
            </div>
          </div>
        </header>

        {/* Main Content */}
        <main className="px-4 py-6 pb-24">
          {!signedIn && !isLoading && (
            <p className="mb-4 text-sm text-yellow-300" role="status">
              Sign in to view your live VS Match wallet. Balances are never credited from the client.
            </p>
          )}
          {isLoading && (
            <section className="mb-8 animate-pulse" role="status" aria-label="Loading wallet">
              <div className="rounded-2xl bg-gray-800 p-6">
                <div className="mb-4 h-4 w-32 rounded bg-gray-700" />
                <div className="mb-6 h-12 w-48 rounded bg-gray-700" />
                <div className="grid grid-cols-2 gap-3">
                  <div className="h-12 rounded-xl bg-gray-700" />
                  <div className="h-12 rounded-xl bg-gray-700" />
                </div>
              </div>
              <p className="mt-3 text-sm text-gray-400">Loading wallet…</p>
            </section>
          )}
          {/* Balance Card */}
          {!isLoading && (
          <section className="mb-8">
            <div className="bg-gradient-to-br from-green-600 via-green-700 to-emerald-800 p-6 rounded-2xl shadow-2xl">
              <div className="mb-4">
                <p className="text-green-100 text-sm mb-1">Available Balance</p>
                <h2 className="text-5xl font-bold text-white">
                  ${wallet.availableBalance.toFixed(2)}
                </h2>
              </div>

              <div className="flex items-center gap-4 mb-6">
                <div className="flex-1 bg-white/10 backdrop-blur-lg p-3 rounded-xl">
                  <p className="text-green-100 text-xs mb-1">Pending</p>
                  <p className="text-white font-bold">${wallet.pendingBalance.toFixed(2)}</p>
                </div>
                <div className="flex-1 bg-white/10 backdrop-blur-lg p-3 rounded-xl">
                  <p className="text-green-100 text-xs mb-1">Total Won</p>
                  <p className="text-white font-bold">${wallet.totalWon.toFixed(2)}</p>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <Link
                  href="/wallet/deposit"
                  className="flex items-center justify-center gap-2 py-3 bg-white text-green-700 font-bold rounded-xl hover:bg-green-50 transition-colors"
                >
                  <Plus size={20} />
                  <span>Deposit</span>
                </Link>
                <Link
                  href="/wallet/withdraw"
                  className="flex items-center justify-center gap-2 py-3 bg-white/10 backdrop-blur-lg text-white font-bold rounded-xl hover:bg-white/20 transition-colors"
                >
                  <ArrowDownRight size={20} />
                  <span>Withdraw</span>
                </Link>
              </div>
            </div>
          </section>
          )}

          {/* Stats Overview */}
          <section className="mb-8">
            <h3 className="text-xl font-bold mb-4">Overview</h3>
            <div className="grid grid-cols-2 gap-3">
              <div className="bg-gray-800 p-4 rounded-xl">
                <div className="flex items-center gap-2 mb-2">
                  <TrendingUp className="text-green-500" size={20} />
                  <span className="text-sm text-gray-400">Total Deposited</span>
                </div>
                <p className="text-2xl font-bold text-white">${wallet.totalDeposited.toFixed(2)}</p>
              </div>

              <div className="bg-gray-800 p-4 rounded-xl">
                <div className="flex items-center gap-2 mb-2">
                  <TrendingDown className="text-red-500" size={20} />
                  <span className="text-sm text-gray-400">Total Withdrawn</span>
                </div>
                <p className="text-2xl font-bold text-white">${wallet.totalWithdrawn.toFixed(2)}</p>
              </div>

              <div className="bg-gray-800 p-4 rounded-xl">
                <div className="flex items-center gap-2 mb-2">
                  <CheckCircle className="text-green-500" size={20} />
                  <span className="text-sm text-gray-400">Total Won</span>
                </div>
                <p className="text-2xl font-bold text-green-500">${wallet.totalWon.toFixed(2)}</p>
              </div>

              <div className="bg-gray-800 p-4 rounded-xl">
                <div className="flex items-center gap-2 mb-2">
                  <XCircle className="text-red-500" size={20} />
                  <span className="text-sm text-gray-400">Total Lost</span>
                </div>
                <p className="text-2xl font-bold text-red-500">${wallet.totalLost.toFixed(2)}</p>
              </div>
            </div>
          </section>

          {/* Transaction History */}
          <section>
            <h3 className="text-xl font-bold mb-4">Transaction History</h3>
            <div className="space-y-3">
              {transactions.map((transaction) => (
                <div
                  key={transaction.id}
                  className="bg-gray-800 hover:bg-gray-700 p-4 rounded-xl transition-all"
                >
                  <div className="flex items-center gap-4">
                    {/* Icon */}
                    <div className="w-10 h-10 bg-gray-700 rounded-full flex items-center justify-center">
                      {getTransactionIcon(transaction.type)}
                    </div>

                    {/* Info */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-1">
                        <h4 className="font-bold text-white capitalize">
                          {transaction.type.replace('_', ' ')}
                        </h4>
                        {getStatusIcon(transaction.status)}
                      </div>
                      <p className="text-sm text-gray-400 truncate">
                        {transaction.description}
                      </p>
                      <p className="text-xs text-gray-500 mt-1">
                        {transaction.createdAt.toLocaleString()}
                      </p>
                    </div>

                    {/* Amount */}
                    <div className="text-right">
                      <div
                        className={`text-lg font-bold ${
                          [VSMatchTransactionType.DEPOSIT, VSMatchTransactionType.WIN, VSMatchTransactionType.REFUND].includes(
                            transaction.type
                          )
                            ? 'text-green-500'
                            : 'text-red-500'
                        }`}
                      >
                        {[VSMatchTransactionType.DEPOSIT, VSMatchTransactionType.WIN, VSMatchTransactionType.REFUND].includes(
                          transaction.type
                        )
                          ? '+'
                          : '-'}
                        ${transaction.amount.toFixed(2)}
                      </div>
                      <div className="text-xs text-gray-400 capitalize">
                        {transaction.status.replace('_', ' ')}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            {/* View All Button */}
            <Link
              href="/wallet/transactions"
              className="block mt-4 py-3 text-center text-sm text-gray-400 hover:text-white transition-colors"
            >
              View all transactions →
            </Link>
          </section>
        </main>
      </div>
    </div>
  );
}

