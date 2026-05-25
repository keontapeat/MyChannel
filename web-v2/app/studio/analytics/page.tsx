'use client';

// Creator Studio - Analytics

import { BarChart3, TrendingUp, Eye, Clock, Users, ThumbsUp, Share2, Calendar } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';

export default function AnalyticsPage() {
  const [timeRange, setTimeRange] = useState<'7d' | '30d' | '90d' | '1y'>('30d');

  // Sample analytics data
  const [analytics] = useState({
    views: {
      total: 485000,
      change: +12.5,
      daily: [35000, 38000, 42000, 39000, 45000, 48000, 52000],
    },
    watchTime: {
      total: 68500, // hours
      change: +8.2,
      daily: [4500, 4800, 5200, 5000, 5600, 5900, 6200],
    },
    subscribers: {
      total: 2500,
      change: +15.3,
      daily: [180, 220, 195, 240, 280, 310, 350],
    },
    revenue: {
      total: 8420.50,
      change: +22.1,
      daily: [580, 620, 690, 650, 720, 810, 890],
    },
    topCountries: [
      { country: 'United States', views: 185000, percentage: 38.1 },
      { country: 'United Kingdom', views: 72500, percentage: 14.9 },
      { country: 'Canada', views: 58200, percentage: 12.0 },
      { country: 'Australia', views: 43650, percentage: 9.0 },
      { country: 'Germany', views: 29100, percentage: 6.0 },
    ],
    topVideos: [
      {
        id: '1',
        title: 'Amazing Tutorial - Part 1',
        views: 125000,
        avgViewDuration: 8.5,
        impressionCTR: 12.8,
      },
      {
        id: '2',
        title: 'Behind the Scenes',
        views: 98000,
        avgViewDuration: 7.2,
        impressionCTR: 10.5,
      },
      {
        id: '3',
        title: 'Q&A with Fans',
        views: 75000,
        avgViewDuration: 11.3,
        impressionCTR: 9.8,
      },
    ],
  });

  const timeRangeLabels = {
    '7d': 'Last 7 days',
    '30d': 'Last 30 days',
    '90d': 'Last 90 days',
    '1y': 'Last year',
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Mobile-First Container */}
      <div className="max-w-[768px] mx-auto">
        {/* Header */}
        <header className="sticky top-0 z-50 bg-white border-b border-gray-200 px-4 py-4">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <Link href="/studio" className="p-2 hover:bg-gray-100 rounded-full transition-colors">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="black">
                  <path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z" />
                </svg>
              </Link>
              <BarChart3 size={28} className="text-blue-600" />
              <div>
                <h1 className="text-xl font-bold text-black">Analytics</h1>
                <p className="text-sm text-gray-600">Channel insights</p>
              </div>
            </div>
          </div>

          {/* Time Range Selector */}
          <div className="flex gap-2 overflow-x-auto scrollbar-hide">
            {(['7d', '30d', '90d', '1y'] as const).map((range) => (
              <button
                key={range}
                onClick={() => setTimeRange(range)}
                className={`px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-all ${
                  timeRange === range
                    ? 'bg-blue-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                {timeRangeLabels[range]}
              </button>
            ))}
          </div>
        </header>

        {/* Main Content */}
        <main className="px-4 py-6 pb-24">
          {/* Key Metrics Cards */}
          <section className="mb-8">
            <div className="grid grid-cols-2 gap-3">
              <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm">
                <div className="flex items-center gap-2 mb-2">
                  <Eye className="text-blue-600" size={20} />
                  <span className="text-sm text-gray-600">Views</span>
                </div>
                <p className="text-2xl font-bold text-black">{(analytics.views.total / 1000).toFixed(0)}K</p>
                <p className="text-xs text-green-600 mt-1">
                  ↑ {analytics.views.change}% vs previous period
                </p>
              </div>

              <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm">
                <div className="flex items-center gap-2 mb-2">
                  <Clock className="text-purple-600" size={20} />
                  <span className="text-sm text-gray-600">Watch Time</span>
                </div>
                <p className="text-2xl font-bold text-black">{(analytics.watchTime.total / 1000).toFixed(1)}K hrs</p>
                <p className="text-xs text-green-600 mt-1">
                  ↑ {analytics.watchTime.change}% vs previous period
                </p>
              </div>

              <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm">
                <div className="flex items-center gap-2 mb-2">
                  <Users className="text-red-600" size={20} />
                  <span className="text-sm text-gray-600">Subscribers</span>
                </div>
                <p className="text-2xl font-bold text-black">+{analytics.subscribers.total}</p>
                <p className="text-xs text-green-600 mt-1">
                  ↑ {analytics.subscribers.change}% vs previous period
                </p>
              </div>

              <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm">
                <div className="flex items-center gap-2 mb-2">
                  <TrendingUp className="text-green-600" size={20} />
                  <span className="text-sm text-gray-600">Revenue</span>
                </div>
                <p className="text-2xl font-bold text-black">${(analytics.revenue.total / 1000).toFixed(1)}K</p>
                <p className="text-xs text-green-600 mt-1">
                  ↑ {analytics.revenue.change}% vs previous period
                </p>
              </div>
            </div>
          </section>

          {/* Views Chart */}
          <section className="mb-8">
            <h2 className="text-lg font-bold text-black mb-4">Views Over Time</h2>
            <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm">
              <div className="flex items-end justify-between h-32 gap-1">
                {analytics.views.daily.map((views, index) => {
                  const maxViews = Math.max(...analytics.views.daily);
                  const heightPercent = (views / maxViews) * 100;

                  return (
                    <div key={index} className="flex-1 flex flex-col items-center">
                      <div
                        className="w-full bg-gradient-to-t from-blue-500 to-blue-600 rounded-t transition-all hover:from-blue-600 hover:to-blue-700 cursor-pointer"
                        style={{ height: `${heightPercent}%` }}
                        title={`${(views / 1000).toFixed(0)}K views`}
                      />
                      <span className="text-xs text-gray-500 mt-1">
                        {index === 0 ? 'Mon' : index === 1 ? 'Tue' : index === 2 ? 'Wed' : index === 3 ? 'Thu' : index === 4 ? 'Fri' : index === 5 ? 'Sat' : 'Sun'}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          </section>

          {/* Top Countries */}
          <section className="mb-8">
            <h2 className="text-lg font-bold text-black mb-4">Top Countries</h2>
            <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm space-y-3">
              {analytics.topCountries.map((country, index) => (
                <div key={country.country}>
                  <div className="flex justify-between text-sm mb-2">
                    <span className="font-medium text-black">{country.country}</span>
                    <span className="text-gray-600">{country.percentage}%</span>
                  </div>
                  <div className="h-2 bg-gray-200 rounded-full overflow-hidden">
                    <div
                      className={`h-full transition-all ${
                        index === 0 ? 'bg-gradient-to-r from-blue-500 to-blue-600' :
                        index === 1 ? 'bg-gradient-to-r from-purple-500 to-purple-600' :
                        index === 2 ? 'bg-gradient-to-r from-green-500 to-green-600' :
                        index === 3 ? 'bg-gradient-to-r from-yellow-500 to-yellow-600' :
                        'bg-gradient-to-r from-red-500 to-red-600'
                      }`}
                      style={{ width: `${country.percentage}%` }}
                    />
                  </div>
                  <p className="text-xs text-gray-500 mt-1">
                    {(country.views / 1000).toFixed(1)}K views
                  </p>
                </div>
              ))}
            </div>
          </section>

          {/* Top Performing Videos */}
          <section>
            <h2 className="text-lg font-bold text-black mb-4">Top Videos</h2>
            <div className="space-y-3">
              {analytics.topVideos.map((video, index) => (
                <Link
                  key={video.id}
                  href={`/watch/${video.id}`}
                  className="block bg-white hover:bg-gray-50 p-4 rounded-xl border border-gray-200 shadow-sm transition-all"
                >
                  <div className="flex items-center gap-2 mb-3">
                    <div
                      className={`
                      w-8 h-8 flex items-center justify-center rounded-full font-bold text-sm
                      ${index === 0 ? 'bg-gradient-to-br from-yellow-400 to-yellow-600 text-white' : ''}
                      ${index === 1 ? 'bg-gradient-to-br from-gray-300 to-gray-500 text-white' : ''}
                      ${index === 2 ? 'bg-gradient-to-br from-amber-700 to-amber-900 text-white' : ''}
                    `}
                    >
                      {index + 1}
                    </div>
                    <h3 className="font-bold text-black flex-1 line-clamp-1">{video.title}</h3>
                  </div>

                  <div className="grid grid-cols-3 gap-3 text-center">
                    <div>
                      <p className="text-lg font-bold text-black">{(video.views / 1000).toFixed(0)}K</p>
                      <p className="text-xs text-gray-600">Views</p>
                    </div>
                    <div>
                      <p className="text-lg font-bold text-black">{video.avgViewDuration} min</p>
                      <p className="text-xs text-gray-600">Avg Duration</p>
                    </div>
                    <div>
                      <p className="text-lg font-bold text-black">{video.impressionCTR}%</p>
                      <p className="text-xs text-gray-600">CTR</p>
                    </div>
                  </div>
                </Link>
              ))}
            </div>
          </section>
        </main>
      </div>
    </div>
  );
}

