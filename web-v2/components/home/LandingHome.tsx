'use client';

/**
 * MyChannel Landing Home — light mode by default.
 * Recreates the reference design: hero with sparkline stat cards + featured
 * player, category chips, Featured + AI Recommended row, Trending Now + Top
 * MyChannels row, and a sticky bottom sign-in / follow bar.
 */

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import {
  Search, Bell, Plus, Play, Camera, BadgeCheck, Star, Flame,
  ChevronRight, ArrowRight,
} from 'lucide-react';
import Sparkline from './Sparkline';

const CATEGORIES = [
  'All', 'Music', 'Live', 'Gaming', 'News', 'Mixest',
  'Podcast', 'Recently uploaded', 'Watched', 'New to you',
];

const STATS = [
  { value: '1M+', label: 'Active Creators', data: [4, 6, 5, 8, 7, 11, 10, 14] },
  { value: '50M+', label: 'Daily Views', data: [6, 5, 7, 6, 9, 8, 12, 15] },
  { value: '10K+', label: 'Awards Given', data: [3, 4, 6, 5, 7, 9, 8, 12] },
];

const AI_RECOMMENDED = [
  { id: 'rec-1', title: 'Hhh', creator: 'Keonta Peat', duration: '0:36', seed: 'rec1' },
  { id: 'rec-2', title: 'Uhh', creator: 'Keonta Peat', duration: '0:38', seed: 'rec2' },
  { id: 'rec-3', title: 'Uhh', creator: 'Keonta Peat', duration: '0:41', seed: 'rec3' },
];

const TRENDING = [
  { id: 'tr-1', rank: 1, title: 'Baby Ju - Free Ty (Official Video) #ShotByBigHornet', channel: 'Baby Ju', views: '10.0M views', seed: 'trend1' },
  { id: 'tr-2', rank: 2, title: 'KTrip - "Whatever" (Block Love Exclusive - Official Music Video)', channel: 'KTrip', views: '8.0M views', seed: 'trend2' },
];

const TOP_CHANNELS = [
  { id: 'ch-1', rank: 1, name: 'Ktrip', subs: '5.0K subs', seed: 'ktrip' },
  { id: 'ch-2', rank: 2, name: 'Baby Juu', subs: '3.5K subs', seed: 'babyjuu' },
  { id: 'ch-3', rank: 3, name: 'Mbk Cari', subs: '2.0K subs', seed: 'mbkcari' },
];

