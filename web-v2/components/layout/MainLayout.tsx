'use client';

// Main Layout Wrapper — desktop rail + mobile drawer + bottom tab bar (YouTube parity)

import { useState, useEffect } from 'react';
import { usePathname } from 'next/navigation';
import Sidebar from './Sidebar';
import TopNav from './TopNav';
import MiniPlayer from './MiniPlayer';
import MobileTabBar from './MobileTabBar';

interface MainLayoutProps {
  children: React.ReactNode;
}

const MainLayout = ({ children }: MainLayoutProps) => {
  const pathname = usePathname();
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false); // desktop rail width
  const [mobileOpen, setMobileOpen] = useState(false);                  // mobile drawer

  // Hamburger: opens the drawer on mobile/tablet, toggles rail width on desktop.
  const toggleSidebar = () => {
    if (typeof window !== 'undefined' && window.matchMedia('(max-width: 1023px)').matches) {
      setMobileOpen((o) => !o);
    } else {
      setIsSidebarCollapsed((c) => !c);
    }
  };

  // Close the mobile drawer whenever the route changes
  useEffect(() => { setMobileOpen(false); }, [pathname]);

  if (pathname.startsWith('/flicks')) {
    return <main className="fixed inset-0 overflow-hidden bg-black">{children}</main>;
  }

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      {/* Top Navigation */}
      <TopNav onToggleSidebar={toggleSidebar} />

      {/* Sidebar — desktop rail (lg+) and mobile slide-in drawer */}
      <Sidebar isCollapsed={isSidebarCollapsed} mobileOpen={mobileOpen} />

      {/* Mobile drawer backdrop */}
      {mobileOpen && (
        <div
          className="lg:hidden fixed inset-0 top-14 bg-black/50 z-30"
          onClick={() => setMobileOpen(false)}
          aria-hidden
        />
      )}

      {/* Main Content — safe-area aware offsets for the fixed mobile chrome */}
      <main
        className={`
          pt-[calc(3.5rem+env(safe-area-inset-top))]
          pb-[calc(3.5rem+env(safe-area-inset-bottom))]
          transition-[padding] duration-200 ease-in-out lg:pb-0
          ${isSidebarCollapsed ? 'lg:pl-[74px]' : 'lg:pl-60'}
        `}
      >
        <div className="min-h-[calc(100dvh-3.5rem-env(safe-area-inset-top))]">
          {children}
        </div>
      </main>

      {/* Mini Player (Floating PiP) */}
      <MiniPlayer />

      {/* Mobile bottom tab bar (< lg) */}
      <MobileTabBar />
    </div>
  );
};

export default MainLayout;
