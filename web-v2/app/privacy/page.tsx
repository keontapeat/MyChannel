'use client';

import MainLayout from '@/components/layout/MainLayout';

export default function PrivacyPage() {
  return (
    <MainLayout>
      <div className="max-w-[800px] mx-auto px-4 sm:px-6 py-10 text-[rgb(var(--color-text-primary))]">
        <h1 className="text-3xl font-bold mb-2">Privacy Policy</h1>
        <p className="text-sm text-[rgb(var(--color-text-tertiary))] mb-6">Last updated: 2025</p>

        <div className="space-y-6 text-[rgb(var(--color-text-secondary))] leading-relaxed">
          <section>
            <h2 className="text-lg font-bold text-[rgb(var(--color-text-primary))] mb-2">Information we collect</h2>
            <p>
              We collect account information, content you upload, usage and watch data, and, for
              real-money features, the identity information required for compliance.
            </p>
          </section>
          <section>
            <h2 className="text-lg font-bold text-[rgb(var(--color-text-primary))] mb-2">How we use it</h2>
            <p>
              To operate the platform, personalize recommendations, process payments, prevent fraud,
              and meet legal obligations.
            </p>
          </section>
          <section>
            <h2 className="text-lg font-bold text-[rgb(var(--color-text-primary))] mb-2">Your rights</h2>
            <p>
              You may access, correct, or delete your personal data, and control privacy settings
              for your watch history, likes, and subscriptions.
            </p>
          </section>
          <section>
            <h2 className="text-lg font-bold text-[rgb(var(--color-text-primary))] mb-2">Data security</h2>
            <p>
              We use industry-standard safeguards to protect your data. No sensitive payment card
              data is stored directly on our servers.
            </p>
          </section>
        </div>
      </div>
    </MainLayout>
  );
}
