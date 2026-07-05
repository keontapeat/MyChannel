'use client';

// Video Upload Page

import { useState, useRef } from 'react';
import { Upload, X, Film, Image as ImageIcon, ShieldAlert } from 'lucide-react';
import { StorageService } from '@/lib/firebase/storage';
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import { useRouter } from 'next/navigation';

interface ModerationVerdict {
  safe: boolean;
  requiresReview: boolean;
  severity: 'low' | 'medium' | 'high' | 'critical';
  recommendedAction: 'allow' | 'monitor' | 'review' | 'block';
  reasons: string[];
}

// Calls the real moderation backend (services/moderation) before publishing.
// This is a pre-flight UX check only — the authoritative enforcement pass
// runs server-side and unconditionally in Cloud Functions
// (functions/main.py moderate_video_on_upload) regardless of what happens
// here, so a network failure here can't be used to bypass moderation.
async function checkModeration(
  title: string,
  description: string,
  thumbnailUri: string
): Promise<ModerationVerdict | null> {
  const apiUrl = process.env.NEXT_PUBLIC_MODERATION_API_URL;
  if (!apiUrl) return null;

  try {
    const idToken = await auth?.currentUser?.getIdToken();
    if (!idToken) return null;

    const res = await fetch(`${apiUrl}/v1/moderate/video`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${idToken}` },
      body: JSON.stringify({ title, description, thumbnailUri }),
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

// Creates the video_transcode_jobs doc that triggers functions/main.py's
// start_transcode_job Cloud Function (real GCP Transcoder API → multi-quality
// HLS/DASH). Previously nothing in the app wrote this doc, so every video
// played back as a single progressive MP4 and the whole transcode pipeline
// (already built and working) never ran. Best-effort: failure here doesn't
// block publishing — the video still plays via the direct MP4 URL, it just
// won't get adaptive-bitrate HLS renditions.
// `firestoreVideoId` is the actual videos/{id} document id the transcode
// webhook must update. `storagePathVideoId` is the id segment used in the
// gs:// object path StorageService.uploadVideo wrote to — note these are NOT
// the same value today (the Firestore doc id comes from addDoc's auto-id,
// while the storage path uses the locally-generated `video_${timestamp}`
// string), so both must be passed explicitly rather than assumed equal.
async function enqueueTranscodeJob(
  firestoreVideoId: string,
  storagePathVideoId: string,
  creatorId: string
): Promise<void> {
  const bucket = process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET;
  if (!bucket) return;

  try {
    await addDoc(collection(db, 'video_transcode_jobs'), {
      videoId: firestoreVideoId,
      creatorId,
      sourcePath: `gs://${bucket}/videos/${creatorId}/${storagePathVideoId}/video.mp4`,
      outputBucket: bucket,
      createdAt: serverTimestamp(),
      status: 'pending',
    });
  } catch (err) {
    console.error('Failed to enqueue transcode job:', err);
  }
}

