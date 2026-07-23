'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import {
  ChevronLeft, Save, Globe, Link2, Lock, Image as ImageIcon,
  Type, AlignLeft, Tag, Loader2,
} from 'lucide-react';
import { doc, getDoc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '@/lib/firebase/config';

type Privacy = 'public' | 'unlisted' | 'private';

interface VideoData {
  title: string;
  description: string;
  thumbnailURL: string;
  tags: string[];
  status: Privacy;
  madeForKids: boolean;
  commentsEnabled: boolean;
}

function PrivacyOption({ value, selected, onSelect }: {
  value: Privacy; selected: boolean; onSelect: () => void;
}) {
  const cfg: Record<Privacy, { icon: React.ElementType; label: string; desc: string }> = {
    public:   { icon: Globe,  label: 'Public',   desc: 'Anyone can watch' },
    unlisted: { icon: Link2,  label: 'Unlisted', desc: 'Only people with the link' },
    private:  { icon: Lock,   label: 'Private',  desc: 'Only you' },
  };
  const { icon: Icon, label, desc } = cfg[value];
  return (
    <button
      type="button"
      onClick={onSelect}
      className={`flex items-start gap-3 p-3 rounded-xl border transition-all text-left ${
        selected
          ? 'border-[rgb(var(--color-primary))] bg-[rgb(var(--color-primary))]/5'
          : 'border-[rgb(var(--color-border))] hover:bg-[rgb(var(--color-surface-hover))]'
      }`}
    >
      <Icon size={18} className={`mt-0.5 ${selected ? 'text-[rgb(var(--color-primary))]' : 'text-[rgb(var(--color-text-secondary))]'}`} />
      <div>
        <p className={`text-[13px] font-semibold ${selected ? 'text-[rgb(var(--color-primary))]' : 'text-[rgb(var(--color-text-primary))]'}`}>{label}</p>
        <p className="text-[11px] text-[rgb(var(--color-text-secondary))]">{desc}</p>
      </div>
    </button>
  );
}

/**
 * Video Edit page — /studio/video-edit?videoId=xxx
 * Flat route (no dynamic segment) for static export compatibility.
 * videoId is read from the URL search params at runtime.
 */
export default function VideoEditClient() {
  const router = useRouter();
  const [videoId, setVideoId] = useState('');
  const [data, setData] = useState<VideoData>({
    title: '', description: '', thumbnailURL: '', tags: [],
    status: 'public', madeForKids: false, commentsEnabled: true,
  });
  const [tagInput, setTagInput] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const vid = new URLSearchParams(window.location.search).get('videoId') ?? '';
    setVideoId(vid);
    if (!vid) { setLoading(false); return; }
    let cancelled = false;
    getDoc(doc(db, 'videos', vid)).then((snap) => {
      if (cancelled) return;
      if (!snap.exists()) { setError('Video not found'); return; }
      const d = snap.data();
      setData({
        title: d.title ?? '',
        description: d.description ?? '',
        thumbnailURL: d.thumbnailURL ?? '',
        tags: d.tags ?? [],
        status: d.isPublic === false ? 'private' : d.status ?? 'public',
        madeForKids: d.madeForKids ?? false,
        commentsEnabled: d.commentsEnabled ?? true,
      });
    }).catch((e: any) => { if (!cancelled) setError(e.message); })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, []);

  const handleSave = async () => {
    if (!videoId) return;
    setSaving(true); setError('');
    try {
      await updateDoc(doc(db, 'videos', videoId), {
        title: data.title.trim(),
        description: data.description.trim(),
        thumbnailURL: data.thumbnailURL.trim(),
        tags: data.tags,
        status: data.status,
        isPublic: data.status === 'public',
        madeForKids: data.madeForKids,
        commentsEnabled: data.commentsEnabled,
        updatedAt: serverTimestamp(),
      });
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setSaving(false);
    }
  };

  const addTag = () => {
    const t = tagInput.trim().toLowerCase();
    if (t && !data.tags.includes(t) && data.tags.length < 20) {
      setData((d) => ({ ...d, tags: [...d.tags, t] }));
    }
    setTagInput('');
  };

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      <div className="max-w-[720px] mx-auto">
        <header className="sticky top-0 z-50 bg-[rgb(var(--color-background))]/95 backdrop-blur border-b border-[rgb(var(--color-border))] px-4 py-3">
          <div className="flex items-center gap-3">
            <button onClick={() => router.back()} className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
              <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
            </button>
            <h1 className="text-[17px] font-bold text-[rgb(var(--color-text-primary))] flex-1">Edit video</h1>
            <button
              onClick={handleSave}
              disabled={saving || !videoId}
              className="flex items-center gap-1.5 px-4 py-1.5 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full hover:opacity-90 disabled:opacity-50 transition-all"
            >
              {saving ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
              {saved ? 'Saved!' : saving ? 'Saving…' : 'Save'}
            </button>
          </div>
        </header>

        {loading ? (
          <div className="flex justify-center py-24"><Loader2 size={28} className="animate-spin text-[rgb(var(--color-text-secondary))]" /></div>
        ) : error && !videoId ? (
          <div className="text-center py-24">
            <p className="text-[rgb(var(--color-text-secondary))]">No video ID specified.</p>
            <Link href="/studio/videos" className="text-[rgb(var(--color-primary))] font-semibold hover:underline mt-2 block">Back to Content</Link>
          </div>
        ) : error ? (
          <div className="text-center py-24 text-red-500">{error}</div>
        ) : (
          <main className="px-4 py-5 space-y-6 pb-24">
            {data.thumbnailURL && (
              <div className="rounded-xl overflow-hidden aspect-video bg-black">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={data.thumbnailURL} alt="Thumbnail" className="w-full h-full object-cover" />
              </div>
            )}

            <div>
              <label className="flex items-center gap-1.5 text-[12px] font-semibold text-[rgb(var(--color-text-secondary))] uppercase mb-2"><Type size={13} /> Title</label>
              <input value={data.title} onChange={(e) => setData((d) => ({ ...d, title: e.target.value }))} maxLength={100}
                placeholder="Add a title that describes your video"
                className="w-full bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] px-4 py-3 text-[14px] rounded-xl border border-[rgb(var(--color-border))] focus:outline-none focus:border-[rgb(var(--color-primary))] transition-colors"
              />
              <p className="text-right text-[11px] text-[rgb(var(--color-text-tertiary))] mt-1">{data.title.length}/100</p>
            </div>

            <div>
              <label className="flex items-center gap-1.5 text-[12px] font-semibold text-[rgb(var(--color-text-secondary))] uppercase mb-2"><AlignLeft size={13} /> Description</label>
              <textarea value={data.description} onChange={(e) => setData((d) => ({ ...d, description: e.target.value }))} rows={5} maxLength={5000}
                placeholder="Tell viewers about your video"
                className="w-full bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] px-4 py-3 text-[13px] rounded-xl border border-[rgb(var(--color-border))] focus:outline-none focus:border-[rgb(var(--color-primary))] transition-colors resize-none"
              />
            </div>

            <div>
              <label className="flex items-center gap-1.5 text-[12px] font-semibold text-[rgb(var(--color-text-secondary))] uppercase mb-2"><ImageIcon size={13} /> Thumbnail URL</label>
              <input value={data.thumbnailURL} onChange={(e) => setData((d) => ({ ...d, thumbnailURL: e.target.value }))}
                placeholder="https://…"
                className="w-full bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] px-4 py-3 text-[13px] rounded-xl border border-[rgb(var(--color-border))] focus:outline-none focus:border-[rgb(var(--color-primary))] transition-colors"
              />
            </div>

            <div>
              <label className="flex items-center gap-1.5 text-[12px] font-semibold text-[rgb(var(--color-text-secondary))] uppercase mb-2"><Tag size={13} /> Tags ({data.tags.length}/20)</label>
              <div className="flex gap-2 mb-2">
                <input value={tagInput} onChange={(e) => setTagInput(e.target.value)}
                  onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ',') { e.preventDefault(); addTag(); } }}
                  placeholder="Add tag, press Enter"
                  className="flex-1 bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] px-3 py-2 text-[13px] rounded-xl border border-[rgb(var(--color-border))] focus:outline-none focus:border-[rgb(var(--color-primary))] transition-colors"
                />
                <button onClick={addTag} className="px-4 py-2 bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] text-[13px] font-medium rounded-xl border border-[rgb(var(--color-border))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors">Add</button>
              </div>
              {data.tags.length > 0 && (
                <div className="flex flex-wrap gap-1.5">
                  {data.tags.map((tag) => (
                    <span key={tag} className="flex items-center gap-1 px-2.5 py-1 bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] text-[12px] rounded-full border border-[rgb(var(--color-border))]">
                      {tag}
                      <button onClick={() => setData((d) => ({ ...d, tags: d.tags.filter((t) => t !== tag) }))} className="text-[rgb(var(--color-text-tertiary))] hover:text-red-500 ml-0.5 text-[10px]">✕</button>
                    </span>
                  ))}
                </div>
              )}
            </div>

            <div>
              <label className="text-[12px] font-semibold text-[rgb(var(--color-text-secondary))] uppercase mb-2 block">Visibility</label>
              <div className="grid grid-cols-3 gap-2">
                {(['public', 'unlisted', 'private'] as Privacy[]).map((v) => (
                  <PrivacyOption key={v} value={v} selected={data.status === v} onSelect={() => setData((d) => ({ ...d, status: v }))} />
                ))}
              </div>
            </div>

            <div className="space-y-3">
              {([
                { key: 'commentsEnabled' as const, label: 'Comments enabled', desc: 'Allow viewers to comment' },
                { key: 'madeForKids' as const, label: 'Made for kids', desc: 'Content directed to children' },
              ] as const).map(({ key, label, desc }) => (
                <div key={key} className="flex items-center justify-between p-3 bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))]">
                  <div>
                    <p className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))]">{label}</p>
                    <p className="text-[11px] text-[rgb(var(--color-text-secondary))]">{desc}</p>
                  </div>
                  <button role="switch" aria-checked={data[key]} onClick={() => setData((d) => ({ ...d, [key]: !d[key] }))}
                    className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${data[key] ? 'bg-[rgb(var(--color-primary))]' : 'bg-[rgb(var(--color-border))]'}`}>
                    <span className={`inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform ${data[key] ? 'translate-x-6' : 'translate-x-1'}`} />
                  </button>
                </div>
              ))}
            </div>

            <div className="p-4 bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))]">
              <p className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">Video Chapters</p>
              <p className="text-[12px] text-[rgb(var(--color-text-secondary))] mb-3">Add timestamped chapters so viewers can jump to sections</p>
              <Link href={`/studio/chapters?videoId=${videoId}`} className="text-[13px] text-[rgb(var(--color-primary))] font-semibold hover:underline">
                Edit chapters →
              </Link>
            </div>

            {error && <p className="text-red-500 text-[13px]">{error}</p>}
          </main>
        )}
      </div>
    </div>
  );
}
