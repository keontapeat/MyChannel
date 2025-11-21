'use client';

// 🔥🎨 BEAUTIFUL YOUTUBE-PREMIUM HEADER 🎨🔥
// Clean, modern, professional - YouTube level design

import { Search, Video, Bell, User, Menu, X, Upload, Flame } from 'lucide-react';
import { useState } from 'react';
import Link from 'next/link';

export default function BeautifulHeader() {
  const [isSearchFocused, setIsSearchFocused] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [showMobileMenu, setShowMobileMenu] = useState(false);

  return (
    <>
      {/* Header - YouTube Premium Style */}
      <header className="
        sticky top-0 z-50
        bg-[rgb(var(--color-background))]/95 backdrop-blur-md
        border-b border-[rgb(var(--color-border))]/10
      ">
        <div className="h-16 px-4 flex items-center justify-between gap-4">
          {/* Left: Logo + Menu */}
          <div className="flex items-center gap-4">
            {/* Mobile Menu Toggle */}
            <button
              onClick={() => setShowMobileMenu(!showMobileMenu)}
              className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors lg:hidden"
              aria-label="Menu"
            >
              {showMobileMenu ? <X size={24} /> : <Menu size={24} />}
            </button>

            {/* Logo */}
            <Link href="/" className="flex items-center gap-2 group">
              <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[rgb(var(--color-primary))] to-pink-500 flex items-center justify-center group-hover:scale-105 transition-transform">
                <Video size={20} className="text-white" fill="white" />
              </div>
              <span className="text-xl font-bold hidden sm:block bg-clip-text text-transparent bg-gradient-to-r from-[rgb(var(--color-text-primary))] to-[rgb(var(--color-text-secondary))]">
                MyChannel
              </span>
            </Link>
          </div>

          {/* Center: Search Bar - YouTube Style */}
          <div className="flex-1 max-w-2xl hidden md:block">
            <div className={`
              relative flex items-center
              transition-all duration-200
              ${isSearchFocused ? 'scale-105' : 'scale-100'}
            `}>
              <input
                type="text"
                placeholder="Search videos, channels, and more..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onFocus={() => setIsSearchFocused(true)}
                onBlur={() => setIsSearchFocused(false)}
                className={`
                  w-full h-11 pl-5 pr-12
                  bg-[rgb(var(--color-surface))]
                  border border-[rgb(var(--color-border))]
                  rounded-full
                  text-[15px] text-[rgb(var(--color-text-primary))]
                  placeholder:text-[rgb(var(--color-text-tertiary))]
                  focus:outline-none focus:border-[rgb(var(--color-primary))]
                  transition-all duration-200
                  ${isSearchFocused ? 'shadow-lg' : 'shadow-sm'}
                `}
              />
              
              {/* Search Button */}
              <button className={`
                absolute right-1 top-1 bottom-1
                w-16 rounded-full
                flex items-center justify-center
                transition-all duration-200
                ${isSearchFocused 
                  ? 'bg-[rgb(var(--color-primary))] text-white' 
                  : 'bg-[rgb(var(--color-surface-hover))] text-[rgb(var(--color-text-secondary))]'
                }
                hover:scale-105
              `}>
                <Search size={18} />
              </button>
            </div>
          </div>

          {/* Right: Actions */}
          <div className="flex items-center gap-2">
            {/* Upload Button - Premium Style */}
            <Link href="/upload">
              <button className="
                group
                flex items-center gap-2
                px-4 py-2 rounded-full
                bg-[rgb(var(--color-surface))]
                hover:bg-[rgb(var(--color-surface-hover))]
                border border-[rgb(var(--color-border))]/20
                transition-all duration-200
                hover:scale-105
                hidden sm:flex
              ">
                <Upload size={18} className="text-[rgb(var(--color-text-secondary))] group-hover:text-[rgb(var(--color-primary))] transition-colors" />
                <span className="text-sm font-medium">Upload</span>
              </button>
            </Link>

            {/* Notifications - Icon Only */}
            <button className="
              relative p-2.5
              hover:bg-[rgb(var(--color-surface-hover))]
              rounded-full
              transition-all duration-200
              group
            ">
              <Bell size={20} className="text-[rgb(var(--color-text-secondary))] group-hover:text-[rgb(var(--color-text-primary))] transition-colors" />
              
              {/* Notification Badge */}
              <div className="absolute top-1.5 right-1.5 w-2 h-2 bg-[rgb(var(--color-primary))] rounded-full ring-2 ring-[rgb(var(--color-background))]" />
            </button>

            {/* User Menu */}
            <button className="
              p-1 hover:opacity-80
              rounded-full
              transition-all duration-200
              ring-2 ring-transparent
              hover:ring-[rgb(var(--color-primary))]/20
            ">
              <img
                src="https://i.pravatar.cc/40?img=3"
                alt="User"
                className="w-9 h-9 rounded-full"
              />
            </button>
          </div>
        </div>

        {/* Mobile Search (below header) */}
        <div className="px-4 pb-3 md:hidden">
          <div className="relative">
            <input
              type="text"
              placeholder="Search..."
              className="
                w-full h-10 pl-4 pr-10
                bg-[rgb(var(--color-surface))]
                border border-[rgb(var(--color-border))]
                rounded-full
                text-sm
                focus:outline-none focus:border-[rgb(var(--color-primary))]
              "
            />
            <Search size={16} className="absolute right-4 top-1/2 -translate-y-1/2 text-[rgb(var(--color-text-secondary))]" />
          </div>
        </div>
      </header>

      {/* Mobile Menu Overlay */}
      {showMobileMenu && (
        <div className="fixed inset-0 z-40 lg:hidden bg-black/50 backdrop-blur-sm animate-fadeIn">
          <div className="w-64 h-full bg-[rgb(var(--color-background))] shadow-2xl animate-slideInRight">
            {/* Mobile navigation content */}
            <div className="p-4 space-y-2">
              <MobileNavItem icon={<Flame size={20} />} text="Home" href="/" />
              <MobileNavItem icon={<TrendingUp size={20} />} text="Trending" href="/trending" />
              <MobileNavItem icon={<Video size={20} />} text="Subscriptions" href="/subscriptions" />
              <MobileNavItem icon={<Award size={20} />} text="Medals" href="/medals" />
            </div>
          </div>
        </div>
      )}
    </>
  );
}

// Mobile Nav Item
function MobileNavItem({ icon, text, href }: { icon: React.ReactNode; text: string; href: string }) {
  return (
    <Link href={href}>
      <div className="
        flex items-center gap-3 px-4 py-3
        rounded-xl
        hover:bg-[rgb(var(--color-surface-hover))]
        transition-colors
        text-[rgb(var(--color-text-primary))]
      ">
        {icon}
        <span className="font-medium">{text}</span>
      </div>
    </Link>
  );
}

