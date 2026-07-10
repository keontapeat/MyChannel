'use client';

import { Shield, X } from 'lucide-react';
import { WAGER_POLICY } from '@/lib/wager-policy';

type AgeGateModalProps = {
  isOpen: boolean;
  onClose: () => void;
  onConfirmAge: (age: number) => void;
};

export function AgeGateModal({ isOpen, onClose, onConfirmAge }: AgeGateModalProps) {
  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-[100] flex items-end justify-center bg-black/70 p-4 sm:items-center"
      role="dialog"
      aria-modal="true"
      aria-labelledby="age-gate-title"
    >
      <div className="w-full max-w-md rounded-2xl border border-gray-700 bg-gray-900 p-6 shadow-2xl">
        <div className="mb-4 flex items-start justify-between gap-3">
          <div className="flex items-center gap-2">
            <Shield className="h-6 w-6 text-blue-400" aria-hidden />
            <h2 id="age-gate-title" className="text-lg font-bold text-white">
              Age verification required
            </h2>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="min-h-[44px] min-w-[44px] rounded-full p-2 text-gray-400 hover:bg-gray-800 hover:text-white"
            aria-label="Close age verification dialog"
          >
            <X size={20} />
          </button>
        </div>

        <p className="mb-6 text-sm text-gray-300">
          VS Matches with real-money wagers require you to be at least{' '}
          {WAGER_POLICY.minimumAge} years old. Confirm your age to continue.
        </p>

        <div className="grid grid-cols-2 gap-3">
          <button
            type="button"
            onClick={() => onConfirmAge(17)}
            className="min-h-[44px] rounded-xl border border-red-500/40 bg-red-950/40 px-4 py-3 text-sm font-semibold text-red-200 hover:bg-red-950/60"
          >
            Under {WAGER_POLICY.minimumAge}
          </button>
          <button
            type="button"
            onClick={() => onConfirmAge(WAGER_POLICY.minimumAge)}
            className="min-h-[44px] rounded-xl bg-green-600 px-4 py-3 text-sm font-semibold text-white hover:bg-green-700"
          >
            I am {WAGER_POLICY.minimumAge}+
          </button>
        </div>

        <p className="mt-4 text-center text-xs text-gray-500">
          Server re-validates age from your compliance profile before holding funds.
        </p>
      </div>
    </div>
  );
}
