'use client';

import MainLayout from '@/components/layout/MainLayout';

export default function AboutPage() {
  return (
    <MainLayout>
      <div className="max-w-[800px] mx-auto px-4 sm:px-6 py-10 text-[rgb(var(--color-text-primary))]">
        <h1 className="text-3xl font-bold mb-4">About MyChannel</h1>
        <p className="text-[rgb(var(--color-text-secondary))] leading-relaxed mb-4">
          MyChannel is a next-generation creator platform that combines video hosting and
          streaming, live broadcasting, real-money competitions, and championship rankings into one
          ecosystem built for creators.
        </p>
        <p className="text-[rgb(var(--color-text-secondary))] leading-relaxed mb-4">
          We give creators better ownership, deeper analytics, and more ways to earn than
          traditional platforms — from ad revenue and channel memberships to VS Matches and tips.
        </p>
        <h2 className="text-xl font-bold mt-8 mb-3">Our mission</h2>
        <p className="text-[rgb(var(--color-text-secondary))] leading-relaxed">
          To build the most powerful, creator-first video platform on Earth.
        </p>
      </div>
    </MainLayout>
  );
}
