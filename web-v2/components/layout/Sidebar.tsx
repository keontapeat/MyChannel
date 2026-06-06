'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  Home, TrendingUp, Users, Library, History, Clock, ThumbsUp,
  PlaySquare, Radio, Trophy, Clapperboard, Settings, HelpCircle,
  Flag, ShoppingBag, Music2,
} from 'lucide-react';

interface SidebarProps { isCollapsed?: boolean }
interface Item { icon: React.ElementType; label: string; href: string; badge?: string }

const MAIN: Item[] = [
  { icon: Home,       label: 'Home',          href: '/' },
  { icon: TrendingUp, label: 'Trending',       href: '/trending' },
  { icon: Users,      label: 'Subscriptions',  href: '/subscriptions' },
];
const YOU: Item[] = [
  { icon: Library,    label: 'Library',        href: '/library' },
  { icon: History,    label: 'History',        href: '/history' },
  { icon: PlaySquare, label: 'Your videos',    href: '/studio/videos' },
  { icon: Clock,      label: 'Watch later',    href: '/watch-later' },
  { icon: ThumbsUp,   label: 'Liked videos',   href: '/liked' },
];
const EXPLORE: Item[] = [
  { icon: ShoppingBag, label: 'Shopping', href: '/cart' },
  { icon: Music2,      label: 'Music',    href: '/search?q=music' },
  { icon: Radio,       label: 'Live',     href: '/live' },
];
const MC: Item[] = [
  { icon: Clapperboard, label: 'Flicks',  href: '/flicks', badge: 'New' },
  { icon: Trophy,       label: 'Medals',  href: '/medals' },
];
const BOTTOM: Item[] = [
  { icon: Settings,   label: 'Settings',     href: '/settings' },
  { icon: HelpCircle, label: 'Help',          href: '/help' },
  { icon: Flag,       label: 'Send feedback', href: '/feedback' },
];

function NavLink({ item, collapsed, pathname }: { item: Item; collapsed: boolean; pathname: string }) {
  const active = pathname === item.href || (item.href !== '/' && pathname.startsWith(item.href));
  const Icon = item.icon;

  if (collapsed) {
    return (
      <Link
        href={item.href}
        title={item.label}
        className={`flex flex-col items-center justify-center gap-1 w-full py-3 rounded-xl transition-colors ${
          active ? 'bg-[rgb(var(--color-surface))]' : 'hover:bg-[rgb(var(--color-surface-hover))]'
        }`}
      >
        <Icon size={20} strokeWidth={active ? 2.2 : 1.7}
          className={active ? 'text-[rgb(var(--color-text-primary))]' : 'text-[rgb(var(--color-text-secondary))]'} />
        <span className="text-[9px] text-[rgb(var(--color-text-secondary))] leading-none truncate w-full text-center px-1">
          {item.label.split(' ')[0]}
        </span>
      </Link>
    );
  }

  return (
    <Link
      href={item.href}
      className={`flex items-center gap-3 h-10 px-3 rounded-xl transition-colors ${
        active ? 'bg-[rgb(var(--color-surface))]' : 'hover:bg-[rgb(var(--color-surface-hover))]'
      }`}
    >
      <Icon size={20} strokeWidth={active ? 2.2 : 1.7}
        className={active ? 'text-[rgb(var(--color-text-primary))]' : 'text-[rgb(var(--color-text-secondary))]'} />
      <span className={`text-[13.5px] flex-1 truncate leading-none ${active ? 'font-medium text-[rgb(var(--color-text-primary))]' : 'text-[rgb(var(--color-text-primary))]'}`}>
        {item.label}
      </span>
      {item.badge && (
        <span className="text-[10px] font-bold px-1.5 py-0.5 bg-[rgb(var(--color-primary))] text-white rounded leading-none">
          {item.badge}
        </span>
      )}
    </Link>
  );
}

function Divider() {
  return <div className="my-2 border-t border-[rgb(var(--color-border))]" />;
}

function SectionHead({ label }: { label: string }) {
  return (
    <p className="px-3 pt-1 pb-1 text-[13px] font-semibold text-[rgb(var(--color-text-primary))]">
      {label}
    </p>
  );
}

export default function Sidebar({ isCollapsed = false }: SidebarProps) {
  const pathname = usePathname();

  return (
    <aside className={`
      fixed left-0 top-14 h-[calc(100vh-3.5rem)]
      bg-[rgb(var(--color-background))]
      overflow-y-auto overflow-x-hidden scrollbar-hide
      transition-[width] duration-200 ease-in-out z-40
      ${isCollapsed ? 'w-[74px]' : 'w-60'}
    `}>
      <nav className="py-2 px-2">

        <div className="space-y-px">
          {MAIN.map(i => <NavLink key={i.href} item={i} collapsed={isCollapsed} pathname={pathname} />)}
        </div>

        <Divider />

        {!isCollapsed && <SectionHead label="You" />}
        <div className="space-y-px">
          {YOU.map(i => <NavLink key={i.href} item={i} collapsed={isCollapsed} pathname={pathname} />)}
        </div>

        <Divider />

        {!isCollapsed && <SectionHead label="Explore" />}
        <div className="space-y-px">
          {EXPLORE.map(i => <NavLink key={i.href} item={i} collapsed={isCollapsed} pathname={pathname} />)}
        </div>

        <Divider />

        {!isCollapsed && <SectionHead label="MyChannel" />}
        <div className="space-y-px">
          {MC.map(i => <NavLink key={i.href} item={i} collapsed={isCollapsed} pathname={pathname} />)}
        </div>

        <Divider />

        <div className="space-y-px">
          {BOTTOM.map(i => <NavLink key={i.href} item={i} collapsed={isCollapsed} pathname={pathname} />)}
        </div>

        {!isCollapsed && (
          <div className="mt-4 px-3 pb-6">
            <div className="flex flex-wrap gap-x-2 gap-y-1">
              {['About','Terms','Privacy'].map(p => (
                <Link key={p} href={`/${p.toLowerCase()}`}
                  className="text-[11px] text-[rgb(var(--color-text-tertiary))] hover:text-[rgb(var(--color-text-secondary))]">
                  {p}
                </Link>
              ))}
            </div>
            <p className="mt-2 text-[11px] text-[rgb(var(--color-text-tertiary))]">© 2025 MyChannel</p>
          </div>
        )}
      </nav>
    </aside>
  );
}
