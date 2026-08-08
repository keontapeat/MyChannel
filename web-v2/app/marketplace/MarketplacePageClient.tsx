'use client';

import { useState, useEffect } from 'react';
import { ChevronLeft, ShoppingBag, Star, Loader2 } from 'lucide-react';
import Link from 'next/link';
import { collection, query, where, orderBy, limit, getDocs } from 'firebase/firestore';
import { db } from '@/lib/firebase/config';

interface MarketplaceListing {
  id: string;
  title: string;
  description: string;
  category: string;
  creatorName: string;
  creatorAvatar: string;
  priceCents: number;
  priceType: string;
  rating: number;
  reviewCount: number;
  deliveryDays: number;
  imageUrl: string;
}

const CATEGORIES = ['All', 'Editing', 'Thumbnails', 'Music', 'Voiceover', 'Animation', 'Graphics', 'SEO', 'Scripting', 'Consulting'];

export default function MarketplacePageClient() {
  const [listings, setListings] = useState<MarketplaceListing[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedCategory, setSelectedCategory] = useState('All');

  useEffect(() => { loadListings(); }, [selectedCategory]);

  const loadListings = async () => {
    setLoading(true);
    try {
      let q;
      if (selectedCategory === 'All') {
        q = query(collection(db, 'marketplace'), where('isActive', '==', true), orderBy('createdAt', 'desc'), limit(50));
      } else {
        q = query(collection(db, 'marketplace'), where('isActive', '==', true), where('category', '==', selectedCategory.toLowerCase()), orderBy('createdAt', 'desc'), limit(50));
      }
      const snap = await getDocs(q);
      setListings(snap.docs.map((d) => ({ id: d.id, ...d.data() } as MarketplaceListing)));
    } finally { setLoading(false); }
  };

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14">
      <div className="max-w-[1200px] mx-auto px-4 py-6 pb-24">
        <div className="flex items-center gap-3 mb-6">
          <Link href="/" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full">
            <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
          </Link>
          <div>
            <h1 className="text-[20px] font-bold text-[rgb(var(--color-text-primary))]">Creator Marketplace</h1>
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">Hire creators for editing, thumbnails, music & more</p>
          </div>
        </div>

        {/* Category chips */}
        <div className="flex gap-2 overflow-x-auto pb-2 mb-6 scrollbar-hide">
          {CATEGORIES.map((cat) => (
            <button
              key={cat}
              onClick={() => setSelectedCategory(cat)}
              className={`px-4 py-2 rounded-full text-[13px] font-medium whitespace-nowrap transition-colors ${
                selectedCategory === cat
                  ? 'bg-[rgb(var(--color-primary))] text-white'
                  : 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-secondary))] hover:bg-[rgb(var(--color-surface-hover))] border border-[rgb(var(--color-border))]'
              }`}
            >
              {cat}
            </button>
          ))}
        </div>

        {loading ? (
          <div className="flex justify-center py-12"><Loader2 size={24} className="animate-spin text-[rgb(var(--color-text-tertiary))]" /></div>
        ) : listings.length === 0 ? (
          <div className="text-center py-20">
            <ShoppingBag size={44} className="mx-auto mb-3 text-[rgb(var(--color-primary))]" />
            <p className="text-[15px] font-semibold text-[rgb(var(--color-text-primary))]">No listings found</p>
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">Check back later for creator services</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {listings.map((listing) => (
              <div key={listing.id} className="bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-xl overflow-hidden hover:shadow-lg transition-shadow">
                {listing.imageUrl && (
                  <img src={listing.imageUrl} alt={listing.title} className="w-full h-40 object-cover" />
                )}
                <div className="p-4">
                  <h3 className="text-[14px] font-semibold text-[rgb(var(--color-text-primary))] line-clamp-2">{listing.title}</h3>
                  <div className="flex items-center gap-2 mt-2">
                    {listing.creatorAvatar && <img src={listing.creatorAvatar} alt="" className="w-5 h-5 rounded-full" />}
                    <span className="text-[12px] text-[rgb(var(--color-text-secondary))]">{listing.creatorName}</span>
                  </div>
                  <div className="flex items-center justify-between mt-3">
                    <div className="flex items-center gap-1">
                      {listing.rating > 0 && (
                        <>
                          <Star size={12} className="text-[rgb(var(--color-primary))] fill-current" />
                          <span className="text-[12px] text-[rgb(var(--color-text-secondary))]">{listing.rating.toFixed(1)} ({listing.reviewCount})</span>
                        </>
                      )}
                      {listing.deliveryDays > 0 && (
                        <span className="text-[12px] text-[rgb(var(--color-text-tertiary))] ml-2">{listing.deliveryDays}d delivery</span>
                      )}
                    </div>
                    <span className="text-[16px] font-bold text-[rgb(var(--color-primary))]">${Math.floor(listing.priceCents / 100)}</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
