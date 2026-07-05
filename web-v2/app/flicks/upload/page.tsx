'use client';

// Flicks Upload Page - Short-Form Video Upload

import { useState, useRef } from 'react';
import { Upload, X, Film, Music, Hash } from 'lucide-react';
import { StorageService } from '@/lib/firebase/storage';
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import { useRouter } from 'next/navigation';

const FlicksUploadPage = () => {
  const router = useRouter();
  const [videoFile, setVideoFile] = useState<File | null>(null);
  const [videoPreview, setVideoPreview] = useState<string>('');
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [tags, setTags] = useState<string[]>([]);
  const [tagInput, setTagInput] = useState('');
  const [musicTrack, setMusicTrack] = useState('');
  const [uploadProgress, setUploadProgress] = useState(0);
  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState('');

  const videoInputRef = useRef<HTMLInputElement>(null);

  const handleVideoSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      // Validate Flick (max 60 seconds, max 100MB)
      const validation = StorageService.validateFlick(file);
      if (!validation.valid) {
        setError(validation.error || 'Invalid video file');
        return;
      }

      // Check duration (would need actual video metadata in production)
      setVideoFile(file);
      setVideoPreview(URL.createObjectURL(file));
      setError('');
    }
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    const file = e.dataTransfer.files[0];
    if (file) {
      const validation = StorageService.validateFlick(file);
      if (!validation.valid) {
        setError(validation.error || 'Invalid video file');
        return;
      }
      setVideoFile(file);
      setVideoPreview(URL.createObjectURL(file));
      setError('');
    }
  };

  const addTag = () => {
    if (tagInput && tags.length < 10 && !tags.includes(tagInput)) {
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
      setError('Please enter a title');
      return;
    }

    // Require an authenticated user — flick uploads are owner-scoped in Storage rules.
    const uid = auth?.currentUser?.uid;
    if (!uid) {
      setError('Please sign in to upload a Flick.');
      router.push('/login');
      return;
    }

    setIsUploading(true);
    setError('');

    try {
      const flickId = `flick_${Date.now()}`;

      // Upload Flick video
      const videoURL = await StorageService.uploadFlick(
        videoFile,
        uid,
        flickId,
        (progress) => {
          setUploadProgress(progress.progress);
        }
      );

      // Save Flick metadata to Firestore
      const docRef = await addDoc(collection(db, 'flicks'), {
        id: flickId,
        title,
        description,
        tags,
        musicTrack: musicTrack || null,
        videoURL,
        thumbnailURL: '',
        creatorId: uid,
        creatorName: auth?.currentUser?.displayName ?? 'Creator',
        creatorAvatar: auth?.currentUser?.photoURL ?? '',
        viewCount: 0,
        likeCount: 0,
        commentCount: 0,
        shareCount: 0,
        isPublic: true,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });

      console.log('✅ Flick saved to Firestore:', docRef.id);

      // Reset form
      setVideoFile(null);
      setVideoPreview('');
      setTitle('');
      setDescription('');
      setTags([]);
      setMusicTrack('');
      setUploadProgress(0);
      setIsUploading(false);
      router.push('/flicks');
    } catch (error) {
      console.error('Upload error:', error);
      setError('Upload failed. Please try again.');
      setIsUploading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))] p-6">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-2xl font-bold text-[rgb(var(--color-text-primary))] mb-6">
          Upload Flick
        </h1>

        <form onSubmit={handleSubmit} className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Video Upload/Preview */}
            <div>
              <label className="block text-sm font-medium text-[rgb(var(--color-text-primary))] mb-2">
                Video *
              </label>

              {!videoFile ? (
                <div
                  onDrop={handleDrop}
                  onDragOver={(e) => e.preventDefault()}
                  onClick={() => videoInputRef.current?.click()}
                  className="aspect-[9/16] border-2 border-dashed border-[rgb(var(--color-border))] rounded-lg p-8 flex flex-col items-center justify-center cursor-pointer hover:border-[rgb(var(--color-primary))] hover:bg-[rgb(var(--color-surface))] transition-colors"
                >
                  <Film size={48} className="mx-auto mb-4 text-[rgb(var(--color-text-secondary))]" />
                  <p className="text-sm text-[rgb(var(--color-text-primary))] mb-1 text-center">
                    Drop video here or click to browse
                  </p>
                  <p className="text-xs text-[rgb(var(--color-text-secondary))] text-center">
                    MP4 or WebM • Max 60 seconds • Max 100MB
                  </p>
                </div>
              ) : (
                <div className="relative aspect-[9/16] rounded-lg overflow-hidden bg-black">
                  <video
                    src={videoPreview}
                    className="w-full h-full object-cover"
                    controls
                  />
                  <button
                    type="button"
                    onClick={() => {
                      setVideoFile(null);
                      setVideoPreview('');
                    }}
                    className="absolute top-2 right-2 p-2 bg-black/50 hover:bg-black/70 rounded-full transition-colors"
                  >
                    <X size={20} className="text-white" />
                  </button>
                </div>
              )}

              <input
                ref={videoInputRef}
                type="file"
                accept="video/mp4,video/webm"
                onChange={handleVideoSelect}
                className="hidden"
              />
            </div>

            {/* Metadata Form */}
            <div className="space-y-4">
              {/* Title */}
              <div>
                <label className="block text-sm font-medium text-[rgb(var(--color-text-primary))] mb-2">
                  Title *
                </label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="Give your Flick a title"
                  maxLength={100}
                  className="w-full px-4 py-2 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-lg text-sm text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] focus:border-[rgb(var(--color-primary))] outline-none"
                  required
                />
                <p className="text-xs text-[rgb(var(--color-text-tertiary))] mt-1">
                  {title.length}/100
                </p>
              </div>

              {/* Description */}
              <div>
                <label className="block text-sm font-medium text-[rgb(var(--color-text-primary))] mb-2">
                  Description
                </label>
                <textarea
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Tell viewers about your Flick"
                  rows={4}
                  maxLength={300}
                  className="w-full px-4 py-2 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-lg text-sm text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] focus:border-[rgb(var(--color-primary))] outline-none resize-none"
                />
                <p className="text-xs text-[rgb(var(--color-text-tertiary))] mt-1">
                  {description.length}/300
                </p>
              </div>

              {/* Tags */}
              <div>
                <label className="block text-sm font-medium text-[rgb(var(--color-text-primary))] mb-2">
                  Tags (Max 10)
                </label>
                <div className="flex gap-2 mb-2">
                  <div className="relative flex-1">
                    <Hash size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[rgb(var(--color-text-tertiary))]" />
                    <input
                      type="text"
                      value={tagInput}
                      onChange={(e) => setTagInput(e.target.value)}
                      onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addTag())}
                      placeholder="Add tag"
                      disabled={tags.length >= 10}
                      className="w-full pl-9 pr-4 py-2 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-lg text-sm text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] focus:border-[rgb(var(--color-primary))] outline-none disabled:opacity-50"
                    />
                  </div>
                  <button
                    type="button"
                    onClick={addTag}
                    disabled={!tagInput || tags.length >= 10}
                    className="px-4 py-2 bg-[rgb(var(--color-primary))] text-white rounded-lg hover:bg-[rgb(var(--color-primary-hover))] disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
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

              {/* Music Track */}
              <div>
                <label className="block text-sm font-medium text-[rgb(var(--color-text-primary))] mb-2">
                  Music Track (Optional)
                </label>
                <div className="relative">
                  <Music size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[rgb(var(--color-text-tertiary))]" />
                  <input
                    type="text"
                    value={musicTrack}
                    onChange={(e) => setMusicTrack(e.target.value)}
                    placeholder="Add a music track"
                    className="w-full pl-9 pr-4 py-2 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-lg text-sm text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] focus:border-[rgb(var(--color-primary))] outline-none"
                  />
                </div>
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
                {isUploading ? 'Uploading...' : 'Upload Flick'}
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
};

export default FlicksUploadPage;

