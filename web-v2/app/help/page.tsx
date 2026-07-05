'use client';

// Help Center — searchable FAQ-style help topics.

import MainLayout from '@/components/layout/MainLayout';
import { useState } from 'react';
import { HelpCircle, Search, ChevronDown } from 'lucide-react';

const TOPICS = [
  { q: 'How do I upload a video?', a: 'Click Create or the Upload button in the top bar, choose your file, add a title, description, and thumbnail, then publish.' },
  { q: 'How do VS Matches work?', a: 'VS Matches are real-money creator competitions. You must be 18+, verified, and in a supported region. Funds are held in escrow until the match settles.' },
  { q: 'How do I get verified?', a: 'Verification is granted based on subscriber count and channel standing. Eligible channels are reviewed automatically.' },
  { q: 'How do I withdraw earnings?', a: 'Open your Wallet, choose Withdraw, and follow the prompts. Withdrawals are subject to identity verification and processing times.' },
  { q: 'How do I go live?', a: 'Use the Go Live option from the create menu. You will need a stable connection and an approved channel.' },
  { q: 'How do I report content?', a: 'Use the menu on any video or channel and select Report. Our moderation team reviews all reports.' },
];

function FaqItem({ q, a }: { q: string; a: string }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="border-b border-[rgb(var(--color-border))]">
      <button
        onClick={() => setOpen(!open)}
        className="flex w-full items-center justify-between gap-4 py-4 text-left"
      >
        <span className="text-sm font-medium text-[rgb(var(--color-text-primary))]">{q}</span>
        <ChevronDown size={18} className={`text-[rgb(var(--color-text-secondary))] transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>
      {open && <p className="pb-4 text-sm text-[rgb(var(--color-text-secondary))] leading-relaxed">{a}</p>}
    </div>
  );
}

export default function HelpPage() {
  const [query, setQuery] = useState('');
  const filtered = TOPICS.filter(
    (t) => t.q.toLowerCase().includes(query.toLowerCase()) || t.a.toLowerCase().includes(query.toLowerCase())
  );

  return (
    <MainLayout>
      <div className="max-w-[800px] mx-auto px-4 sm:px-6 py-10">
        <div className="flex items-center gap-3 mb-6">
          <HelpCircle size={24} className="text-[rgb(var(--color-text-primary))]" />
          <h1 className="text-2xl font-bold text-[rgb(var(--color-text-primary))]">Help Center</h1>
        </div>

        <div className="relative mb-6">
          <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-[rgb(var(--color-text-tertiary))]" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search help topics"
            className="w-full rounded-full border border-[rgb(var(--color-border))] bg-transparent py-2.5 pl-10 pr-4 text-sm text-[rgb(var(--color-text-primary))] outline-none focus:border-[rgb(var(--color-primary))]"
          />
        </div>

        <div>
          {filtered.length === 0 ? (
            <p className="py-8 text-center text-sm text-[rgb(var(--color-text-secondary))]">No matching topics.</p>
          ) : (
            filtered.map((t) => <FaqItem key={t.q} q={t.q} a={t.a} />)
          )}
        </div>
      </div>
    </MainLayout>
  );
}
