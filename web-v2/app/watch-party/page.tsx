import { Suspense } from 'react';
import WatchPartyPageClient from './WatchPartyPageClient';

export async function generateStaticParams() {
  return [];
}

export default function WatchPartyPage() {
  return (
    <Suspense fallback={null}>
      <WatchPartyPageClient />
    </Suspense>
  );
}
