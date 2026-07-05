'use client';

// 🔥 MyChannel home — clean YouTube-style feed.
// Thin sidebar + single search bar + category chips + spacious rounded-thumbnail
// grid, matching youtube.com/. See components/home/HomeFeed.tsx.
// (The previous marketing landing lives in components/home/LandingHome.tsx.)

import HomeFeed from '@/components/home/HomeFeed';

export default function HomePage() {
  return <HomeFeed />;
}
