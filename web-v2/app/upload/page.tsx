'use client';

// Video Upload Page

import { useState, useRef } from 'react';
import { Upload, X, Film, Image as ImageIcon } from 'lucide-react';
import { StorageService } from '@/lib/firebase/storage';
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import { useRouter } from 'next/navigation';

const UploadPage = () => {
  const router = useRouter();
  const [videoFile, setVideoFile] = useState<File | null>(null);
  const [thumbnailFile, setThumbnailFile] = useState<File | null>(null);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState('gaming');
  const [tags, setTags] = useState<string[]>([]);
  const [tagInput, setTagInput] = useState('');
  const [isPublic, setIsPublic] = useState(true);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState('');

  const videoInputRef = useRef<HTMLInputElement>(null);
  const thumbnailInputRef = useRef<HTMLInputElement>(null);

  const categories = [
    'Gaming', 'Movies', 'TV Shows', 'Music', 'Sports', 'News',
    'Education', 'Technology', 'Cooking', 'Travel', 'Comedy', 'Other'
  ];

  const handleVideoSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const validation = StorageService.validateVideo(file);
      if (!validation.valid) {
        setError(validation.error || 'Invalid video file');
        return;
      }
      setVideoFile(file);
      setError('');
    }
  };

  const handleThumbnailSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const validation = StorageService.validateImage(file);
      if (!validation.valid) {
        setError(validation.error || 'Invalid image file');
        return;
      }
      setThumbnailFile(file);
      setError('');
    }
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    const file = e.dataTransfer.files[0];
    if (file) {
      const validation = StorageService.validateVideo(file);
      if (!validation.valid) {
        setError(validation.error || 'Invalid video file');
        return;
      }
      setVideoFile(file);
      setError('');
    }
  };

  const addTag = () => {
    if (tagInput && !tags.includes(tagInput)) {
      setTags([...tags, tagInput]);
      setTagInput('');
    }
  };

  const removeTag = (tagToRemove: string) => {
    setTags(tags.filter((tag) => tag !== tagToRemove));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!videoFile) {
      setError('Please select a video file');
      return;
    }

    if (!title) {
      setError('Please enter a video title');
      return;
    }

    setIsUploading(true);
    setError('');

    try {
      const videoId = `video_${Date.now()}`;

      // Upload video
      const videoURL = await StorageService.uploadVideo(
        videoFile,
        videoId,
        (progress) => {
          setUploadProgress(progress.progress);
        }
      );

      // Upload thumbnail if provided
      let thumbnailURL = '';
      if (thumbnailFile) {
        thumbnailURL = await StorageService.uploadThumbnail(thumbnailFile, videoId);
      }

      // Save video metadata to Firestore
      const uid = auth?.currentUser?.uid ?? 'anonymous';
      const docRef = await addDoc(collection(db, 'videos'), {
        id: videoId,
        title,
        description,
        category,
        tags,
        isPublic,
        videoURL,
        thumbnailURL: thumbnailURL || '',
        creatorId: uid,
        viewCount: 0,
        likeCount: 0,
        dislikeCount: 0,
        commentCount: 0,
        shareCount: 0,
        duration: 0,
        ageRestricted: false,
        madeForKids: false,
        commentsEnabled: true,
        likesEnabled: true,
        downloadsEnabled: false,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });

      console.log('✅ Video saved to Firestore:', docRef.id);

      // Reset form
      setVideoFile(null);
      setThumbnailFile(null);
      setTitle('');
      setDescription('');
      setTags([]);
      setUploadProgress(0);
      setIsUploading(false);

      router.push(`/watch/${docRef.id}`);
    } catch (error) {
      console.error('Upload error:', error);
      setError('Upload failed. Please try again.');
      setIsUploading(false);
    }
  };

  return (
    <div className="max-w-5xl mx-auto p-6">
      <h1 className="text-2xl font-bold text-[rgb(var(--color-text-primary))] mb-6">
        Upload Video
      </h1>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Video Upload */}
        <div>
          <label className="block text-sm font-medium text-[rgb(var(--color-text-primary))] mb-2">
            Video File *
          </label>

          {!videoFile ? (
            <div
              onDrop={handleDrop}
              onDragOver={(e) => e.preventDefault()}
              onClick={() => videoInputRef.current?.click()}
              className="border-2 border-dashed border-[rgb(var(--color-border))] rounded-lg p-12 text-center cursor-pointer hover:border-[rgb(var(--color-primary))] hover:bg-[rgb(var(--color-surface))] transition-colors"
            >
              <Film size={48} className="mx-auto mb-4 text-[rgb(var(--color-text-secondary))]" />
              <p className="text-sm text-[rgb(var(--color-text-primary))] mb-1">
                Drag and drop video file or click to browse
              </p>
              <p className="text-xs text-[rgb(var(--color-text-secondary))]">
                MP4, WebM, or OGG (max 2GB)
              </p>
            </div>
          ) : (
            <div className="flex items-center gap-4 p-4 bg-[rgb(var(--color-surface))] rounded-lg">
              <Film size={24} className="text-[rgb(var(--color-primary))]" />
              <div className="flex-1">
                <p className="text-sm font-medium text-[rgb(var(--color-text-primary))]">
                  {videoFile.name}
                </p>
                <p className="text-xs text-[rgb(var(--color-text-secondary))]">
                  {StorageService.formatFileSize(videoFile.size)}
                </p>
              </div>
              <button
                type="button"
                onClick={() => setVideoFile(null)}
                className="p-1 hover:bg-[rgb(var(--color-surface-hover))] rounded-full"
              >
                <X size={20} className="text-[rgb(var(--color-text-secondary))]" />
              </button>
            </div>
          )}

          <input
            ref={videoInputRef}
            type="file"
            accept="video/*"
            onChange={handleVideoSelect}
            className="hidden"
          />
        </div>

        {/* Thumbnail Upload */}
        <div>
          <label className="block text-sm font-medium text-[rgb(var(--color-text-primary))] mb-2">
            Thumbnail (Optional)
          </label>

          {!thumbnailFile ? (
            <button
              type="button"
              onClick={() => thumbnailInputRef.current?.click()}
              className="flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-surface))] rounded-lg hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
            >
              <ImageIcon size={20} className="text-[rgb(var(--color-text-primary))]" />
              <span className="text-sm text-[rgb(var(--color-text-primary))]">
                Upload Thumbnail
              </span>
            </button>
          ) : (
            <div className="flex items-center gap-4 p-4 bg-[rgb(var(--color-surface))] rounded-lg">
              <img
                src={URL.createObjectURL(thumbnailFile)}
                alt="Thumbnail"
                className="w-20 h-12 object-cover rounded"
              />
              <div className="flex-1">
                <p className="text-sm font-medium text-[rgb(var(--color-text-primary))]">
                  {thumbnailFile.name}
                </p>
                <p className="text-xs text-[rgb(var(--color-text-secondary))]">
                  {StorageService.formatFileSize(thumbnailFile.size)}
                </p>
              </div>
              <button
                type="button"
                onClick={() => setThumbnailFile(null)}
                className="p-1 hover:bg-[rgb(var(--color-surface-hover))] rounded-full"
              >
                <X size={20} className="text-[rgb(var(--color-text-secondary))]" />
              </button>
            </div>
          )}

          <input
            ref={thumbnailInputRef}
            type="file"
            accept="image/*"
            onChange={handleThumbnailSelect}
            className="hidden"
          />
        </div>

        {/* Title */}
        <div>
          <label className="block text-sm font-medium text-[rgb(var(--color-text-primary))] mb-2">
            Title *
          </label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Enter video title"
            className="w-full px-4 py-2 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-lg text-sm text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] focus:border-[rgb(var(--color-primary))] outline-none"
            required
          />
        </div>

        {/* Description */}
        <div>
          <label className="block text-sm font-medium text-[rgb(var(--color-text-primary))] mb-2">
            Description
          </label>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Tell viewers about your video"
            rows={5}
            className="w-full px-4 py-2 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-lg text-sm text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] focus:border-[rgb(var(--color-primary))] outline-none resize-none"
          />
        </div>

        {/* Category */}
        <div>
          <label className="block text-sm font-medium text-[rgb(var(--color-text-primary))] mb-2">
            Category
          </label>
          <select
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            className="w-full px-4 py-2 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-lg text-sm text-[rgb(var(--color-text-primary))] focus:border-[rgb(var(--color-primary))] outline-none"
          >
            {categories.map((cat) => (
              <option key={cat} value={cat.toLowerCase()}>
                {cat}
              </option>
            ))}
          </select>
        </div>

        {/* Tags */}
        <div>
          <label className="block text-sm font-medium text-[rgb(var(--color-text-primary))] mb-2">
            Tags
          </label>
          <div className="flex gap-2 mb-2">
            <input
              type="text"
              value={tagInput}
              onChange={(e) => setTagInput(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addTag())}
              placeholder="Add tag"
              className="flex-1 px-4 py-2 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-lg text-sm text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] focus:border-[rgb(var(--color-primary))] outline-none"
            />
            <button
              type="button"
              onClick={addTag}
              className="px-4 py-2 bg-[rgb(var(--color-primary))] text-white rounded-lg hover:bg-[rgb(var(--color-primary-hover))] transition-colors"
            >
              Add
            </button>
          </div>

          {tags.length > 0 && (
            <div className="flex flex-wrap gap-2">
              {tags.map((tag) => (
                <span
                  key={tag}
                  className="flex items-center gap-1 px-3 py-1 bg-[rgb(var(--color-surface))] rounded-full text-sm"
                >
                  <span className="text-[rgb(var(--color-text-primary))]">#{tag}</span>
                  <button
                    type="button"
                    onClick={() => removeTag(tag)}
                    className="hover:text-[rgb(var(--color-primary))]"
                  >
                    <X size={14} />
                  </button>
                </span>
              ))}
            </div>
          )}
        </div>

        {/* Privacy */}
        <div>
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={isPublic}
              onChange={(e) => setIsPublic(e.target.checked)}
              className="w-4 h-4"
            />
            <span className="text-sm text-[rgb(var(--color-text-primary))]">
              Make this video public
            </span>
          </label>
        </div>

        {/* Error Message */}
        {error && (
          <div className="p-4 bg-red-500/10 border border-red-500 rounded-lg text-sm text-red-500">
            {error}
          </div>
        )}

        {/* Upload Progress */}
        {isUploading && (
          <div>
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm text-[rgb(var(--color-text-primary))]">
                Uploading...
              </span>
              <span className="text-sm font-medium text-[rgb(var(--color-primary))]">
                {uploadProgress}%
              </span>
            </div>
            <div className="h-2 bg-[rgb(var(--color-surface))] rounded-full overflow-hidden">
              <div
                className="h-full bg-[rgb(var(--color-primary))] transition-all duration-300"
                style={{ width: `${uploadProgress}%` }}
              />
            </div>
          </div>
        )}

        {/* Submit Button */}
        <button
          type="submit"
          disabled={isUploading || !videoFile || !title}
          className="w-full py-3 bg-[rgb(var(--color-primary))] text-white font-medium rounded-lg hover:bg-[rgb(var(--color-primary-hover))] disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {isUploading ? 'Uploading...' : 'Upload Video'}
        </button>
      </form>
    </div>
  );
};

export default UploadPage;

