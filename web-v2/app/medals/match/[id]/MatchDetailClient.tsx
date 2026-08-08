'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { subscribeEscrowStatus, type EscrowStatusSnapshot } from '@/lib/vs-match-wallet';
import { copyMatchShareLink, matchSpectatePath } from '@/lib/vs-match-share';

interface MatchDetailClientProps {
  matchId: string;
}

export default function MatchDetailClient({ matchId: initialMatchId }: MatchDetailClientProps) {
  const [matchId, setMatchId] = useState(initialMatchId);
  const [escrowRows, setEscrowRows] = useState<EscrowStatusSnapshot[]>([]);
  const [shareMessage, setShareMessage] = useState<string | null>(null);

  useEffect(() => {
    if (initialMatchId !== '_fallback') return;
    const segments = window.location.pathname.split('/').filter(Boolean);
    const matchIndex = segments.indexOf('match');
    const pathId = matchIndex >= 0 ? segments[matchIndex + 1] : '';
    if (pathId && pathId !== '_fallback') setMatchId(decodeURIComponent(pathId));
  }, [initialMatchId]);

  useEffect(() => {
    let unsub: (() => void) | undefined;
    subscribeEscrowStatus(matchId, setEscrowRows).then((fn) => {
      unsub = fn;
    });
    return () => unsub?.();
  }, [matchId]);

  async function handleShare() {
    const ok = await copyMatchShareLink(matchId);
    setShareMessage(ok ? 'Link copied to clipboard' : 'Could not copy link');
  }

  return (
    <div className="min-h-screen bg-[#0d0e11] text-white">
      <div className="mx-auto max-w-[768px] px-4 py-6">
        <header className="mb-6">
          <Link href="/medals" className="text-sm text-gray-400 hover:text-white">
            ← Championship Hub
          </Link>
          <h1 className="mt-2 text-2xl font-bold">Match {matchId.slice(0, 8)}…</h1>
          <p className="text-sm text-gray-400">Live escrow + match metadata (Firestore listener)</p>
        </header>

        <section className="mb-6 rounded-xl border border-gray-700 bg-gray-900/80 p-4">
          <h2 className="mb-2 text-lg font-semibold">Match funding</h2>
          <p className="text-sm text-gray-400">
            Amounts appear only after the server-authoritative match and escrow records are available.
          </p>
        </section>

        <section className="mb-6 rounded-xl border border-gray-700 bg-gray-900/80 p-4">
          <h2 className="mb-2 text-lg font-semibold">Escrow status</h2>
          {escrowRows.length === 0 ? (
            <p className="text-sm text-gray-400">No escrow rows yet — waiting for server ack.</p>
          ) : (
            <ul className="space-y-2 text-sm">
              {escrowRows.map((row, i) => (
                <li key={`${row.matchId}-${i}`} className="flex justify-between">
                  <span>{row.status}</span>
                  {row.amountCents != null && (
                    <span>${(row.amountCents / 100).toFixed(2)}</span>
                  )}
                </li>
              ))}
            </ul>
          )}
        </section>

        <div className="flex flex-wrap gap-3">
          <Link
            href={matchSpectatePath(matchId)}
            className="min-h-[44px] rounded-lg bg-gray-800 px-4 py-2 font-semibold hover:bg-gray-700"
          >
            Spectate
          </Link>
          <button
            type="button"
            onClick={handleShare}
            className="min-h-[44px] rounded-lg bg-yellow-600 px-4 py-2 font-semibold hover:bg-yellow-500"
          >
            Share match link
          </button>
        </div>
        {shareMessage && <p className="mt-3 text-sm text-green-400">{shareMessage}</p>}
      </div>
    </div>
  );
}
