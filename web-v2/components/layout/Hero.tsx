'use client';

/**
 * Production-Ready Hero Component
 * Premium landing page hero section with video background support
 * 
 * Features:
 * - Responsive design (mobile-first)
 * - Video background with fallback image
 * - Accessible keyboard navigation
 * - SEO-optimized semantic HTML
 * - Performance optimized (lazy loading, intersection observer)
 * - Smooth CSS animations (no heavy dependencies)
 */

import Link from 'next/link';
import { Play, ArrowRight, TrendingUp, Users, Award } from 'lucide-react';
import { useState, useEffect, useRef } from 'react';

interface HeroProps {
  title?: string;
  subtitle?: string;
  ctaPrimary?: {
    text: string;
    href: string;
  };
  ctaSecondary?: {
    text: string;
    href: string;
  };
  backgroundVideo?: string;
  backgroundImage?: string;
  stats?: Array<{
    label: string;
    value: string;
    icon?: React.ReactNode;
  }>;
  featuredVideo?: {
    id: string;
    title: string;
    thumbnail: string;
    channel: string;
  };
}

const defaultStats = [
  { label: 'Active Creators', value: '1M+', icon: <Users size={20} /> },
  { label: 'Daily Views', value: '50M+', icon: <TrendingUp size={20} /> },
  { label: 'Awards Given', value: '10K+', icon: <Award size={20} /> },
];