const UploadPage = () => {
  const router = useRouter();
  const [videoFile, setVideoFile] = useState<File | null>(null);
  const [thumbnailFile, setThumbnailFile] = useState<File | null>(null);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState('gaming');
  const [tags, setTags] = useState<string[]>([]);
  const [tagInput, setTagInput] = useState('');
  const [visibility, setVisibility] = useState<'public' | 'unlisted' | 'private'>('public');
  const [ageRestricted, setAgeRestricted] = useState(false);
  const [madeForKids, setMadeForKids] = useState(false);
  const [commentsEnabled, setCommentsEnabled] = useState(true);
  const [isPremiere, setIsPremiere] = useState(false);
  const [scheduledAt, setScheduledAt] = useState('');
  const [allowedRegions, setAllowedRegions] = useState<string[]>([]);
  const [blockedRegions, setBlockedRegions] = useState<string[]>([]);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [isUploading, setIsUploading] = useState(false);
  const [isCheckingModeration, setIsCheckingModeration] = useState(false);
  const [error, setError] = useState('');
  const [moderationWarning, setModerationWarning] = useState<ModerationVerdict | null>(null);

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

    // Require an authenticated user — uploads are owner-scoped in Storage rules
    // and anonymous uploads would be rejected by the security rules anyway.
    const uid = auth?.currentUser?.uid;
    if (!uid) {
      setError('Please sign in to upload a video.');
      router.push('/login');
      return;
    }

    setError('');
    setModerationWarning(null);

    // Pre-flight moderation check — gives the creator immediate feedback
    // instead of silently publishing and finding out later via a strike.
    // Only hard-blocks on a clear 'block' verdict; 'review' still publishes
    // (server-side enforcement already queues it for admin review) but
    // shows a warning so the creator knows why.
    // Note: the thumbnail hasn't been uploaded yet at this point, so there's
    // no URL to pass — the title/description text pass is still meaningful
    // pre-flight signal; the server-side Cloud Function trigger re-checks
    // everything (including the final thumbnailURL) once the doc is created.
    setIsCheckingModeration(true);
    const verdict = await checkModeration(title, description, '');
    setIsCheckingModeration(false);

    if (verdict && verdict.recommendedAction === 'block') {
      setError(
        `This video can't be published: ${verdict.reasons[0] || 'it violates community guidelines'}.`
      );
      return;
    }
    if (verdict && verdict.requiresReview) {
      setModerationWarning(verdict);
    }

    setIsUploading(true);

    try {
      const videoId = `video_${Date.now()}`;

      // Upload video
      const videoURL = await StorageService.uploadVideo(
        videoFile,
        uid,
        videoId,
        (progress) => {
          setUploadProgress(progress.progress);
        }
      );

      // Upload thumbnail if provided
      let thumbnailURL = '';
      if (thumbnailFile) {
        thumbnailURL = await StorageService.uploadThumbnail(thumbnailFile, uid, videoId);
      }

      // Save video metadata to Firestore
      const isPublic = visibility === 'public';
      const docData: Record<string, any> = {
        id: videoId,
        title,
        description,
        category,
        tags,
        isPublic,
        status: visibility,
        videoURL,
        thumbnailURL: thumbnailURL || '',
        creatorId: uid,
        viewCount: 0,
        likeCount: 0,
        dislikeCount: 0,
        commentCount: 0,
        shareCount: 0,
        duration: 0,
        ageRestricted,
        madeForKids,
        commentsEnabled,
        likesEnabled: true,
        downloadsEnabled: false,
        isPremiere,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      };

      if (isPremiere && scheduledAt) {
        docData.scheduledAt = new Date(scheduledAt);
        docData.status = 'scheduled';
        docData.isPublic = false;
      }

      if (blockedRegions.length > 0) {
        docData.blockedRegions = blockedRegions;
      }

      const docRef = await addDoc(collection(db, 'videos'), docData);

      console.log('✅ Video saved to Firestore:', docRef.id);

      // Kick off real server-side transcoding (multi-quality HLS/DASH via
      // GCP Transcoder API — see functions/main.py start_transcode_job).
      // Best-effort: the video is already playable via the direct MP4 URL
      // above even if this fails, so we don't block on it or surface an error.
      await enqueueTranscodeJob(docRef.id, videoId, uid);

      // Reset form
      setVideoFile(null);
      setThumbnailFile(null);
      setTitle('');
      setDescription('');
      setTags([]);
      setUploadProgress(0);
      setIsUploading(false);
      setAgeRestricted(false);
      setMadeForKids(false);
      setIsPremiere(false);
      setScheduledAt('');

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

        {/* Visibility */}
        <div>
          <label className="block text-sm font-medium text-[rgb(var(--color-text-primary))] mb-2">
            Visibility
          </label>
          <div className="space-y-2">
            {(['public', 'unlisted', 'private'] as const).map((v) => (
              <label key={v} className="flex items-center gap-3 cursor-pointer">
                <input
                  type="radio"
                  name="visibility"
                  value={v}
                  checked={visibility === v}
                  onChange={() => setVisibility(v)}
                  className="w-4 h-4 accent-[rgb(var(--color-primary))]"
                />
                <div>
                  <span className="text-sm font-medium text-[rgb(var(--color-text-primary))] capitalize">{v}</span>
                  <p className="text-xs text-[rgb(var(--color-text-secondary))]">
                    {v === 'public' ? 'Anyone can watch' : v === 'unlisted' ? 'Only people with the link' : 'Only you'}
                  </p>
                </div>
              </label>
            ))}
          </div>
        </div>

        {/* Audience */}
        <div>
          <label className="block text-sm font-medium text-[rgb(var(--color-text-primary))] mb-2">
            Audience
          </label>
          <div className="space-y-2">
            <label className="flex items-center gap-3 cursor-pointer">
              <input
                type="checkbox"
                checked={madeForKids}
                onChange={(e) => { setMadeForKids(e.target.checked); if (e.target.checked) setAgeRestricted(false); }}
                className="w-4 h-4"
              />
              <div>
                <span className="text-sm font-medium text-[rgb(var(--color-text-primary))]">Made for kids</span>
                <p className="text-xs text-[rgb(var(--color-text-secondary))]">Personalization features disabled (COPPA)</p>
              </div>
            </label>
            <label className="flex items-center gap-3 cursor-pointer">
              <input
                type="checkbox"
                checked={ageRestricted}
                onChange={(e) => { setAgeRestricted(e.target.checked); if (e.target.checked) setMadeForKids(false); }}
                className="w-4 h-4"
              />
              <div>
                <span className="text-sm font-medium text-[rgb(var(--color-text-primary))]">Age-restrict this video (18+)</span>
                <p className="text-xs text-[rgb(var(--color-text-secondary))]">Only viewers 18+ can watch this video</p>
              </div>
            </label>
          </div>
        </div>

        {/* Comments */}
        <label className="flex items-center gap-3 cursor-pointer">
          <input
            type="checkbox"
            checked={commentsEnabled}
            onChange={(e) => setCommentsEnabled(e.target.checked)}
            className="w-4 h-4"
          />
          <span className="text-sm text-[rgb(var(--color-text-primary))]">Allow comments</span>
        </label>

        {/* Premiere */}
        <div>
          <label className="flex items-center gap-3 cursor-pointer mb-2">
            <input
              type="checkbox"
              checked={isPremiere}
              onChange={(e) => setIsPremiere(e.target.checked)}
              className="w-4 h-4"
            />
            <div>
              <span className="text-sm font-medium text-[rgb(var(--color-text-primary))]">Schedule as Premiere</span>
              <p className="text-xs text-[rgb(var(--color-text-secondary))]">Video will debut at a scheduled time with live chat</p>
            </div>
          </label>
          {isPremiere && (
            <input
              type="datetime-local"
              value={scheduledAt}
              onChange={(e) => setScheduledAt(e.target.value)}
              min={new Date().toISOString().slice(0, 16)}
              className="w-full px-4 py-2 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-lg text-sm text-[rgb(var(--color-text-primary))] focus:border-[rgb(var(--color-primary))] outline-none"
            />
          )}
        </div>

        {/* Error Message */}
        {error && (
          <div className="p-4 bg-red-500/10 border border-red-500 rounded-lg text-sm text-red-500">
            {error}
          </div>
        )}

        {/* Moderation warning (video still publishes, but is queued for admin review) */}
        {moderationWarning && !error && (
          <div className="flex items-start gap-3 p-4 bg-yellow-500/10 border border-yellow-500/40 rounded-lg text-sm text-yellow-600 dark:text-yellow-400">
            <ShieldAlert size={18} className="flex-shrink-0 mt-0.5" />
            <div>
              <p className="font-medium mb-1">This video will publish but has been flagged for review</p>
              {moderationWarning.reasons.length > 0 && (
                <p className="text-[13px] opacity-90">{moderationWarning.reasons.join(', ')}</p>
              )}
            </div>
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
          disabled={isUploading || isCheckingModeration || !videoFile || !title}
          className="w-full py-3 bg-[rgb(var(--color-primary))] text-white font-medium rounded-lg hover:bg-[rgb(var(--color-primary-hover))] disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {isUploading ? 'Uploading...' : isCheckingModeration ? 'Checking content…' : 'Upload Video'}
        </button>
      </form>
    </div>
  );
};

export default UploadPage;

