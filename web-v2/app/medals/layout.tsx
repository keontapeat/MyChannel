import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Championship Hub',
  robots: { index: false, follow: false },
};

export default function MedalsLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-[#0d0e11] text-white antialiased">{children}</div>
  );
}
