'use client';

// Mobile bottom tab bar — Matches iOS app navigation exactly.
// 5 tabs: Home, Flicks, Upload (center button), Subscriptions, You

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Home, Clapperboard, Plus, Users, User } from 'lucide-react';

const TABS = [
  { icon: Home,         label: 'Home',          href: '/' },
  { icon: Clapperboard, label: 'Flicks',        href: '/flicks' },
  { icon: Plus,         label: 'Upload',        href: '/upload', isCenter: true },
  { icon: Users,        label: 'Subscriptions', href: '/subscriptions' },
  { icon: User,         label: 'You',           href: '/profile/me' },
] as const;

// Routes where the mobile tab bar is hidden (full-bleed video / Flicks / Live)
const HIDDEN_ON = ['/watch', '/live'];

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
      {TABS.map(({ icon: Icon, label, href, ...rest }) => {
        const isActive =
          href === '/' ? pathname === '/' : pathname.startsWith(href);
        const isCenter = 'isCenter' in rest && rest.isCenter;

        return (
          <Link
            key={href}
            href={href}
            className={`
              flex flex-1 flex-col items-center justify-center gap-0.5
              min-h-[56px] py-1.5
              transition-colors
              ${isCenter ? '' : 'hover:bg-[rgb(var(--color-surface-hover))]'}
            `}
            aria-label={label}
            aria-current={isActive ? 'page' : undefined}
          >
            {isCenter ? (
              /* Center upload button — red circle like iOS */
              <span className="flex items-center justify-center w-11 h-11 rounded-full bg-[#EF4444] shadow-lg shadow-red-500/30">
                <Icon
                  size={22}
                  strokeWidth={2.5}
                  className="text-white"
                />
              </span>
            ) : (
              <Icon
                size={22}
                strokeWidth={isActive ? 2.5 : 1.8}
                className={
                  isActive
                    ? 'text-[#EF4444]'
                    : 'text-[rgb(var(--color-text-secondary))]'
                }
                fill={isActive && label === 'Home' ? 'currentColor' : 'none'}
              />
            )}
            <span
              className={`text-[10px] leading-none ${
                isActive
                  ? 'font-semibold text-[#EF4444]'
                  : 'text-[rgb(var(--color-text-secondary))]'
              } ${isCenter ? 'mt-0' : ''}`}
            >
              {isCenter ? '' : label}
            </span>
          </Link>
        );
      })}
    </nav>
  );
}
