'use client';

// Main Layout Wrapper - YouTube Desktop Style

import { useState } from 'react';
import Sidebar from './Sidebar';
import TopNav from './TopNav';
import MiniPlayer from './MiniPlayer';

interface MainLayoutProps {
  children: React.ReactNode;
}

const MainLayout = ({ children }: MainLayoutProps) => {
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false);

  const toggleSidebar = () => {
    setIsSidebarCollapsed(!isSidebarCollapsed);
  };

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      {/* Top Navigation */}
      <TopNav onToggleSidebar={toggleSidebar} />

      {/* Sidebar */}
      <Sidebar isCollapsed={isSidebarCollapsed} onToggleCollapse={toggleSidebar} />

      {/* Main Content */}
      <main
        className={`
          pt-14 transition-all duration-200 ease-in-out
          ${isSidebarCollapsed ? 'pl-[74px]' : 'pl-60'}
        `}
      >
        <div className="min-h-[calc(100vh-3.5rem)]">
          {children}
        </div>
      </main>

      {/* Mini Player (Floating PiP) */}
      <MiniPlayer />
    </div>
  );
};

export default MainLayout;

