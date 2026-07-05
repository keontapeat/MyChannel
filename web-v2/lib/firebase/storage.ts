// Firebase Storage Service for MyChannel Web

import {
  ref,
  uploadBytesResumable,
  getDownloadURL,
  deleteObject,
  UploadTaskSnapshot,
  StorageReference,
} from 'firebase/storage';
import { storage } from './config';

export interface UploadProgress {
  bytesTransferred: number;
  totalBytes: number;
  progress: number; // 0-100
}

export class StorageService {
  // Upload file with progress tracking
  static async uploadFile(
    file: File,
    path: string,
    onProgress?: (progress: UploadProgress) => void
  ): Promise<string> {
    try {
      const storageRef = ref(storage, path);
      const uploadTask = uploadBytesResumable(storageRef, file);

      return new Promise((resolve, reject) => {
        uploadTask.on(
          'state_changed',
          (snapshot: UploadTaskSnapshot) => {
            // Calculate progress
            const progress =
              (snapshot.bytesTransferred / snapshot.totalBytes) * 100;

            if (onProgress) {
              onProgress({
                bytesTransferred: snapshot.bytesTransferred,
                totalBytes: snapshot.totalBytes,
                progress: Math.round(progress),
              });
            }

            console.log(
              `📤 Upload progress: ${Math.round(progress)}% (${snapshot.bytesTransferred}/${snapshot.totalBytes} bytes)`
            );
          },
          (error) => {
            console.error('🚨 Upload error:', error);
            reject(error);
          },
          async () => {
            // Upload complete - get download URL
            try {
              const downloadURL = await getDownloadURL(uploadTask.snapshot.ref);
              console.log('✅ File uploaded:', downloadURL);
              resolve(downloadURL);
            } catch (error) {
              reject(error);
            }
          }
        );
      });
    } catch (error) {
      console.error('🚨 Upload file error:', error);
      throw error;
    }
  }

  // Upload video file
  // Path MUST match storage.rules: videos/{userId}/{videoId}/{filename}
  static async uploadVideo(
    file: File,
    userId: string,
    videoId: string,
    onProgress?: (progress: UploadProgress) => void
  ): Promise<string> {
    if (!userId) throw new Error('uploadVideo requires an authenticated userId');
    const path = `videos/${userId}/${videoId}/video.mp4`;
    return this.uploadFile(file, path, onProgress);
  }

  // Upload thumbnail
  // Path MUST match storage.rules: thumbnails/{userId}/{videoId}/{filename}
  static async uploadThumbnail(
    file: File,
    userId: string,
    videoId: string,
    onProgress?: (progress: UploadProgress) => void
  ): Promise<string> {
    if (!userId) throw new Error('uploadThumbnail requires an authenticated userId');
    const path = `thumbnails/${userId}/${videoId}/thumb.jpg`;
    return this.uploadFile(file, path, onProgress);
  }

  // Upload profile image
  // Path MUST match storage.rules: profile_images/{userId}/{filename}
  static async uploadProfileImage(
    file: File,
    userId: string,
    onProgress?: (progress: UploadProgress) => void
  ): Promise<string> {
    if (!userId) throw new Error('uploadProfileImage requires an authenticated userId');
    const path = `profile_images/${userId}/${Date.now()}.jpg`;
    return this.uploadFile(file, path, onProgress);
  }

  // Upload banner image
  // Path MUST match storage.rules: banner_images/{userId}/{filename}
  static async uploadBannerImage(
    file: File,
    userId: string,
    onProgress?: (progress: UploadProgress) => void
  ): Promise<string> {
    if (!userId) throw new Error('uploadBannerImage requires an authenticated userId');
    const path = `banner_images/${userId}/${Date.now()}.jpg`;
    return this.uploadFile(file, path, onProgress);
  }

  // Upload Flick video
  // Path MUST match storage.rules: flicks/{userId}/{flickId}
  static async uploadFlick(
    file: File,
    userId: string,
    flickId: string,
    onProgress?: (progress: UploadProgress) => void
  ): Promise<string> {
    if (!userId) throw new Error('uploadFlick requires an authenticated userId');
    const path = `flicks/${userId}/${flickId}.mp4`;
    return this.uploadFile(file, path, onProgress);
  }

  // Delete file
  static async deleteFile(fileURL: string): Promise<void> {
    try {
      const fileRef = ref(storage, fileURL);
      await deleteObject(fileRef);
      console.log('✅ File deleted:', fileURL);
    } catch (error) {
      console.error('🚨 Delete file error:', error);
      throw error;
    }
  }

  // Delete video
  static async deleteVideo(userId: string, videoId: string): Promise<void> {
    const path = `videos/${userId}/${videoId}/video.mp4`;
    return this.deleteFile(path);
  }

  // Delete thumbnail
  static async deleteThumbnail(userId: string, videoId: string): Promise<void> {
    const path = `thumbnails/${userId}/${videoId}/thumb.jpg`;
    return this.deleteFile(path);
  }

  // Get download URL without uploading
  static async getDownloadURL(path: string): Promise<string> {
    try {
      const storageRef = ref(storage, path);
      const url = await getDownloadURL(storageRef);
      return url;
    } catch (error) {
      console.error('🚨 Get download URL error:', error);
      throw error;
    }
  }

  // Get storage reference
  static getStorageRef(path: string): StorageReference {
    return ref(storage, path);
  }

  // Validate file size
  static validateFileSize(file: File, maxSizeMB: number): boolean {
    const maxSizeBytes = maxSizeMB * 1024 * 1024;
    return file.size <= maxSizeBytes;
  }

  // Validate file type
  static validateFileType(file: File, allowedTypes: string[]): boolean {
    return allowedTypes.includes(file.type);
  }

  // Format file size for display
  static formatFileSize(bytes: number): string {
    if (bytes === 0) return '0 Bytes';

    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
  }

  // Validate video file
  static validateVideo(file: File): { valid: boolean; error?: string } {
    // Max 2GB for videos
    if (!this.validateFileSize(file, 2048)) {
      return { valid: false, error: 'Video file too large (max 2GB)' };
    }

    const allowedTypes = ['video/mp4', 'video/webm', 'video/ogg'];
    if (!this.validateFileType(file, allowedTypes)) {
      return {
        valid: false,
        error: 'Invalid video format (only MP4, WebM, OGG allowed)',
      };
    }

    return { valid: true };
  }

  // Validate image file
  static validateImage(file: File): { valid: boolean; error?: string } {
    // Max 10MB for images
    if (!this.validateFileSize(file, 10)) {
      return { valid: false, error: 'Image file too large (max 10MB)' };
    }

    const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (!this.validateFileType(file, allowedTypes)) {
      return {
        valid: false,
        error: 'Invalid image format (only JPEG, PNG, WebP allowed)',
      };
    }

    return { valid: true };
  }

  // Validate Flick (short video)
  static validateFlick(file: File): { valid: boolean; error?: string } {
    // Max 100MB for Flicks
    if (!this.validateFileSize(file, 100)) {
      return { valid: false, error: 'Flick file too large (max 100MB)' };
    }

    const allowedTypes = ['video/mp4', 'video/webm'];
    if (!this.validateFileType(file, allowedTypes)) {
      return {
        valid: false,
        error: 'Invalid Flick format (only MP4, WebM allowed)',
      };
    }

    return { valid: true };
  }
}

// Export storage instance
export { storage };