const Hero = ({
  title = 'Your Channel. Your Future.',
  subtitle = 'The next-generation video platform combining YouTube + Twitch + DraftKings + UFC. Create, stream, compete, and win.',
  ctaPrimary = { text: 'Get Started', href: '/signup' },
  ctaSecondary = { text: 'Watch Demo', href: '/watch/demo' },
  backgroundVideo,
  backgroundImage = 'https://images.unsplash.com/photo-1611162617474-5b21e879e113?w=1920&q=80',
  stats = defaultStats,
  featuredVideo,
}: HeroProps) => {
  const [isVideoLoaded, setIsVideoLoaded] = useState(false);
  const [isVisible, setIsVisible] = useState(false);
  const [isMobile, setIsMobile] = useState(false);
  const heroRef = useRef<HTMLElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);

  // Responsive detection
  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth < 768);
    };
    
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  // Intersection Observer for animations
  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
        }
      },
      { threshold: 0.1 }
    );

    if (heroRef.current) {
      observer.observe(heroRef.current);
    }

    return () => {
      if (heroRef.current) {
        observer.unobserve(heroRef.current);
      }
    };
  }, []);

  // Handle video load
  const handleVideoLoad = () => {
    setIsVideoLoaded(true);
    videoRef.current?.play().catch(() => {
      // Autoplay blocked, fallback to image
      setIsVideoLoaded(false);
    });
  };


  return (
    <section
      ref={heroRef}
      className="relative min-h-[600px] md:min-h-[700px] lg:min-h-[800px] flex items-center justify-center overflow-hidden"
      aria-label="Hero section"
    >
      {/* Background Video/Image */}
      <div className="absolute inset-0 z-0">
        {backgroundVideo && !isMobile ? (
          <>
            <video
              ref={videoRef}
              className={`absolute inset-0 w-full h-full object-cover transition-opacity duration-1000 ${
                isVideoLoaded ? 'opacity-100' : 'opacity-0'
              }`}
              autoPlay
              muted
              loop
              playsInline
              onLoadedData={handleVideoLoad}
              aria-hidden="true"
            >
              <source src={backgroundVideo} type="video/mp4" />
            </video>
            {!isVideoLoaded && (
              <img
                src={backgroundImage}
                alt=""
                className="absolute inset-0 w-full h-full object-cover"
                loading="eager"
                aria-hidden="true"
              />
            )}
          </>
        ) : (
          <img
            src={backgroundImage}
            alt=""
            className="absolute inset-0 w-full h-full object-cover"
            loading="eager"
            aria-hidden="true"
          />
        )}
        
        {/* Gradient Overlay */}
        <div className="absolute inset-0 bg-gradient-to-b from-black/60 via-black/40 to-black/80" />
        <div className="absolute inset-0 bg-gradient-to-r from-black/50 to-transparent" />
      </div>

      {/* Content */}
      <div className="relative z-10 w-full max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20 md:py-32">
        <div
          className={`max-w-4xl transition-all duration-600 ${isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-5'}`}
        >
          {/* Title */}
          <h1
            className="text-4xl sm:text-5xl md:text-6xl lg:text-7xl font-bold text-white mb-6 leading-tight animate-fade-in-up"
          >
            {title}
          </h1>

          {/* Subtitle */}
          <p
            className="text-lg sm:text-xl md:text-2xl text-white/90 mb-8 max-w-2xl leading-relaxed animate-fade-in-up"
            style={{ animationDelay: '0.1s' }}
          >
            {subtitle}
          </p>

          {/* CTAs */}
          <div
            className="flex flex-col sm:flex-row gap-4 mb-12 animate-fade-in-up"
            style={{ animationDelay: '0.2s' }}
          >
            <Link
              href={ctaPrimary.href}
              className="inline-flex items-center justify-center gap-2 px-8 py-4 bg-[rgb(var(--color-primary))] hover:bg-[rgb(var(--color-primary-hover))] text-white font-semibold rounded-full transition-all duration-200 shadow-lg hover:shadow-xl transform hover:scale-105 focus:outline-none focus:ring-4 focus:ring-[rgb(var(--color-primary))] focus:ring-opacity-50"
              aria-label={ctaPrimary.text}
            >
              {ctaPrimary.text}
              <ArrowRight size={20} aria-hidden="true" />
            </Link>
            
            {ctaSecondary && (
              <Link
                href={ctaSecondary.href}
                className="inline-flex items-center justify-center gap-2 px-8 py-4 bg-white/10 hover:bg-white/20 backdrop-blur-sm text-white font-semibold rounded-full border-2 border-white/30 transition-all duration-200 focus:outline-none focus:ring-4 focus:ring-white/50"
                aria-label={ctaSecondary.text}
              >
                <Play size={20} aria-hidden="true" />
                {ctaSecondary.text}
              </Link>
            )}
          </div>

          {/* Stats */}
          {stats && stats.length > 0 && (
            <div
              className="grid grid-cols-1 sm:grid-cols-3 gap-6 md:gap-8 animate-fade-in-up"
              role="list"
              aria-label="Platform statistics"
              style={{ animationDelay: '0.3s' }}
            >
              {stats.map((stat, index) => (
                <div
                  key={index}
                  className="flex items-center gap-4 p-4 bg-white/10 backdrop-blur-sm rounded-xl border border-white/20"
                  role="listitem"
                >
                  {stat.icon && (
                    <div className="text-white/90" aria-hidden="true">
                      {stat.icon}
                    </div>
                  )}
                  <div>
                    <div className="text-2xl md:text-3xl font-bold text-white mb-1">
                      {stat.value}
                    </div>
                    <div className="text-sm md:text-base text-white/80">
                      {stat.label}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* Featured Video Preview (Optional) */}
          {featuredVideo && (
            <div
              className="mt-12 max-w-md animate-fade-in-up"
              style={{ animationDelay: '0.4s' }}
            >
              <Link
                href={`/watch/${featuredVideo.id}`}
                className="group relative block rounded-2xl overflow-hidden shadow-2xl transform hover:scale-105 transition-transform duration-300 focus:outline-none focus:ring-4 focus:ring-white/50"
                aria-label={`Watch ${featuredVideo.title}`}
              >
                <div className="relative aspect-video">
                  <img
                    src={featuredVideo.thumbnail}
                    alt={featuredVideo.title}
                    className="w-full h-full object-cover"
                    loading="lazy"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />
                  
                  {/* Play Button Overlay */}
                  <div className="absolute inset-0 flex items-center justify-center">
                    <div className="w-16 h-16 md:w-20 md:h-20 bg-white/90 rounded-full flex items-center justify-center group-hover:bg-white transition-colors shadow-xl">
                      <Play size={32} className="text-[rgb(var(--color-primary))] ml-1" fill="currentColor" aria-hidden="true" />
                    </div>
                  </div>

                  {/* Video Info */}
                  <div className="absolute bottom-0 left-0 right-0 p-4 md:p-6">
                    <h3 className="text-white font-bold text-lg md:text-xl mb-1 line-clamp-2">
                      {featuredVideo.title}
                    </h3>
                    <p className="text-white/80 text-sm">
                      {featuredVideo.channel}
                    </p>
                  </div>
                </div>
              </Link>
            </div>
          )}
        </div>
      </div>

      {/* Scroll Indicator */}
      <div className="absolute bottom-8 left-1/2 transform -translate-x-1/2 z-10 animate-bounce">
        <div className="w-6 h-10 border-2 border-white/50 rounded-full flex items-start justify-center p-2">
          <div className="w-1 h-3 bg-white/50 rounded-full" />
        </div>
        <span className="sr-only">Scroll down</span>
      </div>
    </section>
  );
};

export default Hero;

