'use client';

// Creator Studio - Dashboard

import {
  BarChart3,
  Video,
  DollarSign,
  Users,
  Eye,
  ThumbsUp,
  MessageSquare,
  TrendingUp,
  PlaySquare,
  Settings,
  Upload,
  Bell,
  Award,
} from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';

export default function CreatorStudioPage() {
  // Sample analytics data
  const [analytics] = useState({
    totalViews: 1250000,
    totalSubscribers: 59500,
    totalVideos: 128,
    totalRevenue: 15420.50,
    viewsLast30Days: 485000,
    subscribersLast30Days: 2500,
    revenueLastDay: 320.50,
    averageViewDuration: 8.5, // minutes
    clickThroughRate: 12.5, // percent
    engagementRate: 8.2, // percent
  });

  // Top performing videos
  const [topVideos] = useState([
    {
      id: '1',
      title: 'Amazing Tutorial - Part 1',
      thumbnailURL: 'https://picsum.photos/seed/top1/320/180',
      views: 125000,
      likes: 8500,
      comments: 420,
      revenue: 850.00,
    },
    {
      id: '2',
      title: 'Behind the Scenes',
      thumbnailURL: 'https://picsum.photos/seed/top2/320/180',
      views: 98000,
      likes: 6200,
      comments: 310,
      revenue: 640.00,
    },
    {
      id: '3',
      title: 'Q&A with Fans',
      thumbnailURL: 'https://picsum.photos/seed/top3/320/180',
      views: 75000,
      likes: 5100,
      comments: 890,
      revenue: 520.00,
    },
  ]);

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Mobile-First Container */}
      <div className="max-w-[768px] mx-auto">
        {/* Header */}
        <header className="sticky top-0 z-50 bg-white border-b border-gray-200 px-4 py-4">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <Link href="/" className="p-2 hover:bg-gray-100 rounded-full transition-colors">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="black">
                  <path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z" />
                </svg>
              </Link>
              <div>
                <h1 className="text-xl font-bold text-black">Creator Studio</h1>
                <p className="text-sm text-gray-600">Manage your channel</p>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <button className="p-2 hover:bg-gray-100 rounded-full transition-colors">
                <Bell size={24} className="text-gray-700" />
              </button>
              <button className="p-2 hover:bg-gray-100 rounded-full transition-colors">
                <Settings size={24} className="text-gray-700" />
              </button>
            </div>
          </div>
        </header>

        {/* Main Content */}
        <main className="px-4 py-6 pb-24">
          {/* Quick Actions */}
          <section className="mb-8">
            <div className="grid grid-cols-2 gap-3">
              <Link
                href="/upload"
                className="flex flex-col items-center gap-2 p-4 bg-red-600 text-white rounded-xl hover:bg-red-700 transition-colors shadow-lg"
              >
                <Upload size={28} />
                <span className="text-sm font-bold">Upload Video</span>
              </Link>

              <Link
                href="/studio/analytics"
                className="flex flex-col items-center gap-2 p-4 bg-blue-600 text-white rounded-xl hover:bg-blue-700 transition-colors shadow-lg"
              >
                <BarChart3 size={28} />
                <span className="text-sm font-bold">Analytics</span>
              </Link>

              <Link
                href="/studio/videos"
                className="flex flex-col items-center gap-2 p-4 bg-purple-600 text-white rounded-xl hover:bg-purple-700 transition-colors shadow-lg"
              >
                <Video size={28} />
                <span className="text-sm font-bold">Video Manager</span>
              </Link>

              <Link
                href="/studio/monetization"
                className="flex flex-col items-center gap-2 p-4 bg-green-600 text-white rounded-xl hover:bg-green-700 transition-colors shadow-lg"
              >
                <DollarSign size={28} />
                <span className="text-sm font-bold">Monetization</span>
              </Link>
            </div>
          </section>

          {/* Key Metrics */}
          <section className="mb-8">
            <h2 className="text-xl font-bold text-black mb-4">Channel Overview</h2>
            <div className="grid grid-cols-2 gap-3">
              <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm">
                <div className="flex items-center gap-2 mb-2">
                  <Eye className="text-blue-600" size={20} />
                  <span className="text-sm text-gray-600">Total Views</span>
                </div>
                <p className="text-2xl font-bold text-black">{(analytics.totalViews / 1000000).toFixed(1)}M</p>
                <p className="text-xs text-green-600 mt-1">+{(analytics.viewsLast30Days / 1000).toFixed(0)}K this month</p>
              </div>

              <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm">
                <div className="flex items-center gap-2 mb-2">
                  <Users className="text-red-600" size={20} />
                  <span className="text-sm text-gray-600">Subscribers</span>
                </div>
                <p className="text-2xl font-bold text-black">{(analytics.totalSubscribers / 1000).toFixed(1)}K</p>
                <p className="text-xs text-green-600 mt-1">+{(analytics.subscribersLast30Days / 1000).toFixed(1)}K this month</p>
              </div>

              <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm">
                <div className="flex items-center gap-2 mb-2">
                  <Video className="text-purple-600" size={20} />
                  <span className="text-sm text-gray-600">Total Videos</span>
                </div>
                <p className="text-2xl font-bold text-black">{analytics.totalVideos}</p>
              </div>

              <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm">
                <div className="flex items-center gap-2 mb-2">
                  <DollarSign className="text-green-600" size={20} />
                  <span className="text-sm text-gray-600">Revenue</span>
                </div>
                <p className="text-2xl font-bold text-black">${(analytics.totalRevenue / 1000).toFixed(1)}K</p>
                <p className="text-xs text-green-600 mt-1">${analytics.revenueLastDay.toFixed(2)} today</p>
              </div>
            </div>
          </section>

          {/* Performance Metrics */}
          <section className="mb-8">
            <h2 className="text-xl font-bold text-black mb-4">Performance</h2>
            <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm space-y-4">
              <div>
                <div className="flex justify-between text-sm mb-2">
                  <span className="text-gray-600">Avg. View Duration</span>
                  <span className="font-bold text-black">{analytics.averageViewDuration} min</span>
                </div>
                <div className="h-2 bg-gray-200 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-gradient-to-r from-blue-500 to-blue-600"
                    style={{ width: `${(analytics.averageViewDuration / 15) * 100}%` }}
                  />
                </div>
              </div>

              <div>
                <div className="flex justify-between text-sm mb-2">
                  <span className="text-gray-600">Click-Through Rate</span>
                  <span className="font-bold text-black">{analytics.clickThroughRate}%</span>
                </div>
                <div className="h-2 bg-gray-200 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-gradient-to-r from-green-500 to-green-600"
                    style={{ width: `${(analytics.clickThroughRate / 20) * 100}%` }}
                  />
                </div>
              </div>

              <div>
                <div className="flex justify-between text-sm mb-2">
                  <span className="text-gray-600">Engagement Rate</span>
                  <span className="font-bold text-black">{analytics.engagementRate}%</span>
                </div>
                <div className="h-2 bg-gray-200 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-gradient-to-r from-purple-500 to-purple-600"
                    style={{ width: `${(analytics.engagementRate / 15) * 100}%` }}
                  />
                </div>
              </div>
            </div>
          </section>

          {/* Top Performing Videos */}
          <section>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-bold text-black">Top Videos</h2>
              <Link href="/studio/videos" className="text-sm text-blue-600 font-medium hover:underline">
                See all
              </Link>
            </div>

            <div className="space-y-3">
              {topVideos.map((video, index) => (
                <Link
                  key={video.id}
                  href={`/watch/${video.id}`}
                  className="block bg-white hover:bg-gray-50 p-3 rounded-xl border border-gray-200 shadow-sm transition-all"
                >
                  <div className="flex items-center gap-3">
                    {/* Rank Badge */}
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

                    {/* Thumbnail */}
                    <div className="w-24 h-14 bg-gray-200 rounded overflow-hidden flex-shrink-0">
                      <img
                        src={video.thumbnailURL}
                        alt={video.title}
                        className="w-full h-full object-cover"
                      />
                    </div>

                    {/* Info */}
                    <div className="flex-1 min-w-0">
                      <h3 className="font-bold text-black text-sm line-clamp-1">{video.title}</h3>
                      <div className="flex items-center gap-3 text-xs text-gray-600 mt-1">
                        <span className="flex items-center gap-1">
                          <Eye size={12} />
                          {(video.views / 1000).toFixed(0)}K
                        </span>
                        <span className="flex items-center gap-1">
                          <ThumbsUp size={12} />
                          {(video.likes / 1000).toFixed(1)}K
                        </span>
                        <span className="flex items-center gap-1">
                          <MessageSquare size={12} />
                          {video.comments}
                        </span>
                      </div>
                    </div>

                    {/* Revenue */}
                    <div className="text-right">
                      <p className="text-sm font-bold text-green-600">${video.revenue.toFixed(0)}</p>
                      <p className="text-xs text-gray-600">revenue</p>
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

