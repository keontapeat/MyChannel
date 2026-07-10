'use client';

/**
 * Creator ads dashboard stub — web parity with iOS CreatorAdsDashboardStubView.
 * See docs/ads-remaining.md
 */
export default function CreatorAdsDashboardPage() {
  return (
    <main className="mx-auto max-w-2xl p-6">
      <h1 className="text-2xl font-bold">Creator Ads</h1>
      <p className="mt-2 text-muted-foreground">
        Revenue share, RPM, and fill-rate analytics will appear here once your channel is monetized.
      </p>
      <dl className="mt-6 grid grid-cols-2 gap-4">
        <div className="rounded-lg border p-4">
          <dt className="text-sm text-muted-foreground">Est. RPM</dt>
          <dd className="text-xl font-semibold">—</dd>
        </div>
        <div className="rounded-lg border p-4">
          <dt className="text-sm text-muted-foreground">Ad share</dt>
          <dd className="text-xl font-semibold">90%</dd>
        </div>
      </dl>
    </main>
  );
}