export default function LandingHome() {
  const [selectedCategory, setSelectedCategory] = useState('All');

  return (
    <div className="min-h-screen bg-white text-gray-900">
      <TopBar />

      <main className="mx-auto max-w-[1280px] px-4 sm:px-6 pb-28 pt-6">
        <HeroSection />

        {/* Category chips */}
        <div className="mt-8 flex gap-2 overflow-x-auto scrollbar-hide pb-1">
          {CATEGORIES.map((cat) => {
            const active = cat === selectedCategory;
            return (
              <button
                key={cat}
                onClick={() => setSelectedCategory(cat)}
                className={`whitespace-nowrap rounded-full px-4 py-1.5 text-sm font-medium transition-colors ${
                  active
                    ? 'bg-gray-900 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                {cat}
              </button>
            );
          })}
        </div>

        {/* Two-column content */}
        <div className="mt-6 grid grid-cols-1 gap-x-8 gap-y-10 lg:grid-cols-2">
          <FeaturedColumn />
          <AIRecommendedColumn />
        </div>

        <div className="mt-10 grid grid-cols-1 gap-x-8 gap-y-10 lg:grid-cols-2">
          <TrendingColumn />
          <TopChannelsColumn />
        </div>
      </main>

      <BottomBar />
    </div>
  );
}

/* ---------------------------------------------------------------- Top bar */
function TopBar() {
  const router = useRouter();
  const [query, setQuery] = useState('');

  const submitSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (query.trim()) router.push(`/search?q=${encodeURIComponent(query.trim())}`);
  };

  return (
    <header className="sticky top-0 z-50 border-b border-gray-200 bg-white/90 backdrop-blur">
      <div className="mx-auto flex h-14 max-w-[1280px] items-center gap-4 px-4 sm:px-6">
        <Link href="/" className="flex items-center gap-2">
          <img src="/logo.png" alt="MyChannel" className="w-7 h-7 rounded-lg object-contain" />
          <span className="text-[18px] font-semibold tracking-tight">MyChannel</span>
        </Link>

        <form
          onSubmit={submitSearch}
          className="mx-auto hidden w-full max-w-xl items-center gap-2 rounded-full border border-gray-200 bg-gray-50 px-4 py-2 sm:flex"
        >
          <Search size={18} className="text-gray-400" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search"
            className="w-full bg-transparent text-sm outline-none placeholder:text-gray-400"
          />
        </form>

        <div className="ml-auto flex items-center gap-2 sm:gap-3">
          <Link href="/live" className="rounded-full p-2 text-gray-600 transition-colors hover:bg-gray-100" aria-label="Go live">
            <Camera size={20} />
          </Link>
          <button className="relative rounded-full p-2 text-gray-600 transition-colors hover:bg-gray-100" aria-label="Notifications">
            <Bell size={20} />
            <span className="absolute right-1.5 top-1.5 h-2 w-2 rounded-full bg-red-600" />
          </button>
          <Link
            href="/upload"
            className="inline-flex items-center gap-1.5 rounded-full bg-gray-900 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-gray-800"
          >
            <Plus size={16} /> Create
          </Link>
          <Link href="/login" className="h-8 w-8 rounded-full bg-gradient-to-br from-red-500 to-pink-500" aria-label="Account" />
        </div>
      </div>
    </header>
  );
}

/* ----------------------------------------------------------------- Hero */
function HeroSection() {
  return (
    <section className="grid grid-cols-1 items-center gap-8 lg:grid-cols-[1.4fr_1fr]">
      <div>
        <h1 className="text-4xl font-black leading-[1.05] tracking-tight sm:text-5xl md:text-6xl">
          Your Channel. <span className="block">Your Future.</span>
        </h1>
        <p className="mt-4 max-w-md text-base text-gray-500">
          Create, stream, compete, and win on the next-generation video platform.
        </p>

        <div className="mt-6 flex flex-wrap items-center gap-3">
          <Link
            href="/signup"
            className="inline-flex items-center gap-2 rounded-full bg-red-600 px-5 py-2.5 text-sm font-semibold text-white shadow-sm transition-all hover:bg-red-700 hover:shadow-md"
          >
            Get Started <ArrowRight size={16} />
          </Link>
          <Link
            href="/demo"
            className="inline-flex items-center gap-2 rounded-full border border-gray-300 bg-white px-5 py-2.5 text-sm font-semibold text-gray-800 transition-colors hover:bg-gray-50"
          >
            <Play size={16} /> Watch Demo
          </Link>
        </div>

        {/* Stat cards with sparklines */}
        <div className="mt-8 grid grid-cols-3 gap-3 sm:gap-4">
          {STATS.map((stat) => (
            <div
              key={stat.label}
              className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm"
            >
              <div className="flex items-start justify-between gap-2">
                <span className="text-2xl font-extrabold tracking-tight sm:text-3xl">{stat.value}</span>
                <Sparkline data={stat.data} />
              </div>
              <span className="mt-1 block text-xs text-gray-500">{stat.label}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Featured player */}
      <Link
        href="/watch/shot-by-keonta-intro"
        className="group relative block aspect-video overflow-hidden rounded-2xl bg-black shadow-lg"
      >
        <img
          src="https://images.unsplash.com/photo-1499092346589-b9b6be3e94b2?w=1280&q=80"
          alt="Shot By Keonta"
          className="h-full w-full object-cover opacity-95 transition-transform duration-300 group-hover:scale-105"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-transparent to-transparent" />
        <div className="absolute inset-0 flex items-center justify-center">
          <span className="flex h-16 w-16 items-center justify-center rounded-full bg-white/95 shadow-xl transition-transform group-hover:scale-110">
            <Play size={26} className="ml-1 text-red-600" fill="currentColor" />
          </span>
        </div>
        <div className="absolute bottom-0 left-0 right-0 p-4">
          <h3 className="text-base font-bold text-white">Shot By Keonta</h3>
          <p className="text-xs text-white/80">MyChannel</p>
          <div className="mt-2 h-1 w-full rounded-full bg-white/30">
            <div className="h-1 w-2/3 rounded-full bg-red-600" />
          </div>
        </div>
      </Link>
    </section>
  );
}

/* ---------------------------------------------------------- Featured col */
function FeaturedColumn() {
  return (
    <section>
      <SectionHeading icon={<Star size={16} className="text-amber-500" fill="currentColor" />} title="FEATURED" />
      <Link href="/watch/featured-1" className="group mt-4 block overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm">
        <div className="relative aspect-video bg-gray-100">
          <img
            src="https://images.unsplash.com/photo-1516280440614-37939bbacd81?w=1280&q=80"
            alt="Juicy Booty Banger"
            className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
          />
          <span className="absolute left-3 top-3 inline-flex items-center gap-1 rounded-full bg-black/60 px-2 py-1 text-xs font-medium text-white backdrop-blur">
            <Star size={11} fill="currentColor" className="text-amber-400" /> Entertainment
          </span>
          <span className="absolute right-3 top-3 rounded bg-black/70 px-1.5 py-0.5 text-xs font-semibold text-white">3:00</span>
        </div>
        <div className="flex items-center justify-between p-4">
          <div>
            <h3 className="font-semibold text-gray-900 group-hover:text-red-600">Juicy Booty Banger</h3>
            <p className="mt-1 text-sm text-gray-500">👁 5.0M views</p>
            <span className="mt-3 inline-flex items-center gap-1.5 rounded-full bg-gray-900 px-4 py-1.5 text-sm font-medium text-white">
              <Play size={13} fill="currentColor" /> Play
            </span>
          </div>
          <span className="flex h-10 w-10 items-center justify-center rounded-full bg-gray-100 text-gray-700 transition-colors group-hover:bg-gray-200">
            <Plus size={20} />
          </span>
        </div>
      </Link>
    </section>
  );
}

/* ------------------------------------------------------- AI recommended */
function AIRecommendedColumn() {
  return (
    <section>
      <SectionHeading icon={<Flame size={16} className="text-red-600" />} title="AI RECOMMENDED FOR YOU" />
      <div className="mt-4 grid grid-cols-3 gap-3">
        {AI_RECOMMENDED.map((v) => (
          <Link key={v.id} href={`/watch/${v.id}`} className="group block">
            <div className="relative aspect-[3/4] overflow-hidden rounded-xl bg-gray-100">
              <img
                src={`https://picsum.photos/seed/${v.seed}/400/520`}
                alt={v.title}
                className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
              />
              <span className="absolute bottom-2 right-2 rounded bg-black/70 px-1.5 py-0.5 text-[11px] font-semibold text-white">
                {v.duration}
              </span>
            </div>
            <h4 className="mt-2 truncate text-sm font-semibold text-gray-900">{v.title}</h4>
            <p className="flex items-center gap-1 truncate text-xs text-gray-500">
              {v.creator} <BadgeCheck size={12} className="text-blue-500" /> · 0
            </p>
          </Link>
        ))}
      </div>
    </section>
  );
}

/* ---------------------------------------------------------- Trending col */
function TrendingColumn() {
  return (
    <section>
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-bold text-gray-900">Trending Now</h2>
        <Link href="/trending" className="text-sm font-medium text-blue-600 hover:underline">See all</Link>
      </div>
      <div className="mt-4 space-y-4">
        {TRENDING.map((v) => (
          <Link key={v.id} href={`/watch/${v.id}`} className="group flex gap-3">
            <div className="relative aspect-video w-40 flex-shrink-0 overflow-hidden rounded-lg bg-gray-100">
              <img
                src={`https://picsum.photos/seed/${v.seed}/320/180`}
                alt={v.title}
                className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
              />
              <span className="absolute left-1.5 top-1.5 flex h-5 w-5 items-center justify-center rounded-full bg-white text-xs font-bold text-gray-900 shadow">
                {v.rank}
              </span>
            </div>
            <div className="min-w-0 flex-1">
              <h4 className="line-clamp-2 text-sm font-semibold text-gray-900 group-hover:text-red-600">{v.title}</h4>
              <p className="mt-1 text-xs text-gray-500">{v.channel} · {v.views}</p>
            </div>
          </Link>
        ))}
      </div>
    </section>
  );
}

/* ------------------------------------------------------ Top channels col */
function TopChannelsColumn() {
  const ring = ['ring-red-500', 'ring-pink-500', 'ring-blue-500'];
  return (
    <section>
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-bold text-red-600">Top MyChannels</h2>
        <Link href="/channels" className="text-sm font-medium text-blue-600 hover:underline">See all</Link>
      </div>
      <div className="mt-4 grid grid-cols-3 gap-4">
        {TOP_CHANNELS.map((c, i) => (
          <Link key={c.id} href={`/profile/${c.name}`} className="group flex flex-col items-center text-center">
            <div className="relative">
              <span className={`block rounded-full p-1 ring-2 ${ring[i]}`}>
                <img
                  src={`https://i.pravatar.cc/150?u=${c.seed}`}
                  alt={c.name}
                  className="h-20 w-20 rounded-full object-cover"
                />
              </span>
              <span className="absolute -top-1 left-1/2 -translate-x-1/2 rounded-full bg-red-600 px-2 py-0.5 text-[11px] font-bold text-white shadow">
                #{c.rank}
              </span>
            </div>
            <h4 className="mt-2 text-sm font-semibold text-gray-900 group-hover:text-red-600">{c.name}</h4>
            <p className="text-xs text-gray-500">{c.subs}</p>
          </Link>
        ))}
      </div>
    </section>
  );
}

/* ------------------------------------------------------------- Bottom bar */
function BottomBar() {
  const followers = [
    { rank: 1, name: 'Ktrip', subs: '5.0K subs', seed: 'ktrip' },
    { rank: 2, name: 'Baby Juu', subs: '3.5K subs', seed: 'babyjuu' },
    { rank: 3, name: 'Mbk Cari', subs: '2.0K subs', seed: 'mbkcari' },
  ];
  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 border-t border-gray-200 bg-white/95 backdrop-blur">
      <div className="mx-auto flex max-w-[1280px] items-center gap-4 overflow-x-auto px-4 py-3 sm:px-6 scrollbar-hide">
        {followers.map((f) => (
          <div key={f.rank} className="flex flex-shrink-0 items-center gap-2">
            <div className="relative">
              <img src={`https://i.pravatar.cc/100?u=${f.seed}`} alt={f.name} className="h-10 w-10 rounded-full object-cover" />
              <span className="absolute -left-1 -top-1 rounded-full bg-red-600 px-1.5 text-[10px] font-bold text-white">#{f.rank}</span>
            </div>
            <div className="hidden sm:block">
              <p className="text-sm font-semibold leading-tight text-gray-900">{f.name}</p>
              <p className="text-xs text-gray-500">{f.subs}</p>
            </div>
            <button className="rounded-full border border-gray-300 px-3 py-1 text-xs font-semibold text-gray-800 transition-colors hover:bg-gray-100">
              Follow
            </button>
          </div>
        ))}

        <button className="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full bg-gray-100 text-gray-700 hover:bg-gray-200">
          <ChevronRight size={18} />
        </button>

        <div className="ml-auto flex flex-shrink-0 items-center gap-4">
          <div className="hidden text-right md:block">
            <p className="text-sm font-bold text-gray-900">Sign in</p>
            <p className="text-xs text-gray-500">Live videos, subscribe and own content</p>
          </div>
          <Link
            href="/login"
            className="rounded-full bg-red-600 px-6 py-2.5 text-sm font-bold text-white transition-colors hover:bg-red-700"
          >
            Sign in
          </Link>
        </div>
      </div>
    </div>
  );
}

/* --------------------------------------------------------------- helpers */
function SectionHeading({ icon, title }: { icon: React.ReactNode; title: string }) {
  return (
    <div className="flex items-center gap-2">
      {icon}
      <h2 className="text-sm font-bold uppercase tracking-wide text-gray-900">{title}</h2>
    </div>
  );
}
