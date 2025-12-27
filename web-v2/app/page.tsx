'use client';

// 🔥 YOUTUBE-LEVEL PROFESSIONAL HOME PAGE 🔥
// Desktop: Premium YouTube-style layout with category tabs + video grid
// Mobile: App parity with Stories + Featured + Trending
// NOW CONNECTED TO REAL FIREBASE DATA! 🔥

import { Search, Bell, Plus, Video, Users } from 'lucide-react';
import Link from 'next/link';
import { useState, useRef, useEffect, useCallback } from 'react';
import Sidebar from '@/components/layout/Sidebar';
import TopNav from '@/components/layout/TopNav';
import Header from '@/components/layout/Header';
import Hero from '@/components/layout/Hero';
import CategoryTabs from '@/components/layout/CategoryTabs';
import VideoCard from '@/components/video/VideoCard';
import { VideoGridSkeleton } from '@/components/skeletons/VideoSkeleton';
import { useVideos, useTrendingVideos } from '@/hooks/useVideos';
import { videoService, VideoCategory } from '@/lib/firebase/services/video-service';

// Category mapping for Firebase
const categoryMap: Record<string, VideoCategory | 'all'> = {
  'All': 'all',
  'Music': 'music',
  'Gaming': 'gaming',
  'Entertainment': 'entertainment',
  'Education': 'education',
  'Sports': 'sports',
  'News': 'news',
  'Technology': 'technology',
  'Lifestyle': 'lifestyle',
  'Comedy': 'comedy',
};

