'use client';

import MainLayout from '@/components/layout/MainLayout';

export default function TermsPage() {
  return (
    <MainLayout>
      <div className="max-w-[800px] mx-auto px-4 sm:px-6 py-10 text-[rgb(var(--color-text-primary))]">
        <h1 className="text-3xl font-bold mb-2">Terms of Service</h1>
        <p className="text-sm text-[rgb(var(--color-text-tertiary))] mb-6">Last updated: 2025</p>

        <div className="space-y-6 text-[rgb(var(--color-text-secondary))] leading-relaxed">
          <section>
            <h2 className="text-lg font-bold text-[rgb(var(--color-text-primary))] mb-2">1. Acceptance of terms</h2>
            <p>By accessing or using MyChannel you agree to be bound by these Terms of Service.</p>
          </section>
          <section>
            <h2 className="text-lg font-bold text-[rgb(var(--color-text-primary))] mb-2">2. Eligibility</h2>
            <p>
              You must be at least 18 years old to participate in any real-money feature, including
              VS Matches and wagers. Additional verification may be required.
            </p>
          </section>
          <section>
            <h2 className="text-lg font-bold text-[rgb(var(--color-text-primary))] mb-2">3. Content ownership</h2>
            <p>
              You retain ownership of content you upload. You grant MyChannel a license to host,
              distribute, and display that content on the platform.
            </p>
          </section>
          <section>
            <h2 className="text-lg font-bold text-[rgb(var(--color-text-primary))] mb-2">4. Real-money features</h2>
            <p>
              VS Matches and wagers are subject to regional availability, identity verification,
              daily limits, and a platform fee. Funds are held in escrow until a match settles.
            </p>
          </section>
          <section>
            <h2 className="text-lg font-bold text-[rgb(var(--color-text-primary))] mb-2">5. Prohibited conduct</h2>
            <p>
              You may not upload illegal content, infringe copyright, harass other users, or attempt
              to manipulate competitions or payouts.
            </p>
          </section>
        </div>
      </div>
    </MainLayout>
  );
}
