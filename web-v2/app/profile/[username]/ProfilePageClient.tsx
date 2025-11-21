'use client';

// 🔥 YOUTUBE-LEVEL PROFESSIONAL PROFILE PAGE CLIENT 🔥

import { useState, useEffect } from 'react';
import { 
  Bell, CheckCircle, Share2, MoreHorizontal, Camera, Edit,
} from 'lucide-react';
import Sidebar from '@/components/layout/Sidebar';
import TopNav from '@/components/layout/TopNav';
import VideoCard from '@/components/video/VideoCard';
import { VideoGridSkeleton } from '@/components/skeletons/VideoSkeleton';

interface ProfilePageClientProps {
  username: string;
}

type ProfileTab = 'home' | 'videos' | 'shorts' | 'live' | 'playlists' | 'community' | 'channels' | 'about';

const ProfilePageClient = ({ username }: ProfilePageClientProps) => {
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false);
  const [activeTab, setActiveTab] = useState<ProfileTab>('home');
  const [isSubscribed, setIsSubscribed] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [showBannerEdit, setShowBannerEdit] = useState(false);

  // Mock channel data
  const channel = {
    username: username,
    name: 'Channel Name',
    avatar: 'https://i.pravatar.cc/150?img=8',
    banner: 'https://picsum.photos/seed/banner/2560/400',
    subscribers: '1.5M',
    videoCount: '1,234',
    description: 'Welcome to my channel! Here you\'ll find amazing content about tech, gaming, and lifestyle. Subscribe for daily uploads!',
    isVerified: true,
    isOwner: false, // Set to true to show edit buttons
  };

  // Mock videos
  const videos = Array.from({ length: 24 }, (_, i) => ({
    id: `profile-video-${i + 1}`,
    title: `Video Title ${i + 1} - Amazing Content You Need to Watch`,
    channel: channel.name,
    channelIcon: channel.avatar,
    views: `${Math.floor(Math.random() * 1000 + 100)}K`,
    timeAgo: `${Math.floor(Math.random() * 30 + 1)} days ago`,
    duration: `${Math.floor(Math.random() * 20 + 5)}:${String(Math.floor(Math.random() * 60)).padStart(2, '0')}`,
    thumbnailURL: `https://picsum.photos/seed/profile${i + 1}/640/360`,
    isVerified: channel.isVerified,
  }));

  useEffect(() => {
    // Simulate loading
    const timer = setTimeout(() => {
      setIsLoading(false);
    }, 800);
    return () => clearTimeout(timer);
  }, [activeTab]);

  const tabs: { id: ProfileTab; label: string }[] = [
    { id: 'home', label: 'Home' },
    { id: 'videos', label: 'Videos' },
    { id: 'shorts', label: 'Shorts' },
    { id: 'live', label: 'Live' },
    { id: 'playlists', label: 'Playlists' },
    { id: 'community', label: 'Community' },
    { id: 'channels', label: 'Channels' },
    { id: 'about', label: 'About' },
  ];

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      {/* TopNav */}
      <TopNav onToggleSidebar={() => setIsSidebarCollapsed(!isSidebarCollapsed)} />

      {/* Sidebar */}
      <Sidebar isCollapsed={isSidebarCollapsed} onToggleCollapse={() => setIsSidebarCollapsed(!isSidebarCollapsed)} />

      {/* Main Content */}
      <main className={`pt-14 transition-all duration-200 ${isSidebarCollapsed ? 'pl-16' : 'pl-56'}`}>
        <div className="max-w-[1800px] mx-auto">
          {/* Banner Image */}
          <div 
            className="relative w-full h-[200px] md:h-[240px] bg-[rgb(var(--color-surface))] overflow-hidden group"
            onMouseEnter={() => channel.isOwner && setShowBannerEdit(true)}
            onMouseLeave={() => setShowBannerEdit(false)}
          >
            <img
              src={channel.banner}
              alt="Channel banner"
              className="w-full h-full object-cover"
            />
            
            {/* Edit Banner Button (owner only) */}
            {channel.isOwner && showBannerEdit && (
              <div className="absolute inset-0 bg-black/40 flex items-center justify-center fade-in">
                <button className="flex items-center gap-2 px-4 py-2 bg-white/90 hover:bg-white rounded-full text-black font-medium transition-all btn-press">
                  <Camera size={18} />
                  <span>Change Banner</span>
                </button>
              </div>
            )}
          </div>

          {/* Channel Info Section */}
          <div className="px-6 py-6">
            <div className="flex flex-col md:flex-row md:items-start gap-6">
              {/* Avatar */}
              <div className="relative flex-shrink-0 group">
                <img
                  src={channel.avatar}
                  alt={channel.name}
                  className="w-32 h-32 md:w-40 md:h-40 rounded-full ring-4 ring-[rgb(var(--color-background))] shadow-lg-yt"
                />
                {channel.isOwner && (
                  <button className="absolute bottom-2 right-2 w-10 h-10 bg-[rgb(var(--color-surface))] hover:bg-[rgb(var(--color-surface-hover))] rounded-full flex items-center justify-center shadow-md-yt opacity-0 group-hover:opacity-100 transition-all btn-press">
                    <Camera size={18} className="text-[rgb(var(--color-text-primary))]" />
                  </button>
                )}
              </div>

              {/* Channel Details */}
              <div className="flex-1 min-w-0">
                <div className="flex items-start justify-between gap-4 mb-3">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <h1 className="text-2xl md:text-3xl font-bold text-[rgb(var(--color-text-primary))] truncate">
                        {channel.name}
                      </h1>
                      {channel.isVerified && (
                        <CheckCircle size={20} className="text-[rgb(var(--color-text-secondary))] flex-shrink-0" fill="currentColor" />
                      )}
                    </div>
                    <div className="flex items-center gap-2 text-sm text-[rgb(var(--color-text-secondary))] mb-3">
                      <span>@{channel.username}</span>
                      <span>•</span>
                      <span>{channel.subscribers} subscribers</span>
                      <span>•</span>
                      <span>{channel.videoCount} videos</span>
                    </div>
                    <p className="text-sm text-[rgb(var(--color-text-secondary))] line-clamp-2 max-w-2xl">
                      {channel.description}
                    </p>
                  </div>

                  {/* Action Buttons */}
                  <div className="flex items-center gap-2 flex-shrink-0">
                    {channel.isOwner ? (
                      <button className="flex items-center gap-2 px-4 py-2 rounded-full bg-[rgb(var(--color-surface))] hover:bg-[rgb(var(--color-surface-hover))] text-[rgb(var(--color-text-primary))] font-medium transition-colors btn-press">
                        <Edit size={18} />
                        <span className="hidden sm:inline">Customize channel</span>
                      </button>
                    ) : (
                      <>
                        <button
                          onClick={() => setIsSubscribed(!isSubscribed)}
                          className={`
                            px-4 py-2 rounded-full font-medium transition-all btn-press btn-premium
                            ${isSubscribed
                              ? 'bg-[rgb(var(--color-surface))] hover:bg-[rgb(var(--color-surface-hover))] text-[rgb(var(--color-text-primary))]'
                              : 'bg-[rgb(var(--color-primary))] hover:bg-[rgb(var(--color-primary-hover))] text-white'
                            }
                          `}
                        >
                          {isSubscribed ? 'Subscribed' : 'Subscribe'}
                        </button>
                        <button className="p-2 rounded-full bg-[rgb(var(--color-surface))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors btn-press">
                          <Bell size={18} className="text-[rgb(var(--color-text-primary))]" />
                        </button>
                      </>
                    )}
                    <button className="p-2 rounded-full bg-[rgb(var(--color-surface))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors btn-press">
                      <Share2 size={18} className="text-[rgb(var(--color-text-primary))]" />
                    </button>
                    <button className="p-2 rounded-full bg-[rgb(var(--color-surface))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors btn-press">
                      <MoreHorizontal size={18} className="text-[rgb(var(--color-text-primary))]" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Tabs */}
          <div className="px-6 border-b border-[rgb(var(--color-border))]">
            <div className="flex gap-8 overflow-x-auto scrollbar-hide">
              {tabs.map((tab) => (
                <button
                  key={tab.id}
                  onClick={() => {
                    setActiveTab(tab.id);
                    setIsLoading(true);
                  }}
                  className={`
                    relative py-3 px-1 text-sm font-medium transition-colors whitespace-nowrap
                    ${activeTab === tab.id
                      ? 'text-[rgb(var(--color-text-primary))]'
                      : 'text-[rgb(var(--color-text-secondary))] hover:text-[rgb(var(--color-text-primary))]'
                    }
                  `}
                >
                  {tab.label}
                  {activeTab === tab.id && (
                    <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[rgb(var(--color-text-primary))]"></div>
                  )}
                </button>
              ))}
            </div>
          </div>

          {/* Content Area */}
          <div className="px-6 py-6">
            {activeTab === 'home' && (
              <div>
                {isLoading ? (
                  <VideoGridSkeleton count={12} />
                ) : (
                  <>
                    {/* Featured/Pinned Video Section */}
                    <div className="mb-8">
                      <h2 className="text-lg font-semibold text-[rgb(var(--color-text-primary))] mb-4">
                        Featured
                      </h2>
                      <div className="max-w-2xl">
                        <VideoCard video={videos[0]} index={0} />
                      </div>
                    </div>

                    {/* Recent Uploads */}
                    <div>
                      <h2 className="text-lg font-semibold text-[rgb(var(--color-text-primary))] mb-4">
                        Recent Uploads
                      </h2>
                      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6 gap-x-4 gap-y-8">
                        {videos.slice(1, 13).map((video, index) => (
                          <VideoCard key={video.id} video={video} index={index} />
                        ))}
                      </div>
                    </div>
                  </>
                )}
              </div>
            )}

            {activeTab === 'videos' && (
              <div>
                {isLoading ? (
                  <VideoGridSkeleton count={24} />
                ) : (
                  <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6 gap-x-4 gap-y-8">
                    {videos.map((video, index) => (
                      <VideoCard key={video.id} video={video} index={index} />
                    ))}
                  </div>
                )}
              </div>
            )}

            {activeTab === 'about' && (
              <div className="max-w-4xl">
                <div className="bg-[rgb(var(--color-surface))] rounded-xl p-6 space-y-6">
                  <div>
                    <h3 className="text-sm font-semibold text-[rgb(var(--color-text-secondary))] uppercase mb-2">
                      Description
                    </h3>
                    <p className="text-base text-[rgb(var(--color-text-primary))]">
                      {channel.description}
                    </p>
                  </div>

                  <div className="border-t border-[rgb(var(--color-border))] pt-6">
                    <h3 className="text-sm font-semibold text-[rgb(var(--color-text-secondary))] uppercase mb-2">
                      Stats
                    </h3>
                    <div className="space-y-1 text-sm text-[rgb(var(--color-text-primary))]">
                      <p>Joined: January 1, 2020</p>
                      <p>{channel.subscribers} subscribers</p>
                      <p>{channel.videoCount} videos</p>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {['shorts', 'live', 'playlists', 'community', 'channels'].includes(activeTab) && (
              <div className="py-20 text-center">
                <p className="text-[rgb(var(--color-text-secondary))] text-lg">
                  No {activeTab} yet
                </p>
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  );
};

export default ProfilePageClient;




