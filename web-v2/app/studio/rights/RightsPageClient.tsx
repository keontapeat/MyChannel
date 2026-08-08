'use client';

import { useState, useEffect } from 'react';
import { ChevronLeft, Shield, AlertTriangle, Gavel, Loader2 } from 'lucide-react';
import Link from 'next/link';
import { collection, query, orderBy, limit, getDocs, doc, updateDoc } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

interface CopyrightClaim {
  id: string;
  videoTitle: string;
  claimantName: string;
  contentType: string;
  status: string;
  action: string;
  matchPercentage: number;
}

interface DMCANotice {
  id: string;
  videoTitle: string;
  complainantName: string;
  description: string;
  status: string;
}

export default function RightsPageClient() {
  const [tab, setTab] = useState<'claims' | 'dmca'>('claims');
  const [claims, setClaims] = useState<CopyrightClaim[]>([]);
  const [notices, setNotices] = useState<DMCANotice[]>([]);
  const [loading, setLoading] = useState(true);
  const uid = auth?.currentUser?.uid;

  useEffect(() => {
    if (!uid) { setLoading(false); return; }
    loadData();
  }, [uid]);

  const loadData = async () => {
    if (!uid) return;
    setLoading(true);
    try {
      const [claimsSnap, dmcaSnap] = await Promise.all([
        getDocs(query(collection(db, 'creators', uid, 'copyrightClaims'), orderBy('createdAt', 'desc'), limit(50))),
        getDocs(query(collection(db, 'creators', uid, 'dmcaNotices'), orderBy('createdAt', 'desc'), limit(50))),
      ]);
      setClaims(claimsSnap.docs.map((d) => ({ id: d.id, ...d.data() } as CopyrightClaim)));
      setNotices(dmcaSnap.docs.map((d) => ({ id: d.id, ...d.data() } as DMCANotice)));
    } finally { setLoading(false); }
  };

  const disputeClaim = async (claimId: string) => {
    if (!uid) return;
    setClaims((prev) => prev.map((c) => c.id === claimId ? { ...c, status: 'disputed' } : c));
    await updateDoc(doc(db, 'creators', uid, 'copyrightClaims', claimId), { status: 'disputed' });
  };

  const counterNotify = async (noticeId: string) => {
    if (!uid) return;
    setNotices((prev) => prev.map((n) => n.id === noticeId ? { ...n, status: 'counter-notified' } : n));
    await updateDoc(doc(db, 'creators', uid, 'dmcaNotices', noticeId), { status: 'counter-notified' });
  };

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14">
      <div className="max-w-[800px] mx-auto px-4 py-6 pb-24">
        <div className="flex items-center gap-3 mb-6">
          <Link href="/studio" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full">
            <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
          </Link>
          <div>
            <h1 className="text-[20px] font-bold text-[rgb(var(--color-text-primary))]">Rights Management</h1>
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">Copyright claims & DMCA notices</p>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex gap-1 mb-6 bg-[rgb(var(--color-surface))] p-1 rounded-full w-fit">
          <button onClick={() => setTab('claims')} className={`px-4 py-2 rounded-full text-[13px] font-medium transition-colors ${tab === 'claims' ? 'bg-[rgb(var(--color-primary))] text-white' : 'text-[rgb(var(--color-text-secondary))] hover:bg-[rgb(var(--color-surface-hover))]'}`}>
            Copyright Claims
          </button>
          <button onClick={() => setTab('dmca')} className={`px-4 py-2 rounded-full text-[13px] font-medium transition-colors ${tab === 'dmca' ? 'bg-[rgb(var(--color-primary))] text-white' : 'text-[rgb(var(--color-text-secondary))] hover:bg-[rgb(var(--color-surface-hover))]'}`}>
            DMCA Notices
          </button>
        </div>

        {loading ? (
          <div className="flex justify-center py-12"><Loader2 size={24} className="animate-spin text-[rgb(var(--color-text-tertiary))]" /></div>
        ) : tab === 'claims' ? (
          claims.length === 0 ? (
            <div className="text-center py-20">
              <Shield size={44} className="mx-auto mb-3 text-[rgb(var(--color-primary))]" />
              <p className="text-[15px] font-semibold text-[rgb(var(--color-text-primary))]">No copyright claims</p>
              <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">Your content is clear</p>
            </div>
          ) : (
            <div className="space-y-3">
              {claims.map((claim) => (
                <div key={claim.id} className="bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-xl p-4">
                  <div className="flex items-start gap-3">
                    <AlertTriangle size={18} className={claim.status === 'active' ? 'text-red-500' : 'text-yellow-500'} />
                    <div className="flex-1">
                      <p className="text-[14px] font-semibold text-[rgb(var(--color-text-primary))]">{claim.videoTitle}</p>
                      <p className="text-[12px] text-[rgb(var(--color-text-secondary))] mt-1">Claimed by: {claim.claimantName}</p>
                      <p className="text-[12px] text-[rgb(var(--color-text-tertiary))]">Type: {claim.contentType} • Action: {claim.action} • Match: {claim.matchPercentage}%</p>
                      <span className={`inline-block mt-2 px-2 py-0.5 rounded text-[11px] font-medium ${claim.status === 'active' ? 'bg-red-100 text-red-700 dark:bg-red-900/20 dark:text-red-400' : 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/20 dark:text-yellow-400'}`}>
                        {claim.status}
                      </span>
                    </div>
                    {claim.status === 'active' && (
                      <button onClick={() => disputeClaim(claim.id)} className="px-3 py-1.5 border border-[rgb(var(--color-border))] rounded-full text-[12px] font-medium hover:bg-[rgb(var(--color-surface-hover))]">
                        Dispute
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )
        ) : (
          notices.length === 0 ? (
            <div className="text-center py-20">
              <Gavel size={44} className="mx-auto mb-3 text-[rgb(var(--color-primary))]" />
              <p className="text-[15px] font-semibold text-[rgb(var(--color-text-primary))]">No DMCA notices</p>
              <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">No takedown requests</p>
            </div>
          ) : (
            <div className="space-y-3">
              {notices.map((notice) => (
                <div key={notice.id} className="bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-xl p-4">
                  <p className="text-[14px] font-semibold text-[rgb(var(--color-text-primary))]">{notice.videoTitle}</p>
                  <p className="text-[12px] text-[rgb(var(--color-text-secondary))] mt-1">From: {notice.complainantName}</p>
                  <p className="text-[12px] text-[rgb(var(--color-text-tertiary))] mt-1 line-clamp-2">{notice.description}</p>
                  <div className="flex items-center gap-3 mt-3">
                    <span className={`px-2 py-0.5 rounded text-[11px] font-medium ${notice.status === 'pending' ? 'bg-orange-100 text-orange-700 dark:bg-orange-900/20 dark:text-orange-400' : 'bg-blue-100 text-blue-700 dark:bg-blue-900/20 dark:text-blue-400'}`}>
                      {notice.status}
                    </span>
                    {(notice.status === 'pending' || notice.status === 'removed') && (
                      <button onClick={() => counterNotify(notice.id)} className="px-3 py-1.5 border border-[rgb(var(--color-border))] rounded-full text-[12px] font-medium hover:bg-[rgb(var(--color-surface-hover))]">
                        Counter-Notify
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )
        )}
      </div>
    </div>
  );
}
