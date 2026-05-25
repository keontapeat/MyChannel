'use client';

// 🔥 YOUTUBE-LEVEL PROFESSIONAL SIDEBAR NAVIGATION 🔥

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  Home,
  TrendingUp,
  Users,
  Library,
  History,
  Clock,
  ThumbsUp,
  PlaySquare,
  Radio,
  Trophy,
  DollarSign,
  Video,
  Settings,
  HelpCircle,
  Flag,
  ChevronRight,
} from 'lucide-react';

interface SidebarProps {
  isCollapsed?: boolean;
  onToggleCollapse?: () => void;
}

interface NavItem {
  icon: typeof Home;
  label: string;
  href: string;
  badge?: string;
}

const Sidebar = ({ isCollapsed = false, onToggleCollapse }: SidebarProps) => {
  const pathname = usePathname();

  // Main navigation items
  const mainNav: NavItem[] = [
    { icon: Home, label: 'Home', href: '/' },
    { icon: TrendingUp, label: 'Trending', href: '/trending' },
    { icon: Users, label: 'Subscriptions', href: '/subscriptions' },
  ];

  // Library navigation
  const libraryNav: NavItem[] = [
    { icon: Library, label: 'Library', href: '/library' },
    { icon: History, label: 'History', href: '/history' },
    { icon: Clock, label: 'Watch Later', href: '/watch-later' },
    { icon: ThumbsUp, label: 'Liked Videos', href: '/liked' },
    { icon: PlaySquare, label: 'Playlists', href: '/playlists' },
  ];

  // Features navigation
  const featuresNav: NavItem[] = [
    { icon: Video, label: 'Flicks', href: '/flicks', badge: 'New' },
    { icon: Radio, label: 'Live Streaming', href: '/live' },
    { icon: Trophy, label: 'Championship Medals', href: '/medals', badge: '🥇' },
    { icon: DollarSign, label: 'VS Matches', href: '/vs-matches' },
  ];

  // Bottom navigation
  const bottomNav: NavItem[] = [
    { icon: Settings, label: 'Settings', href: '/settings' },
    { icon: HelpCircle, label: 'Help', href: '/help' },
    { icon: Flag, label: 'Send feedback', href: '/feedback' },
  ];

  const NavItem = ({ item }: { item: NavItem }) => {
    const isActive = pathname === item.href;
    const Icon = item.icon;

    return (
      <Link
        href={item.href}
        className={`
          flex items-center gap-6 px-3 py-2.5 rounded-lg
          transition-all duration-150
          ${
            isActive
              ? 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] font-medium'
              : 'text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]'
          }
          ${isCollapsed ? 'justify-center px-2' : ''}
        `}
      >
        <Icon
          size={20}
          className={isActive ? 'text-[rgb(var(--color-primary))]' : ''}
        />
        {!isCollapsed && (
          <span className="text-sm flex-1">{item.label}</span>
        )}
        {!isCollapsed && item.badge && (
          <span className="text-xs px-2 py-0.5 bg-[rgb(var(--color-primary))] text-white rounded-full font-medium">
            {item.badge}
          </span>
        )}
      </Link>
    );
  };

  const SectionDivider = () => (
    <div className="my-2 border-t border-[rgb(var(--color-border))]" />
  );

  return (
    <aside
      className={`
        fixed left-0 top-14 h-[calc(100vh-3.5rem)]
        bg-white dark:bg-[rgb(var(--color-background))]
        border-r border-[rgb(var(--color-border))]
        overflow-y-auto overflow-x-hidden
        transition-all duration-200 ease-in-out z-40
        ${isCollapsed ? 'w-16' : 'w-56'}
        scrollbar-hide
      `}
    >
      <nav className="py-2 px-2">
        {/* Main Navigation */}
        <div className="space-y-0.5">
          {mainNav.map((item) => (
            <NavItem key={item.href} item={item} />
          ))}
        </div>

        <SectionDivider />

        {/* Library */}
        {!isCollapsed && (
          <div className="px-2 py-1">
            <h3 className="text-xs font-semibold text-[rgb(var(--color-text-secondary))] uppercase tracking-wider mb-2">
              Library
            </h3>
          </div>
        )}
        <div className="space-y-0.5">
          {libraryNav.map((item) => (
            <NavItem key={item.href} item={item} />
          ))}
        </div>

        <SectionDivider />

        {/* Features */}
        {!isCollapsed && (
          <div className="px-2 py-1">
            <h3 className="text-xs font-semibold text-[rgb(var(--color-text-secondary))] uppercase tracking-wider mb-2">
              Features
            </h3>
          </div>
        )}
        <div className="space-y-0.5">
          {featuresNav.map((item) => (
            <NavItem key={item.href} item={item} />
          ))}
        </div>

        <SectionDivider />

        {/* Bottom Navigation */}
        <div className="space-y-0.5 pb-4">
          {bottomNav.map((item) => (
            <NavItem key={item.href} item={item} />
          ))}
        </div>

        {/* Footer */}
        {!isCollapsed && (
          <div className="px-3 py-4 text-xs text-[rgb(var(--color-text-tertiary))]">
            <div className="space-y-1">
              <Link href="/about" className="hover:text-[rgb(var(--color-text-secondary))] transition-colors">
                About
              </Link>
              <span className="mx-1">•</span>
              <Link href="/terms" className="hover:text-[rgb(var(--color-text-secondary))] transition-colors">
                Terms
              </Link>
              <span className="mx-1">•</span>
              <Link href="/privacy" className="hover:text-[rgb(var(--color-text-secondary))] transition-colors">
                Privacy
              </Link>
            </div>
            <div className="mt-4 text-[11px]">
              © 2025 MyChannel
            </div>
          </div>
        )}
      </nav>
    </aside>
  );
};

export default Sidebar;
