'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { Film, Star, Play, Loader2, ChevronRight } from 'lucide-react';
import {
  collection, query, where, orderBy, limit, getDocs,
} from 'firebase/firestore';
import { db } from '@/lib/firebase/config';
import Sidebar from '@/components/layout/Sidebar';
import TopNav from '@/components/layout/TopNav';

interface Movie {
  id: string;
  title: string;
  thumbnailURL: string;
  duration: number;
  viewCount: number;
  likeCount: number;
  isPremium: boolean;
  category: string;
  description: string;
  createdAt: Date;
}

function formatDuration(s: number): string {
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

function formatCount(n: number): string {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'K';
  return String(n);
}

const GENRES = ['All', 'Action', 'Comedy', 'Drama', 'Horror', 'Sci-Fi', 'Documentary', 'Animation'];

/**
 * Movies hub — YouTube Movies parity.
 * Featured hero, genre shelves, free-with-ads + premium sections.
 * Videos are pulled from Firestore where category matches movie genres.
 */
export default function MoviesPage() {
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false);
  const [movies, setMovies] = useState<Movie[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedGenre, setSelectedGenre] = useState('All');

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      try {
        // Fetch long-form videos tagged as movies (duration > 3600s or category matches)
        const q = query(
          collection(db, 'videos'),
          where('isPublic', '==', true),
          orderBy('viewCount', 'desc'),
          limit(80)
        );
        const snap = await getDocs(q);
        if (cancelled) return;
        const rows: Movie[] = snap.docs
          .map((d) => {
            const data = d.data();
            return {
              id: d.id,
              title: data.title ?? 'Untitled',
              thumbnailURL: data.thumbnailURL ?? '',
              duration: data.duration ?? 0,
              viewCount: data.viewCount ?? 0,
              likeCount: data.likeCount ?? 0,
              isPremium: data.isPremium ?? false,
              category: data.category ?? '',
              description: data.description ?? '',
              createdAt: data.createdAt?.toDate?.() ?? new Date(),
            };
          })
          .filter((m) => m.duration > 1800); // 30+ min = movie-length
        setMovies(rows);
      } catch (e) {
        console.error(e);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    load();
    return () => { cancelled = true; };
  }, []);

  const filtered = selectedGenre === 'All'
    ? movies
    : movies.filter((m) => m.category.toLowerCase().includes(selectedGenre.toLowerCase()));

  const featured = filtered[0];
  const freeMovies = filtered.filter((m) => !m.isPremium);
  const premiumMovies = filtered.filter((m) => m.isPremium);

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      <TopNav onToggleSidebar={() => setIsSidebarCollapsed(!isSidebarCollapsed)} />
      <Sidebar isCollapsed={isSidebarCollapsed} />

      <main className={`pt-14 transition-all duration-200 ${isSidebarCollapsed ? 'pl-16' : 'pl-56'}`}>
        <div className="max-w-[1800px] mx-auto px-6 py-6">

          {/* Page header */}
          <div className="flex items-center gap-3 mb-6">
            <Film size={28} className="text-[rgb(var(--color-primary))]" />
            <h1 className="text-[24px] font-bold text-[rgb(var(--color-text-primary))]">Movies</h1>
          </div>

          {loading ? (
            <div className="flex justify-center py-24">
              <Loader2 size={32} className="animate-spin text-[rgb(var(--color-text-secondary))]" />
            </div>
          ) : movies.length === 0 ? (
            <div className="text-center py-24">
              <Film size={48} className="mx-auto mb-4 text-[rgb(var(--color-text-tertiary))]" />
              <p className="text-[rgb(var(--color-text-secondary))]">No movies available yet</p>
            </div>
          ) : (
            <div className="space-y-10">

              {/* Genre chips */}
              <div className="flex gap-2 overflow-x-auto scrollbar-hide pb-1">
                {GENRES.map((genre) => (
                  <button
                    key={genre}
                    onClick={() => setSelectedGenre(genre)}
                    className={`px-4 py-1.5 rounded-full text-[13px] font-medium whitespace-nowrap transition-all ${
                      selectedGenre === genre
                        ? 'bg-[rgb(var(--color-text-primary))] text-[rgb(var(--color-background))]'
                        : 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]'
                    }`}
                  >
                    {genre}
                  </button>
                ))}
              </div>

              {/* Featured hero */}
              {featured && (
                <div className="relative w-full h-[360px] rounded-2xl overflow-hidden">
                  {featured.thumbnailURL && (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={featured.thumbnailURL}
                      alt={featured.title}
                      className="absolute inset-0 w-full h-full object-cover"
                    />
                  )}
                  <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-black/40 to-transparent" />
                  <div className="absolute bottom-0 left-0 p-8">
                    <p className="text-[12px] font-semibold text-[rgb(var(--color-primary))] uppercase mb-2">Featured</p>
                    <h2 className="text-[28px] font-bold text-white mb-2 line-clamp-2">{featured.title}</h2>
                    <div className="flex items-center gap-3 text-[13px] text-white/80 mb-4">
                      <span className="flex items-center gap-1"><Star size={12} className="text-yellow-400" /> {formatCount(featured.likeCount)}</span>
                      <span>{formatDuration(featured.duration)}</span>
                      <span>{featured.isPremium ? '🔒 Premium' : '🆓 Free'}</span>
                    </div>
                    <Link
                      href={`/watch/${featured.id}`}
                      className="inline-flex items-center gap-2 px-6 py-3 bg-white text-black font-bold rounded-full hover:bg-white/90 transition-colors"
                    >
                      <Play size={18} fill="currentColor" /> Watch Now
                    </Link>
                  </div>
                </div>
              )}

              {/* Free movies shelf */}
              {freeMovies.length > 0 && (
                <MovieShelf title="Free to Watch" movies={freeMovies.slice(0, 12)} />
              )}

              {/* Premium movies shelf */}
              {premiumMovies.length > 0 && (
                <MovieShelf title="🔒 Premium" movies={premiumMovies.slice(0, 12)} />
              )}

              {/* All movies grid */}
              {filtered.length > 1 && (
                <section>
                  <h2 className="text-[18px] font-bold text-[rgb(var(--color-text-primary))] mb-4">
                    {selectedGenre === 'All' ? 'All Movies' : selectedGenre}
                  </h2>
                  <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
                    {filtered.map((movie) => (
                      <MovieCard key={movie.id} movie={movie} />
                    ))}
                  </div>
                </section>
              )}
            </div>
          )}
        </div>
      </main>
    </div>
  );
}

