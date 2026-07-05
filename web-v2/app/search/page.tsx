'use client';

// Search & Discovery Page — reads ?q= and queries real videos/channels.

import { Search, TrendingUp, Users, Video as VideoIcon } from 'lucide-react';
import Link from 'next/link';
import { useSearchParams, useRouter } from 'next/navigation';
import { Suspense, useEffect, useState } from 'react';
import { useSearchVideos } from '@/hooks/useVideos';
import { videoService } from '@/lib/firebase/services/video-service';
import { userFirestoreService, UserFirestoreService } from '@/lib/firebase/services/UserFirestoreService';
import type { User } from '@/types';

function SearchInner() {
  const params = useSearchParams();
  const router = useRouter();
  const initialQuery = params.get('q') ?? '';

  const [searchQuery, setSearchQuery] = useState(initialQuery);
  const [activeFilter, setActiveFilter] = useState<'all' | 'videos' | 'channels'>('all');
  const [channels, setChannels] = useState<User[]>([]);
  const [suggestions, setSuggestions] = useState<string[]>([]);
  const [suggestionsOpen, setSuggestionsOpen] = useState(false);

  const { videos, isLoading, search } = useSearchVideos();

  // Run search whenever the committed query changes.
  useEffect(() => {
    const q = initialQuery.trim();
    if (!q) return;
    setSearchQuery(initialQuery);
    search(q);
    userFirestoreService.searchUsers(q, 6).then(setChannels).catch(() => setChannels([]));
  }, [initialQuery, search]);

  // Debounced autocomplete as the user types (real backend when configured;
  // silently yields nothing otherwise — see fetchSuggestions).
  useEffect(() => {
    const q = searchQuery.trim();
    if (!q || q === initialQuery.trim()) { setSuggestions([]); return; }
    const timer = setTimeout(() => {
      videoService.fetchSuggestions(q, 6).then(setSuggestions).catch(() => setSuggestions([]));
    }, 200);
    return () => clearTimeout(timer);
  }, [searchQuery, initialQuery]);

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    const q = searchQuery.trim();
    if (q) {
      setSuggestionsOpen(false);
      router.push(`/search?q=${encodeURIComponent(q)}`);
    }
  };

  const submitSuggestion = (s: string) => {
    setSearchQuery(s);
    setSuggestionsOpen(false);
    router.push(`/search?q=${encodeURIComponent(s)}`);
  };

  const trendingSearches = ['Gaming highlights', 'Cooking tutorials', 'Music covers', 'Tech reviews', 'Fitness workouts'];
  const hasQuery = initialQuery.trim().length > 0;

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-[900px] mx-auto">
        {/* Header with Search */}
        <header className="sticky top-0 z-50 bg-white border-b border-gray-200 px-4 py-4">
          <form onSubmit={submit} className="relative mb-3">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" size={20} />
            <input
              type="text"
              placeholder="Search videos, channels..."
              value={searchQuery}
              onChange={(e) => { setSearchQuery(e.target.value); setSuggestionsOpen(true); }}
              onFocus={() => setSuggestionsOpen(true)}
              onBlur={() => setTimeout(() => setSuggestionsOpen(false), 150)}
              className="w-full bg-gray-100 text-black pl-10 pr-4 py-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-red-500"
              autoFocus
              autoComplete="off"
              role="combobox"
              aria-expanded={suggestionsOpen && suggestions.length > 0}
              aria-controls="search-suggestions"
            />
            {suggestionsOpen && suggestions.length > 0 && (
              <ul
                id="search-suggestions"
                role="listbox"
                className="absolute left-0 right-0 top-full mt-1 bg-white border border-gray-200 rounded-xl shadow-lg overflow-hidden z-10"
              >
                {suggestions.map((s) => (
                  <li key={s} role="option" aria-selected="false">
                    <button
                      type="button"
                      onMouseDown={(e) => e.preventDefault()}
                      onClick={() => submitSuggestion(s)}
                      className="w-full flex items-center gap-3 px-4 py-2.5 text-left text-sm text-black hover:bg-gray-50 transition-colors"
                    >
                      <Search size={14} className="text-gray-400 flex-shrink-0" />
                      <span className="truncate">{s}</span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </form>

          {/* Filter Tabs */}
          <div className="flex gap-2 overflow-x-auto scrollbar-hide">
            {(['all', 'videos', 'channels'] as const).map((filter) => (
              <button
                key={filter}
                onClick={() => setActiveFilter(filter)}
                className={`px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-all capitalize ${
                  activeFilter === filter ? 'bg-red-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                {filter}
              </button>
            ))}
          </div>
        </header>

        <main className="px-4 py-6 pb-24">
          {!hasQuery ? (
            <section>
              <h2 className="text-lg font-bold text-black mb-4 flex items-center gap-2">
                <TrendingUp size={20} className="text-red-600" />
                Trending Searches
              </h2>
              <div className="space-y-2">
                {trendingSearches.map((s) => (
                  <button
                    key={s}
                    onClick={() => router.push(`/search?q=${encodeURIComponent(s)}`)}
                    className="w-full flex items-center gap-3 p-3 bg-white hover:bg-gray-50 rounded-xl border border-gray-200 transition-all text-left"
                  >
                    <TrendingUp size={18} className="text-gray-400" />
                    <span className="text-black">{s}</span>
                  </button>
                ))}
              </div>
            </section>
          ) : (
            <div className="space-y-8">
              {/* Channels */}
              {(activeFilter === 'all' || activeFilter === 'channels') && channels.length > 0 && (
                <section>
                  <h2 className="text-lg font-bold text-black mb-4 flex items-center gap-2">
                    <Users size={20} className="text-blue-600" />
                    Channels
                  </h2>
                  <div className="space-y-3">
                    {channels.map((channel) => (
                      <Link
                        key={channel.id}
                        href={`/profile/${channel.username}`}
                        className="flex items-center gap-3 p-3 bg-white hover:bg-gray-50 rounded-xl border border-gray-200 transition-all"
                      >
                        <img
                          src={channel.profileImageURL || `https://i.pravatar.cc/150?u=${channel.id}`}
                          alt={channel.displayName}
                          className="w-16 h-16 rounded-full"
                        />
                        <div className="flex-1">
                          <h3 className="font-bold text-black">{channel.displayName}</h3>
                          <p className="text-sm text-gray-600">
                            {UserFirestoreService.formatSubscriberCount(channel.subscriberCount ?? 0)}
                          </p>
                        </div>
                        <span className="px-4 py-2 bg-red-600 text-white text-sm font-bold rounded-full">
                          View
                        </span>
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
                  {isLoading ? (
                    <div className="space-y-3">
                      {Array.from({ length: 5 }).map((_, i) => (
                        <div key={i} className="flex gap-3 p-3 animate-pulse">
                          <div className="w-40 h-24 bg-gray-200 rounded-lg" />
                          <div className="flex-1 space-y-2 py-1">
                            <div className="h-4 bg-gray-200 rounded w-3/4" />
                            <div className="h-3 bg-gray-200 rounded w-1/3" />
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : videos.length === 0 ? (
                    <p className="text-sm text-gray-500 py-8 text-center">
                      No videos found for &quot;{initialQuery}&quot;.
                    </p>
                  ) : (
                    <div className="space-y-3">
                      {videos.map((video) => (
                        <Link
                          key={video.id}
                          href={`/watch/${video.id}`}
                          className="flex gap-3 bg-white hover:bg-gray-50 p-3 rounded-xl border border-gray-200 transition-all"
                        >
                          <div className="relative w-40 h-24 bg-gray-200 rounded-lg overflow-hidden flex-shrink-0">
                            <img src={video.thumbnailURL} alt={video.title} className="w-full h-full object-cover" />
                            <div className="absolute bottom-1 right-1 bg-black/80 text-white text-xs px-1.5 py-0.5 rounded">
                              {videoService.formatDuration(video.duration)}
                            </div>
                          </div>
                          <div className="flex-1 min-w-0">
                            <h3 className="font-bold text-black text-sm line-clamp-2 mb-1">{video.title}</h3>
                            <p className="text-xs text-gray-600 mb-1">{video.creator?.displayName ?? 'Unknown'}</p>
                            <p className="text-xs text-gray-600">
                              {videoService.formatViewCount(video.viewCount)} views • {videoService.formatTimeAgo(video.createdAt)}
                            </p>
                          </div>
                        </Link>
                      ))}
                    </div>
                  )}
                </section>
              )}
            </div>
          )}
        </main>
      </div>
    </div>
  );
}

export default function SearchPage() {
  return (
    <Suspense fallback={<div className="min-h-screen bg-gray-50" />}>
      <SearchInner />
    </Suspense>
  );
}

