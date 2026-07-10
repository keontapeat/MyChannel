'use client';

import { AlertTriangle, CheckCircle, Info, Shield } from 'lucide-react';
import {
  WAGER_POLICY,
  canWagerClientPreflight,
  dailyLimitDollars,
  requiresKYC,
  isRegionAllowed,
  type AccountTier,
} from '@/lib/wager-policy';

export type CompliancePreflightInput = {
  age: number;
  kycApproved: boolean;
  region: string;
  alreadyWageredToday: number;
  tier: AccountTier;
  termsAcceptedVersion: string | null;
  wagerAmountDollars?: number;
};

type ComplianceStatusBannerProps = {
  preflight: CompliancePreflightInput;
  className?: string;
};

type StatusTone = 'ok' | 'warn' | 'block';

function toneFor(ok: boolean, blocking: boolean): StatusTone {
  if (blocking) return 'block';
  if (ok) return 'ok';
  return 'warn';
}

export function ComplianceStatusBanner({ preflight, className = '' }: ComplianceStatusBannerProps) {
  const amount = preflight.wagerAmountDollars ?? 0;
  const result = canWagerClientPreflight({
    age: preflight.age,
    kycApproved: preflight.kycApproved,
    amountDollars: amount > 0 ? amount : WAGER_POLICY.minWagerDollars,
    region: preflight.region,
    alreadyWageredToday: preflight.alreadyWageredToday,
    tier: preflight.tier,
    termsAcceptedVersion: preflight.termsAcceptedVersion,
  });

  const dailyLimit = dailyLimitDollars(preflight.tier);
  const remainingDaily = Math.max(0, dailyLimit - preflight.alreadyWageredToday);
  const kycNeeded = requiresKYC(amount > 0 ? amount : WAGER_POLICY.kycRequiredAboveDollars + 1);
  const regionOk = isRegionAllowed(preflight.region);
  const termsOk = preflight.termsAcceptedVersion === WAGER_POLICY.currentTermsVersion;
  const ageOk = preflight.age >= WAGER_POLICY.minimumAge;

  const kycTone = toneFor(preflight.kycApproved, kycNeeded && !preflight.kycApproved);
  const regionTone = toneFor(regionOk, !regionOk);
  const dailyTone = toneFor(
    remainingDaily > 0,
    amount > 0 && preflight.alreadyWageredToday + amount > dailyLimit
  );
  const termsTone = toneFor(termsOk, !termsOk);
  const ageTone = toneFor(ageOk, !ageOk);

  const overallBlocking = !result.ok;
  const containerClass = overallBlocking
    ? 'border-red-500/40 bg-red-950/30'
    : 'border-blue-500/30 bg-blue-900/30';

  return (
    <section
      className={`rounded-xl border p-4 ${containerClass} ${className}`}
      role="status"
      aria-label="Compliance status"
    >
      <div className="mb-3 flex items-center gap-2">
        <Shield className="h-5 w-5 text-blue-300" aria-hidden />
        <h3 className="text-sm font-bold text-white">Compliance preflight</h3>
        {overallBlocking ? (
          <span className="ml-auto text-xs font-semibold text-red-300">Action required</span>
        ) : (
          <span className="ml-auto text-xs font-semibold text-green-300">Ready</span>
        )}
      </div>

      <ul className="space-y-2 text-sm">
        <StatusRow
          label="Age (18+)"
          value={ageOk ? 'Verified' : 'Not verified'}
          tone={ageTone}
        />
        <StatusRow
          label="KYC"
          value={
            preflight.kycApproved
              ? 'Approved'
              : kycNeeded
                ? 'Required for wagers over $500'
                : 'Not required at this amount'
          }
          tone={kycTone}
        />
        <StatusRow
          label="Region"
          value={regionOk ? preflight.region : `${preflight.region} — not eligible`}
          tone={regionTone}
        />
        <StatusRow
          label="Daily limit"
          value={`$${preflight.alreadyWageredToday.toFixed(0)} / $${dailyLimit.toLocaleString()} used · $${remainingDaily.toFixed(0)} left`}
          tone={dailyTone}
        />
        <StatusRow
          label="Terms"
          value={
            termsOk
              ? `Accepted (v${WAGER_POLICY.currentTermsVersion})`
              : `Accept v${WAGER_POLICY.currentTermsVersion}`
          }
          tone={termsTone}
        />
      </ul>

      {!result.ok && (
        <div className="mt-3 flex items-start gap-2 text-xs text-red-200">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" aria-hidden />
          <ul className="space-y-0.5">
            {result.reasons.map((reason) => (
              <li key={reason}>• {reason}</li>
            ))}
          </ul>
        </div>
      )}

      {result.ok && (
        <p className="mt-3 flex items-center gap-2 text-xs text-green-200">
          <CheckCircle className="h-4 w-4" aria-hidden />
          Client preflight passed — server will re-validate before holding funds.
        </p>
      )}

      <p className="mt-2 flex items-start gap-2 text-xs text-blue-200/80">
        <Info className="mt-0.5 h-3.5 w-3.5 shrink-0" aria-hidden />
        Funds are held in escrow until match outcome is verified.
      </p>
    </section>
  );
}

function StatusRow({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone: StatusTone;
}) {
  const icon =
    tone === 'ok' ? (
      <CheckCircle className="h-4 w-4 text-green-400" aria-hidden />
    ) : tone === 'block' ? (
      <AlertTriangle className="h-4 w-4 text-red-400" aria-hidden />
    ) : (
      <Info className="h-4 w-4 text-yellow-400" aria-hidden />
    );

  return (
    <li className="flex items-start gap-2 text-blue-100">
      {icon}
      <span>
        <span className="font-semibold text-white">{label}:</span> {value}
      </span>
    </li>
  );
}