export default function HomePage() {
  const [showAuthBanner, setShowAuthBanner] = useState(true);
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false);
  const [isMobile, setIsMobile] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState('All');
  const observerRef = useRef<HTMLDivElement>(null);

  // 🔥 REAL FIREBASE DATA - No more mock videos!
  const { 
    videos: firebaseVideos, 
    isLoading, 
    isLoadingMore: loadingMore, 
    hasMore, 
    loadMore,
    setCategory,
    refresh 
  } = useVideos({ 
    category: categoryMap[selectedCategory] || 'all',
    pageSize: 24,
    autoFetch: true 
  });

  // Transform Firebase videos to component format
  const videos = firebaseVideos.map(video => ({
    id: video.id,
    title: video.title,
    channel: video.creator.displayName,
    channelIcon: video.creator.profileImageURL || `https://i.pravatar.cc/150?u=${video.creator.id}`,
    subscribers: videoService.formatViewCount(video.creator.subscriberCount || 0),
    views: videoService.formatViewCount(video.viewCount),
    timeAgo: videoService.formatTimeAgo(video.createdAt),
    duration: videoService.formatDuration(video.duration),
    thumbnailURL: video.thumbnailURL || `https://picsum.photos/seed/${video.id}/640/360`,
    isVerified: video.creator.isVerified || false,
  }));

  // Detect screen size
  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth <= 768);
    };
    
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  // Handle category change
  const handleCategoryChange = useCallback((category: string) => {
    setSelectedCategory(category);
    setCategory(categoryMap[category] || 'all');
  }, [setCategory]);

  // Infinite scroll observer
  useEffect(() => {
    if (!observerRef.current || isMobile) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && hasMore && !loadingMore) {
          loadMore();
        }
      },
      { threshold: 0.1 }
    );

    observer.observe(observerRef.current);

    return () => {
      if (observerRef.current) {
        observer.unobserve(observerRef.current);
      }
    };
  }, [hasMore, loadingMore, isMobile, loadMore]);

  // Featured videos (including Shot By Keonta intro)
  const featuredVideos = [
    {
      id: 'shot-by-keonta-intro',
      title: 'Shot By Keonta',
      channel: 'MyChannel',
      subscribers: '59.5K',
      views: '85.8K',
      thumbnailURL: 'https://picsum.photos/seed/keonta-intro/1280/720',
      videoURL: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      channelIcon: 'https://i.pravatar.cc/150?img=1',
    },
    {
      id: 'featured-2',
      title: 'Amazing Content',
      channel: 'Creator Studio',
      subscribers: '120K',
      views: '250K',
      thumbnailURL: 'https://picsum.photos/seed/feat2/1280/720',
      videoURL: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      channelIcon: 'https://i.pravatar.cc/150?img=2',
    },
    {
      id: 'featured-3',
      title: 'Trending Now',
      channel: 'MyChannel',
      subscribers: '89K',
      views: '180K',
      thumbnailURL: 'https://picsum.photos/seed/feat3/1280/720',
      videoURL: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      channelIcon: 'https://i.pravatar.cc/150?img=3',
    },
  ];

  const [currentFeaturedIndex, setCurrentFeaturedIndex] = useState(0);

  // Mock videos for desktop grid
  const desktopVideos = Array.from({ length: 24 }, (_, i) => ({
    id: `video-${i + 1}`,
    title: `Amazing Video Title ${i + 1} - This is a longer title to test truncation`,
    channel: 'Creator Name',
    channelIcon: `https://i.pravatar.cc/150?img=${(i % 10) + 1}`,
    subscribers: `${Math.floor(Math.random() * 500 + 50)}K`,
    views: `${Math.floor(Math.random() * 1000 + 100)}K`,
    timeAgo: `${Math.floor(Math.random() * 30 + 1)} days ago`,
    duration: `${Math.floor(Math.random() * 20 + 5)}:${String(Math.floor(Math.random() * 60)).padStart(2, '0')}`,
    thumbnailURL: `https://picsum.photos/seed/video${i + 1}/640/360`,
    isVerified: Math.random() > 0.5,
  }));

  // 📱 MOBILE LAYOUT (≤768px) - App Parity
  if (isMobile) {
    return (
      <div className="min-h-screen bg-white">
        {/* Mobile-First Container */}
        <div className="max-w-[768px] mx-auto">
          {/* Top Header */}
          <header className="sticky top-0 z-50 bg-white border-b border-gray-200 px-4 py-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <img 
                  src="/logo.png" 
                  alt="MyChannel" 
                  className="w-10 h-10 rounded-lg"
                />
                <span className="text-xl font-bold text-black">MyChannel</span>
              </div>

              <div className="flex items-center gap-4">
                <button className="p-2 hover:bg-gray-100 rounded-full transition-colors">
                  <Search size={24} className="text-gray-700" />
                </button>
                <button className="p-2 hover:bg-gray-100 rounded-full transition-colors">
                  <Bell size={24} className="text-yellow-500" />
                </button>
                <button className="w-10 h-10 bg-gray-900 rounded-full flex items-center justify-center hover:bg-gray-800 transition-colors">
                  <Plus size={20} className="text-white" />
                </button>
              </div>
            </div>
          </header>

          {/* Main Content */}
          <main className="px-4 py-6 pb-24">
            {/* Auth Banner - 💎 MOBILE PREMIUM 💎 */}
            {showAuthBanner && (
              <div className="mb-6 p-5 bg-gradient-to-br from-red-50 to-pink-50 dark:from-gray-800 dark:to-gray-900 rounded-2xl border border-red-100/50 dark:border-gray-700/50 shadow-premium fade-in-up">
                <button
                  onClick={() => setShowAuthBanner(false)}
                  className="float-right text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 text-2xl w-8 h-8 flex items-center justify-center rounded-full hover:bg-white/50 dark:hover:bg-gray-800/50 transition-all"
                >
                  ×
                </button>
                <div className="mb-4">
                  <h3 className="text-base font-black text-black dark:text-white leading-tight">Your Channel. Your Future.</h3>
                  <p className="text-xs text-gray-700 dark:text-gray-300">Join MyChannel to post stories and videos.</p>
                </div>
                <div className="flex gap-3">
                  <Link
                    href="/signup"
                    className="btn-premium flex-1 py-3 bg-gradient-to-r from-red-600 to-red-700 text-white text-sm font-bold rounded-full text-center shadow-lg"
                  >
                    Create account
                  </Link>
                  <Link
                    href="/login"
                    className="flex-1 py-3 text-gray-800 dark:text-gray-200 text-sm font-bold text-center rounded-full border-2 border-gray-300 dark:border-gray-600 hover:bg-white/80 dark:hover:bg-gray-800/80 transition-all"
                  >
                    Sign in
                  </Link>
                </div>
              </div>
            )}

            {/* Stories Section */}
            <section className="mb-8">
              <h2 className="text-xl font-bold text-red-600 mb-4">Stories</h2>
              <div className="flex gap-4 overflow-x-auto scrollbar-hide pb-2">
                <div className="flex flex-col items-center flex-shrink-0">
                  <button className="w-20 h-20 bg-gray-900 rounded-full flex items-center justify-center hover:bg-gray-800 transition-colors">
                    <Plus size={32} className="text-white" />
                  </button>
                  <span className="text-xs text-gray-400 mt-2">Your Story</span>
                </div>
                {/* Placeholder for future stories */}
              </div>
            </section>

            {/* Featured Section */}
            <section className="mb-8">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-bold text-red-600">Featured</h2>
              </div>

              <div className="relative">
                {/* Featured Video Card */}
                <Link href={`/watch/${featuredVideos[currentFeaturedIndex].id}`}>
                  <div className="relative aspect-video bg-black rounded-2xl overflow-hidden">
                    {/* Video Thumbnail/Player */}
                    <img
                      src={featuredVideos[currentFeaturedIndex].thumbnailURL}
                      alt={featuredVideos[currentFeaturedIndex].title}
                      className="w-full h-full object-cover"
                    />

                    {/* Gradient Overlay */}
                    <div className="absolute inset-0 bg-gradient-to-b from-transparent via-transparent to-black/80" />

                    {/* Video Info Overlay */}
                    <div className="absolute bottom-0 left-0 right-0 p-4">
                      <div className="flex items-center gap-3 mb-2">
                        <img
                          src={featuredVideos[currentFeaturedIndex].channelIcon}
                          alt={featuredVideos[currentFeaturedIndex].channel}
                          className="w-12 h-12 rounded-full border-2 border-white"
                        />
                        <div className="flex-1 min-w-0">
                          <h3 className="text-white font-bold text-lg truncate">
                            {featuredVideos[currentFeaturedIndex].title}
                          </h3>
                          <p className="text-white/80 text-sm">
                            {featuredVideos[currentFeaturedIndex].channel} • {featuredVideos[currentFeaturedIndex].subscribers} subscribers • {featuredVideos[currentFeaturedIndex].views} views
                          </p>
                        </div>
                      </div>
                    </div>

                    {/* Play Button (Centered) */}
                    <div className="absolute inset-0 flex items-center justify-center">
                      <button className="w-16 h-16 bg-white rounded-full flex items-center justify-center hover:scale-110 transition-transform shadow-lg">
                        <div className="w-0 h-0 border-t-8 border-t-transparent border-l-12 border-l-red-600 border-b-8 border-b-transparent ml-1" />
                      </button>
                    </div>

                    {/* Add to List Button */}
                    <button className="absolute bottom-4 right-4 w-10 h-10 bg-white rounded-full flex items-center justify-center hover:bg-gray-100 transition-colors shadow-lg">
                      <Plus size={20} className="text-black" />
                    </button>
                  </div>
                </Link>

                {/* Carousel Dots */}
                <div className="flex items-center justify-center gap-2 mt-4">
                  {featuredVideos.map((_, index) => (
                    <button
                      key={index}
                      onClick={() => setCurrentFeaturedIndex(index)}
                      className={`h-2 rounded-full transition-all ${
                        index === currentFeaturedIndex
                          ? 'w-8 bg-red-600'
                          : 'w-2 bg-gray-300 hover:bg-gray-400'
                      }`}
                    />
                  ))}
                </div>
              </div>
            </section>

            {/* Trending Now Section */}
            <section>
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-bold text-red-600">Trending Now</h2>
                <Link href="/trending" className="text-sm text-red-600 font-medium hover:underline">
                  See all
                </Link>
              </div>

              <div className="grid grid-cols-2 gap-3">
                {Array.from({ length: 6 }).map((_, i) => (
                  <Link
                    key={i}
                    href={`/watch/trending-${i + 1}`}
                    className="group"
                  >
                    <div className="aspect-video bg-gray-200 rounded-lg overflow-hidden mb-2">
                      <img
                        src={`https://picsum.photos/seed/trend${i}/640/360`}
                        alt={`Trending video ${i + 1}`}
                        className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                      />
                    </div>
                    <h3 className="text-sm font-medium text-black line-clamp-2 mb-1 group-hover:text-red-600 transition-colors">
                      Trending Video Title {i + 1}
                    </h3>
                    <p className="text-xs text-gray-600">
                      {Math.floor(Math.random() * 500 + 50)}K views
                    </p>
                  </Link>
                ))}
              </div>
            </section>
          </main>

          {/* Bottom Navigation (Mobile) */}
          <nav className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 z-50 max-w-[768px] mx-auto">
            <div className="flex items-center justify-around py-2">
              <Link href="/" className="flex flex-col items-center gap-1 p-2">
                <div className="text-black">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z" />
                  </svg>
                </div>
                <span className="text-xs font-medium text-black">Home</span>
              </Link>

              <Link href="/flicks" className="flex flex-col items-center gap-1 p-2">
                <Video size={24} className="text-gray-400" />
                <span className="text-xs text-gray-400">Flicks</span>
              </Link>

              <Link
                href="/upload"
                className="flex flex-col items-center -mt-6"
              >
                <div className="w-14 h-14 bg-blue-500 rounded-full flex items-center justify-center shadow-lg hover:bg-blue-600 transition-colors">
                  <Plus size={28} className="text-white font-bold" />
                </div>
                <span className="text-xs font-medium text-gray-700 mt-1">Create</span>
              </Link>

              <Link href="/search" className="flex flex-col items-center gap-1 p-2">
                <Search size={24} className="text-gray-400" />
                <span className="text-xs text-gray-400">Search</span>
              </Link>

              <Link href="/profile" className="flex flex-col items-center gap-1 p-2">
                <Users size={24} className="text-gray-400" />
                <span className="text-xs text-gray-400">Profile</span>
              </Link>
            </div>
          </nav>
        </div>
      </div>
    );
  }

  // 💻 DESKTOP LAYOUT (>768px) - YouTube Professional
  const toggleSidebar = () => {
    setIsSidebarCollapsed(!isSidebarCollapsed);
  };

  return (
    <div className="min-h-screen bg-white dark:bg-[rgb(var(--color-background))]">
      {/* Skip Navigation Link (Accessibility) */}
      <a 
        href="#main-content" 
        className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-[100] focus:px-4 focus:py-2 focus:bg-[rgb(var(--color-primary))] focus:text-white focus:rounded-lg focus:outline-none focus:ring-4 focus:ring-[rgb(var(--color-primary))] focus:ring-offset-2"
      >
        Skip to main content
      </a>

      {/* Top Navigation */}
      <Header onToggleSidebar={toggleSidebar} />

      {/* Sidebar */}
      <Sidebar isCollapsed={isSidebarCollapsed} onToggleCollapse={toggleSidebar} />

      {/* Hero Section - Premium Landing */}
      <Hero
        title="Your Channel. Your Future."
        subtitle="The next-generation video platform combining YouTube + Twitch + DraftKings + UFC. Create, stream, compete, and win."
        ctaPrimary={{
          text: 'Get Started',
          href: '/signup',
        }}
        ctaSecondary={{
          text: 'Watch Demo',
          href: `/watch/${featuredVideos[0].id}`,
        }}
        backgroundImage="https://images.unsplash.com/photo-1611162617474-5b21e879e113?w=1920&q=80"
        stats={[
          { label: 'Active Creators', value: '1M+', icon: null },
          { label: 'Daily Views', value: '50M+', icon: null },
          { label: 'Awards Given', value: '10K+', icon: null },
        ]}
        featuredVideo={{
          id: featuredVideos[0].id,
          title: featuredVideos[0].title,
          thumbnail: featuredVideos[0].thumbnailURL,
          channel: featuredVideos[0].channel,
        }}
      />

      {/* Category Tabs - Sticky below header */}
      <div className={`transition-all duration-200 ${isSidebarCollapsed ? 'pl-16' : 'pl-56'}`}>
        <CategoryTabs
          activeCategory={selectedCategory}
          onCategoryChange={handleCategoryChange}
        />
      </div>

      {/* Main Content */}
      <main
        id="main-content"
        className={`
          transition-all duration-200 ease-in-out
          ${isSidebarCollapsed ? 'pl-16' : 'pl-56'}
        `}
      >
        <div className="min-h-[calc(100vh-3.5rem)] px-6 py-6">
          {/* Auth Banner - Premium Subtle Design */}
          {showAuthBanner && (
            <div className="mb-6 p-6 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-xl max-w-[1800px] mx-auto fade-in">
              <button
                onClick={() => setShowAuthBanner(false)}
                className="float-right text-[rgb(var(--color-text-secondary))] hover:text-[rgb(var(--color-text-primary))] text-2xl w-8 h-8 flex items-center justify-center rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-all"
              >
                ×
              </button>
              <div className="flex items-start gap-6">
                <div className="flex-shrink-0 w-12 h-12 bg-[rgb(var(--color-primary))] rounded-lg flex items-center justify-center text-white font-bold text-lg">
                  MC
                </div>
                <div className="flex-1">
                  <h3 className="text-lg font-semibold text-[rgb(var(--color-text-primary))] mb-2">
                    Sign in to enjoy more features
                  </h3>
                  <p className="text-sm text-[rgb(var(--color-text-secondary))] mb-4">
                    Like videos, comment, subscribe and create your own content
                  </p>
                  <div className="flex gap-3">
                    <Link
                      href="/login"
                      className="px-4 py-2 bg-[rgb(var(--color-primary))] hover:bg-[rgb(var(--color-primary-hover))] text-white text-sm font-medium rounded-full transition-all btn-press"
                    >
                      Sign in
                    </Link>
                  </div>
                </div>
              </div>
            </div>
          )}

                {/* Video Grid - YouTube Premium Layout with Infinite Scroll */}
                <div className="max-w-[1800px] mx-auto">
                  {isLoading ? (
                    <VideoGridSkeleton count={24} />
                  ) : videos.length === 0 ? (
                    // Empty state when no videos found
                    <div className="py-20 text-center">
                      <div className="w-20 h-20 mx-auto mb-6 rounded-full bg-[rgb(var(--color-surface))] flex items-center justify-center">
                        <Video size={40} className="text-[rgb(var(--color-text-secondary))]" />
                      </div>
                      <h3 className="text-xl font-semibold text-[rgb(var(--color-text-primary))] mb-2">
                        No videos yet
                      </h3>
                      <p className="text-[rgb(var(--color-text-secondary))] mb-6">
                        {selectedCategory === 'All' 
                          ? 'Be the first to upload a video!' 
                          : `No ${selectedCategory.toLowerCase()} videos found. Try a different category.`}
                      </p>
                      <Link
                        href="/upload"
                        className="inline-flex items-center gap-2 px-6 py-3 bg-[rgb(var(--color-primary))] text-white rounded-full font-medium hover:bg-[rgb(var(--color-primary-hover))] transition-colors"
                      >
                        <Plus size={20} />
                        Upload Video
                      </Link>
                    </div>
                  ) : (
                    <>
                      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6 gap-x-4 gap-y-10">
                        {videos.map((video, index) => (
                          <VideoCard key={video.id} video={video} index={index % 4} />
                        ))}
                      </div>
                      
                      {/* Infinite Scroll Trigger */}
                      {hasMore && (
                        <div ref={observerRef} className="py-8">
                          {loadingMore && (
                            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6 gap-x-4 gap-y-10">
                              {Array.from({ length: 12 }).map((_, i) => (
                                <div key={i} className="space-y-3 animate-pulse">
                                  <div className="aspect-video rounded-xl bg-[rgb(var(--color-surface-hover))] skeleton"></div>
                                  <div className="flex gap-3">
                                    <div className="w-10 h-10 rounded-full bg-[rgb(var(--color-surface-hover))] skeleton flex-shrink-0"></div>
                                    <div className="flex-1 space-y-2">
                                      <div className="h-4 bg-[rgb(var(--color-surface-hover))] rounded skeleton w-full"></div>
                                      <div className="h-3 bg-[rgb(var(--color-surface-hover))] rounded skeleton w-3/4"></div>
                                    </div>
                                  </div>
                                </div>
                              ))}
                            </div>
                          )}
                        </div>
                      )}
                      
                      {!hasMore && videos.length > 0 && (
                        <div className="py-8 text-center text-[rgb(var(--color-text-secondary))] text-sm">
                          You've reached the end! 🎉
                        </div>
                      )}
                    </>
                  )}
                </div>
        </div>
      </main>
    </div>
  );
}
