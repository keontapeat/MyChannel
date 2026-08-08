'use client';

import { useState, useEffect } from 'react';
import { ChevronLeft, GraduationCap, BookOpen, Award, Flame, Loader2 } from 'lucide-react';
import Link from 'next/link';
import { collection, query, orderBy, limit, getDocs, doc, getDoc } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

interface Course { id: string; title: string; description: string; category: string; creatorName: string; thumbnailUrl: string; videoCount: number; totalMinutes: number; enrolledCount: number; rating: number; }
interface Progress { totalHours: number; videosCompleted: number; certificates: number; currentStreak: number; globalRank: number; points: number; }

export default function UniversityPageClient() {
  const [courses, setCourses] = useState<Course[]>([]);
  const [progress, setProgress] = useState<Progress>({ totalHours: 0, videosCompleted: 0, certificates: 0, currentStreak: 0, globalRank: 0, points: 0 });
  const [tab, setTab] = useState<'dashboard' | 'courses' | 'certificates'>('dashboard');
  const [loading, setLoading] = useState(true);
  const uid = auth?.currentUser?.uid;

  useEffect(() => {
    (async () => {
      try {
        const snap = await getDocs(query(collection(db, 'university_courses'), orderBy('enrolledCount', 'desc'), limit(20)));
        setCourses(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Course)));
        if (uid) {
          const p = await getDoc(doc(db, 'users', uid, 'university', 'progress'));
          if (p.exists()) setProgress(p.data() as Progress);
        }
      } finally { setLoading(false); }
    })();
  }, [uid]);

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14">
      <div className="max-w-[900px] mx-auto px-4 py-6 pb-24">
        <div className="flex items-center gap-3 mb-6">
          <Link href="/" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full"><ChevronLeft size={20} /></Link>
          <div><h1 className="text-[20px] font-bold text-[rgb(var(--color-text-primary))]">🎓 MyChannel University</h1><p className="text-[13px] text-[rgb(var(--color-text-secondary))]">AI-verified learning paths. Real creator credentials.</p></div>
        </div>

        <div className="flex gap-1 mb-6 bg-[rgb(var(--color-surface))] p-1 rounded-full w-fit">
          {(['dashboard', 'courses', 'certificates'] as const).map((t) => (
            <button key={t} onClick={() => setTab(t)} className={`px-4 py-2 rounded-full text-[13px] font-medium capitalize transition-colors ${tab === t ? 'bg-[rgb(var(--color-primary))] text-white' : 'text-[rgb(var(--color-text-secondary))] hover:bg-[rgb(var(--color-surface-hover))]'}`}>{t}</button>
          ))}
        </div>

        {loading ? <div className="flex justify-center py-12"><Loader2 size={24} className="animate-spin" /></div> : tab === 'dashboard' ? (
          <div className="space-y-6">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              <StatCard icon={<BookOpen size={20} />} value={`${progress.totalHours.toFixed(0)}h`} label="Learning" />
              <StatCard icon={<Award size={20} />} value={`${progress.certificates}`} label="Certificates" />
              <StatCard icon={<Flame size={20} />} value={`${progress.currentStreak}d`} label="Streak" />
              <StatCard icon={<GraduationCap size={20} />} value={`#${progress.globalRank || '—'}`} label="Rank" />
            </div>
            <div><h2 className="text-[16px] font-bold text-[rgb(var(--color-text-primary))] mb-3">Featured Courses</h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {courses.slice(0, 6).map((c) => <CourseCard key={c.id} course={c} />)}
              </div>
            </div>
          </div>
        ) : tab === 'courses' ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {courses.map((c) => <CourseCard key={c.id} course={c} />)}
          </div>
        ) : (
          <div className="text-center py-20">
            <Award size={48} className="mx-auto mb-3 text-[rgb(var(--color-primary))]" />
            <p className="text-[15px] font-semibold text-[rgb(var(--color-text-primary))]">Certificates</p>
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">Complete courses to earn AI-verified certificates</p>
          </div>
        )}
      </div>
    </div>
  );
}

function StatCard({ icon, value, label }: { icon: React.ReactNode; value: string; label: string }) {
  return (
    <div className="bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-xl p-4 text-center">
      <div className="text-[rgb(var(--color-primary))] flex justify-center mb-2">{icon}</div>
      <p className="text-[20px] font-bold text-[rgb(var(--color-text-primary))]">{value}</p>
      <p className="text-[11px] text-[rgb(var(--color-text-secondary))]">{label}</p>
    </div>
  );
}

function CourseCard({ course }: { course: Course }) {
  return (
    <div className="bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-xl overflow-hidden hover:shadow-lg transition-shadow">
      {course.thumbnailUrl && <img src={course.thumbnailUrl} alt={course.title} className="w-full h-32 object-cover" />}
      <div className="p-3">
        <p className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))] line-clamp-2">{course.title}</p>
        <p className="text-[11px] text-[rgb(var(--color-text-secondary))] mt-1">{course.creatorName}</p>
        <div className="flex gap-3 mt-2 text-[11px] text-[rgb(var(--color-text-tertiary))]">
          <span>{course.videoCount} videos</span>
          <span>{course.totalMinutes}m</span>
          {course.rating > 0 && <span>★ {course.rating.toFixed(1)}</span>}
        </div>
      </div>
    </div>
  );
}
