'use client';

import { useState, useEffect } from 'react';
import { ChevronLeft, Users, Check, X, Loader2 } from 'lucide-react';
import Link from 'next/link';
import { collection, query, where, orderBy, limit, getDocs, doc, updateDoc } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

interface Collaboration {
  id: string;
  title: string;
  description: string;
  initiatorId: string;
  initiatorName: string;
  initiatorAvatar: string;
  collaboratorNames: string[];
  status: string;
  type: string;
  createdAt: Date;
}

export default function CollaborationsPageClient() {
  const [tab, setTab] = useState<'active' | 'requests' | 'past'>('active');
  const [collabs, setCollabs] = useState<Collaboration[]>([]);
  const [loading, setLoading] = useState(true);
  const uid = auth?.currentUser?.uid;

  useEffect(() => {
    if (!uid) { setLoading(false); return; }
    loadCollabs();
  }, [uid]);

  const loadCollabs = async () => {
    if (!uid) return;
    setLoading(true);
    try {
      const snap = await getDocs(query(
        collection(db, 'collaborations'),
        where('participantIds', 'array-contains', uid),
        orderBy('createdAt', 'desc'), limit(100)
      ));
      setCollabs(snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          title: data.title ?? '',
          description: data.description ?? '',
          initiatorId: data.initiatorId ?? '',
          initiatorName: data.initiatorName ?? '',
          initiatorAvatar: data.initiatorAvatar ?? '',
          collaboratorNames: data.collaboratorNames ?? [],
          status: data.status ?? 'pending',
          type: data.type ?? 'video',
          createdAt: data.createdAt?.toDate?.() ?? new Date(),
        };
      }));
    } finally { setLoading(false); }
  };

  const updateStatus = async (id: string, status: string) => {
    setCollabs((prev) => prev.map((c) => c.id === id ? { ...c, status } : c));
    await updateDoc(doc(db, 'collaborations', id), { status });
  };

  const filtered = collabs.filter((c) => {
    if (tab === 'active') return ['accepted', 'in-progress'].includes(c.status);
    if (tab === 'requests') return c.status === 'pending' && c.initiatorId !== uid;
    return ['completed', 'declined'].includes(c.status);
  });

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14">
      <div className="max-w-[800px] mx-auto px-4 py-6 pb-24">
        <div className="flex items-center gap-3 mb-6">
          <Link href="/studio" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full">
            <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
          </Link>
          <div>
            <h1 className="text-[20px] font-bold text-[rgb(var(--color-text-primary))]">Collaborations</h1>
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">Co-create with other creators</p>
          </div>
        </div>

        <div className="flex gap-1 mb-6 bg-[rgb(var(--color-surface))] p-1 rounded-full w-fit">
          {(['active', 'requests', 'past'] as const).map((t) => (
            <button key={t} onClick={() => setTab(t)} className={`px-4 py-2 rounded-full text-[13px] font-medium capitalize transition-colors ${tab === t ? 'bg-[rgb(var(--color-primary))] text-white' : 'text-[rgb(var(--color-text-secondary))] hover:bg-[rgb(var(--color-surface-hover))]'}`}>
              {t}
            </button>
          ))}
        </div>

        {loading ? (
          <div className="flex justify-center py-12"><Loader2 size={24} className="animate-spin text-[rgb(var(--color-text-tertiary))]" /></div>
        ) : filtered.length === 0 ? (
          <div className="text-center py-20">
            <Users size={44} className="mx-auto mb-3 text-[rgb(var(--color-primary))]" />
            <p className="text-[15px] font-semibold text-[rgb(var(--color-text-primary))]">No {tab} collaborations</p>
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">Team up with other creators</p>
          </div>
        ) : (
          <div className="space-y-3">
            {filtered.map((collab) => (
              <div key={collab.id} className="bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-xl p-4">
                <div className="flex items-start gap-3">
                  {collab.initiatorAvatar && (
                    <img src={collab.initiatorAvatar} alt="" className="w-10 h-10 rounded-full" />
                  )}
                  <div className="flex-1">
                    <p className="text-[14px] font-semibold text-[rgb(var(--color-text-primary))]">{collab.title}</p>
                    <p className="text-[12px] text-[rgb(var(--color-text-secondary))] mt-0.5">From: {collab.initiatorName}</p>
                    {collab.description && <p className="text-[12px] text-[rgb(var(--color-text-tertiary))] mt-1 line-clamp-2">{collab.description}</p>}
                    {collab.collaboratorNames.length > 0 && (
                      <p className="text-[12px] text-[rgb(var(--color-text-tertiary))] mt-1">With: {collab.collaboratorNames.join(', ')}</p>
                    )}
                    <div className="flex items-center gap-2 mt-2">
                      <span className="px-2 py-0.5 rounded text-[11px] font-medium bg-[rgb(var(--color-surface-hover))] text-[rgb(var(--color-text-secondary))]">{collab.type}</span>
                      <span className="px-2 py-0.5 rounded text-[11px] font-medium bg-[rgb(var(--color-surface-hover))] text-[rgb(var(--color-text-secondary))]">{collab.status}</span>
                    </div>
                  </div>
                </div>
                {tab === 'requests' && collab.status === 'pending' && (
                  <div className="flex gap-2 mt-3 pt-3 border-t border-[rgb(var(--color-border))]">
                    <button onClick={() => updateStatus(collab.id, 'accepted')} className="flex items-center gap-1.5 px-3 py-1.5 bg-[rgb(var(--color-primary))] text-white rounded-full text-[12px] font-medium hover:opacity-90">
                      <Check size={14} /> Accept
                    </button>
                    <button onClick={() => updateStatus(collab.id, 'declined')} className="flex items-center gap-1.5 px-3 py-1.5 border border-[rgb(var(--color-border))] rounded-full text-[12px] font-medium hover:bg-[rgb(var(--color-surface-hover))]">
                      <X size={14} /> Decline
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
