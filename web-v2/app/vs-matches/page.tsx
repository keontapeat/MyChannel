'use client';

// VS Matches lives under the Championship hub (/medals). Redirect for parity
// with the sidebar link and any external references.

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

export default function VSMatchesRedirectPage() {
  const router = useRouter();
  useEffect(() => {
    router.replace('/medals');
  }, [router]);
  return null;
}
