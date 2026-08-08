'use client';

import { ChevronLeft, Star, Check } from 'lucide-react';
import Link from 'next/link';

const PLANS = [
  { id: 'monthly', name: 'MyChannel Premium', price: '$11.99/month', features: ['Ad-free viewing', 'Background playback', 'Offline downloads', 'Exclusive content', '4K streaming', 'Priority support'] },
  { id: 'yearly', name: 'Premium Annual', price: '$119.99/year', features: ['Everything in monthly', '2 months free', 'Early access to features', 'Creator analytics boost', 'Exclusive badges'] },
];

export default function PremiumPageClient() {
  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14">
      <div className="max-w-[640px] mx-auto px-4 py-6 pb-24">
        <div className="flex items-center gap-3 mb-8">
          <Link href="/" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full"><ChevronLeft size={20} /></Link>
          <div><h1 className="text-[20px] font-bold text-[rgb(var(--color-text-primary))]">MyChannel Premium</h1><p className="text-[13px] text-[rgb(var(--color-text-secondary))]">The best viewing experience</p></div>
        </div>

        <div className="text-center mb-8">
          <Star size={48} className="mx-auto mb-3 text-[rgb(var(--color-primary))]" />
          <h2 className="text-[24px] font-bold text-[rgb(var(--color-text-primary))]">Go Premium</h2>
          <p className="text-[14px] text-[rgb(var(--color-text-secondary))] mt-1">Ad-free videos, offline downloads, and exclusive content</p>
        </div>

        <div className="space-y-4">
          {PLANS.map((plan) => (
            <div key={plan.id} className="bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-xl p-5">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-[15px] font-bold text-[rgb(var(--color-text-primary))]">{plan.name}</h3>
                <span className="text-[16px] font-bold text-[rgb(var(--color-primary))]">{plan.price}</span>
              </div>
              <ul className="space-y-2 mb-4">
                {plan.features.map((f, i) => (
                  <li key={i} className="flex items-center gap-2 text-[13px] text-[rgb(var(--color-text-primary))]">
                    <Check size={14} className="text-[rgb(var(--color-primary))] flex-shrink-0" /> {f}
                  </li>
                ))}
              </ul>
              <button className="w-full py-2.5 bg-[rgb(var(--color-primary))] text-white text-[14px] font-semibold rounded-full hover:opacity-90 transition-opacity">Subscribe</button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
