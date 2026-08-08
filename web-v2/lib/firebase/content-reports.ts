import {doc, getDoc, serverTimestamp, setDoc} from 'firebase/firestore';
import {auth, db} from './config';

export type ReportableContentType = 'video' | 'live_stream';
export type ContentReportReason =
  | 'spam'
  | 'harassment'
  | 'hate_or_abuse'
  | 'sexual_content'
  | 'violence'
  | 'dangerous_acts'
  | 'misinformation'
  | 'copyright'
  | 'other';

export const CONTENT_REPORT_REASONS: ReadonlyArray<{
  value: ContentReportReason;
  label: string;
}> = [
  {value: 'spam', label: 'Spam or scam'},
  {value: 'harassment', label: 'Harassment or bullying'},
  {value: 'hate_or_abuse', label: 'Hate or abusive content'},
  {value: 'sexual_content', label: 'Sexual content'},
  {value: 'violence', label: 'Violence or graphic content'},
  {value: 'dangerous_acts', label: 'Dangerous acts'},
  {value: 'misinformation', label: 'Harmful misinformation'},
  {value: 'copyright', label: 'Copyright infringement'},
  {value: 'other', label: 'Other policy violation'},
];

async function reportId(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
}

export async function submitContentReport(input: {
  contentType: ReportableContentType;
  contentId: string;
  contentCreatorId?: string;
  reason: ContentReportReason;
}): Promise<'created' | 'existing'> {
  const user = auth.currentUser;
  if (!user) throw new Error('Sign in to submit a report.');
  if (!input.contentId) throw new Error('This content is unavailable.');

  const id = await reportId(`${user.uid}\u001f${input.contentType}\u001f${input.contentId}`);
  const reportRef = doc(db, 'content_reports', id);
  if ((await getDoc(reportRef)).exists()) return 'existing';

  await setDoc(reportRef, {
    type: input.contentType,
    contentId: input.contentId,
    contentCreatorId: input.contentCreatorId || '',
    reporterId: user.uid,
    reason: input.reason,
    status: 'pending',
    reviewed: false,
    createdAt: serverTimestamp(),
  });
  return 'created';
}