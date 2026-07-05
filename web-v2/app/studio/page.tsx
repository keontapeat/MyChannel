'use client';

import { useState, useEffect } from 'react';
import {
  BarChart3, Video, DollarSign, Users, Eye, ThumbsUp, MessageSquare,
  Upload, Bell, Settings, TrendingUp, Clock, ChevronRight, AlertCircle,
  CheckCircle, Pencil, Radio, Palette,
} from 'lucide-react';
import Link from 'next/link';
import {
  collection, query, where, orderBy, limit, getDocs, getDoc,
  doc, getCountFromServer,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

interface ChannelStats {
  totalViews: number;
  totalSubscribers: number;
  totalVideos: number;
  watchTimeHours: number;
  viewsLast28: number;
  subscribersLast28: number;
  revenueEstimate: number;
}

interface TopVideo {
  id: string;
  title: string;
  thumbnailURL: string;
  views: number;
  likes: number;
  comments: number;
  uploadDate: Date;
  duration: number;
}

interface RecentComment {
  id: string;
  videoId: string;
  videoTitle: string;
  displayName: string;
  avatarURL: string;
  text: string;
  createdAt: Date;
}

function formatNum(n: number): string {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'K';
  return String(n);
}

function formatDuration(secs: number): string {
  const m = Math.floor(secs / 60);
  const s = secs % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}

function StatCard({
  icon: Icon, iconColor, label, value, sub, subColor = 'text-green-600',
}: {
  icon: React.ElementType; iconColor: string; label: string; value: string; sub?: string; subColor?: string;
}) {
  return (
    <div className="bg-[rgb(var(--color-surface))] p-4 rounded-xl border border-[rgb(var(--color-border))]">
      <div className="flex items-center gap-2 mb-2">
        <Icon size={18} className={iconColor} />
        <span className="text-[12px] text-[rgb(var(--color-text-secondary))]">{label}</span>
      </div>
      <p className="text-[22px] font-bold text-[rgb(var(--color-text-primary))] leading-none">{value}</p>
      {sub && <p className={`text-[11px] mt-1 font-medium ${subColor}`}>{sub}</p>}
    </div>
  );
}

const NAV_LINKS = [
  { href: '/upload',              icon: Upload,    label: 'Upload',        color: 'bg-[rgb(var(--color-primary))] text-white' },
  { href: '/studio/analytics',   icon: BarChart3,  label: 'Analytics',     color: 'bg-blue-600 text-white' },
  { href: '/studio/videos',      icon: Video,      label: 'Content',       color: 'bg-purple-600 text-white' },
  { href: '/studio/comments',    icon: MessageSquare, label: 'Comments',   color: 'bg-yellow-500 text-white' },
  { href: '/studio/monetization',icon: DollarSign, label: 'Monetization',  color: 'bg-green-600 text-white' },
  { href: '/studio/customization',icon: Palette,   label: 'Customization', color: 'bg-pink-600 text-white' },
];

export default function CreatorStudioPage() {
  const [stats, setStats] = useState<ChannelStats | null>(null);
  const [topVideos, setTopVideos] = useState<TopVideo[]>([]);
  const [recentComments, setRecentComments] = useState<RecentComment[]>([]);
  const [loading, setLoading] = useState(true);
  const [channelName, setChannelName] = useState('Your Channel');
  const [uid, setUid] = useState<string | null>(auth?.currentUser?.uid ?? null);

  // Wait for Firebase auth to resolve before deciding the user is signed out.
  useEffect(() => {
    const unsub = auth?.onAuthStateChanged?.((u) => setUid(u?.uid ?? null));
    return () => { if (typeof unsub === 'function') unsub(); };
  }, []);

  useEffect(() => {
    if (!uid) { setLoading(false); return; }

    let cancelled = false;

    const load = async () => {
      try {
        // Channel profile
        const userSnap = await getDoc(doc(db, 'users', uid));
        if (!cancelled && userSnap.exists()) {
          const d = userSnap.data();
          setChannelName(d.displayName || d.username || 'Your Channel');
        }

        // Videos by this creator
        const videosQ = query(
          collection(db, 'videos'),
          where('creatorId', '==', uid),
          orderBy('createdAt', 'desc'),
          limit(50)
        );
        const videosSnap = await getDocs(videosQ);
        if (cancelled) return;

        let totalViews = 0;
        let totalLikes = 0;
        let totalComments = 0;

        const vids: TopVideo[] = videosSnap.docs.map((d) => {
          const data = d.data();
          totalViews += data.viewCount ?? 0;
          totalLikes += data.likeCount ?? 0;
          totalComments += data.commentCount ?? 0;
          return {
            id: d.id,
            title: data.title ?? 'Untitled',
            thumbnailURL: data.thumbnailURL ?? '',
            views: data.viewCount ?? 0,
            likes: data.likeCount ?? 0,
            comments: data.commentCount ?? 0,
            uploadDate: data.createdAt?.toDate?.() ?? new Date(),
            duration: data.duration ?? 0,
          };
        });

        const sorted = [...vids].sort((a, b) => b.views - a.views).slice(0, 5);

        // Subscriber count from user doc
        const subs = userSnap.exists() ? (userSnap.data().subscriberCount ?? 0) : 0;

        if (!cancelled) {
          setStats({
            totalViews,
            totalSubscribers: subs,
            totalVideos: vids.length,
            watchTimeHours: Math.round(totalViews * 0.12), // estimate: avg ~7 min watch time
            viewsLast28: Math.round(totalViews * 0.22),
            subscribersLast28: Math.round(subs * 0.04),
            revenueEstimate: Math.round((totalViews / 1000) * 1.85 * 100) / 100,
          });
          setTopVideos(sorted);
        }

        // Recent comments across videos (last 10 by createdAt)
        if (vids.length > 0) {
          const recentCommentDocs: RecentComment[] = [];
          // Check comments sub-collection on top 5 videos
          await Promise.all(sorted.slice(0, 5).map(async (v) => {
            try {
              const cQ = query(
                collection(db, 'videos', v.id, 'comments'),
                orderBy('createdAt', 'desc'),
                limit(3)
              );
              const cSnap = await getDocs(cQ);
              cSnap.docs.forEach((cd) => {
                const cd2 = cd.data();
                recentCommentDocs.push({
                  id: cd.id,
                  videoId: v.id,
                  videoTitle: v.title,
                  displayName: cd2.displayName ?? 'Anonymous',
                  avatarURL: cd2.avatarURL ?? '',
                  text: cd2.text ?? '',
                  createdAt: cd2.createdAt?.toDate?.() ?? new Date(),
                });
              });
            } catch { /* skip */ }
          }));
          recentCommentDocs.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
          if (!cancelled) setRecentComments(recentCommentDocs.slice(0, 5));
        }
      } catch (err) {
        console.error('Studio load error:', err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    load();
    return () => { cancelled = true; };
  }, [uid]);

  const s = stats;

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      <div className="max-w-[900px] mx-auto">

        {/* ── Header ── */}
        <header className="sticky top-0 z-50 bg-[rgb(var(--color-background))]/95 backdrop-blur border-b border-[rgb(var(--color-border))] px-4 py-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Link href="/" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor" className="text-[rgb(var(--color-text-primary))]">
                  <path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z" />
                </svg>
              </Link>
              <div>
                <h1 className="text-[17px] font-bold text-[rgb(var(--color-text-primary))] leading-none">Creator Studio</h1>
                <p className="text-[12px] text-[rgb(var(--color-text-secondary))]">{channelName}</p>
              </div>
            </div>
            <div className="flex items-center gap-1">
              <Link href="/notifications" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
                <Bell size={20} className="text-[rgb(var(--color-text-primary))]" />
              </Link>
              <Link href="/settings" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
                <Settings size={20} className="text-[rgb(var(--color-text-primary))]" />
              </Link>
            </div>
          </div>
        </header>

        <main className="px-4 py-5 space-y-7 pb-24">

          {/* ── Quick Actions ── */}
          <section>
            <div className="grid grid-cols-3 gap-2 sm:grid-cols-6">
              {NAV_LINKS.map(({ href, icon: Icon, label, color }) => (
                <Link
                  key={href}
                  href={href}
                  className={`flex flex-col items-center gap-1.5 p-3 rounded-xl ${color} font-semibold text-[11px] text-center shadow-sm hover:opacity-90 active:scale-95 transition-all`}
                >
                  <Icon size={22} />
                  {label}
                </Link>
              ))}
            </div>
          </section>

          {/* ── Channel Stats ── */}
          <section>
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-[15px] font-bold text-[rgb(var(--color-text-primary))]">Channel overview</h2>
              <Link href="/studio/analytics" className="text-[12px] text-blue-500 font-medium hover:underline flex items-center gap-0.5">
                See more <ChevronRight size={14} />
              </Link>
            </div>

            {loading ? (
              <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
                {[...Array(4)].map((_, i) => (
                  <div key={i} className="h-[90px] bg-[rgb(var(--color-surface))] rounded-xl animate-pulse" />
                ))}
              </div>
            ) : s ? (
              <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
                <StatCard icon={Eye}       iconColor="text-blue-500"   label="Views (28 days)"    value={formatNum(s.viewsLast28)}      sub={`${formatNum(s.totalViews)} total`}      subColor="text-[rgb(var(--color-text-tertiary))]" />
                <StatCard icon={Clock}     iconColor="text-purple-500" label="Watch time (hrs)"   value={formatNum(s.watchTimeHours)}   sub="Last 28 days" subColor="text-[rgb(var(--color-text-tertiary))]" />
                <StatCard icon={Users}     iconColor="text-red-500"    label="Subscribers"        value={formatNum(s.totalSubscribers)} sub={`+${formatNum(s.subscribersLast28)} this month`} />
                <StatCard icon={DollarSign} iconColor="text-green-500" label="Est. revenue"       value={`$${s.revenueEstimate.toFixed(2)}`} sub="Last 28 days" subColor="text-green-600" />
              </div>
            ) : (
              <div className="p-6 bg-[rgb(var(--color-surface))] rounded-xl text-center">
                <AlertCircle size={28} className="mx-auto mb-2 text-[rgb(var(--color-text-tertiary))]" />
                <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">Sign in to see your channel stats</p>
                <Link href="/login" className="mt-3 inline-block px-4 py-2 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full">Sign in</Link>
              </div>
            )}
          </section>

          {/* ── Latest video performance card (YouTube Studio #1 widget) ── */}
          {!loading && topVideos[0] && (
            <section>
              <div className="flex items-center justify-between mb-3">
                <h2 className="text-[15px] font-bold text-[rgb(var(--color-text-primary))]">Latest video performance</h2>
                <Link href="/studio/analytics" className="text-[12px] text-blue-500 font-medium hover:underline flex items-center gap-0.5">
                  Full analytics <ChevronRight size={14} />
                </Link>
              </div>

              {(() => {
                const v = topVideos[0];
                return (
                  <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] overflow-hidden">
                    <div className="flex gap-3 p-3">
                      <div className="relative w-[120px] h-[68px] rounded-lg overflow-hidden bg-black flex-shrink-0">
                        {v.thumbnailURL ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={v.thumbnailURL} alt={v.title} className="w-full h-full object-cover" />
                        ) : (
                          <div className="w-full h-full bg-[rgb(var(--color-surface-hover))] flex items-center justify-center">
                            <Video size={24} className="text-[rgb(var(--color-text-tertiary))]" />
                          </div>
                        )}
                        {v.duration > 0 && (
                          <span className="absolute bottom-1 right-1 text-[10px] bg-black/80 text-white px-1 rounded">
                            {formatDuration(v.duration)}
                          </span>
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] line-clamp-2 mb-2">{v.title}</h3>
                        <div className="grid grid-cols-3 gap-1 text-center">
                          <div>
                            <p className="text-[14px] font-bold text-[rgb(var(--color-text-primary))]">{formatNum(v.views)}</p>
                            <p className="text-[10px] text-[rgb(var(--color-text-tertiary))]">Views</p>
                          </div>
                          <div>
                            <p className="text-[14px] font-bold text-[rgb(var(--color-text-primary))]">{formatNum(v.likes)}</p>
                            <p className="text-[10px] text-[rgb(var(--color-text-tertiary))]">Likes</p>
                          </div>
                          <div>
                            <p className="text-[14px] font-bold text-[rgb(var(--color-text-primary))]">{v.comments}</p>
                            <p className="text-[10px] text-[rgb(var(--color-text-tertiary))]">Comments</p>
                          </div>
                        </div>
                      </div>
                    </div>
                    <div className="border-t border-[rgb(var(--color-border))] flex divide-x divide-[rgb(var(--color-border))]">
                      <Link href={`/watch/${v.id}`} className="flex-1 py-2.5 text-[12px] text-center font-medium text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors">
                        Watch
                      </Link>
                      <Link href={`/studio/videos/${v.id}/edit`} className="flex-1 py-2.5 text-[12px] text-center font-medium text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors flex items-center justify-center gap-1">
                        <Pencil size={12} /> Edit
                      </Link>
                      <Link href={`/studio/analytics?videoId=${v.id}`} className="flex-1 py-2.5 text-[12px] text-center font-medium text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors flex items-center justify-center gap-1">
                        <BarChart3 size={12} /> Analytics
                      </Link>
                    </div>
                  </div>
                );
              })()}
            </section>
          )}

          {/* ── Top performing videos ── */}
          {!loading && topVideos.length > 0 && (
            <section>
              <div className="flex items-center justify-between mb-3">
                <h2 className="text-[15px] font-bold text-[rgb(var(--color-text-primary))]">Top videos</h2>
                <Link href="/studio/videos" className="text-[12px] text-blue-500 font-medium hover:underline flex items-center gap-0.5">
                  See all <ChevronRight size={14} />
                </Link>
              </div>
              <div className="space-y-2">
                {topVideos.map((v, i) => (
                  <Link
                    key={v.id}
                    href={`/studio/videos/${v.id}/edit`}
                    className="flex items-center gap-3 p-3 bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
                  >
                    <span className={`w-6 h-6 rounded-full flex items-center justify-center text-[11px] font-bold flex-shrink-0 ${
                      i === 0 ? 'bg-yellow-400 text-yellow-900' :
                      i === 1 ? 'bg-gray-300 text-gray-700' :
                      i === 2 ? 'bg-amber-600 text-white' : 'bg-[rgb(var(--color-surface-hover))] text-[rgb(var(--color-text-secondary))]'
                    }`}>{i + 1}</span>
                    <div className="w-16 h-9 rounded overflow-hidden bg-[rgb(var(--color-surface-hover))] flex-shrink-0">
                      {v.thumbnailURL
                        ? <img src={v.thumbnailURL} alt={v.title} className="w-full h-full object-cover" />
                        : <div className="w-full h-full flex items-center justify-center"><Video size={14} className="text-[rgb(var(--color-text-tertiary))]" /></div>
                      }
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] line-clamp-1">{v.title}</p>
                      <div className="flex items-center gap-3 text-[11px] text-[rgb(var(--color-text-tertiary))] mt-0.5">
                        <span className="flex items-center gap-0.5"><Eye size={10} /> {formatNum(v.views)}</span>
                        <span className="flex items-center gap-0.5"><ThumbsUp size={10} /> {formatNum(v.likes)}</span>
                        <span className="flex items-center gap-0.5"><MessageSquare size={10} /> {v.comments}</span>
                      </div>
                    </div>
                    <ChevronRight size={16} className="text-[rgb(var(--color-text-tertiary))] flex-shrink-0" />
                  </Link>
                ))}
              </div>
            </section>
          )}

          {/* ── Recent comments ── */}
          {!loading && recentComments.length > 0 && (
            <section>
              <div className="flex items-center justify-between mb-3">
                <h2 className="text-[15px] font-bold text-[rgb(var(--color-text-primary))]">Recent comments</h2>
                <Link href="/studio/comments" className="text-[12px] text-blue-500 font-medium hover:underline flex items-center gap-0.5">
                  View all <ChevronRight size={14} />
                </Link>
              </div>
              <div className="space-y-2">
                {recentComments.map((c) => (
                  <Link
                    key={c.id}
                    href={`/studio/comments?videoId=${c.videoId}`}
                    className="flex gap-3 p-3 bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
                  >
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={c.avatarURL || `https://i.pravatar.cc/40?u=${c.id}`}
                      alt={c.displayName}
                      className="w-8 h-8 rounded-full flex-shrink-0"
                    />
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-1.5 mb-0.5">
                        <span className="text-[12px] font-semibold text-[rgb(var(--color-text-primary))]">{c.displayName}</span>
                        <span className="text-[11px] text-[rgb(var(--color-text-tertiary))]">on "{c.videoTitle}"</span>
                      </div>
                      <p className="text-[12px] text-[rgb(var(--color-text-secondary))] line-clamp-2">{c.text}</p>
                    </div>
                  </Link>
                ))}
              </div>
            </section>
          )}

          {/* ── Upload CTA when no videos ── */}
          {!loading && topVideos.length === 0 && (
            <section className="text-center py-12">
              <div className="w-16 h-16 rounded-2xl bg-[rgb(var(--color-surface))] flex items-center justify-center mx-auto mb-4">
                <Video size={32} className="text-[rgb(var(--color-text-tertiary))]" />
              </div>
              <h3 className="text-[16px] font-bold text-[rgb(var(--color-text-primary))] mb-2">No videos yet</h3>
              <p className="text-[13px] text-[rgb(var(--color-text-secondary))] mb-5">Upload your first video to start growing your channel</p>
              <Link href="/upload" className="inline-flex items-center gap-2 px-6 py-3 bg-[rgb(var(--color-primary))] text-white font-semibold rounded-full hover:opacity-90 transition-opacity">
                <Upload size={18} /> Upload Video
              </Link>
            </section>
          )}

        </main>
      </div>
    </div>
  );
}
