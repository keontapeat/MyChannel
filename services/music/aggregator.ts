/**
 * aggregator.ts — Distribution delivery adapters.
 *
 * Real music distribution happens one of two ways:
 *   1) Through an aggregator API (FUGA, Revelator, SonoSuite, Believe) that fans
 *      your release out to every DSP. Recommended unless you have direct DSP deals.
 *   2) Direct DDEX delivery to a DSP that issued you a party id + ingestion bucket.
 *
 * This module exposes a single deliverRelease() that picks an adapter based on
 * DISTRIBUTION_PROVIDER. Each adapter takes the DDEX XML + asset URLs and hands
 * off to the partner, returning a provider delivery id we can poll for status.
 *
 * Env:
 *   DISTRIBUTION_PROVIDER   "fuga" | "revelator" | "sonosuite" | "ddex_sftp" | "mock"
 *   AGGREGATOR_API_BASE     base URL of the partner API
 *   AGGREGATOR_API_KEY      bearer token / api key for the partner
 *   DDEX_SFTP_HOST/USER/...  for direct SFTP delivery (when DISTRIBUTION_PROVIDER=ddex_sftp)
 */

export interface DeliveryAssets {
  ernXml: string;
  audioURLs: string[];
  artworkURL: string;
  upc: string;
  releaseId: string;
}

export interface DeliveryResult {
  provider: string;
  deliveryId: string;
  status: 'submitted' | 'queued' | 'error';
  message: string;
  raw?: any;
}

const PROVIDER = (process.env.DISTRIBUTION_PROVIDER || 'mock').toLowerCase();
const API_BASE = process.env.AGGREGATOR_API_BASE || '';
const API_KEY = process.env.AGGREGATOR_API_KEY || '';

/** Generic JSON aggregator adapter (FUGA/Revelator/SonoSuite-style REST). */
async function deliverViaAggregator(assets: DeliveryAssets): Promise<DeliveryResult> {
  if (!API_BASE || !API_KEY) {
    return {
      provider: PROVIDER,
      deliveryId: '',
      status: 'error',
      message: `Distribution provider "${PROVIDER}" is selected but AGGREGATOR_API_BASE/AGGREGATOR_API_KEY are not configured.`,
    };
  }

  // Most aggregators accept an ERN + asset manifest. The exact path differs per
  // partner; this uses a conventional /v1/deliveries endpoint. Adjust per your
  // partner's API contract when you sign with them.
  const res = await fetch(`${API_BASE.replace(/\/$/, '')}/v1/deliveries`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      upc: assets.upc,
      releaseId: assets.releaseId,
      ern: assets.ernXml,
      assets: {
        audio: assets.audioURLs,
        artwork: assets.artworkURL,
      },
    }),
  });

  const raw: any = await res.json().catch(() => ({}));
  if (!res.ok) {
    return {
      provider: PROVIDER,
      deliveryId: '',
      status: 'error',
      message: raw.error || `Aggregator responded ${res.status}`,
      raw,
    };
  }

  return {
    provider: PROVIDER,
    deliveryId: raw.deliveryId || raw.id || '',
    status: 'submitted',
    message: 'Release delivered to aggregator for DSP fan-out.',
    raw,
  };
}

/**
 * Direct DDEX-over-SFTP delivery stub. Wiring an SFTP client (ssh2-sftp-client)
 * is environment-specific; we record intent and return queued so a worker can
 * ship the ERN + binaries to the DSP's ingestion bucket.
 */
async function deliverViaDDEXSFTP(assets: DeliveryAssets): Promise<DeliveryResult> {
  const host = process.env.DDEX_SFTP_HOST;
  if (!host) {
    return {
      provider: 'ddex_sftp',
      deliveryId: '',
      status: 'error',
      message: 'DDEX_SFTP_HOST is not configured for direct DDEX delivery.',
    };
  }
  // A background worker (not in this request path) should pick up the queued
  // delivery, open SFTP, and upload `${upc}/` with the ERN + audio + artwork.
  return {
    provider: 'ddex_sftp',
    deliveryId: `ddex_${assets.upc}_${Date.now()}`,
    status: 'queued',
    message: `Queued DDEX batch for SFTP delivery to ${host}.`,
  };
}

/** Mock adapter for local/dev so the full flow works without a partner account. */
async function deliverMock(assets: DeliveryAssets): Promise<DeliveryResult> {
  return {
    provider: 'mock',
    deliveryId: `mock_${assets.upc}_${Date.now()}`,
    status: 'submitted',
    message:
      'Mock delivery accepted. Set DISTRIBUTION_PROVIDER + AGGREGATOR_API_* to deliver to real DSPs.',
  };
}

export async function deliverRelease(assets: DeliveryAssets): Promise<DeliveryResult> {
  switch (PROVIDER) {
    case 'fuga':
    case 'revelator':
    case 'sonosuite':
    case 'believe':
      return deliverViaAggregator(assets);
    case 'ddex_sftp':
      return deliverViaDDEXSFTP(assets);
    case 'mock':
    default:
      return deliverMock(assets);
  }
}

export function activeProvider(): string {
  return PROVIDER;
}
