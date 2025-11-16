// Video Firestore Service - Matches iOS Implementation

import {
  query,
  where,
  orderBy,
  limit as firestoreLimit,
} from 'firebase/firestore';
import { FirestoreService } from '../firestore';
import type { Video, VideoCategory, SearchFilters } from '@/types';

export class VideoFirestoreService {
  private static instance: VideoFirestoreService;
  private static readonly COLLECTION = 'videos';

  private constructor() {}

  static getInstance(): VideoFirestoreService {
    if (!VideoFirestoreService.instance) {
      VideoFirestoreService.instance = new VideoFirestoreService();
    }
    return VideoFirestoreService.instance;
  }

  // Fetch video by ID
  async fetchVideo(videoId: string): Promise<Video | null> {
    try {
      return await FirestoreService.getDocument<Video>(
        VideoFirestoreService.COLLECTION,
        videoId
      );
    } catch (error) {
      console.error('🚨 Fetch video error:', error);
      return null;
    }
  }

  // Fetch multiple videos
  async fetchVideos(limitCount: number = 24): Promise<Video[]> {
    try {
      const constraints = [
        where('isPublic', '==', true),
        orderBy('createdAt', 'desc'),
        firestoreLimit(limitCount),
      ];

      return await FirestoreService.getDocuments<Video>(
        VideoFirestoreService.COLLECTION,
        constraints
      );
    } catch (error) {
      console.error('🚨 Fetch videos error:', error);
      return [];
    }
  }

  // Fetch trending videos
  async fetchTrendingVideos(limitCount: number = 24): Promise<Video[]> {
    try {
      const constraints = [
        where('isPublic', '==', true),
        orderBy('viewCount', 'desc'),
        firestoreLimit(limitCount),
      ];

      return await FirestoreService.getDocuments<Video>(
        VideoFirestoreService.COLLECTION,
        constraints
      );
    } catch (error) {
      console.error('🚨 Fetch trending videos error:', error);
      return [];
    }
  }

  // Fetch videos by category
  async fetchVideosByCategory(
    category: string,
    limitCount: number = 24
  ): Promise<Video[]> {
    try {
      const constraints = [
        where('isPublic', '==', true),
        where('category', '==', category),
        orderBy('createdAt', 'desc'),
        firestoreLimit(limitCount),
      ];

      return await FirestoreService.getDocuments<Video>(
        VideoFirestoreService.COLLECTION,
        constraints
      );
    } catch (error) {
      console.error('🚨 Fetch videos by category error:', error);
      return [];
    }
  }

  // Fetch videos by creator
  async fetchVideosByCreator(
    creatorId: string,
    limitCount: number = 24
  ): Promise<Video[]> {
    try {
      const constraints = [
        where('creatorId', '==', creatorId),
        where('isPublic', '==', true),
        orderBy('createdAt', 'desc'),
        firestoreLimit(limitCount),
      ];

      return await FirestoreService.getDocuments<Video>(
        VideoFirestoreService.COLLECTION,
        constraints
      );
    } catch (error) {
      console.error('🚨 Fetch videos by creator error:', error);
      return [];
    }
  }

  // Search videos
  async searchVideos(
    searchQuery: string,
    filters?: SearchFilters,
    limitCount: number = 50
  ): Promise<Video[]> {
    try {
      // Note: Firestore doesn't support full-text search
      // You'll need to use Algolia or similar for production
      // This is a basic implementation

      const constraints = [
        where('isPublic', '==', true),
        orderBy('createdAt', 'desc'),
        firestoreLimit(limitCount),
      ];

      // Add category filter if provided
      if (filters?.category) {
        constraints.unshift(where('category', '==', filters.category));
      }

      const videos = await FirestoreService.getDocuments<Video>(
        VideoFirestoreService.COLLECTION,
        constraints
      );

      // Client-side filtering by title/description
      return videos.filter(
        (video) =>
          video.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
          video.description.toLowerCase().includes(searchQuery.toLowerCase())
      );
    } catch (error) {
      console.error('🚨 Search videos error:', error);
      return [];
    }
  }

