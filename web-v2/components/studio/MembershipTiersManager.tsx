'use client';

// MembershipTiersManager — creator-side tier editor.
// Writes channels/{uid}/membershipTiers/{tierId} which create_membership_checkout
// reads server-side for pricing. This is CONFIG only (no money moves here).
// Prices are entered in dollars and stored as integer cents.

import { useEffect, useState } from 'react';
import { Plus, Trash2, Loader2, Star } from 'lucide-react';
import {
  collection, getDocs, orderBy, query, doc, setDoc, deleteDoc, addDoc, serverTimestamp,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

interface Tier {
  id: string;
  name: string;
  priceCents: number;
  perks: string[];
}

export default function MembershipTiersManager() {
  const [uid, setUid] = useState<string | null>(auth?.currentUser?.uid ?? null);
  const [tiers, setTiers] = useState<Tier[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  // Draft for a new tier
  const [name, setName] = useState('');
  const [price, setPrice] = useState('');
  const [perks, setPerks] = useState('');

  useEffect(() => {
    const unsub = auth?.onAuthStateChanged?.((u) => setUid(u?.uid ?? null));
    return () => { if (typeof unsub === 'function') unsub(); };
  }, []);

  useEffect(() => {
    if (!uid) { setLoading(false); return; }
    let cancelled = false;
    getDocs(query(collection(db, 'channels', uid, 'membershipTiers'), orderBy('priceCents', 'asc')))
      .then((snap) => {
        if (cancelled) return;
        setTiers(snap.docs.map((d) => ({
          id: d.id,
          name: d.data().name ?? 'Tier',
          priceCents: d.data().priceCents ?? 0,
          perks: d.data().perks ?? [],
        })));
      })
      .catch(() => {})
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, [uid]);

  const addTier = async () => {
    if (!uid) return;
    const dollars = parseFloat(price);
    const priceCents = Math.round((Number.isFinite(dollars) ? dollars : 0) * 100);
    if (!name.trim() || priceCents <= 0) { setError('Enter a name and a price above $0.'); return; }
    setSaving(true);
    setError('');
    try {
      const perkList = perks.split('\n').map((p) => p.trim()).filter(Boolean).slice(0, 10);
      const ref = await addDoc(collection(db, 'channels', uid, 'membershipTiers'), {
        name: name.trim(),
        priceCents,
        perks: perkList,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      setTiers((prev) => [...prev, { id: ref.id, name: name.trim(), priceCents, perks: perkList }]
        .sort((a, b) => a.priceCents - b.priceCents));
      setName(''); setPrice(''); setPerks('');
    } catch {
      setError('Could not save. Check that you are signed in and have permission.');
    } finally {
      setSaving(false);
    }
  };

  const removeTier = async (id: string) => {
    if (!uid) return;
    const prev = tiers;
    setTiers((t) => t.filter((x) => x.id !== id));
    try {
      await deleteDoc(doc(db, 'channels', uid, 'membershipTiers', id));
    } catch {
      setTiers(prev); // rollback
    }
  };

  if (!uid) {
    return (
      <div className="bg-white p-4 rounded-xl border border-gray-200 text-center">
        <p className="text-sm text-gray-600">Sign in to manage membership tiers.</p>
      </div>
    );
  }

  return (
    <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm">
      <div className="flex items-center gap-2 mb-4">
        <Star size={18} className="text-purple-600" fill="currentColor" />
        <h3 className="font-bold text-black">Membership Tiers</h3>
      </div>

      {loading ? (
        <div className="flex justify-center py-6"><Loader2 size={20} className="animate-spin text-gray-400" /></div>
      ) : (
        <>
          <div className="space-y-2 mb-4">
            {tiers.length === 0 && (
              <p className="text-sm text-gray-500">No tiers yet. Add one below.</p>
            )}
            {tiers.map((t) => (
              <div key={t.id} className="flex items-center justify-between p-3 rounded-lg border border-gray-200">
                <div className="min-w-0">
                  <p className="font-semibold text-black text-sm truncate">{t.name}</p>
                  {t.perks.length > 0 && (
                    <p className="text-xs text-gray-500 truncate">{t.perks.join(' · ')}</p>
                  )}
                </div>
                <div className="flex items-center gap-3 flex-shrink-0">
                  <span className="font-bold text-green-600 text-sm">${(t.priceCents / 100).toFixed(2)}/mo</span>
                  <button onClick={() => removeTier(t.id)} aria-label="Delete tier" className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-gray-100 rounded-full">
                    <Trash2 size={15} />
                  </button>
                </div>
              </div>
            ))}
          </div>

          {/* New tier form */}
          <div className="border-t border-gray-200 pt-4 space-y-2">
            <input
              value={name}
              onChange={(e) => setName(e.target.value.slice(0, 60))}
              placeholder="Tier name (e.g. Supporter)"
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm text-black outline-none focus:border-purple-500"
            />
            <input
              value={price}
              onChange={(e) => setPrice(e.target.value.replace(/[^0-9.]/g, ''))}
              inputMode="decimal"
              placeholder="Monthly price in USD (e.g. 4.99)"
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm text-black outline-none focus:border-purple-500"
            />
            <textarea
              value={perks}
              onChange={(e) => setPerks(e.target.value)}
              placeholder="Perks — one per line (badge, emotes, members-only posts…)"
              rows={3}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm text-black outline-none focus:border-purple-500 resize-none"
            />
            {error && <p className="text-xs text-red-500">{error}</p>}
            <button
              onClick={addTier}
              disabled={saving}
              className="w-full py-2.5 bg-purple-600 text-white font-semibold rounded-lg hover:opacity-90 disabled:opacity-50 flex items-center justify-center gap-2 text-sm"
            >
              {saving ? <Loader2 size={15} className="animate-spin" /> : <Plus size={15} />}
              Add tier
            </button>
          </div>
        </>
      )}
    </div>
  );
}
