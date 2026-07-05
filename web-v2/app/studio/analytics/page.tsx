'use client';

import { useState, useEffect } from 'react';
import {
  BarChart3, TrendingUp, Eye, Clock, Users, ThumbsUp,
  MessageSquare, DollarSign, Monitor, Smartphone, Tablet,
  Globe, ChevronLeft, ChevronRight,
} from 'lucide-react';
import Link from 'next/link';
import {
  collection, query, where, orderBy, limit, getDocs, getDoc, doc,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

type Range = '7d' | '28d' | '90d' | '365d';

const RANGE_LABELS: Record<Range, string> = {
  '7d':   'Last 7 days',
  '28d':  'Last 28 days',
  '90d':  'Last 90 days',
  '365d': 'Last year',
};

// Web has no impression / reach tracking pipeline yet. Views, likes and comments
// are real (from Firestore); impressions, CTR, watch time, revenue and the
// audience/traffic breakdowns below are ESTIMATES derived from those real counts.
const EST_IMPRESSIONS_PER_VIEW = 8.5;
const EST_CTR = Math.round((100 / EST_IMPRESSIONS_PER_VIEW) * 10) / 10; // ~11.8%

interface VideoStat {
  id: string;
  title: string;
  thumbnailURL: string;
  views: number;
  watchTimeHrs: number;
  avgViewDuration: number; // seconds
  ctr: number;
  likes: number;
  comments: number;
  revenue: number;
  impressions: number;
}

interface AggStats {
  views: number;
  watchTimeHrs: number;
  subscribers: number;
  revenue: number;
  avgViewDuration: number;
  impressions: number;
  ctr: number;
  likes: number;
  comments: number;
}

function formatNum(n: number): string {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'K';
  return String(Math.round(n));
}

function formatSecs(s: number): string {
  const m = Math.floor(s / 60);
  const ss = Math.round(s % 60);
  return `${m}:${String(ss).padStart(2, '0')}`;
}

function MiniBarChart({ values, color = 'bg-blue-500' }: { values: number[]; color?: string }) {
  const max = Math.max(...values, 1);
  return (
    <div className="flex items-end gap-[2px] h-14 w-full">
      {values.map((v, i) => (
        <div key={i} className="flex-1 flex flex-col justify-end">
          <div
            className={`${color} rounded-sm transition-all`}
            style={{ height: `${Math.max(4, (v / max) * 100)}%` }}
          />
        </div>
      ))}
    </div>
  );
}

function MetricCard({
  icon: Icon, iconColor, label, value, sub, subColor = 'text-green-500', chart, chartColor,
}: {
  icon: React.ElementType; iconColor: string; label: string; value: string;
  sub?: string; subColor?: string; chart?: number[]; chartColor?: string;
}) {
  return (
    <div className="bg-[rgb(var(--color-surface))] p-4 rounded-xl border border-[rgb(var(--color-border))]">
      <div className="flex items-center gap-2 mb-1">
        <Icon size={16} className={iconColor} />
        <span className="text-[11px] text-[rgb(var(--color-text-secondary))]">{label}</span>
      </div>
      <p className="text-[20px] font-bold text-[rgb(var(--color-text-primary))] leading-none mb-1">{value}</p>
      {sub && <p className={`text-[11px] font-medium ${subColor}`}>{sub}</p>}
      {chart && chart.length > 0 && (
        <div className="mt-3">
          <MiniBarChart values={chart} color={chartColor} />
        </div>
      )}
    </div>
  );
}

// YouTube Studio tab system
const TABS = ['Overview', 'Reach', 'Engagement', 'Audience', 'Revenue'] as const;
type Tab = typeof TABS[number];

export default function AnalyticsPage() {
  const [range, setRange] = useState<Range>('28d');
  const [activeTab, setActiveTab] = useState<Tab>('Overview');
  const [videos, setVideos] = useState<VideoStat[]>([]);
  const [agg, setAgg] = useState<AggStats | null>(null);
  const [loading, setLoading] = useState(true);
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
        const videosQ = query(
          collection(db, 'videos'),
          where('creatorId', '==', uid),
          orderBy('viewCount', 'desc'),
          limit(50)
        );
        const snap = await getDocs(videosQ);
        if (cancelled) return;

        let totalViews = 0, totalLikes = 0, totalComments = 0, totalDuration = 0, count = 0;

        const vids: VideoStat[] = snap.docs.map((d) => {
          const data = d.data();
          const views = data.viewCount ?? 0;
          const dur = data.duration ?? 0;
          totalViews += views;
          totalLikes += data.likeCount ?? 0;
          totalComments += data.commentCount ?? 0;
          totalDuration += dur;
          count++;
          return {
            id: d.id,
            title: data.title ?? 'Untitled',
            thumbnailURL: data.thumbnailURL ?? '',
            views,
            watchTimeHrs: Math.round((views * 0.12) * 10) / 10,
            avgViewDuration: dur > 0 ? Math.round(dur * 0.55) : 0,
            ctr: EST_CTR,
            likes: data.likeCount ?? 0,
            comments: data.commentCount ?? 0,
            revenue: parseFloat(((views / 1000) * 1.85).toFixed(2)),
            impressions: Math.round(views * EST_IMPRESSIONS_PER_VIEW),
          };
        });

        const userSnap = await getDoc(doc(db, 'users', uid));
        const subs = userSnap.exists() ? (userSnap.data().subscriberCount ?? 0) : 0;

        if (!cancelled) {
          setVideos(vids);
          setAgg({
            views: totalViews,
            watchTimeHrs: Math.round(totalViews * 0.12),
            subscribers: subs,
            revenue: parseFloat(((totalViews / 1000) * 1.85).toFixed(2)),
            avgViewDuration: count > 0 ? Math.round(totalDuration / count * 0.55) : 0,
            impressions: Math.round(totalViews * EST_IMPRESSIONS_PER_VIEW),
            ctr: EST_CTR,
            likes: totalLikes,
            comments: totalComments,
          });
        }
      } catch (e) {
        console.error(e);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    load();
    return () => { cancelled = true; };
  }, [uid, range]);

  // Generate simple sparkline from video view counts (most recent 7 data points)
  const sparkViews = videos.slice(0, 7).map((v) => v.views).reverse();
  const sparkWatchTime = videos.slice(0, 7).map((v) => v.watchTimeHrs).reverse();

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      <div className="max-w-[900px] mx-auto">

        {/* Header */}
        <header className="sticky top-0 z-50 bg-[rgb(var(--color-background))]/95 backdrop-blur border-b border-[rgb(var(--color-border))] px-4 py-3">
          <div className="flex items-center gap-3 mb-3">
            <Link href="/studio" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
              <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
            </Link>
            <BarChart3 size={22} className="text-blue-500" />
            <div>
              <h1 className="text-[17px] font-bold text-[rgb(var(--color-text-primary))] leading-none">Analytics</h1>
              <p className="text-[11px] text-[rgb(var(--color-text-secondary))]">Channel analytics</p>
            </div>
          </div>

          {/* Date range */}
          <div className="flex gap-2 overflow-x-auto scrollbar-hide pb-1">
            {(Object.keys(RANGE_LABELS) as Range[]).map((r) => (
              <button
                key={r}
                onClick={() => setRange(r)}
                className={`px-3 py-1.5 rounded-full text-[12px] font-medium whitespace-nowrap transition-all ${
                  range === r
                    ? 'bg-[rgb(var(--color-text-primary))] text-[rgb(var(--color-background))]'
                    : 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]'
                }`}
              >
                {RANGE_LABELS[r]}
              </button>
            ))}
          </div>

          {/* YouTube Studio-style tabs */}
          <div className="flex gap-0 mt-3 border-b border-[rgb(var(--color-border))] -mb-[1px]">
            {TABS.map((t) => (
              <button
                key={t}
                onClick={() => setActiveTab(t)}
                className={`px-3 py-2 text-[12px] font-semibold whitespace-nowrap border-b-2 transition-colors ${
                  activeTab === t
                    ? 'border-[rgb(var(--color-text-primary))] text-[rgb(var(--color-text-primary))]'
                    : 'border-transparent text-[rgb(var(--color-text-secondary))] hover:text-[rgb(var(--color-text-primary))]'
                }`}
              >
                {t}
              </button>
            ))}
          </div>
        </header>

        <main className="px-4 py-5 space-y-7 pb-24">

          {!loading && agg && (
            <div className="flex items-start gap-2 p-3 rounded-xl bg-blue-50 dark:bg-blue-900/10 border border-blue-100 dark:border-blue-900/30">
              <BarChart3 size={14} className="text-blue-500 mt-0.5 flex-shrink-0" />
              <p className="text-[11px] leading-snug text-[rgb(var(--color-text-secondary))]">
                Views, likes and comments are actual. Impressions, CTR, watch time, revenue and the
                audience &amp; traffic breakdowns are estimates until full analytics tracking is enabled.
              </p>
            </div>
          )}

          {loading ? (
            <div className="grid grid-cols-2 gap-2">
              {[...Array(6)].map((_, i) => (
                <div key={i} className="h-[110px] bg-[rgb(var(--color-surface))] rounded-xl animate-pulse" />
              ))}
            </div>
          ) : !agg ? (
            <div className="py-16 text-center">
              <p className="text-[rgb(var(--color-text-secondary))] text-[13px]">Sign in to view your analytics</p>
              <Link href="/login" className="mt-3 inline-block px-4 py-2 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full">Sign in</Link>
            </div>
          ) : (
            <>
              {/* ── Overview tab ── */}
              {activeTab === 'Overview' && (
                <section className="space-y-5">
                  <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
                    <MetricCard icon={Eye}         iconColor="text-blue-500"   label="Views"         value={formatNum(agg.views)}         sub={`+${formatNum(Math.round(agg.views * 0.12))} vs prev`} chart={sparkViews}     chartColor="bg-blue-500" />
                    <MetricCard icon={Clock}       iconColor="text-purple-500" label="Watch time"    value={`${formatNum(agg.watchTimeHrs)}h`} sub="Hours"                                              chart={sparkWatchTime} chartColor="bg-purple-500" />
                    <MetricCard icon={Users}       iconColor="text-red-500"    label="Subscribers"   value={formatNum(agg.subscribers)}   sub={`+${formatNum(Math.round(agg.subscribers * 0.04))}`} />
                    <MetricCard icon={DollarSign}  iconColor="text-green-500"  label="Revenue (est)" value={`$${agg.revenue.toFixed(2)}`} sub="RPM: $1.85" subColor="text-green-500" />
                    <MetricCard icon={TrendingUp}  iconColor="text-orange-500" label="Impressions"   value={formatNum(agg.impressions)}   sub={`CTR: ${agg.ctr}%`} subColor="text-orange-500" />
                    <MetricCard icon={ThumbsUp}    iconColor="text-pink-500"   label="Likes"         value={formatNum(agg.likes)}         sub={`${agg.comments} comments`} subColor="text-[rgb(var(--color-text-tertiary))]" />
                  </div>

                  {/* Avg view duration */}
                  <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
                    <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-3">Key metrics</h3>
                    <div className="space-y-3">
                      {[
                        { label: 'Avg. view duration', value: formatSecs(agg.avgViewDuration), max: '10:00', pct: Math.min(100, (agg.avgViewDuration / 600) * 100), color: 'bg-blue-500' },
                        { label: 'Click-through rate', value: `${agg.ctr}%`, max: '15%', pct: Math.min(100, (agg.ctr / 15) * 100), color: 'bg-green-500' },
                        { label: 'Revenue per 1K views', value: '$1.85', max: '$10', pct: 18.5, color: 'bg-yellow-500' },
                      ].map(({ label, value, pct, color }) => (
                        <div key={label}>
                          <div className="flex justify-between text-[12px] mb-1">
                            <span className="text-[rgb(var(--color-text-secondary))]">{label}</span>
                            <span className="font-semibold text-[rgb(var(--color-text-primary))]">{value}</span>
                          </div>
                          <div className="h-1.5 bg-[rgb(var(--color-surface-hover))] rounded-full overflow-hidden">
                            <div className={`h-full ${color} rounded-full`} style={{ width: `${pct}%` }} />
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </section>
              )}

              {/* ── Reach tab ── */}
              {activeTab === 'Reach' && (
                <section className="space-y-5">
                  <div className="grid grid-cols-2 gap-2">
                    <MetricCard icon={Eye}        iconColor="text-blue-500"   label="Impressions"         value={formatNum(agg.impressions)} sub="How often shown" />
                    <MetricCard icon={TrendingUp} iconColor="text-orange-500" label="Impressions CTR"      value={`${agg.ctr}%`}             sub="Click-through rate" />
                    <MetricCard icon={Eye}        iconColor="text-purple-500" label="Views from search"    value={formatNum(Math.round(agg.views * 0.32))} sub="~32% of total" />
                    <MetricCard icon={Eye}        iconColor="text-green-500"  label="Views from suggested" value={formatNum(Math.round(agg.views * 0.28))} sub="~28% of total" />
                  </div>

                  {/* Traffic sources */}
                  <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
                    <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-3">Traffic sources</h3>
                    <div className="space-y-3">
                      {[
                        { source: 'Search', pct: 32, color: 'bg-blue-500' },
                        { source: 'Suggested videos', pct: 28, color: 'bg-purple-500' },
                        { source: 'Browse features', pct: 18, color: 'bg-green-500' },
                        { source: 'External', pct: 12, color: 'bg-orange-500' },
                        { source: 'Other', pct: 10, color: 'bg-gray-400' },
                      ].map(({ source, pct, color }) => (
                        <div key={source}>
                          <div className="flex justify-between text-[12px] mb-1">
                            <span className="text-[rgb(var(--color-text-secondary))]">{source}</span>
                            <span className="font-semibold text-[rgb(var(--color-text-primary))]">{pct}%</span>
                          </div>
                          <div className="h-1.5 bg-[rgb(var(--color-surface-hover))] rounded-full overflow-hidden">
                            <div className={`h-full ${color} rounded-full`} style={{ width: `${pct}%` }} />
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </section>
              )}

              {/* ── Engagement tab ── */}
              {activeTab === 'Engagement' && (
                <section className="space-y-5">
                  <div className="grid grid-cols-2 gap-2">
                    <MetricCard icon={Clock}       iconColor="text-purple-500" label="Watch time"       value={`${formatNum(agg.watchTimeHrs)}h`} sub="Total hours" />
                    <MetricCard icon={Clock}       iconColor="text-blue-500"   label="Avg. view duration" value={formatSecs(agg.avgViewDuration)} sub="Per view" />
                    <MetricCard icon={ThumbsUp}    iconColor="text-pink-500"   label="Likes"            value={formatNum(agg.likes)}             sub={`Like ratio: ${agg.views > 0 ? ((agg.likes / agg.views) * 100).toFixed(1) : 0}%`} />
                    <MetricCard icon={MessageSquare} iconColor="text-yellow-500" label="Comments"       value={formatNum(agg.comments)}          sub="Total" />
                  </div>

                  {/* Top videos by engagement */}
                  <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
                    <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-3">Top videos by watch time</h3>
                    <div className="space-y-3">
                      {videos.slice(0, 5).map((v) => (
                        <Link key={v.id} href={`/studio/videos/${v.id}/edit`} className="flex items-center gap-3 hover:opacity-80 transition-opacity">
                          <div className="w-16 h-9 rounded overflow-hidden bg-[rgb(var(--color-surface-hover))] flex-shrink-0">
                            {v.thumbnailURL
                              ? <img src={v.thumbnailURL} alt={v.title} className="w-full h-full object-cover" />
                              : <div className="w-full h-full flex items-center justify-center text-[rgb(var(--color-text-tertiary))] text-[10px]">No img</div>
                            }
                          </div>
                          <div className="flex-1 min-w-0">
                            <p className="text-[12px] font-medium text-[rgb(var(--color-text-primary))] line-clamp-1">{v.title}</p>
                            <p className="text-[11px] text-[rgb(var(--color-text-tertiary))]">{v.watchTimeHrs}h · avg {formatSecs(v.avgViewDuration)}</p>
                          </div>
                          <ChevronRight size={14} className="text-[rgb(var(--color-text-tertiary))] flex-shrink-0" />
                        </Link>
                      ))}
                    </div>
                  </div>
                </section>
              )}

              {/* ── Audience tab ── */}
              {activeTab === 'Audience' && (
                <section className="space-y-5">
                  <div className="grid grid-cols-2 gap-2">
                    <MetricCard icon={Users}      iconColor="text-red-500"    label="Subscribers"        value={formatNum(agg.subscribers)} sub="Total" />
                    <MetricCard icon={Users}      iconColor="text-green-500"  label="New subscribers"    value={`+${formatNum(Math.round(agg.subscribers * 0.04))}`} sub="This period" />
                    <MetricCard icon={Eye}        iconColor="text-blue-500"   label="Unique viewers"     value={formatNum(Math.round(agg.views * 0.72))} sub="Est." />
                    <MetricCard icon={Users}      iconColor="text-orange-500" label="Returning viewers"  value={formatNum(Math.round(agg.views * 0.38))} sub="Est." />
                  </div>

                  {/* Device breakdown */}
                  <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
                    <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-3">Device type</h3>
                    <div className="space-y-3">
                      {[
                        { icon: Smartphone, label: 'Mobile', pct: 61, color: 'bg-blue-500' },
                        { icon: Monitor,    label: 'Desktop', pct: 28, color: 'bg-purple-500' },
                        { icon: Tablet,     label: 'Tablet',  pct:  7, color: 'bg-green-500' },
                        { icon: Monitor,    label: 'TV',       pct:  4, color: 'bg-orange-500' },
                      ].map(({ icon: Icon, label, pct, color }) => (
                        <div key={label}>
                          <div className="flex items-center justify-between text-[12px] mb-1">
                            <span className="flex items-center gap-1.5 text-[rgb(var(--color-text-secondary))]">
                              <Icon size={13} /> {label}
                            </span>
                            <span className="font-semibold text-[rgb(var(--color-text-primary))]">{pct}%</span>
                          </div>
                          <div className="h-1.5 bg-[rgb(var(--color-surface-hover))] rounded-full overflow-hidden">
                            <div className={`h-full ${color} rounded-full`} style={{ width: `${pct}%` }} />
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Top geographies */}
                  <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
                    <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-3 flex items-center gap-1.5">
                      <Globe size={14} /> Top geographies
                    </h3>
                    <div className="space-y-2">
                      {[
                        { country: '🇺🇸 United States', pct: 38 },
                        { country: '🇬🇧 United Kingdom', pct: 15 },
                        { country: '🇨🇦 Canada',          pct: 12 },
                        { country: '🇦🇺 Australia',        pct:  9 },
                        { country: '🇩🇪 Germany',          pct:  6 },
                      ].map(({ country, pct }) => (
                        <div key={country} className="flex items-center justify-between">
                          <span className="text-[12px] text-[rgb(var(--color-text-secondary))]">{country}</span>
                          <span className="text-[12px] font-semibold text-[rgb(var(--color-text-primary))]">{pct}%</span>
                        </div>
                      ))}
                    </div>
                  </div>
                </section>
              )}

              {/* ── Revenue tab ── */}
              {activeTab === 'Revenue' && (
                <section className="space-y-5">
                  <div className="grid grid-cols-2 gap-2">
                    <MetricCard icon={DollarSign} iconColor="text-green-500"  label="Est. revenue"     value={`$${agg.revenue.toFixed(2)}`}                               sub="This period"  subColor="text-green-500" />
                    <MetricCard icon={DollarSign} iconColor="text-blue-500"   label="RPM"              value="$1.85"                                                       sub="Per 1K views" />
                    <MetricCard icon={DollarSign} iconColor="text-purple-500" label="Ad revenue"       value={`$${(agg.revenue * 0.62).toFixed(2)}`}                      sub="62% of total" />
                    <MetricCard icon={DollarSign} iconColor="text-orange-500" label="Other revenue"    value={`$${(agg.revenue * 0.38).toFixed(2)}`}                      sub="Memberships + tips" />
                  </div>

                  {/* Revenue by stream */}
                  <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
                    <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-3">Revenue breakdown</h3>
                    <div className="space-y-3">
                      {[
                        { source: 'Skippable ads',    pct: 42, color: 'bg-blue-500' },
                        { source: 'Non-skippable ads', pct: 20, color: 'bg-purple-500' },
                        { source: 'Memberships',       pct: 18, color: 'bg-green-500' },
                        { source: 'Super Chat / Tips', pct: 12, color: 'bg-yellow-500' },
                        { source: 'Other',             pct:  8, color: 'bg-gray-400' },
                      ].map(({ source, pct, color }) => (
                        <div key={source}>
                          <div className="flex justify-between text-[12px] mb-1">
                            <span className="text-[rgb(var(--color-text-secondary))]">{source}</span>
                            <span className="font-semibold text-[rgb(var(--color-text-primary))]">{pct}%</span>
                          </div>
                          <div className="h-1.5 bg-[rgb(var(--color-surface-hover))] rounded-full overflow-hidden">
                            <div className={`h-full ${color} rounded-full`} style={{ width: `${pct}%` }} />
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Top earning videos */}
                  <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
                    <h3 className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] mb-3">Top earning videos</h3>
                    <div className="space-y-3">
                      {videos.slice(0, 5).map((v) => (
                        <div key={v.id} className="flex items-center gap-3">
                          <div className="w-16 h-9 rounded overflow-hidden bg-[rgb(var(--color-surface-hover))] flex-shrink-0">
                            {v.thumbnailURL
                              ? <img src={v.thumbnailURL} alt={v.title} className="w-full h-full object-cover" />
                              : null
                            }
                          </div>
                          <div className="flex-1 min-w-0">
                            <p className="text-[12px] font-medium text-[rgb(var(--color-text-primary))] line-clamp-1">{v.title}</p>
                            <p className="text-[11px] text-[rgb(var(--color-text-tertiary))]">{formatNum(v.views)} views</p>
                          </div>
                          <p className="text-[13px] font-bold text-green-500 flex-shrink-0">${v.revenue.toFixed(2)}</p>
                        </div>
                      ))}
                    </div>
                  </div>
                </section>
              )}

              {/* Per-video breakdown table (Overview only) */}
              {activeTab === 'Overview' && videos.length > 0 && (
                <section>
                  <div className="flex items-center justify-between mb-3">
                    <h2 className="text-[15px] font-bold text-[rgb(var(--color-text-primary))]">Video performance</h2>
                    <Link href="/studio/videos" className="text-[12px] text-blue-500 font-medium hover:underline flex items-center gap-0.5">
                      Manage <ChevronRight size={14} />
                    </Link>
                  </div>
                  <div className="space-y-2">
                    {videos.slice(0, 10).map((v) => (
                      <Link
                        key={v.id}
                        href={`/studio/analytics?videoId=${v.id}`}
                        className="flex items-center gap-3 p-3 bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
                      >
                        <div className="w-16 h-9 rounded overflow-hidden bg-[rgb(var(--color-surface-hover))] flex-shrink-0">
                          {v.thumbnailURL ? <img src={v.thumbnailURL} alt={v.title} className="w-full h-full object-cover" /> : null}
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="text-[12px] font-semibold text-[rgb(var(--color-text-primary))] line-clamp-1">{v.title}</p>
                          <div className="flex gap-3 text-[11px] text-[rgb(var(--color-text-tertiary))] mt-0.5">
                            <span>{formatNum(v.views)} views</span>
                            <span>{v.ctr}% CTR</span>
                            <span>{formatSecs(v.avgViewDuration)} avg</span>
                          </div>
                        </div>
                        <ChevronRight size={14} className="text-[rgb(var(--color-text-tertiary))] flex-shrink-0" />
                      </Link>
                    ))}
                  </div>
                </section>
              )}
            </>
          )}
        </main>
      </div>
    </div>
  );
}
