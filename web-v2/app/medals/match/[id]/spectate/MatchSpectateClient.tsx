'use client';

import Link from 'next/link';
import {useEffect, useState} from 'react';

export default function MatchSpectateClient({initialMatchId}: {initialMatchId: string}) {
  const [matchId, setMatchId] = useState(initialMatchId);

  useEffect(() => {
    if (initialMatchId !== '_fallback') return;
    const segments = window.location.pathname.split('/').filter(Boolean);
    const matchIndex = segments.indexOf('match');
    const pathId = matchIndex >= 0 ? segments[matchIndex + 1] : '';
    if (pathId && pathId !== '_fallback') setMatchId(decodeURIComponent(pathId));
  }, [initialMatchId]);

  return (
    <div className="min-h-screen bg-[#0d0e11] text-white">
      <div className="mx-auto max-w-[768px] px-4 py-6">
        <Link href={`/medals/match/${matchId}`} className="text-sm text-gray-400 hover:text-white">
          ← Match detail
        </Link>
        <h1 className="mt-4 text-2xl font-bold">Spectating match</h1>
        <p className="mt-2 text-gray-400">
          Match <span className="font-mono text-white">{matchId}</span> is waiting for an authorized live feed.
        </p>
        <div
          className="mt-8 flex aspect-video items-center justify-center rounded-xl border border-dashed border-gray-600 bg-gray-900/60"
          role="status"
          aria-label="Live stream status"
        >
          <span className="text-gray-500">Live stream unavailable</span>
        </div>
      </div>
    </div>
  );
}
