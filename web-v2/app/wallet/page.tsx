'use client';

// VS Match Wallet - Manage Your Funds

import { DollarSign, TrendingUp, TrendingDown, Plus, ArrowUpRight, ArrowDownRight, Clock, CheckCircle, XCircle } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';
import {
  VSMatchWallet,
  VSMatchTransaction,
  VSMatchTransactionType,
  VSMatchTransactionStatus,
} from '@/types/vs-matches';

export default function WalletPage() {
  // Sample wallet data
  const [wallet, setWallet] = useState<VSMatchWallet>({
    userId: 'current-user',
    availableBalance: 1250.50,
    pendingBalance: 500.00,
    totalDeposited: 5000.00,
    totalWithdrawn: 2000.00,
    totalWon: 3500.00,
    totalLost: 1500.00,
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  // Sample transactions
  const [transactions] = useState<VSMatchTransaction[]>([
    {
      id: '1',
      userId: 'current-user',
      type: VSMatchTransactionType.WIN,
      amount: 450.00,
      status: VSMatchTransactionStatus.COMPLETED,
      matchId: 'match-123',
      createdAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
      completedAt: new Date(Date.now() - 1 * 60 * 60 * 1000),
      description: 'Won VS Match against Competitor',
    },
    {
      id: '2',
      userId: 'current-user',
      type: VSMatchTransactionType.DEPOSIT,
      amount: 1000.00,
      status: VSMatchTransactionStatus.COMPLETED,
      createdAt: new Date(Date.now() - 24 * 60 * 60 * 1000),
      completedAt: new Date(Date.now() - 23 * 60 * 60 * 1000),
      description: 'Deposit via Stripe',
    },
    {
      id: '3',
      userId: 'current-user',
      type: VSMatchTransactionType.WAGER,
      amount: 500.00,
      status: VSMatchTransactionStatus.PENDING,
      matchId: 'match-456',
      createdAt: new Date(Date.now() - 1 * 60 * 60 * 1000),
      description: 'Wager for VS Match (Gold Medal)',
    },
  ]);

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
          {/* Balance Card */}
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

