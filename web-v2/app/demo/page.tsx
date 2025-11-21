'use client';

/**
 * Demo Page - Showcase Hero Component
 * Accessible at /demo
 */

import Hero from '@/components/layout/Hero';
import Header from '@/components/layout/Header';
import { useState } from 'react';

export default function DemoPage() {
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="min-h-screen">
      {/* Skip Navigation */}
      <a 
        href="#main-content" 
        className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-[100] focus:px-4 focus:py-2 focus:bg-[rgb(var(--color-primary))] focus:text-white focus:rounded-lg"
      >
        Skip to main content
      </a>

      <Header onToggleSidebar={() => setSidebarOpen(!sidebarOpen)} />

      <main id="main-content" className="pt-14">
        {/* Hero Showcase */}
        <Hero
          title="Your Channel. Your Future."
          subtitle="The next-generation video platform combining YouTube + Twitch + DraftKings + UFC. Create, stream, compete, and win."
          ctaPrimary={{
            text: 'Get Started',
            href: '/signup',
          }}
          ctaSecondary={{
            text: 'Watch Demo',
            href: '/watch/demo',
          }}
          backgroundImage="https://images.unsplash.com/photo-1611162617474-5b21e879e113?w=1920&q=80"
          stats={[
            { label: 'Active Creators', value: '1M+', icon: null },
            { label: 'Daily Views', value: '50M+', icon: null },
            { label: 'Awards Given', value: '10K+', icon: null },
          ]}
          featuredVideo={{
            id: 'demo',
            title: 'Shot By Keonta - Introduction',
            thumbnail: 'https://picsum.photos/1280/720',
            channel: 'MyChannel',
          }}
        />

        {/* Additional Content */}
        <section className="py-20 px-4 bg-white dark:bg-[rgb(var(--color-background))]">
          <div className="max-w-4xl mx-auto text-center">
            <h2 className="text-3xl font-bold mb-4 text-[rgb(var(--color-text-primary))]">
              Premium Hero Component
            </h2>
            <p className="text-lg text-[rgb(var(--color-text-secondary))]">
              This demo page showcases the production-ready Hero component with all features enabled.
            </p>
          </div>
        </section>
      </main>
    </div>
  );
}