  // Save video
  async saveVideo(video: Omit<Video, 'id'>): Promise<string> {
    try {
      const videoId = this.generateVideoId();
      const videoWithId: Video = {
        ...video,
        id: videoId,
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      await FirestoreService.setDocument(
        VideoFirestoreService.COLLECTION,
        videoId,
        videoWithId
      );

      console.log('✅ Video saved:', videoId);
      return videoId;
    } catch (error) {
      console.error('🚨 Save video error:', error);
      throw error;
    }
  }

  // Update video metadata
  async updateVideoMetadata(
    videoId: string,
    updates: Partial<Video>
  ): Promise<void> {
    try {
      await FirestoreService.updateDocument(
        VideoFirestoreService.COLLECTION,
        videoId,
        {
          ...updates,
          updatedAt: new Date(),
        }
      );

      console.log('✅ Video metadata updated:', videoId);
    } catch (error) {
      console.error('🚨 Update video metadata error:', error);
      throw error;
    }
  }

  // Increment view count
  async incrementViewCount(videoId: string): Promise<void> {
    try {
      await FirestoreService.incrementField(
        VideoFirestoreService.COLLECTION,
        videoId,
        'viewCount',
        1
      );

      console.log('✅ View count incremented:', videoId);
    } catch (error) {
      console.error('🚨 Increment view count error:', error);
      throw error;
    }
  }

  // Increment like count
  async incrementLikeCount(videoId: string): Promise<void> {
    try {
      await FirestoreService.incrementField(
        VideoFirestoreService.COLLECTION,
        videoId,
        'likeCount',
        1
      );

      console.log('✅ Like count incremented:', videoId);
    } catch (error) {
      console.error('🚨 Increment like count error:', error);
      throw error;
    }
  }

  // Decrement like count
  async decrementLikeCount(videoId: string): Promise<void> {
    try {
      await FirestoreService.incrementField(
        VideoFirestoreService.COLLECTION,
        videoId,
        'likeCount',
        -1
      );

      console.log('✅ Like count decremented:', videoId);
    } catch (error) {
      console.error('🚨 Decrement like count error:', error);
      throw error;
    }
  }

  // Increment comment count
  async incrementCommentCount(videoId: string): Promise<void> {
    try {
      await FirestoreService.incrementField(
        VideoFirestoreService.COLLECTION,
        videoId,
        'commentCount',
        1
      );

      console.log('✅ Comment count incremented:', videoId);
    } catch (error) {
      console.error('🚨 Increment comment count error:', error);
      throw error;
    }
  }

  // Increment share count
  async incrementShareCount(videoId: string): Promise<void> {
    try {
      await FirestoreService.incrementField(
        VideoFirestoreService.COLLECTION,
        videoId,
        'shareCount',
        1
      );

      console.log('✅ Share count incremented:', videoId);
    } catch (error) {
      console.error('🚨 Increment share count error:', error);
      throw error;
    }
  }

  // Delete video
  async deleteVideo(videoId: string): Promise<void> {
    try {
      await FirestoreService.deleteDocument(
        VideoFirestoreService.COLLECTION,
        videoId
      );

      console.log('✅ Video deleted:', videoId);
    } catch (error) {
      console.error('🚨 Delete video error:', error);
      throw error;
    }
  }

  // Generate unique video ID
  private generateVideoId(): string {
    return `video_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  // Format duration (seconds to MM:SS or HH:MM:SS)
  static formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = Math.floor(seconds % 60);

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${minutes}:${secs.toString().padStart(2, '0')}`;
  }

  // Format view count (1.2M, 850K, etc.)
  static formatViewCount(count: number): string {
    if (count >= 1000000) {
      return (count / 1000000).toFixed(1) + 'M';
    } else if (count >= 1000) {
      return (count / 1000).toFixed(1) + 'K';
    }
    return count.toString();
  }

  // Time ago formatter
  static formatTimeAgo(date: Date): string {
    const seconds = Math.floor((Date.now() - date.getTime()) / 1000);

    if (seconds < 60) return 'just now';
    if (seconds < 3600) return Math.floor(seconds / 60) + ' minutes ago';
    if (seconds < 86400) return Math.floor(seconds / 3600) + ' hours ago';
    if (seconds < 2592000) return Math.floor(seconds / 86400) + ' days ago';
    if (seconds < 31536000)
      return Math.floor(seconds / 2592000) + ' months ago';
    return Math.floor(seconds / 31536000) + ' years ago';
  }
}

// Export singleton instance
export const videoFirestoreService = VideoFirestoreService.getInstance();

