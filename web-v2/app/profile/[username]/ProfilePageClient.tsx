'use client';

// Channel / profile page — real Firestore data.
//   • Channel header from users/{id} (resolved by username)
//   • Videos tab: videos where creatorId == channel.id
//   • Community tab: communityPosts where creatorId == channel.id
//   • Subscribe state via SubscribeButton (users/{uid}/subscriptions/{channelId})
// Flicks/Live/Playlists tabs surface a real empty state until those
// collections have per-channel data wired (flicks/liveStreams have no
// creator-scoped list built yet elsewhere in the app).

import { useState, useEffect, useCallback } from 'react';
import Link from 'next/link';
import {
  CheckCircle, Share2, MoreHorizontal, Edit, Loader2, Video as VideoIcon,
} from 'lucide-react';
import MainLayout from '@/components/layout/MainLayout';
import VideoCard from '@/components/video/VideoCard';
import SubscribeButton from '@/components/video/SubscribeButton';
import { VideoGridSkeleton } from '@/components/skeletons/VideoSkeleton';
import { db } from '@/lib/firebase/config';
import { useAuth } from '@/contexts/AuthContext';
import { userFirestoreService, UserFirestoreService } from '@/lib/firebase/services/UserFirestoreService';
import { videoService, type Video } from '@/lib/firebase/services/video-service';
import {
  collection, query, where, orderBy, limit, getDocs,
} from 'firebase/firestore';
import type { User } from '@/types';

interface ProfilePageClientProps {
  username: string;
}

type ProfileTab = 'home' | 'videos' | 'flicks' | 'live' | 'playlists' | 'community' | 'about';

interface CommunityPostRow {
  id: string;
  text: string;
  imageURL?: string;
  likeCount: number;
  commentCount: number;
  createdAt: Date;
}

function toCardVideo(video: Video, index: number, channel: User) {
  return {
    id: video.id,
    title: video.title,
    thumbnailURL: video.thumbnailURL,
    duration: videoService.formatDuration(video.duration),
    channel: channel.displayName,
    channelIcon: channel.profileImageURL || `https://i.pravatar.cc/150?u=${channel.id}`,
    views: videoService.formatViewCount(video.viewCount),
    timeAgo: videoService.formatTimeAgo(video.createdAt),
    isVerified: channel.isVerified,
    channelId: channel.id,
    index,
  };
}

function timeAgo(date: Date): string {
  const secs = Math.floor((Date.now() - date.getTime()) / 1000);
  if (secs < 60) return `${secs}s ago`;
  if (secs < 3600) return `${Math.floor(secs / 60)}m ago`;
  if (secs < 86400) return `${Math.floor(secs / 3600)}h ago`;
  if (secs < 604800) return `${Math.floor(secs / 86400)}d ago`;
  return date.toLocaleDateString();
}

