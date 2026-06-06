'use client';

import { useState, useEffect, useRef } from 'react';
import {
  Palette, Image, Type, Globe, ChevronLeft, Save,
  Camera, Link2, Twitter, Instagram, CheckCircle,
} from 'lucide-react';
import Link from 'next/link';
import { doc, getDoc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { ref, uploadBytesResumable, getDownloadURL } from 'firebase/storage';
import { db, auth, storage } from '@/lib/firebase/config';

type Tab = 'Branding' | 'Layout' | 'Basic info';

interface ChannelData {
  displayName: string;
  username: string;
  bio: string;
  profileImageURL: string;
  bannerImageURL: string;
  website: string;
  twitter: string;
  instagram: string;
}

const EMPTY: ChannelData = {
  displayName: '',
  username: '',
  bio: '',
  profileImageURL: '',
  bannerImageURL: '',
  website: '',
  twitter: '',
  instagram: '',
};

export default function CustomizationClient() {
  const [tab, setTab] = useState<Tab>('Branding');
  const [data, setData] = useState<ChannelData>(EMPTY);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [uploadingBanner, setUploadingBanner] = useState(false);
  const avatarRef = useRef<HTMLInputElement>(null);
  const bannerRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const uid = auth?.currentUser?.uid;
    if (!uid) { setLoading(false); return; }
    let cancelled = false;

    getDoc(doc(db, 'users', uid)).then((snap) => {
      if (!cancelled && snap.exists()) {
        const d = snap.data();
        setData({
          displayName: d.displayName ?? '',
          username: d.username ?? '',
          bio: d.bio ?? '',
          profileImageURL: d.profileImageURL ?? '',
          bannerImageURL: d.bannerImageURL ?? '',
          website: d.socialLinks?.website ?? '',
          twitter: d.socialLinks?.twitter ?? '',
          instagram: d.socialLinks?.instagram ?? '',
        });
      }
      if (!cancelled) setLoading(false);
    }).catch(() => { if (!cancelled) setLoading(false); });

    return () => { cancelled = true; };
  }, []);

  const uploadImage = async (file: File, path: string, field: 'profileImageURL' | 'bannerImageURL') => {
    const setter = field === 'profileImageURL' ? setUploadingAvatar : setUploadingBanner;
    setter(true);
    try {
      const storageRef = ref(storage, path);
      await new Promise<void>((resolve, reject) => {
        const task = uploadBytesResumable(storageRef, file);
        task.on('state_changed', null, reject, () => resolve());
      });
      const url = await getDownloadURL(storageRef);
      setData((prev) => ({ ...prev, [field]: url }));
    } catch (e) {
      console.error(e);
    } finally {
      setter(false);
    }
  };

  const handleAvatarChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const uid = auth?.currentUser?.uid ?? 'unknown';
    uploadImage(file, `avatars/${uid}/${Date.now()}.jpg`, 'profileImageURL');
  };

  const handleBannerChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const uid = auth?.currentUser?.uid ?? 'unknown';
    uploadImage(file, `banners/${uid}/${Date.now()}.jpg`, 'bannerImageURL');
  };

  const handleSave = async () => {
    const uid = auth?.currentUser?.uid;
    if (!uid) return;
    setSaving(true);
    try {
      await updateDoc(doc(db, 'users', uid), {
        displayName: data.displayName,
        username: data.username,
        bio: data.bio,
        profileImageURL: data.profileImageURL,
        bannerImageURL: data.bannerImageURL,
        'socialLinks.website': data.website,
        'socialLinks.twitter': data.twitter,
        'socialLinks.instagram': data.instagram,
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

  const set = (field: keyof ChannelData) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) =>
    setData((prev) => ({ ...prev, [field]: e.target.value }));

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      <div className="max-w-[900px] mx-auto">

        {/* Header */}
        <header className="sticky top-0 z-50 bg-[rgb(var(--color-background))]/95 backdrop-blur border-b border-[rgb(var(--color-border))] px-4 py-3 space-y-3">
          <div className="flex items-center gap-3">
            <Link href="/studio" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
              <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
            </Link>
            <Palette size={20} className="text-pink-500" />
            <div className="flex-1">
              <h1 className="text-[17px] font-bold text-[rgb(var(--color-text-primary))] leading-none">Customization</h1>
              <p className="text-[11px] text-[rgb(var(--color-text-secondary))]">Channel branding & layout</p>
            </div>
            <button
              onClick={handleSave}
              disabled={saving || loading}
              className="flex items-center gap-1.5 px-4 py-1.5 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full hover:opacity-90 disabled:opacity-50 transition-opacity"
            >
              {saved ? <><CheckCircle size={14} /> Saved</> : saving ? 'Saving…' : <><Save size={14} /> Publish</>}
            </button>
          </div>

          {/* Tabs */}
          <div className="flex border-b border-[rgb(var(--color-border))] -mb-[1px]">
            {(['Branding', 'Layout', 'Basic info'] as Tab[]).map((t) => (
              <button
                key={t}
                onClick={() => setTab(t)}
                className={`px-3 py-2 text-[12px] font-semibold whitespace-nowrap border-b-2 transition-colors ${
                  tab === t
                    ? 'border-[rgb(var(--color-text-primary))] text-[rgb(var(--color-text-primary))]'
                    : 'border-transparent text-[rgb(var(--color-text-secondary))] hover:text-[rgb(var(--color-text-primary))]'
                }`}
              >
                {t}
              </button>
            ))}
          </div>
        </header>

        <main className="px-4 py-5 pb-24 space-y-6">
          {loading ? (
            <div className="space-y-4">
              {[...Array(4)].map((_, i) => <div key={i} className="h-16 bg-[rgb(var(--color-surface))] rounded-xl animate-pulse" />)}
            </div>
          ) : (
            <>
              {/* ── Branding tab ── */}
              {tab === 'Branding' && (
                <div className="space-y-5">
                  {/* Profile picture */}
                  <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
                    <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">Profile picture</h3>
                    <p className="text-[11px] text-[rgb(var(--color-text-secondary))] mb-4">Appears next to your channel name across MyChannel. Use an image at least 98×98 pixels, no larger than 4MB.</p>
                    <div className="flex items-center gap-4">
                      <div className="relative w-20 h-20 rounded-full overflow-hidden bg-[rgb(var(--color-surface-hover))] flex-shrink-0">
                        {data.profileImageURL
                          ? <img src={data.profileImageURL} alt="Profile" className="w-full h-full object-cover" />
                          : <div className="w-full h-full flex items-center justify-center bg-purple-600 text-white text-2xl font-bold">{data.displayName?.[0]?.toUpperCase() ?? '?'}</div>
                        }
                        {uploadingAvatar && (
                          <div className="absolute inset-0 bg-black/50 flex items-center justify-center">
                            <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                          </div>
                        )}
                      </div>
                      <div className="space-y-2">
                        <button
                          onClick={() => avatarRef.current?.click()}
                          disabled={uploadingAvatar}
                          className="flex items-center gap-2 px-4 py-2 border border-[rgb(var(--color-border))] text-[13px] font-medium text-[rgb(var(--color-text-primary))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors disabled:opacity-50"
                        >
                          <Camera size={14} /> Change
                        </button>
                        {data.profileImageURL && (
                          <button
                            onClick={() => setData((p) => ({ ...p, profileImageURL: '' }))}
                            className="text-[12px] text-red-500 hover:underline"
                          >
                            Remove
                          </button>
                        )}
                      </div>
                      <input ref={avatarRef} type="file" accept="image/*" className="hidden" onChange={handleAvatarChange} />
                    </div>
                  </div>

                  {/* Banner */}
                  <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
                    <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">Banner image</h3>
                    <p className="text-[11px] text-[rgb(var(--color-text-secondary))] mb-4">Appears at the top of your channel. Use an image at least 2048×1152 pixels.</p>
                    <div
                      className="relative w-full aspect-[6/1] rounded-xl overflow-hidden bg-[rgb(var(--color-surface-hover))] flex items-center justify-center cursor-pointer hover:opacity-90 transition-opacity"
                      onClick={() => bannerRef.current?.click()}
                    >
                      {data.bannerImageURL
                        ? <img src={data.bannerImageURL} alt="Banner" className="w-full h-full object-cover" />
                        : <div className="flex flex-col items-center gap-2 text-[rgb(var(--color-text-tertiary))]">
                            <Image size={28} />
                            <span className="text-[12px]">Upload banner</span>
                          </div>
                      }
                      {uploadingBanner && (
                        <div className="absolute inset-0 bg-black/50 flex items-center justify-center">
                          <div className="w-6 h-6 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                        </div>
                      )}
                    </div>
                    <div className="flex gap-2 mt-2">
                      <button
                        onClick={() => bannerRef.current?.click()}
                        disabled={uploadingBanner}
                        className="flex items-center gap-2 px-4 py-2 border border-[rgb(var(--color-border))] text-[13px] font-medium text-[rgb(var(--color-text-primary))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors disabled:opacity-50"
                      >
                        <Camera size={14} /> {data.bannerImageURL ? 'Change' : 'Upload'}
                      </button>
                      {data.bannerImageURL && (
                        <button
                          onClick={() => setData((p) => ({ ...p, bannerImageURL: '' }))}
                          className="px-4 py-2 border border-[rgb(var(--color-border))] text-[13px] font-medium text-red-500 rounded-full hover:bg-red-50 dark:hover:bg-red-900/10 transition-colors"
                        >
                          Remove
                        </button>
                      )}
                    </div>
                    <input ref={bannerRef} type="file" accept="image/*" className="hidden" onChange={handleBannerChange} />
                  </div>
                </div>
              )}

              {/* ── Basic info tab ── */}
              {tab === 'Basic info' && (
                <div className="space-y-4">
                  {[
                    { label: 'Channel name', field: 'displayName' as const, placeholder: 'Your channel name', hint: 'The name that viewers see across MyChannel.' },
                    { label: 'Handle', field: 'username' as const, placeholder: '@yourhandle', hint: 'Your unique channel URL: mychannel.live/@yourhandle' },
                  ].map(({ label, field, placeholder, hint }) => (
                    <div key={field} className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
                      <label className="block text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">{label}</label>
                      <p className="text-[11px] text-[rgb(var(--color-text-secondary))] mb-3">{hint}</p>
                      <input
                        type="text"
                        value={data[field]}
                        onChange={set(field)}
                        placeholder={placeholder}
                        className="w-full px-3 py-2 bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] rounded-xl text-[13px] text-[rgb(var(--color-text-primary))] focus:outline-none focus:border-[rgb(var(--color-primary))]"
                      />
                    </div>
                  ))}

                  <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
                    <label className="block text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">Description</label>
                    <p className="text-[11px] text-[rgb(var(--color-text-secondary))] mb-3">Tell viewers about your channel. Up to 1,000 characters.</p>
                    <textarea
                      value={data.bio}
                      onChange={set('bio')}
                      placeholder="Describe your channel..."
                      maxLength={1000}
                      rows={4}
                      className="w-full px-3 py-2 bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] rounded-xl text-[13px] text-[rgb(var(--color-text-primary))] resize-none focus:outline-none focus:border-[rgb(var(--color-primary))]"
                    />
                    <p className="text-[11px] text-[rgb(var(--color-text-tertiary))] text-right mt-1">{data.bio.length}/1000</p>
                  </div>

                  {/* Links */}
                  <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4 space-y-3">
                    <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))]">Links</h3>
                    {[
                      { icon: Globe,     field: 'website' as const,   placeholder: 'https://yourwebsite.com', label: 'Website' },
                      { icon: Twitter,   field: 'twitter' as const,   placeholder: '@twitterhandle',          label: 'Twitter / X' },
                      { icon: Instagram, field: 'instagram' as const, placeholder: '@instagramhandle',        label: 'Instagram' },
                    ].map(({ icon: Icon, field, placeholder, label }) => (
                      <div key={field} className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-[rgb(var(--color-surface-hover))] flex items-center justify-center flex-shrink-0">
                          <Icon size={16} className="text-[rgb(var(--color-text-secondary))]" />
                        </div>
                        <input
                          type="text"
                          value={data[field]}
                          onChange={set(field)}
                          placeholder={placeholder}
                          aria-label={label}
                          className="flex-1 px-3 py-2 bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] rounded-xl text-[13px] text-[rgb(var(--color-text-primary))] focus:outline-none focus:border-[rgb(var(--color-primary))]"
                        />
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* ── Layout tab ── */}
              {tab === 'Layout' && (
                <div className="space-y-4">
                  <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
                    <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">Channel trailer</h3>
                    <p className="text-[11px] text-[rgb(var(--color-text-secondary))] mb-4">For non-subscribed visitors — introduce yourself in a short video.</p>
                    <Link
                      href="/upload"
                      className="inline-flex items-center gap-2 px-4 py-2 border border-[rgb(var(--color-border))] text-[13px] font-medium text-[rgb(var(--color-text-primary))] rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
                    >
                      <Type size={14} /> Upload trailer
                    </Link>
                  </div>

                  <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
                    <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">Featured sections</h3>
                    <p className="text-[11px] text-[rgb(var(--color-text-secondary))] mb-4">Add up to 12 sections to your channel homepage. Organize playlists, featured videos, and more.</p>
                    <button className="inline-flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full hover:opacity-90 transition-opacity">
                      + Add section
                    </button>
                  </div>
                </div>
              )}
            </>
          )}
        </main>
      </div>
    </div>
  );
}
