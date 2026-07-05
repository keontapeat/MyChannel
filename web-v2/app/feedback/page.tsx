'use client';

// Send feedback — wired to Firestore `feedback` collection.

import MainLayout from '@/components/layout/MainLayout';
import { useState } from 'react';
import { Flag, CheckCircle } from 'lucide-react';
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

export default function FeedbackPage() {
  const [category, setCategory] = useState('general');
  const [message, setMessage] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!message.trim() || submitting) return;
    setSubmitting(true);
    try {
      await addDoc(collection(db, 'feedback'), {
        category,
        message: message.trim(),
        userId: auth?.currentUser?.uid ?? null,
        userEmail: auth?.currentUser?.email ?? null,
        createdAt: serverTimestamp(),
        status: 'new',
        platform: 'web',
        userAgent: typeof navigator !== 'undefined' ? navigator.userAgent : '',
      });
      setSubmitted(true);
    } catch (err) {
      console.error('Feedback submission error:', err);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <MainLayout>
      <div className="max-w-[640px] mx-auto px-4 sm:px-6 py-10">
        <div className="flex items-center gap-3 mb-6">
          <Flag size={24} className="text-[rgb(var(--color-text-primary))]" />
          <h1 className="text-2xl font-bold text-[rgb(var(--color-text-primary))]">Send feedback</h1>
        </div>

        {submitted ? (
          <div className="rounded-xl border border-green-200 bg-green-50 p-6 text-center">
            <CheckCircle size={32} className="mx-auto mb-3 text-green-600" />
            <p className="text-sm font-medium text-green-800">Thanks for your feedback.</p>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="mb-1 block text-sm font-medium text-[rgb(var(--color-text-primary))]">Category</label>
              <select
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                className="w-full rounded-lg border border-[rgb(var(--color-border))] bg-transparent px-3 py-2 text-sm text-[rgb(var(--color-text-primary))]"
              >
                <option value="general">General feedback</option>
                <option value="bug">Report a bug</option>
                <option value="feature">Feature request</option>
                <option value="content">Content / moderation</option>
              </select>
            </div>
            <div>
              <label className="mb-1 block text-sm font-medium text-[rgb(var(--color-text-primary))]">Message</label>
              <textarea
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                rows={6}
                placeholder="Tell us what's on your mind..."
                className="w-full rounded-lg border border-[rgb(var(--color-border))] bg-transparent px-3 py-2 text-sm text-[rgb(var(--color-text-primary))] outline-none focus:border-[rgb(var(--color-primary))]"
              />
            </div>
            <button
              type="submit"
              disabled={submitting}
              className="rounded-full bg-[rgb(var(--color-primary))] px-6 py-2.5 text-sm font-semibold text-white hover:opacity-90 transition-opacity disabled:opacity-50"
            >
              {submitting ? 'Sending…' : 'Submit feedback'}
            </button>
          </form>
        )}
      </div>
    </MainLayout>
  );
}
