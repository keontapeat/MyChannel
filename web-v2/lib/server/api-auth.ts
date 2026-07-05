// Server-side auth guard for API route handlers.
//
// IMPORTANT: These route handlers do NOT ship with the current static export
// (`output: 'export'` in next.config.ts). They are intended to run on a Node
// runtime (Cloud Functions / Cloud Run). This guard makes them fail-closed so
// that wherever they are hosted, they require a valid Firebase ID token and
// can't be abused to burn Vertex AI / Remove.bg quota.
//
// Credentials use Application Default Credentials (ADC) — no secrets in code.
// On Cloud Functions/Run the service account is provided automatically; locally
// use `gcloud auth application-default login`.

import { NextRequest, NextResponse } from 'next/server';
import { getApps, initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth, type DecodedIdToken } from 'firebase-admin/auth';

function ensureAdminApp(): void {
  if (getApps().length === 0) {
    initializeApp({ credential: applicationDefault() });
  }
}

export type AuthResult =
  | { user: DecodedIdToken; error?: undefined }
  | { user?: undefined; error: NextResponse };

/**
 * Verify the `Authorization: Bearer <firebaseIdToken>` header on a request.
 * Returns the decoded token on success, or a 401 NextResponse to return.
 */
export async function verifyRequestAuth(request: NextRequest): Promise<AuthResult> {
  const header = request.headers.get('authorization') || '';
  const match = header.match(/^Bearer (.+)$/i);
  if (!match) {
    return {
      error: NextResponse.json(
        { error: 'Unauthorized: missing bearer token' },
        { status: 401 }
      ),
    };
  }

  try {
    ensureAdminApp();
    const user = await getAuth().verifyIdToken(match[1]);
    return { user };
  } catch {
    return {
      error: NextResponse.json(
        { error: 'Unauthorized: invalid or expired token' },
        { status: 401 }
      ),
    };
  }
}
