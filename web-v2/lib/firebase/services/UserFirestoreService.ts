// User Firestore Service - Matches iOS Implementation

import {
  query,
  where,
  orderBy,
  limit as firestoreLimit,
} from 'firebase/firestore';
import { FirestoreService } from '../firestore';
import type { User } from '@/types';

export class UserFirestoreService {
  private static instance: UserFirestoreService;
  private static readonly COLLECTION = 'users';

  private constructor() {}

  static getInstance(): UserFirestoreService {
    if (!UserFirestoreService.instance) {
      UserFirestoreService.instance = new UserFirestoreService();
    }
    return UserFirestoreService.instance;
  }

  // Fetch user by ID
  async fetchUser(userId: string): Promise<User | null> {
    try {
      return await FirestoreService.getDocument<User>(
        UserFirestoreService.COLLECTION,
        userId
      );
    } catch (error) {
      console.error('🚨 Fetch user error:', error);
      return null;
    }
  }

  // Fetch user by username
  async fetchUserByUsername(username: string): Promise<User | null> {
    try {
      const constraints = [where('username', '==', username), firestoreLimit(1)];

      const users = await FirestoreService.getDocuments<User>(
        UserFirestoreService.COLLECTION,
        constraints
      );

      return users.length > 0 ? users[0] : null;
    } catch (error) {
      console.error('🚨 Fetch user by username error:', error);
      return null;
    }
  }

  // Fetch user by email
  async fetchUserByEmail(email: string): Promise<User | null> {
    try {
      const constraints = [where('email', '==', email), firestoreLimit(1)];

      const users = await FirestoreService.getDocuments<User>(
        UserFirestoreService.COLLECTION,
        constraints
      );

      return users.length > 0 ? users[0] : null;
    } catch (error) {
      console.error('🚨 Fetch user by email error:', error);
      return null;
    }
  }

  // Fetch multiple users
  async fetchUsers(limitCount: number = 50): Promise<User[]> {
    try {
      const constraints = [
        orderBy('subscriberCount', 'desc'),
        firestoreLimit(limitCount),
      ];

      return await FirestoreService.getDocuments<User>(
        UserFirestoreService.COLLECTION,
        constraints
      );
    } catch (error) {
      console.error('🚨 Fetch users error:', error);
      return [];
    }
  }

  // Search users by username or display name
  async searchUsers(searchQuery: string, limitCount: number = 20): Promise<User[]> {
    try {
      // Note: Firestore doesn't support full-text search
      // This is client-side filtering - use Algolia for production

      const constraints = [
        orderBy('subscriberCount', 'desc'),
        firestoreLimit(limitCount * 2), // Fetch more to filter
      ];

      const users = await FirestoreService.getDocuments<User>(
        UserFirestoreService.COLLECTION,
        constraints
      );

      // Client-side filtering
      return users
        .filter(
          (user) =>
            user.username.toLowerCase().includes(searchQuery.toLowerCase()) ||
            user.displayName.toLowerCase().includes(searchQuery.toLowerCase())
        )
        .slice(0, limitCount);
    } catch (error) {
      console.error('🚨 Search users error:', error);
      return [];
    }
  }

  // Create user profile
  async createUser(userId: string, userData: Omit<User, 'id'>): Promise<void> {
    try {
      const user: User = {
        ...userData,
        id: userId,
        createdAt: new Date(),
        subscriberCount: 0,
        videoCount: 0,
        isVerified: false,
        isAdmin: false,
      };

      await FirestoreService.setDocument(
        UserFirestoreService.COLLECTION,
        userId,
        user
      );

      console.log('✅ User profile created:', userId);
    } catch (error) {
      console.error('🚨 Create user error:', error);
      throw error;
    }
  }

  // Update user profile
  async updateUser(userId: string, updates: Partial<User>): Promise<void> {
    try {
      await FirestoreService.updateDocument(
        UserFirestoreService.COLLECTION,
        userId,
        updates
      );

      console.log('✅ User profile updated:', userId);
    } catch (error) {
      console.error('🚨 Update user error:', error);
      throw error;
    }
  }

  // Increment subscriber count
  async incrementSubscriberCount(userId: string): Promise<void> {
    try {
      await FirestoreService.incrementField(
        UserFirestoreService.COLLECTION,
        userId,
        'subscriberCount',
        1
      );

      console.log('✅ Subscriber count incremented:', userId);
    } catch (error) {
      console.error('🚨 Increment subscriber count error:', error);
      throw error;
    }
  }

  // Decrement subscriber count
  async decrementSubscriberCount(userId: string): Promise<void> {
    try {
      await FirestoreService.incrementField(
        UserFirestoreService.COLLECTION,
        userId,
        'subscriberCount',
        -1
      );

      console.log('✅ Subscriber count decremented:', userId);
    } catch (error) {
      console.error('🚨 Decrement subscriber count error:', error);
      throw error;
    }
  }

  // Increment video count
  async incrementVideoCount(userId: string): Promise<void> {
    try {
      await FirestoreService.incrementField(
        UserFirestoreService.COLLECTION,
        userId,
        'videoCount',
        1
      );

      console.log('✅ Video count incremented:', userId);
    } catch (error) {
      console.error('🚨 Increment video count error:', error);
      throw error;
    }
  }

  // Decrement video count
  async decrementVideoCount(userId: string): Promise<void> {
    try {
      await FirestoreService.incrementField(
        UserFirestoreService.COLLECTION,
        userId,
        'videoCount',
        -1
      );

      console.log('✅ Video count decremented:', userId);
    } catch (error) {
      console.error('🚨 Decrement video count error:', error);
      throw error;
    }
  }

  // Delete user
  async deleteUser(userId: string): Promise<void> {
    try {
      await FirestoreService.deleteDocument(
        UserFirestoreService.COLLECTION,
        userId
      );

      console.log('✅ User deleted:', userId);
    } catch (error) {
      console.error('🚨 Delete user error:', error);
      throw error;
    }
  }

  // Check if username is available
  async isUsernameAvailable(username: string): Promise<boolean> {
    try {
      const user = await this.fetchUserByUsername(username);
      return user === null;
    } catch (error) {
      console.error('🚨 Check username availability error:', error);
      return false;
    }
  }

  // Format subscriber count (1.2M, 850K, etc.)
  static formatSubscriberCount(count: number): string {
    if (count >= 1000000) {
      return (count / 1000000).toFixed(1) + 'M subscribers';
    } else if (count >= 1000) {
      return (count / 1000).toFixed(1) + 'K subscribers';
    }
    return count + ' subscribers';
  }
}

// Export singleton instance
export const userFirestoreService = UserFirestoreService.getInstance();

