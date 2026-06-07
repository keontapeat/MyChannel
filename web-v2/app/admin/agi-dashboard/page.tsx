'use client';

// AGI Agent Dashboard - Admin Only

import {
  Bot,
  DollarSign,
  TrendingUp,
  Shield,
  BarChart3,
  Zap,
  CheckCircle,
  XCircle,
  Clock,
  AlertTriangle,
  Play,
  Pause,
  RefreshCw,
} from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';

// Agent categories
type AgentCategory = 'money-maker' | 'growth' | 'gaming' | 'safety' | 'analytics' | 'scale';

interface AGIAgent {
  id: string;
  name: string;
  category: AgentCategory;
  isActive: boolean;
  status: 'running' | 'stopped' | 'error' | 'paused';
  metrics: {
    successCount: number;
    errorCount: number;
    totalRuns: number;
    revenue?: number;
    impressions?: number;
    avgResponseTime: number; // milliseconds
  };
  lastRunTime?: Date;
}

export default function AGIDashboardPage() {
  // All 30 AGI agents
  const [agents, setAgents] = useState<AGIAgent[]>(() => [
    // Money Maker Agents (5)
    {
      id: 'dynamic-pricing',
      name: 'Dynamic Pricing Agent',
      category: 'money-maker',
      isActive: true,
      status: 'running',
      metrics: { successCount: 1250, errorCount: 12, totalRuns: 1262, revenue: 15420.50, avgResponseTime: 120 },
      lastRunTime: new Date(Date.now() - 5 * 60 * 1000),
    },
    {
      id: 'ad-placement',
      name: 'Ad Placement Agent',
      category: 'money-maker',
      isActive: true,
      status: 'running',
      metrics: { successCount: 8500, errorCount: 85, totalRuns: 8585, impressions: 1250000, avgResponseTime: 80 },
      lastRunTime: new Date(Date.now() - 2 * 60 * 1000),
    },
    {
      id: 'fraud-detection',
      name: 'Fraud Detection Agent',
      category: 'money-maker',
      isActive: true,
      status: 'running',
      metrics: { successCount: 3200, errorCount: 5, totalRuns: 3205, avgResponseTime: 95 },
      lastRunTime: new Date(Date.now() - 10 * 60 * 1000),
    },
    {
      id: 'upsell',
      name: 'Upsell Agent',
      category: 'money-maker',
      isActive: true,
      status: 'running',
      metrics: { successCount: 1850, errorCount: 20, totalRuns: 1870, revenue: 8250.00, avgResponseTime: 110 },
      lastRunTime: new Date(Date.now() - 8 * 60 * 1000),
    },
    {
      id: 'match-fairness',
      name: 'Match Fairness Agent',
      category: 'money-maker',
      isActive: true,
      status: 'running',
      metrics: { successCount: 520, errorCount: 2, totalRuns: 522, avgResponseTime: 150 },
      lastRunTime: new Date(Date.now() - 15 * 60 * 1000),
    },

    // Growth Agents (4)
    {
      id: 'viral-prediction',
      name: 'Viral Prediction Engine',
      category: 'growth',
      isActive: true,
      status: 'running',
      metrics: { successCount: 2100, errorCount: 18, totalRuns: 2118, avgResponseTime: 200 },
      lastRunTime: new Date(Date.now() - 30 * 60 * 1000),
    },
    {
      id: 'retention-optimizer',
      name: 'Retention Optimizer',
      category: 'growth',
      isActive: true,
      status: 'running',
      metrics: { successCount: 1500, errorCount: 10, totalRuns: 1510, avgResponseTime: 180 },
      lastRunTime: new Date(Date.now() - 20 * 60 * 1000),
    },
    {
      id: 'seo-discovery',
      name: 'SEO Discovery Booster',
      category: 'growth',
      isActive: true,
      status: 'running',
      metrics: { successCount: 980, errorCount: 8, totalRuns: 988, avgResponseTime: 250 },
      lastRunTime: new Date(Date.now() - 45 * 60 * 1000),
    },
    {
      id: 'thumbnail-ab',
      name: 'Thumbnail A/B Testing',
      category: 'growth',
      isActive: false,
      status: 'stopped',
      metrics: { successCount: 520, errorCount: 5, totalRuns: 525, avgResponseTime: 150 },
      lastRunTime: new Date(Date.now() - 120 * 60 * 1000),
    },

    // Gaming Agents (5)
    {
      id: 'match-orchestrator',
      name: 'Match Orchestrator',
      category: 'gaming',
      isActive: true,
      status: 'running',
      metrics: { successCount: 850, errorCount: 6, totalRuns: 856, avgResponseTime: 140 },
      lastRunTime: new Date(Date.now() - 3 * 60 * 1000),
    },
    {
      id: 'prize-pool-manager',
      name: 'Prize Pool Manager',
      category: 'gaming',
      isActive: true,
      status: 'running',
      metrics: { successCount: 420, errorCount: 3, totalRuns: 423, revenue: 25000.00, avgResponseTime: 100 },
      lastRunTime: new Date(Date.now() - 10 * 60 * 1000),
    },
    {
      id: 'anti-cheat',
      name: 'Anti-Cheat Guardian',
      category: 'gaming',
      isActive: true,
      status: 'running',
      metrics: { successCount: 1200, errorCount: 1, totalRuns: 1201, avgResponseTime: 90 },
      lastRunTime: new Date(Date.now() - 5 * 60 * 1000),
    },
    {
      id: 'tournament-scheduler',
      name: 'Tournament Scheduler',
      category: 'gaming',
      isActive: true,
      status: 'running',
      metrics: { successCount: 180, errorCount: 2, totalRuns: 182, avgResponseTime: 120 },
      lastRunTime: new Date(Date.now() - 30 * 60 * 1000),
    },
    {
      id: 'leaderboard-calculator',
      name: 'Leaderboard Calculator',
      category: 'gaming',
      isActive: true,
      status: 'running',
      metrics: { successCount: 650, errorCount: 4, totalRuns: 654, avgResponseTime: 110 },
      lastRunTime: new Date(Date.now() - 8 * 60 * 1000),
    },

    // Safety Agents (5)
    {
      id: 'content-moderation',
      name: 'Content Moderation AI',
      category: 'safety',
      isActive: true,
      status: 'running',
      metrics: { successCount: 5200, errorCount: 25, totalRuns: 5225, avgResponseTime: 180 },
      lastRunTime: new Date(Date.now() - 1 * 60 * 1000),
    },
    {
      id: 'copyright-protector',
      name: 'Copyright Protector',
      category: 'safety',
      isActive: true,
      status: 'running',
      metrics: { successCount: 1500, errorCount: 10, totalRuns: 1510, avgResponseTime: 200 },
      lastRunTime: new Date(Date.now() - 15 * 60 * 1000),
    },
    {
      id: 'spam-destroyer',
      name: 'Spam Destroyer',
      category: 'safety',
      isActive: true,
      status: 'running',
      metrics: { successCount: 3800, errorCount: 18, totalRuns: 3818, avgResponseTime: 85 },
      lastRunTime: new Date(Date.now() - 2 * 60 * 1000),
    },
    {
      id: 'toxicity-filter',
      name: 'Toxicity Filter',
      category: 'safety',
      isActive: true,
      status: 'running',
      metrics: { successCount: 2100, errorCount: 12, totalRuns: 2112, avgResponseTime: 95 },
      lastRunTime: new Date(Date.now() - 5 * 60 * 1000),
    },
    {
      id: 'report-handler',
      name: 'Realtime Report Handler',
      category: 'safety',
      isActive: true,
      status: 'running',
      metrics: { successCount: 850, errorCount: 6, totalRuns: 856, avgResponseTime: 120 },
      lastRunTime: new Date(Date.now() - 10 * 60 * 1000),
    },

    // Analytics Agents (5)
    {
      id: 'creator-analytics',
      name: 'Creator Analytics Pro',
      category: 'analytics',
      isActive: true,
      status: 'running',
      metrics: { successCount: 1200, errorCount: 8, totalRuns: 1208, avgResponseTime: 220 },
      lastRunTime: new Date(Date.now() - 20 * 60 * 1000),
    },
    {
      id: 'audience-insights',
      name: 'Audience Insights Agent',
      category: 'analytics',
      isActive: true,
      status: 'running',
      metrics: { successCount: 980, errorCount: 5, totalRuns: 985, avgResponseTime: 180 },
      lastRunTime: new Date(Date.now() - 25 * 60 * 1000),
    },
    {
      id: 'revenue-attribution',
      name: 'Revenue Attribution AI',
      category: 'analytics',
      isActive: true,
      status: 'running',
      metrics: { successCount: 720, errorCount: 4, totalRuns: 724, avgResponseTime: 240 },
      lastRunTime: new Date(Date.now() - 30 * 60 * 1000),
    },
    {
      id: 'trend-forecaster',
      name: 'Trend Forecaster',
      category: 'analytics',
      isActive: true,
      status: 'running',
      metrics: { successCount: 520, errorCount: 3, totalRuns: 523, avgResponseTime: 300 },
      lastRunTime: new Date(Date.now() - 40 * 60 * 1000),
    },
    {
      id: 'competitor-intelligence',
      name: 'Competitor Intelligence',
      category: 'analytics',
      isActive: false,
      status: 'stopped',
      metrics: { successCount: 180, errorCount: 2, totalRuns: 182, avgResponseTime: 280 },
      lastRunTime: new Date(Date.now() - 120 * 60 * 1000),
    },

    // Scale Agents (6)
    {
      id: 'cdn-optimizer',
      name: 'CDN Optimizer',
      category: 'scale',
      isActive: true,
      status: 'running',
      metrics: { successCount: 2500, errorCount: 15, totalRuns: 2515, avgResponseTime: 150 },
      lastRunTime: new Date(Date.now() - 10 * 60 * 1000),
    },
    {
      id: 'db-performance',
      name: 'Database Performance Monitor',
      category: 'scale',
      isActive: true,
      status: 'running',
      metrics: { successCount: 1800, errorCount: 10, totalRuns: 1810, avgResponseTime: 120 },
      lastRunTime: new Date(Date.now() - 5 * 60 * 1000),
    },
    {
      id: 'auto-scaler',
      name: 'Auto Scaler',
      category: 'scale',
      isActive: true,
      status: 'running',
      metrics: { successCount: 950, errorCount: 5, totalRuns: 955, avgResponseTime: 100 },
      lastRunTime: new Date(Date.now() - 15 * 60 * 1000),
    },
    {
      id: 'bandwidth-manager',
      name: 'Bandwidth Manager',
      category: 'scale',
      isActive: true,
      status: 'running',
      metrics: { successCount: 1200, errorCount: 8, totalRuns: 1208, avgResponseTime: 110 },
      lastRunTime: new Date(Date.now() - 12 * 60 * 1000),
    },
    {
      id: 'cache-optimizer',
      name: 'Cache Optimizer',
      category: 'scale',
      isActive: true,
      status: 'running',
      metrics: { successCount: 3200, errorCount: 20, totalRuns: 3220, avgResponseTime: 80 },
      lastRunTime: new Date(Date.now() - 3 * 60 * 1000),
    },
    {
      id: 'load-balancer',
      name: 'Load Balancer',
      category: 'scale',
      isActive: true,
      status: 'running',
      metrics: { successCount: 4500, errorCount: 25, totalRuns: 4525, avgResponseTime: 90 },
      lastRunTime: new Date(Date.now() - 2 * 60 * 1000),
    },
  ]);

  const [selectedCategory, setSelectedCategory] = useState<AgentCategory | 'all'>('all');

  const categories: { value: AgentCategory | 'all'; label: string; icon: typeof Bot; color: string }[] = [
    { value: 'all', label: 'All', icon: Bot, color: 'from-gray-700 to-gray-900' },
    { value: 'money-maker', label: 'Money Maker', icon: DollarSign, color: 'from-green-600 to-green-800' },
    { value: 'growth', label: 'Growth', icon: TrendingUp, color: 'from-blue-600 to-blue-800' },
    { value: 'gaming', label: 'Gaming', icon: Zap, color: 'from-purple-600 to-purple-800' },
    { value: 'safety', label: 'Safety', icon: Shield, color: 'from-red-600 to-red-800' },
    { value: 'analytics', label: 'Analytics', icon: BarChart3, color: 'from-yellow-600 to-yellow-800' },
    { value: 'scale', label: 'Scale', icon: RefreshCw, color: 'from-cyan-600 to-cyan-800' },
  ];

  const filteredAgents = agents.filter((agent) => selectedCategory === 'all' || agent.category === selectedCategory);

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'running':
        return 'bg-green-100 text-green-700';
      case 'stopped':
        return 'bg-gray-100 text-gray-700';
      case 'error':
        return 'bg-red-100 text-red-700';
      case 'paused':
        return 'bg-yellow-100 text-yellow-700';
      default:
        return 'bg-gray-100 text-gray-700';
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'running':
        return <CheckCircle size={16} className="text-green-600" />;
      case 'stopped':
        return <XCircle size={16} className="text-gray-400" />;
      case 'error':
        return <AlertTriangle size={16} className="text-red-600" />;
      case 'paused':
        return <Clock size={16} className="text-yellow-600" />;
      default:
        return null;
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black text-white">
      {/* Mobile-First Container */}
      <div className="max-w-[768px] mx-auto">
        {/* Header */}
        <header className="sticky top-0 z-50 bg-gray-900/95 backdrop-blur-lg border-b border-gray-700 px-4 py-4">
          <div className="flex items-center gap-3 mb-4">
            <Link href="/" className="p-2 hover:bg-gray-800 rounded-full transition-colors">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="white">
                <path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z" />
              </svg>
            </Link>
            <Bot size={28} className="text-purple-500" />
            <div>
              <h1 className="text-2xl font-bold">AGI Agent Dashboard</h1>
              <p className="text-sm text-gray-400">
                {agents.filter((a) => a.isActive).length} / {agents.length} agents active
              </p>
            </div>
          </div>

          {/* Category Filter */}
          <div className="flex gap-2 overflow-x-auto scrollbar-hide">
            {categories.map((category) => {
              const Icon = category.icon;
              return (
                <button
                  key={category.value}
                  onClick={() => setSelectedCategory(category.value)}
                  className={`
                    flex items-center gap-2 px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-all
                    ${
                      selectedCategory === category.value
                        ? `bg-gradient-to-r ${category.color} text-white scale-105`
                        : 'bg-gray-800 text-gray-300 hover:bg-gray-700'
                    }
                  `}
                >
                  <Icon size={16} />
                  <span>{category.label}</span>
                </button>
              );
            })}
          </div>
        </header>

        {/* Main Content */}
        <main className="px-4 py-6 pb-24">
          {/* Agent Cards */}
          <div className="space-y-3">
            {filteredAgents.map((agent) => (
              <div key={agent.id} className="bg-gray-800 hover:bg-gray-750 p-4 rounded-xl transition-all">
                <div className="flex items-start justify-between mb-3">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="font-bold text-white">{agent.name}</h3>
                      {getStatusIcon(agent.status)}
                    </div>
                    <span
                      className={`inline-block text-xs px-2 py-1 rounded-full font-medium capitalize ${getStatusColor(
                        agent.status
                      )}`}
                    >
                      {agent.status}
                    </span>
                  </div>

                  <div className="flex gap-2">
                    {agent.isActive ? (
                      <button className="p-2 hover:bg-gray-700 rounded-lg transition-colors">
                        <Pause size={18} className="text-yellow-500" />
                      </button>
                    ) : (
                      <button className="p-2 hover:bg-gray-700 rounded-lg transition-colors">
                        <Play size={18} className="text-green-500" />
                      </button>
                    )}
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-3 text-center">
                  <div>
                    <p className="text-lg font-bold text-white">{agent.metrics.successCount}</p>
                    <p className="text-xs text-gray-400">Success</p>
                  </div>
                  <div>
                    <p className="text-lg font-bold text-red-500">{agent.metrics.errorCount}</p>
                    <p className="text-xs text-gray-400">Errors</p>
                  </div>
                  <div>
                    <p className="text-lg font-bold text-white">{agent.metrics.avgResponseTime}ms</p>
                    <p className="text-xs text-gray-400">Avg Time</p>
                  </div>
                </div>

                {agent.metrics.revenue && (
                  <div className="mt-3 pt-3 border-t border-gray-700">
                    <div className="flex items-center justify-between">
                      <span className="text-sm text-gray-400">Revenue Generated</span>
                      <span className="text-lg font-bold text-green-500">${agent.metrics.revenue.toFixed(2)}</span>
                    </div>
                  </div>
                )}

                {agent.lastRunTime && (
                  <p className="text-xs text-gray-500 mt-2">
                    Last run: {new Date(agent.lastRunTime).toLocaleTimeString()}
                  </p>
                )}
              </div>
            ))}
          </div>
        </main>
      </div>
    </div>
  );
}

