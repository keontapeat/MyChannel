'use client';

import { useState, useEffect, useRef } from 'react';
import {
  ChevronLeft, Save, Eye, Globe, Lock, Link2, CheckCircle,
  Image, X, Tag, Clock, BarChart3,
} from 'lucide-react';
import Link from 'next/link';
import { doc, getDoc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { ref, uploadBytesResumable, getDownloadURL } from 'firebase/storage';
import { db, auth, storage } from '@/lib/firebase/config';

type Visibility = 'public' | 'unlisted' | 'private';

interface VideoData {
  title: string;
  description: string;
  tags: string[];
  category: string;
  visibility: Visibility;
  thumbnailURL: string;
  videoURL: string;
  viewCount: number;
  likeCount: number;
  commentCount: number;
  duration: number;
  createdAt: Date;
  commentsEnabled: boolean;
  madeForKids: boolean;
}

const CATEGORIES = [
  'Gaming', 'Music', 'Education', 'Technology', 'Sports', 'News',
  'Entertainment', 'Comedy', 'Lifestyle', 'Travel', 'Cooking', 'Other',
];

function formatNum(n: number) {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'K';
  return String(n);
}

function formatDuration(s: number) {
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const ss = s % 60;
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(ss).padStart(2, '0')}`;
  return `${m}:${String(ss).padStart(2, '0')}`;
}

export default function VideoEditClient({ videoId }: { videoId: string }) {
  const [data, setData] = useState<VideoData | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [tagInput, setTagInput] = useState('');
  const [uploadingThumb, setUploadingThumb] = useState(false);
  const [notFound, setNotFound] = useState(false);
  const thumbRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!videoId || videoId === '_fallback') { setLoading(false); setNotFound(true); return; }
    let cancelled = false;

    getDoc(doc(db, 'videos', videoId)).then((snap) => {
      if (cancelled) return;
      if (!snap.exists()) { setNotFound(true); setLoading(false); return; }
      const d = snap.data();
      setData({
        title: d.title ?? '',
        description: d.description ?? '',
        tags: d.tags ?? [],
        category: d.category ?? 'entertainment',
        visibility: d.isPublic === false ? 'private' : d.status ?? 'public',
        thumbnailURL: d.thumbnailURL ?? '',
        videoURL: d.videoURL ?? '',
        viewCount: d.viewCount ?? 0,
        likeCount: d.likeCount ?? 0,
        commentCount: d.commentCount ?? 0,
        duration: d.duration ?? 0,
        createdAt: d.createdAt?.toDate?.() ?? new Date(),
        commentsEnabled: d.commentsEnabled !== false,
        madeForKids: d.madeForKids ?? false,
      });
      setLoading(false);
    }).catch(() => { if (!cancelled) setLoading(false); });

    return () => { cancelled = true; };
  }, [videoId]);

  const set = <K extends keyof VideoData>(k: K) =>
    (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) =>
      setData((p) => p ? { ...p, [k]: e.target.value } : p);

  const addTag = () => {
    const t = tagInput.trim().replace(/^#/, '');
    if (!t || !data) return;
    if (!data.tags.includes(t)) setData({ ...data, tags: [...data.tags, t] });
    setTagInput('');
  };

  const removeTag = (tag: string) =>
    setData((p) => p ? { ...p, tags: p.tags.filter((t) => t !== tag) } : p);

  const handleThumbChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !data) return;
    setUploadingThumb(true);
    try {
      const storageRef = ref(storage, `thumbnails/${videoId}/${Date.now()}.jpg`);
      await new Promise<void>((res, rej) => {
        const task = uploadBytesResumable(storageRef, file);
        task.on('state_changed', null, rej, () => res());
      });
      const url = await getDownloadURL(storageRef);
      setData({ ...data, thumbnailURL: url });
    } catch (e) {
      console.error(e);
    } finally {
      setUploadingThumb(false);
    }
  };

  const handleSave = async () => {
    if (!data) return;
    setSaving(true);
    try {
      await updateDoc(doc(db, 'videos', videoId), {
        title: data.title,
        description: data.description,
        tags: data.tags,
        category: data.category.toLowerCase(),
        isPublic: data.visibility === 'public',
        status: data.visibility,
        thumbnailURL: data.thumbnailURL,
        commentsEnabled: data.commentsEnabled,
        madeForKids: data.madeForKids,
        updatedAt: serverTimestamp(),
      });
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (e) {
      console.error(e);
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-[rgb(var(--color-background))] flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-[rgb(var(--color-border))] border-t-[rgb(var(--color-primary))] rounded-full animate-spin" />
      </div>
    );
  }

  if (notFound || !data) {
    return (
      <div className="min-h-screen bg-[rgb(var(--color-background))] flex flex-col items-center justify-center gap-3">
        <p className="text-[rgb(var(--color-text-secondary))] text-[14px]">Video not found</p>
        <Link href="/studio/videos" className="text-[rgb(var(--color-primary))] text-[13px] hover:underline">Back to content</Link>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      <div className="max-w-[900px] mx-auto">

        {/* Header */}
        <header className="sticky top-0 z-50 bg-[rgb(var(--color-background))]/95 backdrop-blur border-b border-[rgb(var(--color-border))] px-4 py-3">
          <div className="flex items-center gap-3">
            <Link href="/studio/videos" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
              <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
            </Link>
            <div className="flex-1 min-w-0">
              <h1 className="text-[15px] font-bold text-[rgb(var(--color-text-primary))] line-clamp-1">{data.title || 'Edit video'}</h1>
              <p className="text-[11px] text-[rgb(var(--color-text-secondary))]">
                {data.createdAt.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })} ·{' '}
                {formatNum(data.viewCount)} views
              </p>
            </div>
            <div className="flex items-center gap-2">
              <Link
                href={`/watch/${videoId}`}
                target="_blank"
                className="flex items-center gap-1 px-3 py-1.5 border border-[rgb(var(--color-border))] text-[12px] font-medium text-[rgb(var(--color-text-primary))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
              >
                <Eye size={13} /> Watch
              </Link>
              <button
                onClick={handleSave}
                disabled={saving}
                className="flex items-center gap-1.5 px-4 py-1.5 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full hover:opacity-90 disabled:opacity-50 transition-opacity"
              >
                {saved ? <><CheckCircle size={14} /> Saved</> : saving ? 'Saving…' : <><Save size={14} /> Save</>}
              </button>
            </div>
          </div>
        </header>

        <main className="px-4 py-5 pb-24 space-y-5">

          {/* Stats row */}
          <div className="grid grid-cols-4 gap-2">
            {[
              { label: 'Views',    value: formatNum(data.viewCount) },
              { label: 'Likes',   value: formatNum(data.likeCount) },
              { label: 'Comments', value: String(data.commentCount) },
              { label: 'Duration', value: data.duration > 0 ? formatDuration(data.duration) : '—' },
            ].map(({ label, value }) => (
              <div key={label} className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-3 text-center">
                <p className="text-[16px] font-bold text-[rgb(var(--color-text-primary))]">{value}</p>
                <p className="text-[10px] text-[rgb(var(--color-text-tertiary))]">{label}</p>
              </div>
            ))}
          </div>

          {/* Thumbnail */}
          <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
            <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">Thumbnail</h3>
            <p className="text-[11px] text-[rgb(var(--color-text-secondary))] mb-3">Select or upload a picture that shows what's in your video. A good thumbnail stands out and draws viewer attention.</p>
            <div className="flex items-center gap-3">
              <div className="relative w-[120px] h-[68px] rounded-xl overflow-hidden bg-[rgb(var(--color-surface-hover))] flex-shrink-0">
                {data.thumbnailURL
                  ? <img src={data.thumbnailURL} alt="Thumbnail" className="w-full h-full object-cover" />
                  : <div className="w-full h-full flex items-center justify-center"><Image size={20} className="text-[rgb(var(--color-text-tertiary))]" /></div>
                }
                {uploadingThumb && (
                  <div className="absolute inset-0 bg-black/50 flex items-center justify-center">
                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  </div>
                )}
              </div>
              <div className="space-y-1.5">
                <button
                  onClick={() => thumbRef.current?.click()}
                  disabled={uploadingThumb}
                  className="flex items-center gap-2 px-3 py-1.5 border border-[rgb(var(--color-border))] text-[12px] font-medium text-[rgb(var(--color-text-primary))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors disabled:opacity-50"
                >
                  <Image size={13} /> Upload thumbnail
                </button>
                <Link
                  href="/studio/thumbnail-creator"
                  className="flex items-center gap-2 px-3 py-1.5 text-[12px] font-medium text-[rgb(var(--color-primary))] hover:underline"
                >
                  Open Thumbnail Creator →
                </Link>
              </div>
              <input ref={thumbRef} type="file" accept="image/*" className="hidden" onChange={handleThumbChange} />
            </div>
          </div>

          {/* Title */}
          <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
            <label className="block text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">Title <span className="text-red-500">*</span></label>
            <p className="text-[11px] text-[rgb(var(--color-text-secondary))] mb-2">Add a title that describes your video (max 100 chars)</p>
            <input
              type="text"
              value={data.title}
              onChange={set('title')}
              maxLength={100}
              placeholder="Add a title"
              className="w-full px-3 py-2 bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] rounded-xl text-[13px] text-[rgb(var(--color-text-primary))] focus:outline-none focus:border-[rgb(var(--color-primary))]"
            />
            <p className="text-[11px] text-[rgb(var(--color-text-tertiary))] text-right mt-1">{data.title.length}/100</p>
          </div>

          {/* Description */}
          <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
            <label className="block text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">Description</label>
            <p className="text-[11px] text-[rgb(var(--color-text-secondary))] mb-2">Tell viewers about your video. The first few lines appear in search results.</p>
            <textarea
              value={data.description}
              onChange={set('description')}
              maxLength={5000}
              placeholder="Tell viewers about your video..."
              rows={5}
              className="w-full px-3 py-2 bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] rounded-xl text-[13px] text-[rgb(var(--color-text-primary))] resize-none focus:outline-none focus:border-[rgb(var(--color-primary))]"
            />
            <p className="text-[11px] text-[rgb(var(--color-text-tertiary))] text-right mt-1">{data.description.length}/5000</p>
          </div>

          {/* Tags */}
          <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
            <label className="block text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">Tags</label>
            <p className="text-[11px] text-[rgb(var(--color-text-secondary))] mb-2">Tags help people find your content. Enter a tag and press Enter or Add.</p>
            <div className="flex gap-2 mb-2">
              <div className="flex-1 flex items-center gap-2 px-3 py-2 bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] rounded-xl">
                <Tag size={14} className="text-[rgb(var(--color-text-tertiary))] flex-shrink-0" />
                <input
                  type="text"
                  value={tagInput}
                  onChange={(e) => setTagInput(e.target.value)}
                  onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); addTag(); } }}
                  placeholder="Add a tag..."
                  className="flex-1 bg-transparent text-[13px] text-[rgb(var(--color-text-primary))] outline-none"
                />
              </div>
              <button
                onClick={addTag}
                className="px-4 py-2 bg-[rgb(var(--color-primary))] text-white text-[12px] font-semibold rounded-xl hover:opacity-90"
              >
                Add
              </button>
            </div>
            {data.tags.length > 0 && (
              <div className="flex flex-wrap gap-2">
                {data.tags.map((tag) => (
                  <span key={tag} className="flex items-center gap-1 px-3 py-1 bg-[rgb(var(--color-surface-hover))] text-[rgb(var(--color-text-primary))] text-[12px] rounded-full">
                    #{tag}
                    <button onClick={() => removeTag(tag)} className="ml-0.5 hover:text-red-500 transition-colors">
                      <X size={12} />
                    </button>
                  </span>
                ))}
              </div>
            )}
          </div>

          {/* Category */}
          <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
            <label className="block text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">Category</label>
            <p className="text-[11px] text-[rgb(var(--color-text-secondary))] mb-2">Add your video to a category so viewers can find it more easily.</p>
            <select
              value={data.category}
              onChange={set('category')}
              className="w-full px-3 py-2 bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] rounded-xl text-[13px] text-[rgb(var(--color-text-primary))] focus:outline-none focus:border-[rgb(var(--color-primary))]"
            >
              {CATEGORIES.map((c) => (
                <option key={c} value={c.toLowerCase()}>{c}</option>
              ))}
            </select>
          </div>

          {/* Visibility */}
          <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
            <label className="block text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">Visibility</label>
            <p className="text-[11px] text-[rgb(var(--color-text-secondary))] mb-3">Choose when to publish and who can see your video.</p>
            <div className="space-y-2">
              {([
                { value: 'public',   icon: Globe,  label: 'Public',   desc: 'Everyone can watch your video' },
                { value: 'unlisted', icon: Link2,  label: 'Unlisted', desc: 'Anyone with the video link can watch' },
                { value: 'private',  icon: Lock,   label: 'Private',  desc: 'Only you can watch your video' },
              ] as { value: Visibility; icon: React.ElementType; label: string; desc: string }[]).map(({ value, icon: Icon, label, desc }) => (
                <label
                  key={value}
                  className={`flex items-center gap-3 p-3 rounded-xl border cursor-pointer transition-colors ${
                    data.visibility === value
                      ? 'bg-blue-50 border-blue-300 dark:bg-blue-900/20 dark:border-blue-700'
                      : 'border-[rgb(var(--color-border))] hover:bg-[rgb(var(--color-surface-hover))]'
                  }`}
                >
                  <input
                    type="radio"
                    name="visibility"
                    value={value}
                    checked={data.visibility === value}
                    onChange={() => setData((p) => p ? { ...p, visibility: value } : p)}
                    className="sr-only"
                  />
                  <Icon size={16} className={data.visibility === value ? 'text-blue-500' : 'text-[rgb(var(--color-text-secondary))]'} />
                  <div className="flex-1">
                    <p className={`text-[13px] font-semibold ${data.visibility === value ? 'text-blue-600 dark:text-blue-400' : 'text-[rgb(var(--color-text-primary))]'}`}>{label}</p>
                    <p className="text-[11px] text-[rgb(var(--color-text-tertiary))]">{desc}</p>
                  </div>
                  {data.visibility === value && <CheckCircle size={16} className="text-blue-500 flex-shrink-0" />}
                </label>
              ))}
            </div>
          </div>

          {/* More options */}
          <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4 space-y-3">
            <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))]">More options</h3>
            <label className="flex items-center justify-between">
              <div>
                <p className="text-[13px] text-[rgb(var(--color-text-primary))]">Comments</p>
                <p className="text-[11px] text-[rgb(var(--color-text-tertiary))]">Allow viewers to comment on this video</p>
              </div>
              <button
                onClick={() => setData((p) => p ? { ...p, commentsEnabled: !p.commentsEnabled } : p)}
                className={`relative w-10 h-5 rounded-full transition-colors ${data.commentsEnabled ? 'bg-[rgb(var(--color-primary))]' : 'bg-[rgb(var(--color-surface-hover))]'}`}
              >
                <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform ${data.commentsEnabled ? 'translate-x-5' : 'translate-x-0.5'}`} />
              </button>
            </label>
            <label className="flex items-center justify-between">
              <div>
                <p className="text-[13px] text-[rgb(var(--color-text-primary))]">Made for kids</p>
                <p className="text-[11px] text-[rgb(var(--color-text-tertiary))]">Is this video made for kids? (affects personalization)</p>
              </div>
              <button
                onClick={() => setData((p) => p ? { ...p, madeForKids: !p.madeForKids } : p)}
                className={`relative w-10 h-5 rounded-full transition-colors ${data.madeForKids ? 'bg-[rgb(var(--color-primary))]' : 'bg-[rgb(var(--color-surface-hover))]'}`}
              >
                <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform ${data.madeForKids ? 'translate-x-5' : 'translate-x-0.5'}`} />
              </button>
            </label>
          </div>

          {/* Quick links */}
          <div className="flex gap-2">
            <Link href={`/studio/analytics?videoId=${videoId}`} className="flex-1 flex items-center justify-center gap-2 p-3 bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] text-[12px] font-medium text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors">
              <BarChart3 size={14} /> Analytics
            </Link>
            <Link href={`/studio/comments?videoId=${videoId}`} className="flex-1 flex items-center justify-center gap-2 p-3 bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] text-[12px] font-medium text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors">
              <Clock size={14} /> Comments
            </Link>
          </div>

        </main>
      </div>
    </div>
  );
}
