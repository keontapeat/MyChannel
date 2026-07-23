'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { ChevronLeft, Plus, Trash2, Save, Loader2, Users, DollarSign } from 'lucide-react';
import { collection, query, where, getDocs, addDoc, deleteDoc, doc, serverTimestamp } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

interface Tier {
  id: string;
  name: string;
  priceMonthly: number;  // cents — never raw float
  perks: string[];
  badgeEmoji: string;
  memberCount: number;
}

const EMOJI_OPTIONS = ['⭐', '🔥', '💎', '👑', '🚀', '🎖️', '🏆', '❤️'];

/**
 * Studio Memberships Manager — YouTube Channel Memberships parity.
 * Create and manage monetized membership tiers with perks.
 * 💰 Money note: actual billing is handled by the Cloud Function / Stripe integration,
 * not by this UI. This page only writes tier definitions to Firestore.
 */
export default function MembershipsClient() {
  const router = useRouter();
  const [tiers, setTiers] = useState<Tier[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [uid, setUid] = useState<string | null>(auth?.currentUser?.uid ?? null);
  const [error, setError] = useState('');

  // New tier form
  const [newName, setNewName] = useState('');
  const [newPrice, setNewPrice] = useState('4.99');
  const [newPerks, setNewPerks] = useState('');
  const [newEmoji, setNewEmoji] = useState('⭐');
  const [showForm, setShowForm] = useState(false);

  useEffect(() => {
    const unsub = auth?.onAuthStateChanged?.((u) => setUid(u?.uid ?? null));
    return () => { if (typeof unsub === 'function') unsub(); };
  }, []);

  useEffect(() => {
    if (!uid) { setLoading(false); return; }
    let cancelled = false;
    const load = async () => {
      try {
        const q = query(collection(db, 'membershipTiers'), where('channelId', '==', uid));
        const snap = await getDocs(q);
        if (cancelled) return;
        setTiers(snap.docs.map((d) => ({
          id: d.id,
          name: d.data().name ?? '',
          priceMonthly: d.data().priceMonthly ?? 499,
          perks: d.data().perks ?? [],
          badgeEmoji: d.data().badgeEmoji ?? '⭐',
          memberCount: d.data().memberCount ?? 0,
        })));
      } catch (e: any) {
        setError(e.message);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    load();
    return () => { cancelled = true; };
  }, [uid]);

  const handleCreate = async () => {
    if (!uid || !newName.trim()) return;
    const priceInCents = Math.round(parseFloat(newPrice) * 100);
    if (isNaN(priceInCents) || priceInCents < 99) {
      setError('Minimum price is $0.99');
      return;
    }
    setSaving(true);
    setError('');
    try {
      const ref = await addDoc(collection(db, 'membershipTiers'), {
        channelId: uid,
        name: newName.trim(),
        priceMonthly: priceInCents,
        perks: newPerks.split('\n').map((p) => p.trim()).filter(Boolean),
        badgeEmoji: newEmoji,
        memberCount: 0,
        createdAt: serverTimestamp(),
      });
      setTiers((prev) => [...prev, {
        id: ref.id,
        name: newName.trim(),
        priceMonthly: priceInCents,
        perks: newPerks.split('\n').map((p) => p.trim()).filter(Boolean),
        badgeEmoji: newEmoji,
        memberCount: 0,
      }]);
      setNewName('');
      setNewPrice('4.99');
      setNewPerks('');
      setNewEmoji('⭐');
      setShowForm(false);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (tierId: string) => {
    if (!confirm('Delete this tier? Existing members will keep access until period end.')) return;
    try {
      await deleteDoc(doc(db, 'membershipTiers', tierId));
      setTiers((prev) => prev.filter((t) => t.id !== tierId));
    } catch (e: any) {
      setError(e.message);
    }
  };

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      <div className="max-w-[720px] mx-auto">

        {/* Header */}
        <header className="sticky top-0 z-50 bg-[rgb(var(--color-background))]/95 backdrop-blur border-b border-[rgb(var(--color-border))] px-4 py-3">
          <div className="flex items-center gap-3">
            <button onClick={() => router.back()} className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
              <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
            </button>
            <div className="flex items-center gap-2 flex-1">
              <Users size={18} className="text-purple-500" />
              <div>
                <h1 className="text-[17px] font-bold text-[rgb(var(--color-text-primary))] leading-none">Memberships</h1>
                <p className="text-[11px] text-[rgb(var(--color-text-secondary))]">{tiers.length} tier{tiers.length !== 1 ? 's' : ''}</p>
              </div>
            </div>
            {!showForm && (
              <button
                onClick={() => setShowForm(true)}
                className="flex items-center gap-1.5 px-3 py-1.5 bg-[rgb(var(--color-primary))] text-white text-[12px] font-semibold rounded-full hover:opacity-90 transition-opacity"
              >
                <Plus size={14} /> New tier
              </button>
            )}
          </div>
        </header>

        {loading ? (
          <div className="flex justify-center py-24"><Loader2 size={28} className="animate-spin text-[rgb(var(--color-text-secondary))]" /></div>
        ) : (
          <main className="px-4 py-5 pb-24 space-y-4">

            <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
              <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">
                Create up to 5 tiers. Members pay monthly and get the perks you define.
                Billing is handled automatically — <strong>10% platform fee</strong> applies.
              </p>
            </div>

            {/* Create form */}
            {showForm && (
              <div className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4 space-y-4">
                <h2 className="text-[15px] font-bold text-[rgb(var(--color-text-primary))]">New tier</h2>

                {/* Emoji picker */}
                <div>
                  <label className="text-[12px] font-semibold text-[rgb(var(--color-text-secondary))] uppercase mb-2 block">Badge</label>
                  <div className="flex gap-2">
                    {EMOJI_OPTIONS.map((emoji) => (
                      <button
                        key={emoji}
                        onClick={() => setNewEmoji(emoji)}
                        className={`text-xl w-9 h-9 rounded-lg border transition-all ${newEmoji === emoji ? 'border-[rgb(var(--color-primary))] bg-[rgb(var(--color-primary))]/10' : 'border-[rgb(var(--color-border))] hover:bg-[rgb(var(--color-surface-hover))]'}`}
                      >
                        {emoji}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="text-[12px] font-semibold text-[rgb(var(--color-text-secondary))] uppercase mb-2 block">Tier name</label>
                    <input
                      value={newName}
                      onChange={(e) => setNewName(e.target.value)}
                      placeholder="e.g. Fan, Super Fan"
                      className="w-full bg-[rgb(var(--color-background))] text-[rgb(var(--color-text-primary))] px-3 py-2 text-[13px] rounded-xl border border-[rgb(var(--color-border))] focus:outline-none focus:border-[rgb(var(--color-primary))] transition-colors"
                    />
                  </div>
                  <div>
                    <label className="text-[12px] font-semibold text-[rgb(var(--color-text-secondary))] uppercase mb-2 block">Price / month (USD)</label>
                    <div className="relative">
                      <DollarSign size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-[rgb(var(--color-text-tertiary))]" />
                      <input
                        type="number"
                        value={newPrice}
                        onChange={(e) => setNewPrice(e.target.value)}
                        min="0.99"
                        step="0.01"
                        className="w-full bg-[rgb(var(--color-background))] text-[rgb(var(--color-text-primary))] pl-8 pr-3 py-2 text-[13px] rounded-xl border border-[rgb(var(--color-border))] focus:outline-none focus:border-[rgb(var(--color-primary))] transition-colors"
                      />
                    </div>
                  </div>
                </div>

                <div>
                  <label className="text-[12px] font-semibold text-[rgb(var(--color-text-secondary))] uppercase mb-2 block">Perks (one per line)</label>
                  <textarea
                    value={newPerks}
                    onChange={(e) => setNewPerks(e.target.value)}
                    rows={4}
                    placeholder={"Members-only badge\nExclusive livestream access\nEarly video access"}
                    className="w-full bg-[rgb(var(--color-background))] text-[rgb(var(--color-text-primary))] px-3 py-2 text-[13px] rounded-xl border border-[rgb(var(--color-border))] focus:outline-none focus:border-[rgb(var(--color-primary))] transition-colors resize-none"
                  />
                </div>

                {error && <p className="text-red-500 text-[12px]">{error}</p>}

                <div className="flex gap-2">
                  <button
                    onClick={handleCreate}
                    disabled={saving || !newName.trim()}
                    className="flex-1 flex items-center justify-center gap-2 py-2.5 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-xl hover:opacity-90 disabled:opacity-50 transition-all"
                  >
                    {saving ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
                    Create tier
                  </button>
                  <button
                    onClick={() => setShowForm(false)}
                    className="px-4 py-2.5 bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] text-[13px] rounded-xl border border-[rgb(var(--color-border))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            )}

            {/* Existing tiers */}
            {tiers.length === 0 && !showForm ? (
              <div className="text-center py-16">
                <Users size={40} className="mx-auto mb-3 text-[rgb(var(--color-text-tertiary))]" />
                <p className="text-[14px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">No tiers yet</p>
                <p className="text-[12px] text-[rgb(var(--color-text-secondary))] mb-5">Create your first membership tier to start earning recurring revenue</p>
                <button
                  onClick={() => setShowForm(true)}
                  className="inline-flex items-center gap-2 px-5 py-2.5 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full hover:opacity-90 transition-opacity"
                >
                  <Plus size={16} /> Create tier
                </button>
              </div>
            ) : (
              <div className="space-y-3">
                {tiers.map((tier) => (
                  <div key={tier.id} className="bg-[rgb(var(--color-surface))] rounded-xl border border-[rgb(var(--color-border))] p-4">
                    <div className="flex items-start justify-between gap-3 mb-3">
                      <div className="flex items-center gap-3">
                        <span className="text-2xl">{tier.badgeEmoji}</span>
                        <div>
                          <p className="text-[15px] font-bold text-[rgb(var(--color-text-primary))]">{tier.name}</p>
                          <p className="text-[13px] text-[rgb(var(--color-primary))] font-semibold">
                            ${(tier.priceMonthly / 100).toFixed(2)}/month
                          </p>
                        </div>
                      </div>
                      <div className="flex items-center gap-3 flex-shrink-0">
                        <div className="text-right">
                          <p className="text-[15px] font-bold text-[rgb(var(--color-text-primary))]">{tier.memberCount}</p>
                          <p className="text-[11px] text-[rgb(var(--color-text-secondary))]">members</p>
                        </div>
                        <button
                          onClick={() => handleDelete(tier.id)}
                          className="p-1.5 text-[rgb(var(--color-text-tertiary))] hover:text-red-500 transition-colors"
                          aria-label="Delete tier"
                        >
                          <Trash2 size={16} />
                        </button>
                      </div>
                    </div>
                    {tier.perks.length > 0 && (
                      <ul className="space-y-1">
                        {tier.perks.map((perk, i) => (
                          <li key={i} className="flex items-center gap-2 text-[12px] text-[rgb(var(--color-text-secondary))]">
                            <span className="text-[rgb(var(--color-primary))]">✓</span> {perk}
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                ))}
              </div>
            )}
          </main>
        )}
      </div>
    </div>
  );
}
