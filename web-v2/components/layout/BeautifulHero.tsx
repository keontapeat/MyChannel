'use client';

// 🔥🎨 BEAUTIFUL YOUTUBE-PREMIUM HERO SECTION 🎨🔥
// The most stunning hero section ever created

import { Play, TrendingUp, Award, Zap, CheckCircle, Eye } from 'lucide-react';
import { useState, useEffect } from 'react';
import Link from 'next/link';

interface HeroVideo {
  id: string;
  title: string;
  description: string;
  thumbnailURL: string;
  channel: string;
  channelIcon: string;
  views: string;
  category: string;
}

interface BeautifulHeroProps {
  featuredVideos: HeroVideo[];
}

export default function BeautifulHero({ featuredVideos }: BeautifulHeroProps) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isAnimating, setIsAnimating] = useState(false);

  const currentVideo = featuredVideos[currentIndex] || featuredVideos[0];

  // Auto-rotate every 5 seconds
  useEffect(() => {
    if (featuredVideos.length <= 1) return;

    const interval = setInterval(() => {
      setIsAnimating(true);
      setTimeout(() => {
        setCurrentIndex((prev) => (prev + 1) % featuredVideos.length);
        setIsAnimating(false);
      }, 300);
    }, 5000);

    return () => clearInterval(interval);
  }, [featuredVideos.length]);

  if (!currentVideo) return null;

  return (
    <div className="relative h-[60vh] min-h-[500px] max-h-[700px] overflow-hidden bg-black">
      {/* Background Video/Image with Parallax */}
      <div className={`
        absolute inset-0 transition-opacity duration-500
        ${isAnimating ? 'opacity-0' : 'opacity-100'}
      `}>
        <img
          src={currentVideo.thumbnailURL}
          alt={currentVideo.title}
          className="w-full h-full object-cover scale-110 animate-slow-zoom"
        />
        
        {/* Gradient Overlays - YouTube Premium Style */}
        <div className="absolute inset-0 bg-gradient-to-t from-black via-black/50 to-transparent" />
        <div className="absolute inset-0 bg-gradient-to-r from-black/80 via-transparent to-black/60" />
        <div className="absolute inset-0 bg-black/20" /> {/* Subtle dark overlay */}
      </div>

      {/* Content Container */}
      <div className="relative h-full flex items-end pb-16 md:pb-20">
        <div className="container-youtube w-full">
          <div className="max-w-3xl space-y-6">
            {/* Category Badge - Premium Style */}
            <div className="flex items-center gap-3 animate-slideInRight">
              <div className="flex items-center gap-2 px-4 py-2 rounded-full bg-white/10 backdrop-blur-md border border-white/20">
                <TrendingUp size={16} className="text-[rgb(var(--color-primary))]" />
                <span className="text-white text-sm font-semibold uppercase tracking-wide">
                  {currentVideo.category}
                </span>
              </div>
              
              <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-[rgb(var(--color-primary))]/20 backdrop-blur-md border border-[rgb(var(--color-primary))]/30">
                <Award size={14} className="text-[rgb(var(--color-primary))]" />
                <span className="text-white text-xs font-bold">FEATURED</span>
              </div>
            </div>

            {/* Title - Beautiful Typography */}
            <h1 className={`
              text-4xl md:text-5xl lg:text-6xl font-bold text-white
              leading-tight tracking-tight
              drop-shadow-2xl
              transition-all duration-500
              ${isAnimating ? 'opacity-0 translate-y-4' : 'opacity-100 translate-y-0'}
            `}>
              {currentVideo.title}
            </h1>

            {/* Description - Clean & Readable */}
            <p className={`
              text-base md:text-lg text-white/90
              leading-relaxed max-w-2xl
              drop-shadow-lg
              line-clamp-2
              transition-all duration-500 delay-75
              ${isAnimating ? 'opacity-0 translate-y-4' : 'opacity-100 translate-y-0'}
            `}>
              {currentVideo.description}
            </p>

            {/* Metadata - YouTube Style */}
            <div className={`
              flex items-center gap-4 text-white/80
              transition-all duration-500 delay-150
              ${isAnimating ? 'opacity-0 translate-y-4' : 'opacity-100 translate-y-0'}
            `}>
              <div className="flex items-center gap-2">
                <img
                  src={currentVideo.channelIcon}
                  alt={currentVideo.channel}
                  className="w-8 h-8 rounded-full ring-2 ring-white/30"
                />
                <span className="font-medium">{currentVideo.channel}</span>
                <CheckCircle size={16} className="text-white/90" fill="currentColor" />
              </div>
              
              <span className="opacity-50">•</span>
              
              <div className="flex items-center gap-1.5">
                <Eye size={16} />
                <span>{currentVideo.views} views</span>
              </div>
            </div>

            {/* CTA Buttons - Premium Style */}
            <div className={`
              flex items-center gap-4
              transition-all duration-500 delay-200
              ${isAnimating ? 'opacity-0 translate-y-4' : 'opacity-100 translate-y-0'}
            `}>
              <Link href={`/watch/${currentVideo.id}`}>
                <button className="
                  group/play
                  flex items-center gap-3
                  px-8 py-4 rounded-full
                  bg-white text-black
                  hover:bg-white/90
                  transition-all duration-200
                  shadow-xl hover:shadow-2xl
                  hover:scale-105
                  font-semibold text-base
                ">
                  <Play size={20} className="fill-current" />
                  <span>Watch Now</span>
                </button>
              </Link>

              <button className="
                flex items-center gap-2
                px-6 py-4 rounded-full
                bg-white/10 text-white
                hover:bg-white/20
                backdrop-blur-md
                border border-white/30
                transition-all duration-200
                font-medium
              ">
                <Zap size={18} />
                <span>Add to List</span>
              </button>
            </div>

            {/* Pagination Dots - YouTube Style */}
            {featuredVideos.length > 1 && (
              <div className="flex items-center gap-2 pt-4">
                {featuredVideos.map((_, i) => (
                  <button
                    key={i}
                    onClick={() => {
                      setIsAnimating(true);
                      setTimeout(() => {
                        setCurrentIndex(i);
                        setIsAnimating(false);
                      }, 300);
                    }}
                    className={`
                      h-1 rounded-full transition-all duration-300
                      ${i === currentIndex 
                        ? 'w-8 bg-white' 
                        : 'w-2 bg-white/40 hover:bg-white/60'
                      }
                    `}
                    aria-label={`Go to slide ${i + 1}`}
                  />
                ))}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Ambient Light Effect (Premium Touch) */}
      <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-3/4 h-32 bg-[rgb(var(--color-primary))]/20 blur-3xl opacity-50" />
    </div>
  );
}