function MovieShelf({ title, movies }: { title: string; movies: Movie[] }) {
  return (
    <section>
      <div className="flex items-center justify-between mb-3">
        <h2 className="text-[18px] font-bold text-[rgb(var(--color-text-primary))]">{title}</h2>
        <button className="text-[13px] text-blue-500 font-medium hover:underline flex items-center gap-0.5">
          See all <ChevronRight size={14} />
        </button>
      </div>
      <div className="flex gap-4 overflow-x-auto scrollbar-hide pb-2">
        {movies.map((movie) => (
          <div key={movie.id} className="flex-shrink-0 w-[160px]">
            <MovieCard movie={movie} />
          </div>
        ))}
      </div>
    </section>
  );
}

function MovieCard({ movie }: { movie: Movie }) {
  return (
    <Link href={`/watch/${movie.id}`} className="block group">
      <div className="relative aspect-[2/3] rounded-xl overflow-hidden bg-[rgb(var(--color-surface))] mb-2">
        {movie.thumbnailURL ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={movie.thumbnailURL}
            alt={movie.title}
            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center">
            <Film size={32} className="text-[rgb(var(--color-text-tertiary))]" />
          </div>
        )}
        {movie.isPremium && (
          <span className="absolute top-2 right-2 text-[10px] bg-yellow-500 text-black font-bold px-1.5 py-0.5 rounded">
            PREMIUM
          </span>
        )}
        <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors flex items-center justify-center">
          <Play size={32} className="text-white opacity-0 group-hover:opacity-100 transition-opacity" fill="currentColor" />
        </div>
      </div>
      <p className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] line-clamp-2 mb-1">{movie.title}</p>
      <div className="flex items-center gap-2 text-[11px] text-[rgb(var(--color-text-tertiary))]">
        <span>{formatDuration(movie.duration)}</span>
        {movie.isPremium ? (
          <span className="text-yellow-500 font-medium">Premium</span>
        ) : (
          <span className="text-green-500 font-medium">Free</span>
        )}
      </div>
    </Link>
  );
}
