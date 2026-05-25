'use client';

// 🔥 YOUTUBE-LEVEL PROFESSIONAL TOP NAVIGATION BAR 🔥

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import {
  Search, Upload, Bell, User, Menu, Settings, LogOut, Video, DollarSign, ChevronDown,
} from 'lucide-react';
import { useState, useRef, useEffect } from 'react';

interface TopNavProps {
  onToggleSidebar?: () => void;
}

const TopNav = ({ onToggleSidebar }: TopNavProps) => {
  const router = useRouter();
  const [searchQuery, setSearchQuery] = useState('');
  const [showUserMenu, setShowUserMenu] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);
  const [searchFocused, setSearchFocused] = useState(false);
  const userMenuRef = useRef<HTMLDivElement>(null);
  const notificationsRef = useRef<HTMLDivElement>(null);

  // Mock user data - replace with actual auth
  const isAuthenticated = false;
  const user = {
    name: 'John Doe',
    avatar: 'https://i.pravatar.cc/150?img=1',
  };

  // Close dropdowns when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (userMenuRef.current && !userMenuRef.current.contains(event.target as Node)) {
        setShowUserMenu(false);
      }
      if (notificationsRef.current && !notificationsRef.current.contains(event.target as Node)) {
        setShowNotifications(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (searchQuery.trim()) {
      router.push(`/search?q=${encodeURIComponent(searchQuery)}`);
    }
  };

  return (
    <header className="fixed top-0 left-0 right-0 h-14 bg-white dark:bg-[rgb(var(--color-background))] border-b border-[rgb(var(--color-border))] z-50">
      <div className="flex items-center justify-between h-full px-4">
        {/* Left: Logo and Menu */}
        <div className="flex items-center gap-4">
          <button
            onClick={onToggleSidebar}
            className="p-2 rounded-full hover:bg-[rgb(var(--color-surface))] transition-colors"
            aria-label="Toggle sidebar"
          >
            <Menu size={20} className="text-[rgb(var(--color-text-primary))]" />
          </button>

          <Link href="/" className="flex items-center gap-2">
            <div className="w-8 h-8 bg-[rgb(var(--color-primary))] rounded-lg flex items-center justify-center">
              <Video size={20} className="text-white" />
            </div>
            <span className="text-lg font-bold text-[rgb(var(--color-text-primary))] hidden sm:block">
              MyChannel
            </span>
          </Link>
        </div>

        {/* Center: Search */}
        <div className="flex-1 max-w-2xl mx-4">
          <form onSubmit={handleSearch} className="flex gap-0">
            <div 
              className={`
                flex-1 flex items-center
                bg-white dark:bg-[rgb(var(--color-surface))]
                border border-[rgb(var(--color-border))]
                rounded-l-full
                overflow-hidden
                transition-all duration-150
                ${searchFocused ? 'border-[rgb(var(--color-primary))]' : ''}
              `}
            >
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onFocus={() => setSearchFocused(true)}
                onBlur={() => setSearchFocused(false)}
                placeholder="Search"
                className="flex-1 bg-transparent px-4 py-2 text-sm text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] outline-none"
              />
            </div>
            <button
              type="submit"
              className="px-6 py-2 bg-[rgb(var(--color-surface))] hover:bg-[rgb(var(--color-surface-hover))] border border-[rgb(var(--color-border))] border-l-0 rounded-r-full transition-colors"
              aria-label="Search"
            >
              <Search size={18} className="text-[rgb(var(--color-text-primary))]" />
            </button>
          </form>
        </div>

        {/* Right: Actions and User */}
        <div className="flex items-center gap-2">
          {isAuthenticated ? (
            <>
              {/* Upload Button */}
              <Link
                href="/upload"
                className="flex items-center gap-2 px-4 py-2 rounded-full hover:bg-[rgb(var(--color-surface))] transition-colors"
              >
                <Upload size={18} className="text-[rgb(var(--color-text-primary))]" />
                <span className="text-sm font-medium text-[rgb(var(--color-text-primary))] hidden md:block">
                  Upload
                </span>
              </Link>

              {/* Notifications */}
              <div className="relative" ref={notificationsRef}>
                <button
                  onClick={() => setShowNotifications(!showNotifications)}
                  className="relative p-2 rounded-full hover:bg-[rgb(var(--color-surface))] transition-colors"
                  aria-label="Notifications"
                >
                  <Bell size={20} className="text-[rgb(var(--color-text-primary))]" />
                  <span className="absolute top-1 right-1 w-2 h-2 bg-[rgb(var(--color-primary))] rounded-full"></span>
                </button>

                {/* Notifications Dropdown */}
                {showNotifications && (
                  <div className="absolute right-0 mt-2 w-80 bg-white dark:bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-lg shadow-xl-yt overflow-hidden">
                    <div className="px-4 py-3 border-b border-[rgb(var(--color-border))]">
                      <h3 className="text-sm font-semibold text-[rgb(var(--color-text-primary))]">
                        Notifications
                      </h3>
                    </div>
                    <div className="max-h-96 overflow-y-auto">
                      <div className="p-4 text-center text-sm text-[rgb(var(--color-text-secondary))]">
                        No new notifications
                      </div>
                    </div>
                  </div>
                )}
              </div>

              {/* User Menu */}
              <div className="relative" ref={userMenuRef}>
                <button
                  onClick={() => setShowUserMenu(!showUserMenu)}
                  className="flex items-center gap-2 p-1 rounded-full hover:bg-[rgb(var(--color-surface))] transition-colors"
                  aria-label="User menu"
                >
                  <img
                    src={user.avatar}
                    alt={user.name}
                    className="w-8 h-8 rounded-full"
                  />
                  <ChevronDown size={16} className="text-[rgb(var(--color-text-secondary))] hidden md:block" />
                </button>

                {/* User Dropdown */}
                {showUserMenu && (
                  <div className="absolute right-0 mt-2 w-64 bg-white dark:bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-lg shadow-xl-yt overflow-hidden">
                    {/* User Info */}
                    <div className="px-4 py-3 border-b border-[rgb(var(--color-border))]">
                      <div className="flex items-center gap-3">
                        <img
                          src={user.avatar}
                          alt={user.name}
                          className="w-10 h-10 rounded-full"
                        />
                        <div>
                          <p className="text-sm font-semibold text-[rgb(var(--color-text-primary))]">
                            {user.name}
                          </p>
                          <p className="text-xs text-[rgb(var(--color-text-secondary))]">
                            View profile
                          </p>
                        </div>
                      </div>
                    </div>

                    {/* Menu Items */}
                    <div className="py-2">
                      <Link
                        href="/studio"
                        className="flex items-center gap-3 px-4 py-2 hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
                      >
                        <Video size={18} className="text-[rgb(var(--color-text-secondary))]" />
                        <span className="text-sm text-[rgb(var(--color-text-primary))]">
                          Creator Studio
                        </span>
                      </Link>

                      <Link
                        href="/wallet"
                        className="flex items-center gap-3 px-4 py-2 hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
                      >
                        <DollarSign size={18} className="text-[rgb(var(--color-text-secondary))]" />
                        <span className="text-sm text-[rgb(var(--color-text-primary))]">
                          Wallet
                        </span>
                      </Link>

                      <Link
                        href="/settings"
                        className="flex items-center gap-3 px-4 py-2 hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
                      >
                        <Settings size={18} className="text-[rgb(var(--color-text-secondary))]" />
                        <span className="text-sm text-[rgb(var(--color-text-primary))]">
                          Settings
                        </span>
                      </Link>

                      <div className="border-t border-[rgb(var(--color-border))] my-2"></div>

                      <button
                        onClick={() => {/* Handle logout */}}
                        className="flex items-center gap-3 px-4 py-2 w-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
                      >
                        <LogOut size={18} className="text-[rgb(var(--color-text-secondary))]" />
                        <span className="text-sm text-[rgb(var(--color-text-primary))]">
                          Sign out
                        </span>
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </>
          ) : (
            <Link
              href="/login"
              className="flex items-center gap-2 px-4 py-2 rounded-full border border-[rgb(var(--color-border))] hover:bg-[rgb(var(--color-surface))] transition-colors"
            >
              <User size={18} className="text-[rgb(var(--color-primary))]" />
              <span className="text-sm font-medium text-[rgb(var(--color-primary))]">Sign in</span>
            </Link>
          )}
        </div>
      </div>
    </header>
  );
};

export default TopNav;
