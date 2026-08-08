'use client';

import {FormEvent, useState} from 'react';
import {Flag, Loader2, X} from 'lucide-react';
import {
  CONTENT_REPORT_REASONS,
  ContentReportReason,
  ReportableContentType,
  submitContentReport,
} from '@/lib/firebase/content-reports';

interface ContentReportDialogProps {
  contentType: ReportableContentType;
  contentId: string;
  contentCreatorId?: string;
  title: string;
  onClose: () => void;
}

export default function ContentReportDialog({
  contentType,
  contentId,
  contentCreatorId,
  title,
  onClose,
}: ContentReportDialogProps) {
  const [reason, setReason] = useState<ContentReportReason>('spam');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isSubmitted, setIsSubmitted] = useState(false);
  const [error, setError] = useState('');

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (isSubmitting) return;
    setIsSubmitting(true);
    setError('');
    try {
      await submitContentReport({contentType, contentId, contentCreatorId, reason});
      setIsSubmitted(true);
    } catch (submitError) {
      setError(submitError instanceof Error ? submitError.message : 'Unable to submit report.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/70 p-4" role="presentation">
      <section
        role="dialog"
        aria-modal="true"
        aria-labelledby="content-report-title"
        className="w-full max-w-md rounded-2xl border border-[rgb(var(--color-border))] bg-[rgb(var(--color-background))] p-5 shadow-2xl"
      >
        <div className="mb-4 flex items-start justify-between gap-4">
          <div>
            <h2 id="content-report-title" className="text-lg font-semibold text-[rgb(var(--color-text-primary))]">
              Report {title}
            </h2>
            <p className="mt-1 text-sm text-[rgb(var(--color-text-secondary))]">
              Reports are private and reviewed by the Trust &amp; Safety team.
            </p>
          </div>
          <button type="button" onClick={onClose} aria-label="Close report dialog" className="min-h-11 min-w-11 rounded-full p-2 text-[rgb(var(--color-text-secondary))] hover:bg-[rgb(var(--color-surface-hover))]">
            <X size={20} />
          </button>
        </div>

        {isSubmitted ? (
          <div className="space-y-4" role="status">
            <p className="text-sm text-[rgb(var(--color-text-primary))]">Report received. Thank you for helping keep MyChannel safe.</p>
            <button type="button" onClick={onClose} className="min-h-11 w-full rounded-full bg-[rgb(var(--color-primary))] px-4 py-2 text-sm font-semibold text-white">Done</button>
          </div>
        ) : (
          <form onSubmit={submit} className="space-y-4">
            <label className="block text-sm font-medium text-[rgb(var(--color-text-primary))]">
              Reason
              <select value={reason} onChange={(event) => setReason(event.target.value as ContentReportReason)} className="mt-2 min-h-11 w-full rounded-lg border border-[rgb(var(--color-border))] bg-[rgb(var(--color-surface))] px-3 text-[rgb(var(--color-text-primary))]">
                {CONTENT_REPORT_REASONS.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
              </select>
            </label>
            {error && <p role="alert" className="text-sm text-red-500">{error}</p>}
            <button type="submit" disabled={isSubmitting} className="flex min-h-11 w-full items-center justify-center gap-2 rounded-full bg-red-600 px-4 py-2 text-sm font-semibold text-white hover:bg-red-700 disabled:opacity-60">
              {isSubmitting ? <Loader2 size={18} className="animate-spin" /> : <Flag size={18} />}
              {isSubmitting ? 'Submitting…' : 'Submit report'}
            </button>
          </form>
        )}
      </section>
    </div>
  );
}