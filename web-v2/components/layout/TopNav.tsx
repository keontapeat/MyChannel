'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Search, Bell, User, Menu, Upload, Video, DollarSign, Settings, LogOut, Mic } from 'lucide-react';
import { useState, useRef, useEffect } from 'react';
import { useAuth } from '@/contexts/AuthContext';

interface TopNavProps {
  onToggleSidebar?: () => void;
}

export default function TopNav({ onToggleSidebar }: TopNavProps) {
  const router = useRouter();
  const [q, setQ] = useState('');
  const [focused, setFocused] = useState(false);
  const [userMenu, setUserMenu] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  // Shared auth state from the root-level provider — survives page/component
  // remounts during client-side navigation, so it never flickers back to
  // "signed out" when moving between routes.
  const { user: firebaseUser, isAuthenticated: isAuth, authResolved, signOut } = useAuth();

  const user = {
    name: firebaseUser?.displayName || firebaseUser?.email?.split('@')[0] || 'Creator',
    avatar: firebaseUser?.photoURL || '',
  };

  const handleSignOut = async () => {
    setUserMenu(false);
    try {
      await signOut();
      router.push('/');
    } catch (err) {
      console.error('Sign out failed:', err);
    }
  };

  useEffect(() => {
    const close = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) setUserMenu(false);
    };
    document.addEventListener('mousedown', close);
    return () => document.removeEventListener('mousedown', close);
  }, []);

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (q.trim()) router.push(`/search?q=${encodeURIComponent(q.trim())}`);
  };

  return (
    <header className="fixed top-0 left-0 right-0 z-50 flex h-[calc(3.5rem+env(safe-area-inset-top))] items-end justify-between gap-2 bg-[rgb(var(--color-background))]/95 px-3 pb-2 pt-[env(safe-area-inset-top)] backdrop-blur sm:items-center sm:gap-4 sm:px-4 sm:pb-0">

      {/* ── Left: hamburger + logo ── */}
      <div className="flex min-w-0 flex-shrink-0 items-center gap-2 sm:gap-4">
        <button
          onClick={onToggleSidebar}
          className="flex h-10 w-10 items-center justify-center rounded-full transition-colors hover:bg-[rgb(var(--color-surface-hover))]"
          aria-label="Open navigation menu"
        >
          <Menu size={20} className="text-[rgb(var(--color-text-primary))]" />
        </button>

        <Link href="/" className="flex flex-shrink-0 items-center gap-2" aria-label="MyChannel home">
          <img
            src="/logo.png"
            alt=""
            width={32}
            height={32}
            className="h-8 w-8 object-contain"
          />
          <span className="hidden text-[18px] font-semibold leading-none tracking-tight text-[rgb(var(--color-text-primary))] md:block">
            MyChannel
          </span>
        </Link>
      </div>

      {/* ── Center: desktop/tablet search; mobile opens the dedicated search screen ── */}
      <div className="hidden min-w-0 flex-1 items-center justify-center sm:flex sm:max-w-[600px]">
        <form onSubmit={submit} className="flex min-w-0 w-full">
          {/* Input */}
          <div
            className={`flex flex-1 items-center h-10 border rounded-l-full pl-4 pr-3 bg-[rgb(var(--color-background))] transition-colors ${
              focused
                ? 'border-blue-500 shadow-[inset_0_0_0_1px_rgb(37,99,235)]'
                : 'border-[rgb(var(--color-border))]'
            }`}
          >
            {focused && <Search size={15} className="text-[rgb(var(--color-text-tertiary))] mr-2 flex-shrink-0" />}
            <input
              type="text"
              value={q}
              onChange={e => setQ(e.target.value)}
              onFocus={() => setFocused(true)}
              onBlur={() => setFocused(false)}
              placeholder="Search"
              className="w-full bg-transparent text-[14px] text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] outline-none"
            />
          </div>
          {/* Search button */}
          <button
            type="submit"
            className="h-10 w-16 flex items-center justify-center border border-l-0 border-[rgb(var(--color-border))] rounded-r-full bg-[rgb(var(--color-surface))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors flex-shrink-0"
            aria-label="Search"
          >
            <Search size={18} className="text-[rgb(var(--color-text-primary))]" />
          </button>
        </form>

        {/* Mic */}
        <button
          className="ml-2 w-10 h-10 flex items-center justify-center rounded-full bg-[rgb(var(--color-surface))] hover:bg-[rgb(var(--color-surface-hover))] flex-shrink-0 transition-colors"
          aria-label="Search with voice"
        >
          <Mic size={18} className="text-[rgb(var(--color-text-primary))]" />
        </button>
      </div>

      {/* ── Right: actions ── */}
      <div className="flex items-center gap-1 flex-shrink-0">
        {!authResolved ? (
          // Avoid flashing "Sign in" before Firebase reports the real auth state
          <div className="w-9 h-9 rounded-full bg-[rgb(var(--color-surface))] animate-pulse" />
        ) : isAuth ? (
          <>
            {/* Create */}
            <Link
              href="/upload"
              className="flex items-center gap-2 h-9 px-4 rounded-full border border-[rgb(var(--color-border))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors text-[13.5px] font-medium text-[rgb(var(--color-text-primary))]"
            >
              <Upload size={16} />
              <span className="hidden md:block">Create</span>
            </Link>

            {/* Notifications */}
            <button className="relative w-10 h-10 flex items-center justify-center rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors" aria-label="Notifications">
              <Bell size={20} className="text-[rgb(var(--color-text-primary))]" />
              <span className="absolute top-1.5 right-1.5 w-[9px] h-[9px] rounded-full bg-[rgb(var(--color-primary))] border-2 border-[rgb(var(--color-background))]" />
            </button>

            {/* Avatar + dropdown */}
            <div className="relative" ref={menuRef}>
              <button
                onClick={() => setUserMenu(!userMenu)}
                className="w-10 h-10 flex items-center justify-center rounded-full overflow-hidden hover:ring-2 hover:ring-[rgb(var(--color-border))] transition-all"
                aria-label="Account"
              >
                {user.avatar ? (
                  <img src={user.avatar} alt={user.name} className="w-8 h-8 rounded-full object-cover" />
                ) : (
                  <div className="w-8 h-8 rounded-full bg-purple-600 flex items-center justify-center text-white text-[13px] font-semibold">
                    {user.name.charAt(0).toUpperCase()}
                  </div>
                )}
              </button>

              {userMenu && (
                <div className="absolute right-0 mt-2 w-64 bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] rounded-xl shadow-lg overflow-hidden z-50">
                  <div className="flex items-center gap-3 px-4 py-3 border-b border-[rgb(var(--color-border))]">
                    <div className="w-10 h-10 rounded-full bg-purple-600 flex items-center justify-center text-white font-semibold flex-shrink-0">
                      {user.name.charAt(0).toUpperCase()}
                    </div>
                    <div className="min-w-0">
                      <p className="text-[14px] font-semibold text-[rgb(var(--color-text-primary))] truncate">{user.name}</p>
                      <Link href="/profile/me" className="text-[13px] text-blue-500 hover:underline">View your channel</Link>
                    </div>
                  </div>
                  <div className="py-1">
                    {[
                      { icon: Video,       label: 'Creator Studio', href: '/studio' },
                      { icon: DollarSign,  label: 'Wallet',         href: '/wallet' },
                      { icon: Settings,    label: 'Settings',       href: '/settings' },
                    ].map(({ icon: Icon, label, href }) => (
                      <Link key={href} href={href} className="flex items-center gap-3 px-4 py-2.5 text-[13.5px] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors">
                        <Icon size={18} className="text-[rgb(var(--color-text-secondary))]" />
                        {label}
                      </Link>
                    ))}
                    <div className="my-1 border-t border-[rgb(var(--color-border))]" />
                    <button
                      onClick={handleSignOut}
                      className="flex w-full items-center gap-3 px-4 py-2.5 text-[13.5px] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
                    >
                      <LogOut size={18} className="text-[rgb(var(--color-text-secondary))]" />
                      Sign out
                    </button>
                  </div>
                </div>
              )}
            </div>
          </>
        ) : (
          <Link
            href="/login"
            className="flex items-center gap-2 h-9 px-4 rounded-full border border-blue-500 text-blue-500 hover:bg-blue-50 dark:hover:bg-blue-950/30 transition-colors text-[13.5px] font-medium"
          >
            <User size={16} />
            Sign in
          </Link>
        )}
      </div>
    </header>
  );
}
