'use client';

import Link from 'next/link';

type SpectatePageProps = {
  params: { id: string };
};

/** Spectator stub — read-only match view until live stream wiring lands. */
export default function MatchSpectatePage({ params }: SpectatePageProps) {
  const matchId = params.id;

  return (
    <div className="min-h-screen bg-[#0d0e11] text-white">
      <div className="mx-auto max-w-[768px] px-4 py-6">
        <Link href={`/medals/match/${matchId}`} className="text-sm text-gray-400 hover:text-white">
          ← Match detail
        </Link>
        <h1 className="mt-4 text-2xl font-bold">Spectating match</h1>
        <p className="mt-2 text-gray-400">
          Stub spectator view for <span className="font-mono text-white">{matchId}</span>.
          Live HLS/WebRTC feed will mount here.
        </p>
        <div
          className="mt-8 flex aspect-video items-center justify-center rounded-xl border border-dashed border-gray-600 bg-gray-900/60"
          role="img"
          aria-label="Spectator video placeholder"
        >
          <span className="text-gray-500">Live stream placeholder</span>
        </div>
      </div>
    </div>
  );
}
