'use client';

// Mobile bottom tab bar — YouTube mobile parity.
// Visible only on < md screens. Hidden on the watch page (full-screen player takes over).

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Home, Search, Upload, TrendingUp, User } from 'lucide-react';

const TABS = [
  { icon: Home,       label: 'Home',     href: '/' },
  { icon: Search,     label: 'Search',   href: '/search' },
  { icon: Upload,     label: 'Upload',   href: '/upload' },
  { icon: TrendingUp, label: 'Trending', href: '/trending' },
  { icon: User,       label: 'You',      href: '/profile/me' },
] as const;

// Routes where the mobile tab bar is hidden (full-bleed video / Flicks)
const HIDDEN_ON = ['/watch', '/flicks', '/live'];

export default function MobileTabBar() {
  const pathname = usePathname();

  const hidden = HIDDEN_ON.some((prefix) => pathname.startsWith(prefix));
  if (hidden) return null;

  return (
    <nav
      className="
        lg:hidden
        fixed bottom-0 left-0 right-0 z-50
        bg-[rgb(var(--color-background))] border-t border-[rgb(var(--color-border))]
        flex items-stretch
        safe-bottom
      "
      aria-label="Mobile navigation"
    >
      {TABS.map(({ icon: Icon, label, href }) => {
        const isActive =
          href === '/' ? pathname === '/' : pathname.startsWith(href);

        // Upload tab gets a special center-pill style
        const isUpload = label === 'Upload';

        return (
          <Link
            key={href}
            href={href}
            className={`
              flex flex-1 flex-col items-center justify-center gap-0.5
              py-2 min-h-[52px]
              transition-colors
              ${isUpload ? '' : 'hover:bg-[rgb(var(--color-surface-hover))]'}
            `}
            aria-label={label}
            aria-current={isActive ? 'page' : undefined}
          >
            {isUpload ? (
              /* Upload gets a filled pill like YouTube */
              <span className="flex items-center justify-center w-9 h-7 rounded-lg bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))]">
                <Icon
                  size={18}
                  strokeWidth={2}
                  className="text-[rgb(var(--color-text-primary))]"
                />
              </span>
            ) : (
              <Icon
                size={22}
                strokeWidth={isActive ? 2.5 : 1.8}
                className={
                  isActive
                    ? 'text-[rgb(var(--color-text-primary))]'
                    : 'text-[rgb(var(--color-text-secondary))]'
                }
                fill={isActive && label !== 'Search' ? 'currentColor' : 'none'}
              />
            )}
            <span
              className={`text-[10px] leading-none ${
                isActive
                  ? 'font-semibold text-[rgb(var(--color-text-primary))]'
                  : 'text-[rgb(var(--color-text-secondary))]'
              } ${isUpload ? 'mt-0.5' : ''}`}
            >
              {label}
            </span>
          </Link>
        );
      })}
    </nav>
  );
}
