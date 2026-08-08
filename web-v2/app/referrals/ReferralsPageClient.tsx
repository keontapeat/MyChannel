'use client';

import { useState, useEffect } from 'react';
import { ChevronLeft, Share2, Gift, Loader2, Copy } from 'lucide-react';
import Link from 'next/link';
import { collection, query, orderBy, getDocs, doc, getDoc } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

interface ReferralCode {
  id: string;
  code: string;
  currentUses: number;
  referrerBonusCents: number;
  refereeBonusCents: number;
}

interface Conversion {
  id: string;
  code: string;
  refereeEmail: string;
  isValid: boolean;
  createdAt: Date;
}

export default function ReferralsPageClient() {
  const [codes, setCodes] = useState<ReferralCode[]>([]);
  const [conversions, setConversions] = useState<Conversion[]>([]);
  const [totalCents, setTotalCents] = useState(0);
  const [loading, setLoading] = useState(true);
  const uid = auth?.currentUser?.uid;

  useEffect(() => {
    if (!uid) { setLoading(false); return; }
    (async () => {
      try {
        const [codesSnap, convSnap, earningsDoc] = await Promise.all([
          getDocs(query(collection(db, 'users', uid, 'referralCodes'), orderBy('createdAt', 'desc'))),
          getDocs(query(collection(db, 'users', uid, 'referralConversions'), orderBy('createdAt', 'desc'))),
          getDoc(doc(db, 'users', uid, 'earnings', 'referrals')),
        ]);
        setCodes(codesSnap.docs.map((d) => ({ id: d.id, ...d.data() } as ReferralCode)));
        setConversions(convSnap.docs.map((d) => ({ id: d.id, ...d.data(), createdAt: d.data().createdAt?.toDate?.() ?? new Date() } as Conversion)));
        setTotalCents((earningsDoc.data()?.totalCents as number) ?? 0);
      } finally { setLoading(false); }
    })();
  }, [uid]);

  const copyLink = (code: string) => { navigator.clipboard?.writeText(`https://mychannel.live/ref/${code}`); };

  if (!uid) return (
    <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14 flex items-center justify-center">
      <div className="text-center">
        <Gift size={48} className="mx-auto mb-4 text-[rgb(var(--color-primary))]" />
        <p className="text-[15px] font-semibold text-[rgb(var(--color-text-primary))] mb-2">Sign in to manage referrals</p>
        <Link href="/login" className="px-4 py-2 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full">Sign in</Link>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14">
      <div className="max-w-[640px] mx-auto px-4 py-6 pb-24">
        <div className="flex items-center gap-3 mb-6">
          <Link href="/" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full"><ChevronLeft size={20} /></Link>
          <div><h1 className="text-[20px] font-bold text-[rgb(var(--color-text-primary))]">Referrals</h1><p className="text-[13px] text-[rgb(var(--color-text-secondary))]">Invite friends, earn rewards</p></div>
        </div>
        {loading ? <div className="flex justify-center py-12"><Loader2 size={24} className="animate-spin" /></div> : (
          <div className="space-y-6">
            <div className="bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-xl p-6 text-center">
              <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">Total Referral Earnings</p>
              <p className="text-[32px] font-bold text-[rgb(var(--color-primary))]">${Math.floor(totalCents / 100)}.{(totalCents % 100).toString().padStart(2, '0')}</p>
            </div>
            <div>
              <h2 className="text-[16px] font-bold text-[rgb(var(--color-text-primary))] mb-3">My Referral Codes</h2>
              {codes.length === 0 ? <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">No referral codes yet</p> : (
                <div className="space-y-3">
                  {codes.map((code) => (
                    <div key={code.id} className="bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-xl p-4">
                      <div className="flex items-center justify-between">
                        <span className="text-[18px] font-bold font-mono text-[rgb(var(--color-text-primary))]">{code.code}</span>
                        <button onClick={() => copyLink(code.code)} className="flex items-center gap-1.5 px-3 py-1.5 bg-[rgb(var(--color-primary))] text-white text-[12px] font-medium rounded-full hover:opacity-90"><Copy size={12} /> Copy Link</button>
                      </div>
                      <div className="flex gap-6 mt-3 text-[12px] text-[rgb(var(--color-text-secondary))]">
                        <span>Uses: {code.currentUses}</span>
                        <span>You earn: ${code.referrerBonusCents / 100}</span>
                        <span>Friend gets: ${code.refereeBonusCents / 100}</span>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
            <div className="bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-xl p-4">
              <h3 className="text-[14px] font-bold text-[rgb(var(--color-text-primary))] mb-3">How It Works</h3>
              <div className="space-y-3">
                {[['Share your code', 'Send your unique referral code to friends'], ['Friend signs up', 'They create an account using your code'], ['Both earn rewards', 'You both get signup bonuses']].map(([title, desc], i) => (
                  <div key={i} className="flex items-start gap-3">
                    <span className="w-5 h-5 bg-[rgb(var(--color-primary))] text-white text-[11px] font-bold rounded-full flex items-center justify-center flex-shrink-0">{i + 1}</span>
                    <div><p className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))]">{title}</p><p className="text-[12px] text-[rgb(var(--color-text-tertiary))]">{desc}</p></div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
