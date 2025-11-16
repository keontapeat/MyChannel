'use client';

// Video Grid Component - YouTube-style video grid

import VideoCard from './VideoCard';
import { useState, useEffect } from 'react';
import type { Video } from '@/types';

const VideoGrid = () => {
  const [videos, setVideos] = useState<Video[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Mock data for now - replace with actual API call
    const mockVideos: Video[] = Array.from({ length: 12 }, (_, i) => ({
      id: `video-${i + 1}`,
      title: `Amazing Video Title ${i + 1} - This is a longer title to test truncation`,
      description: 'Video description',
      videoURL: `https://example.com/video-${i + 1}.mp4`,
      thumbnailURL: `https://picsum.photos/seed/${i + 1}/320/180`,
      duration: Math.floor(Math.random() * 3600) + 60,
      viewCount: Math.floor(Math.random() * 1000000),
      likeCount: Math.floor(Math.random() * 50000),
      dislikeCount: Math.floor(Math.random() * 1000),
      commentCount: Math.floor(Math.random() * 5000),
      shareCount: Math.floor(Math.random() * 1000),
      createdAt: new Date(Date.now() - Math.random() * 365 * 24 * 60 * 60 * 1000),
      updatedAt: new Date(),
      creatorId: 'user-1',
      creator: {
        id: 'user-1',
        username: 'creator',
        displayName: 'Creator Name',
        email: 'creator@example.com',
        profileImageURL: `https://i.pravatar.cc/150?img=${i + 1}`,
        bannerImageURL: '',
        subscriberCount: Math.floor(Math.random() * 1000000),
        videoCount: Math.floor(Math.random() * 100),
        createdAt: new Date(),
        isVerified: Math.random() > 0.5,
        isAdmin: false,
      },
      category: {
        id: 'gaming',
        name: 'Gaming',
        slug: 'gaming',
      },
      tags: ['gaming', 'tutorial', 'fun'],
      isPublic: true,
      ageRestricted: false,
      madeForKids: false,
      commentsEnabled: true,
      likesEnabled: true,
      downloadsEnabled: true,
    }));

    setTimeout(() => {
      setVideos(mockVideos);
      setIsLoading(false);
    }, 500);
  }, []);

  if (isLoading) {
    return (
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        {Array.from({ length: 12 }).map((_, i) => (
          <div key={i} className="animate-pulse">
            <div className="aspect-video bg-[rgb(var(--color-surface))] rounded-lg mb-3"></div>
            <div className="h-4 bg-[rgb(var(--color-surface))] rounded w-3/4 mb-2"></div>
            <div className="h-3 bg-[rgb(var(--color-surface))] rounded w-1/2"></div>
          </div>
        ))}
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
      {videos.map((video) => (
        <VideoCard key={video.id} video={video} />
      ))}
    </div>
  );
};

export default VideoGrid;

