'use client';

import { useState, useEffect } from 'react';
import { ChevronLeft, Globe, Loader2 } from 'lucide-react';
import Link from 'next/link';
import { collection, query, orderBy, limit, getDocs } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

interface TranslationJob {
  id: string;
  videoTitle: string;
  sourceLanguage: string;
  targetLanguage: string;
  type: string;
  status: string;
  progress: number;
}

export default function TranslationsPageClient() {
  const [jobs, setJobs] = useState<TranslationJob[]>([]);
  const [loading, setLoading] = useState(true);
  const uid = auth?.currentUser?.uid;

  useEffect(() => {
    if (!uid) { setLoading(false); return; }
    (async () => {
      try {
        const snap = await getDocs(query(
          collection(db, 'creators', uid, 'translations'),
          orderBy('createdAt', 'desc'), limit(50)
        ));
        setJobs(snap.docs.map((d) => ({ id: d.id, ...d.data() } as TranslationJob)));
      } finally { setLoading(false); }
    })();
  }, [uid]);

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14">
      <div className="max-w-[800px] mx-auto px-4 py-6 pb-24">
        <div className="flex items-center gap-3 mb-6">
          <Link href="/studio" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full">
            <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
          </Link>
          <div>
            <h1 className="text-[20px] font-bold text-[rgb(var(--color-text-primary))]">Translations & Dubbing</h1>
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">Multi-language captions and dubbing</p>
          </div>
        </div>

        {loading ? (
          <div className="flex justify-center py-12"><Loader2 size={24} className="animate-spin text-[rgb(var(--color-text-tertiary))]" /></div>
        ) : jobs.length === 0 ? (
          <div className="text-center py-20">
            <Globe size={44} className="mx-auto mb-3 text-[rgb(var(--color-primary))]" />
            <p className="text-[15px] font-semibold text-[rgb(var(--color-text-primary))]">No translation jobs</p>
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">Translate your videos to reach a global audience</p>
          </div>
        ) : (
          <div className="space-y-3">
            {jobs.map((job) => (
              <div key={job.id} className="bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-xl p-4">
                <div className="flex items-start justify-between">
                  <div>
                    <p className="text-[14px] font-semibold text-[rgb(var(--color-text-primary))]">{job.videoTitle}</p>
                    <p className="text-[12px] text-[rgb(var(--color-text-secondary))] mt-1">
                      {job.sourceLanguage.toUpperCase()} → {job.targetLanguage} • {job.type}
                    </p>
                  </div>
                  <span className={`px-2 py-0.5 rounded text-[11px] font-medium ${
                    job.status === 'completed' ? 'bg-green-100 text-green-700 dark:bg-green-900/20 dark:text-green-400'
                    : job.status === 'processing' ? 'bg-blue-100 text-blue-700 dark:bg-blue-900/20 dark:text-blue-400'
                    : 'bg-gray-100 text-gray-700 dark:bg-gray-900/20 dark:text-gray-400'
                  }`}>
                    {job.status}
                  </span>
                </div>
                {job.status === 'processing' && job.progress > 0 && (
                  <div className="mt-3">
                    <div className="w-full h-1.5 bg-[rgb(var(--color-surface-hover))] rounded-full overflow-hidden">
                      <div className="h-full bg-[rgb(var(--color-primary))] rounded-full transition-all" style={{ width: `${job.progress}%` }} />
                    </div>
                    <p className="text-[11px] text-[rgb(var(--color-text-tertiary))] mt-1">{job.progress}% complete</p>
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
