'use client';

// Search & Discovery Page

import { Search, Filter, TrendingUp, Clock, Users, Video as VideoIcon } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';

export default function SearchPage() {
  const [searchQuery, setSearchQuery] = useState('');
  const [activeFilter, setActiveFilter] = useState<'all' | 'videos' | 'channels' | 'playlists'>('all');

  // Sample search results
  const searchResults = {
    videos: Array.from({ length: 8 }).map((_, i) => ({
      id: `video-${i + 1}`,
      title: `Search Result Video ${i + 1}`,
      thumbnailURL: `https://picsum.photos/seed/search${i}/640/360`,
      channel: 'Creator Name',
      views: Math.floor(Math.random() * 100000 + 10000),
      uploadDate: new Date(Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000),
      duration: `${Math.floor(Math.random() * 10 + 5)}:${Math.floor(Math.random() * 60).toString().padStart(2, '0')}`,
    })),
    channels: Array.from({ length: 4 }).map((_, i) => ({
      id: `channel-${i + 1}`,
      username: `creator${i + 1}`,
      displayName: `Creator ${i + 1}`,
      profileImageURL: `https://i.pravatar.cc/150?img=${i + 1}`,
      subscribers: Math.floor(Math.random() * 100000 + 1000),
      videoCount: Math.floor(Math.random() * 100 + 10),
    })),
  };

  // Trending searches
  const trendingSearches = [
    'Gaming highlights',
    'Cooking tutorials',
    'Music covers',
    'Tech reviews',
    'Fitness workouts',
  ];

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Mobile-First Container */}
      <div className="max-w-[768px] mx-auto">
        {/* Header with Search */}
        <header className="sticky top-0 z-50 bg-white border-b border-gray-200 px-4 py-4">
          <div className="relative mb-3">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" size={20} />
            <input
              type="text"
              placeholder="Search videos, channels, playlists..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full bg-gray-100 text-black pl-10 pr-4 py-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-red-500"
              autoFocus
            />
          </div>

          {/* Filter Tabs */}
          <div className="flex gap-2 overflow-x-auto scrollbar-hide">
            {(['all', 'videos', 'channels', 'playlists'] as const).map((filter) => (
              <button
                key={filter}
                onClick={() => setActiveFilter(filter)}
                className={`px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-all capitalize ${
                  activeFilter === filter
                    ? 'bg-red-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                {filter}
              </button>
            ))}
          </div>
        </header>

        {/* Main Content */}
        <main className="px-4 py-6 pb-24">
          {!searchQuery ? (
            /* Trending Searches */
            <section>
              <h2 className="text-lg font-bold text-black mb-4 flex items-center gap-2">
                <TrendingUp size={20} className="text-red-600" />
                Trending Searches
              </h2>
              <div className="space-y-2">
                {trendingSearches.map((search, index) => (
                  <button
                    key={index}
                    onClick={() => setSearchQuery(search)}
                    className="w-full flex items-center gap-3 p-3 bg-white hover:bg-gray-50 rounded-xl border border-gray-200 transition-all text-left"
                  >
                    <TrendingUp size={18} className="text-gray-400" />
                    <span className="text-black">{search}</span>
                  </button>
                ))}
              </div>
            </section>
          ) : (
            /* Search Results */
            <div className="space-y-8">
              {/* Channels */}
              {(activeFilter === 'all' || activeFilter === 'channels') && (
                <section>
                  <h2 className="text-lg font-bold text-black mb-4 flex items-center gap-2">
                    <Users size={20} className="text-blue-600" />
                    Channels
                  </h2>
                  <div className="space-y-3">
                    {searchResults.channels.map((channel) => (
                      <Link
                        key={channel.id}
                        href={`/profile/${channel.username}`}
                        className="flex items-center gap-3 p-3 bg-white hover:bg-gray-50 rounded-xl border border-gray-200 transition-all"
                      >
                        <img
                          src={channel.profileImageURL}
                          alt={channel.displayName}
                          className="w-16 h-16 rounded-full"
                        />
                        <div className="flex-1">
                          <h3 className="font-bold text-black">{channel.displayName}</h3>
                          <p className="text-sm text-gray-600">
                            {(channel.subscribers / 1000).toFixed(1)}K subscribers • {channel.videoCount} videos
                          </p>
                        </div>
                        <button className="px-4 py-2 bg-red-600 text-white text-sm font-bold rounded-full hover:bg-red-700 transition-colors">
                          Subscribe
                        </button>
                      </Link>
                    ))}
                  </div>
                </section>
              )}

              {/* Videos */}
              {(activeFilter === 'all' || activeFilter === 'videos') && (
                <section>
                  <h2 className="text-lg font-bold text-black mb-4 flex items-center gap-2">
                    <VideoIcon size={20} className="text-red-600" />
                    Videos
                  </h2>
                  <div className="space-y-3">
                    {searchResults.videos.map((video) => (
                      <Link
                        key={video.id}
                        href={`/watch/${video.id}`}
                        className="flex gap-3 bg-white hover:bg-gray-50 p-3 rounded-xl border border-gray-200 transition-all"
                      >
                        <div className="relative w-40 h-24 bg-gray-200 rounded-lg overflow-hidden flex-shrink-0">
                          <img
                            src={video.thumbnailURL}
                            alt={video.title}
                            className="w-full h-full object-cover"
                          />
                          <div className="absolute bottom-1 right-1 bg-black/80 text-white text-xs px-1.5 py-0.5 rounded">
                            {video.duration}
                          </div>
                        </div>
                        <div className="flex-1 min-w-0">
                          <h3 className="font-bold text-black text-sm line-clamp-2 mb-1">{video.title}</h3>
                          <p className="text-xs text-gray-600 mb-1">{video.channel}</p>
                          <p className="text-xs text-gray-600">
                            {(video.views / 1000).toFixed(0)}K views •{' '}
                            {Math.floor((Date.now() - video.uploadDate.getTime()) / (1000 * 60 * 60 * 24))}d ago
                          </p>
                        </div>
                      </Link>
                    ))}
                  </div>
                </section>
              )}
            </div>
          )}
        </main>
      </div>
    </div>
  );
}