const ProfilePageClient = ({ username: initialUsername }: ProfilePageClientProps) => {
  const [username, setUsername] = useState(initialUsername === '_fallback' ? '' : initialUsername);
  const [activeTab, setActiveTab] = useState<ProfileTab>('home');
  const { user: authUser, authResolved } = useAuth();

  const [channel, setChannel] = useState<User | null>(null);
  const [notFound, setNotFound] = useState(false);
  const [loadingChannel, setLoadingChannel] = useState(true);
  const isMeRoute = username === 'me';

  const [videos, setVideos] = useState<Video[]>([]);
  const [loadingVideos, setLoadingVideos] = useState(true);

  const [posts, setPosts] = useState<CommunityPostRow[]>([]);
  const [loadingPosts, setLoadingPosts] = useState(false);

  const isOwner = !!channel && (isMeRoute || authUser?.uid === channel.id);

  useEffect(() => {
    if (initialUsername !== '_fallback') return;
    const segments = window.location.pathname.split('/').filter(Boolean);
    const profileIndex = segments.indexOf('profile');
    const pathUsername = profileIndex >= 0 ? segments[profileIndex + 1] : '';
    if (pathUsername && pathUsername !== '_fallback') {
      setUsername(decodeURIComponent(pathUsername));
    }
  }, [initialUsername]);

  // Resolve channel by username. The "me" pseudo-route means "the signed-in
  // user's own channel" — it's not a real username, so it's resolved by uid
  // via the shared auth context instead of a Firestore username query (which
  // would never match and previously caused a false "channel not found" that
  // looked like the user had been signed out).
  useEffect(() => {
    if (!username) return;

    if (isMeRoute) {
      // Wait for auth to resolve before deciding not-found vs sign-in-required.
      if (!authResolved) return;
      if (!authUser) {
        setLoadingChannel(false);
        setNotFound(false); // handled by the "sign in required" branch below
        return;
      }
      let cancelled = false;
      setLoadingChannel(true);
      userFirestoreService.fetchUser(authUser.uid).then((profile) => {
        if (cancelled) return;
        if (profile) setChannel(profile);
        else setNotFound(true);
        setLoadingChannel(false);
      });
      return () => { cancelled = true; };
    }

    let cancelled = false;
    setLoadingChannel(true);
    userFirestoreService.fetchUserByUsername(username).then((user) => {
      if (cancelled) return;
      if (user) setChannel(user);
      else setNotFound(true);
      setLoadingChannel(false);
    });
    return () => { cancelled = true; };
  }, [username, isMeRoute, authResolved, authUser]);

  // Load this channel's videos once resolved
  useEffect(() => {
    if (!channel) return;
    let cancelled = false;
    setLoadingVideos(true);
    videoService.fetchVideosByCreator(channel.id, 48).then((rows) => {
      if (!cancelled) { setVideos(rows); setLoadingVideos(false); }
    });
    return () => { cancelled = true; };
  }, [channel]);

  // Load community posts lazily when that tab is opened
  const loadCommunityPosts = useCallback(async () => {
    if (!channel) return;
    setLoadingPosts(true);
    try {
      const snap = await getDocs(
        query(
          collection(db, 'communityPosts'),
          where('creatorId', '==', channel.id),
          orderBy('createdAt', 'desc'),
          limit(30)
        )
      );
      setPosts(snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          text: data.text ?? '',
          imageURL: data.imageURL,
          likeCount: data.likeCount ?? 0,
          commentCount: data.commentCount ?? 0,
          createdAt: data.createdAt?.toDate?.() ?? new Date(),
        };
      }));
    } catch (err) {
      console.error(err);
    } finally {
      setLoadingPosts(false);
    }
  }, [channel]);

  useEffect(() => {
    if (activeTab === 'community' && channel && posts.length === 0 && !loadingPosts) {
      loadCommunityPosts();
    }
  }, [activeTab, channel, posts.length, loadingPosts, loadCommunityPosts]);

  const tabs: { id: ProfileTab; label: string }[] = [
    { id: 'home', label: 'Home' },
    { id: 'videos', label: 'Videos' },
    { id: 'flicks', label: 'Flicks' },
    { id: 'live', label: 'Live' },
    { id: 'playlists', label: 'Playlists' },
    { id: 'community', label: 'Community' },
    { id: 'about', label: 'About' },
  ];

  if (loadingChannel) {
    return (
      <MainLayout>
        <div className="max-w-[1800px] mx-auto">
          {/* Banner skeleton */}
          <div className="w-full h-[120px] sm:h-[180px] md:h-[240px] bg-gradient-to-br from-[rgb(var(--color-surface))] to-[rgb(var(--color-surface-hover))] animate-pulse" />
          <div className="px-4 sm:px-6 py-6">
            <div className="flex flex-col sm:flex-row sm:items-start gap-4 sm:gap-6">
              <div className="w-24 h-24 sm:w-32 sm:h-32 md:w-40 md:h-40 rounded-full bg-[rgb(var(--color-surface))] animate-pulse flex-shrink-0" />
              <div className="flex-1 space-y-3 w-full pt-2">
                <div className="h-7 w-48 bg-[rgb(var(--color-surface))] rounded animate-pulse" />
                <div className="h-4 w-64 bg-[rgb(var(--color-surface))] rounded animate-pulse" />
                <div className="h-4 w-full max-w-md bg-[rgb(var(--color-surface))] rounded animate-pulse" />
              </div>
            </div>
          </div>
        </div>
      </MainLayout>
    );
  }

  if (isMeRoute && authResolved && !authUser) {
    return (
      <MainLayout>
        <div className="max-w-[1800px] mx-auto flex flex-col items-center justify-center py-32 px-4 text-center">
          <div className="w-20 h-20 rounded-full bg-[rgb(var(--color-surface))] flex items-center justify-center mb-4">
            <VideoIcon size={32} className="text-[rgb(var(--color-text-tertiary))]" />
          </div>
          <h2 className="text-xl font-bold text-[rgb(var(--color-text-primary))] mb-2">Sign in to view your channel</h2>
          <p className="text-[rgb(var(--color-text-secondary))] text-sm mb-6">
            You need to be signed in to see your own channel page.
          </p>
          <Link href="/login" className="px-5 py-2.5 bg-[rgb(var(--color-primary))] text-white text-sm font-semibold rounded-full hover:opacity-90 transition-opacity">
            Sign in
          </Link>
        </div>
      </MainLayout>
    );
  }

  if (notFound || !channel) {
    return (
      <MainLayout>
        <div className="max-w-[1800px] mx-auto flex flex-col items-center justify-center py-32 px-4 text-center">
          <div className="w-20 h-20 rounded-full bg-[rgb(var(--color-surface))] flex items-center justify-center mb-4">
            <VideoIcon size={32} className="text-[rgb(var(--color-text-tertiary))]" />
          </div>
          <h2 className="text-xl font-bold text-[rgb(var(--color-text-primary))] mb-2">This channel doesn&apos;t exist</h2>
          <p className="text-[rgb(var(--color-text-secondary))] text-sm mb-6">
            The channel you&apos;re looking for isn&apos;t available. It might have been removed or the link is incorrect.
          </p>
          <Link href="/" className="px-5 py-2.5 bg-[rgb(var(--color-primary))] text-white text-sm font-semibold rounded-full hover:opacity-90 transition-opacity">
            Go home
          </Link>
        </div>
      </MainLayout>
    );
  }

  return (
    <MainLayout>
      <div className="max-w-[1800px] mx-auto">
        {/* Banner */}
        <div className="relative w-full h-[120px] sm:h-[180px] md:h-[240px] bg-gradient-to-br from-[rgb(var(--color-surface))] to-[rgb(var(--color-surface-hover))] overflow-hidden">
          {channel.bannerImageURL ? (
            <img src={channel.bannerImageURL} alt="Channel banner" className="w-full h-full object-cover" />
          ) : (
            <div className="absolute inset-0 bg-gradient-to-br from-[rgb(var(--color-primary))]/15 via-transparent to-transparent" />
          )}
        </div>

        {/* Channel Info */}
        <div className="px-4 sm:px-6 py-5 sm:py-6">
          <div className="flex flex-col sm:flex-row sm:items-start gap-4 sm:gap-6">
            <div className="relative flex-shrink-0 -mt-10 sm:-mt-0 self-center sm:self-auto">
              <img
                src={channel.profileImageURL || `https://i.pravatar.cc/150?u=${channel.id}`}
                alt={channel.displayName}
                className="w-24 h-24 sm:w-32 sm:h-32 md:w-40 md:h-40 rounded-full ring-4 ring-[rgb(var(--color-background))] shadow-xl object-cover"
              />
            </div>

            <div className="flex-1 min-w-0 text-center sm:text-left">
              <div className="flex flex-col sm:flex-row sm:items-start justify-between gap-4 mb-1">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-center sm:justify-start gap-2 mb-1">
                    <h1 className="text-xl sm:text-2xl md:text-3xl font-bold text-[rgb(var(--color-text-primary))] truncate">
                      {channel.displayName}
                    </h1>
                    {channel.isVerified && (
                      <CheckCircle size={18} className="text-[rgb(var(--color-text-secondary))] flex-shrink-0" fill="currentColor" />
                    )}
                  </div>
                  <div className="flex items-center justify-center sm:justify-start gap-1.5 text-[13px] sm:text-sm text-[rgb(var(--color-text-secondary))] mb-3 flex-wrap">
                    <span>@{channel.username}</span>
                    <span>•</span>
                    <span>{UserFirestoreService.formatSubscriberCount(channel.subscriberCount ?? 0)}</span>
                    <span>•</span>
                    <span>{channel.videoCount ?? 0} videos</span>
                  </div>
                  {channel.bio && (
                    <p className="text-sm text-[rgb(var(--color-text-secondary))] line-clamp-2 max-w-2xl mx-auto sm:mx-0">
                      {channel.bio}
                    </p>
                  )}
                </div>

                <div className="flex items-center justify-center gap-2 flex-shrink-0">
                  {isOwner ? (
                    <Link
                      href="/studio/customization"
                      className="flex items-center gap-2 px-4 py-2 rounded-full bg-[rgb(var(--color-surface))] hover:bg-[rgb(var(--color-surface-hover))] text-[rgb(var(--color-text-primary))] font-medium text-sm transition-colors"
                    >
                      <Edit size={16} />
                      <span>Customize channel</span>
                    </Link>
                  ) : (
                    <SubscribeButton channelId={channel.id} />
                  )}
                  <button className="w-9 h-9 flex items-center justify-center rounded-full bg-[rgb(var(--color-surface))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors" aria-label="Share channel">
                    <Share2 size={16} className="text-[rgb(var(--color-text-primary))]" />
                  </button>
                  <button className="w-9 h-9 flex items-center justify-center rounded-full bg-[rgb(var(--color-surface))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors" aria-label="More options">
                    <MoreHorizontal size={16} className="text-[rgb(var(--color-text-primary))]" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div className="px-4 sm:px-6 border-b border-[rgb(var(--color-border))] sticky top-14 bg-[rgb(var(--color-background))]/95 backdrop-blur z-10">
          <div className="flex gap-6 sm:gap-8 overflow-x-auto scrollbar-hide">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`relative py-3 px-0.5 text-sm font-medium transition-colors whitespace-nowrap ${
                  activeTab === tab.id
                    ? 'text-[rgb(var(--color-text-primary))]'
                    : 'text-[rgb(var(--color-text-secondary))] hover:text-[rgb(var(--color-text-primary))]'
                }`}
              >
                {tab.label}
                {activeTab === tab.id && (
                  <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[rgb(var(--color-text-primary))] rounded-full" />
                )}
              </button>
            ))}
          </div>
        </div>

        {/* Content */}
        <div className="px-4 sm:px-6 py-6">
            {activeTab === 'home' && (
              loadingVideos ? (
                <VideoGridSkeleton count={12} />
              ) : videos.length === 0 ? (
                <EmptyTab icon={VideoIcon} message="This channel hasn't uploaded any videos yet." />
              ) : (
                <>
                  <div className="mb-8">
                    <h2 className="text-lg font-semibold text-[rgb(var(--color-text-primary))] mb-4">Featured</h2>
                    <div className="max-w-2xl">
                      <VideoCard video={toCardVideo(videos[0], 0, channel)} index={0} />
                    </div>
                  </div>
                  {videos.length > 1 && (
                    <div>
                      <h2 className="text-lg font-semibold text-[rgb(var(--color-text-primary))] mb-4">Recent Uploads</h2>
                      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6 gap-x-4 gap-y-8">
                        {videos.slice(1, 13).map((video, index) => (
                          <VideoCard key={video.id} video={toCardVideo(video, index, channel)} index={index} />
                        ))}
                      </div>
                    </div>
                  )}
                </>
              )
            )}

            {activeTab === 'videos' && (
              loadingVideos ? (
                <VideoGridSkeleton count={24} />
              ) : videos.length === 0 ? (
                <EmptyTab icon={VideoIcon} message="This channel hasn't uploaded any videos yet." />
              ) : (
                <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6 gap-x-4 gap-y-8">
                  {videos.map((video, index) => (
                    <VideoCard key={video.id} video={toCardVideo(video, index, channel)} index={index} />
                  ))}
                </div>
              )
            )}

            {activeTab === 'community' && (
              <div className="max-w-2xl">
                {loadingPosts ? (
                  <div className="flex justify-center py-16">
                    <Loader2 size={24} className="animate-spin text-[rgb(var(--color-text-secondary))]" />
                  </div>
                ) : posts.length === 0 ? (
                  <p className="text-center text-[rgb(var(--color-text-secondary))] py-16 text-sm">No community posts yet</p>
                ) : (
                  <div className="space-y-4">
                    {posts.map((post) => (
                      <div key={post.id} className="bg-[rgb(var(--color-surface))] rounded-2xl border border-[rgb(var(--color-border))] p-4">
                        <p className="text-[13px] text-[rgb(var(--color-text-tertiary))] mb-2">{timeAgo(post.createdAt)}</p>
                        {post.text && <p className="text-[14px] text-[rgb(var(--color-text-primary))] whitespace-pre-wrap mb-3">{post.text}</p>}
                        {post.imageURL && (
                          <img src={post.imageURL} alt="" className="w-full rounded-xl object-cover max-h-96 mb-3" />
                        )}
                        <div className="flex items-center gap-4 text-[12px] text-[rgb(var(--color-text-secondary))]">
                          <span>{post.likeCount} likes</span>
                          <span>{post.commentCount} comments</span>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {activeTab === 'about' && (
              <div className="max-w-4xl">
                <div className="bg-[rgb(var(--color-surface))] rounded-xl p-6 space-y-6">
                  <div>
                    <h3 className="text-sm font-semibold text-[rgb(var(--color-text-secondary))] uppercase mb-2">Description</h3>
                    <p className="text-base text-[rgb(var(--color-text-primary))]">{channel.bio || 'No description yet.'}</p>
                  </div>

                  <div className="border-t border-[rgb(var(--color-border))] pt-6">
                    <h3 className="text-sm font-semibold text-[rgb(var(--color-text-secondary))] uppercase mb-2">Stats</h3>
                    <div className="space-y-1 text-sm text-[rgb(var(--color-text-primary))]">
                      <p>Joined: {channel.createdAt ? new Date(channel.createdAt).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' }) : '—'}</p>
                      <p>{UserFirestoreService.formatSubscriberCount(channel.subscriberCount ?? 0)}</p>
                      <p>{channel.videoCount ?? 0} videos</p>
                    </div>
                  </div>

                  {channel.socialLinks && (channel.socialLinks.website || channel.socialLinks.twitter || channel.socialLinks.instagram) && (
                    <div className="border-t border-[rgb(var(--color-border))] pt-6">
                      <h3 className="text-sm font-semibold text-[rgb(var(--color-text-secondary))] uppercase mb-2">Links</h3>
                      <div className="space-y-1 text-sm">
                        {channel.socialLinks.website && (
                          <a href={channel.socialLinks.website} target="_blank" rel="noopener noreferrer" className="text-[rgb(var(--color-primary))] hover:underline block">
                            {channel.socialLinks.website}
                          </a>
                        )}
                        {channel.socialLinks.twitter && (
                          <a href={channel.socialLinks.twitter} target="_blank" rel="noopener noreferrer" className="text-[rgb(var(--color-primary))] hover:underline block">
                            {channel.socialLinks.twitter}
                          </a>
                        )}
                        {channel.socialLinks.instagram && (
                          <a href={channel.socialLinks.instagram} target="_blank" rel="noopener noreferrer" className="text-[rgb(var(--color-primary))] hover:underline block">
                            {channel.socialLinks.instagram}
                          </a>
                        )}
                      </div>
                    </div>
                  )}
                </div>
              </div>
            )}

            {['flicks', 'live', 'playlists'].includes(activeTab) && (
              <div className="py-20 text-center">
                <p className="text-[rgb(var(--color-text-secondary))] text-lg">
                  No {activeTab === 'flicks' ? 'Flicks' : activeTab} yet
                </p>
              </div>
            )}
          </div>
        </div>
    </MainLayout>
  );
};

function EmptyTab({ icon: Icon, message }: { icon: React.ElementType; message: string }) {
  return (
    <div className="py-20 text-center">
      <Icon size={40} className="mx-auto mb-3 text-[rgb(var(--color-text-tertiary))]" />
      <p className="text-[rgb(var(--color-text-secondary))] text-sm">{message}</p>
    </div>
  );
}

export default ProfilePageClient;
