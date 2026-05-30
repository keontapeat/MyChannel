'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Home, Search, Plus, Video, User } from 'lucide-react';

export default function GlobalTabBar() {
  const pathname = usePathname();

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-white dark:bg-black border-t border-gray-200 dark:border-gray-800 z-50 pb-safe">
      <div className="flex items-center justify-around h-16 max-w-lg mx-auto">
        <Link href="/" className={`flex flex-col items-center justify-center w-full h-full ${pathname === '/' ? 'text-black dark:text-white' : 'text-gray-400'}`}>
          <Home size={24} className={pathname === '/' ? 'fill-current' : ''} />
          <span className="text-[10px] mt-1 font-medium">Home</span>
        </Link>

        <Link href="/flicks" className={`flex flex-col items-center justify-center w-full h-full ${pathname === '/flicks' ? 'text-black dark:text-white' : 'text-gray-400'}`}>
          <Video size={24} className={pathname === '/flicks' ? 'fill-current' : ''} />
          <span className="text-[10px] mt-1 font-medium">Flicks</span>
        </Link>

        {/* Center Plus Button */}
        <Link href="/upload" className="flex flex-col items-center justify-center w-full h-full">
          <div className="w-12 h-12 bg-black dark:bg-white rounded-full flex items-center justify-center hover:scale-105 transition-transform">
            <Plus size={28} className="text-white dark:text-black" />
          </div>
        </Link>

        <Link href="/search" className={`flex flex-col items-center justify-center w-full h-full ${pathname === '/search' ? 'text-black dark:text-white' : 'text-gray-400'}`}>
          <Search size={24} className={pathname === '/search' ? 'fill-current' : ''} />
          <span className="text-[10px] mt-1 font-medium">Search</span>
        </Link>

        <Link href="/profile" className={`flex flex-col items-center justify-center w-full h-full ${pathname === '/profile' ? 'text-black dark:text-white' : 'text-gray-400'}`}>
          <User size={24} className={pathname === '/profile' ? 'fill-current' : ''} />
          <span className="text-[10px] mt-1 font-medium">Profile</span>
        </Link>
      </div>
    </nav>
  );
}
