'use client';

import { useState, useEffect, useRef } from 'react';
import { ThumbsUp, Reply, ChevronDown, MoreVertical } from 'lucide-react';
import {
  collection,
  addDoc,
  query,
  orderBy,
  onSnapshot,
  serverTimestamp,
  doc,
  updateDoc,
  increment,
  limit,
  startAfter,
  getDocs,
  type QueryDocumentSnapshot,
  type DocumentData,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import { formatViewCount } from '@/lib/utils/format';
import type { Comment } from '@/types';

interface CommentSectionProps {
  videoId: string;
  commentCount: number;
}

type SortOrder = 'top' | 'new';

const PAGE_SIZE = 20;

function timeAgo(date: Date): string {
  const secs = Math.floor((Date.now() - date.getTime()) / 1000);
  if (secs < 60) return `${secs}s ago`;
  if (secs < 3600) return `${Math.floor(secs / 60)}m ago`;
  if (secs < 86400) return `${Math.floor(secs / 3600)}h ago`;
  if (secs < 604800) return `${Math.floor(secs / 86400)}d ago`;
  return date.toLocaleDateString();
}

interface CommentDoc {
  id: string;
  userId: string;
  displayName: string;
  avatarURL: string;
  text: string;
  createdAt: Date;
  likeCount: number;
  replyCount: number;
  isPinned: boolean;
}

function CommentRow({
  comment,
  onReply,
}: {
  comment: CommentDoc;
  onReply: (id: string, name: string) => void;
}) {
  const [liked, setLiked] = useState(false);
  const [localLikes, setLocalLikes] = useState(comment.likeCount);

  const handleLike = async () => {
    const next = !liked;
    setLiked(next);
    setLocalLikes((n) => n + (next ? 1 : -1));
    try {
      await updateDoc(doc(db, 'videos', comment.id.split('_')[0], 'comments', comment.id), {
        likeCount: increment(next ? 1 : -1),
      });
    } catch {
      // optimistic rollback
      setLiked(!next);
      setLocalLikes((n) => n + (next ? -1 : 1));
    }
  };

  return (
    <div className="flex gap-3">
      {/* Avatar */}
      <img
        src={comment.avatarURL || `https://i.pravatar.cc/150?u=${comment.userId}`}
        alt={comment.displayName}
        className="w-9 h-9 rounded-full flex-shrink-0 mt-0.5"
      />

      <div className="flex-1 min-w-0">
        {/* Header */}
        <div className="flex items-center gap-2 mb-1">
          <span className="text-[13px] font-semibold text-[rgb(var(--color-text-primary))]">
            {comment.displayName}
          </span>
          {comment.isPinned && (
            <span className="text-[11px] text-[rgb(var(--color-primary))] font-medium">📌 Pinned</span>
          )}
          <span className="text-[12px] text-[rgb(var(--color-text-tertiary))]">
            {timeAgo(comment.createdAt)}
          </span>
        </div>

        {/* Text */}
        <p className="text-[13.5px] text-[rgb(var(--color-text-primary))] whitespace-pre-wrap break-words leading-snug">
          {comment.text}
        </p>

        {/* Actions */}
        <div className="flex items-center gap-1 mt-1.5">
          <button
            onClick={handleLike}
            className={`flex items-center gap-1 px-2 py-1 rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors text-[12px] ${
              liked ? 'text-[rgb(var(--color-primary))]' : 'text-[rgb(var(--color-text-secondary))]'
            }`}
            aria-label="Like comment"
          >
            <ThumbsUp size={14} fill={liked ? 'currentColor' : 'none'} />
            {localLikes > 0 && <span>{formatViewCount(localLikes)}</span>}
          </button>

          <button
            onClick={() => onReply(comment.id, comment.displayName)}
            className="flex items-center gap-1 px-2 py-1 rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors text-[12px] text-[rgb(var(--color-text-secondary))]"
          >
            <Reply size={14} />
            Reply
          </button>
        </div>
      </div>

      <button className="p-1 rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors flex-shrink-0 self-start mt-1" aria-label="More options">
        <MoreVertical size={16} className="text-[rgb(var(--color-text-tertiary))]" />
      </button>
    </div>
  );
}

const CommentSection = ({ videoId, commentCount: initialCount }: CommentSectionProps) => {
  const [commentText, setCommentText] = useState('');
  const [replyingTo, setReplyingTo] = useState<{ id: string; name: string } | null>(null);
  const [comments, setComments] = useState<CommentDoc[]>([]);
  const [sort, setSort] = useState<SortOrder>('top');
  const [submitting, setSubmitting] = useState(false);
  const [commentCount, setCommentCount] = useState(initialCount);
  const [loadingMore, setLoadingMore] = useState(false);
  const [lastDoc, setLastDoc] = useState<QueryDocumentSnapshot<DocumentData> | null>(null);
  const [hasMore, setHasMore] = useState(true);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // Real-time listener for first page
  useEffect(() => {
    if (!videoId || videoId === '_fallback') return;

    const colRef = collection(db, 'videos', videoId, 'comments');
    const q = query(
      colRef,
      orderBy(sort === 'top' ? 'likeCount' : 'createdAt', 'desc'),
      limit(PAGE_SIZE)
    );

    const unsub = onSnapshot(q, (snap) => {
      const docs: CommentDoc[] = snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          userId: data.userId ?? '',
          displayName: data.displayName ?? 'Anonymous',
          avatarURL: data.avatarURL ?? '',
          text: data.text ?? '',
          createdAt: data.createdAt?.toDate?.() ?? new Date(),
          likeCount: data.likeCount ?? 0,
          replyCount: data.replyCount ?? 0,
          isPinned: data.isPinned ?? false,
        };
      });
      setComments(docs);
      setLastDoc(snap.docs[snap.docs.length - 1] ?? null);
      setHasMore(snap.docs.length === PAGE_SIZE);
    });

    return () => unsub();
  }, [videoId, sort]);

  const loadMore = async () => {
    if (!lastDoc || loadingMore) return;
    setLoadingMore(true);
    try {
      const colRef = collection(db, 'videos', videoId, 'comments');
      const q = query(
        colRef,
        orderBy(sort === 'top' ? 'likeCount' : 'createdAt', 'desc'),
        startAfter(lastDoc),
        limit(PAGE_SIZE)
      );
      const snap = await getDocs(q);
      const more: CommentDoc[] = snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          userId: data.userId ?? '',
          displayName: data.displayName ?? 'Anonymous',
          avatarURL: data.avatarURL ?? '',
          text: data.text ?? '',
          createdAt: data.createdAt?.toDate?.() ?? new Date(),
          likeCount: data.likeCount ?? 0,
          replyCount: data.replyCount ?? 0,
          isPinned: data.isPinned ?? false,
        };
      });
      setComments((prev) => [...prev, ...more]);
      setLastDoc(snap.docs[snap.docs.length - 1] ?? null);
      setHasMore(snap.docs.length === PAGE_SIZE);
    } finally {
      setLoadingMore(false);
    }
  };

  const handleSubmit = async () => {
    const text = commentText.trim();
    if (!text || submitting) return;

    const currentUser = auth.currentUser;
    const displayName = currentUser?.displayName ?? 'Anonymous';
    const avatarURL = currentUser?.photoURL ?? '';
    const userId = currentUser?.uid ?? `anon_${Date.now()}`;

    setSubmitting(true);
    try {
      const colRef = collection(db, 'videos', videoId, 'comments');
      await addDoc(colRef, {
        userId,
        displayName,
        avatarURL,
        text,
        createdAt: serverTimestamp(),
        likeCount: 0,
        replyCount: 0,
        isPinned: false,
        parentCommentId: replyingTo?.id ?? null,
      });

      // Increment video comment count
      await updateDoc(doc(db, 'videos', videoId), {
        commentCount: increment(1),
      });

      setCommentText('');
      setReplyingTo(null);
      setCommentCount((n) => n + 1);
    } catch (err) {
      console.error('Failed to post comment:', err);
    } finally {
      setSubmitting(false);
    }
  };

  const handleReply = (id: string, name: string) => {
    setReplyingTo({ id, name });
    setCommentText(`@${name} `);
    textareaRef.current?.focus();
  };

  const currentUser = auth?.currentUser;
  const avatarSrc = currentUser?.photoURL || `https://i.pravatar.cc/150?img=2`;

  return (
    <div className="space-y-4">
      {/* Header + sort */}
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold text-[rgb(var(--color-text-primary))]">
          {formatViewCount(commentCount)} Comments
        </h3>
        <div className="relative">
          <button
            className="flex items-center gap-1 px-3 py-1.5 text-[13px] font-medium text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors"
            onClick={() => setSort((s) => (s === 'top' ? 'new' : 'top'))}
          >
            <ChevronDown size={16} />
            {sort === 'top' ? 'Top comments' : 'Newest first'}
          </button>
        </div>
      </div>

      {/* Reply indicator */}
      {replyingTo && (
        <div className="flex items-center gap-2 text-[12px] text-[rgb(var(--color-text-secondary))] bg-[rgb(var(--color-surface))] px-3 py-1.5 rounded-lg">
          <Reply size={13} />
          Replying to <span className="font-medium text-[rgb(var(--color-primary))]">@{replyingTo.name}</span>
          <button
            onClick={() => { setReplyingTo(null); setCommentText(''); }}
            className="ml-auto text-[rgb(var(--color-text-tertiary))] hover:text-[rgb(var(--color-text-primary))]"
          >
            ✕
          </button>
        </div>
      )}

      {/* Composer */}
      <div className="flex gap-3">
        <img
          src={avatarSrc}
          alt="Your avatar"
          className="w-10 h-10 rounded-full flex-shrink-0"
        />
        <div className="flex-1">
          <textarea
            ref={textareaRef}
            value={commentText}
            onChange={(e) => setCommentText(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) handleSubmit();
            }}
            placeholder="Add a comment..."
            className="w-full px-0 py-2 bg-transparent text-sm text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] border-b border-[rgb(var(--color-border))] focus:border-[rgb(var(--color-primary))] outline-none resize-none"
            rows={1}
          />
          {commentText && (
            <div className="flex items-center justify-end gap-2 mt-2">
              <button
                onClick={() => { setCommentText(''); setReplyingTo(null); }}
                className="px-4 py-2 text-sm font-medium text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleSubmit}
                disabled={submitting}
                className="px-4 py-2 text-sm font-medium bg-[rgb(var(--color-primary))] text-white rounded-full hover:opacity-90 disabled:opacity-50 transition-opacity"
              >
                {submitting ? 'Posting…' : 'Comment'}
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Comments list */}
      <div className="space-y-5 mt-4">
        {comments.length === 0 ? (
          <p className="text-center text-sm text-[rgb(var(--color-text-secondary))] py-8">
            Be the first to comment
          </p>
        ) : (
          comments.map((c) => (
            <CommentRow key={c.id} comment={c} onReply={handleReply} />
          ))
        )}
      </div>

      {/* Load more */}
      {hasMore && comments.length > 0 && (
        <button
          onClick={loadMore}
          disabled={loadingMore}
          className="w-full py-2 text-sm font-medium text-[rgb(var(--color-primary))] hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors disabled:opacity-50"
        >
          {loadingMore ? 'Loading…' : 'Show more comments'}
        </button>
      )}
    </div>
  );
};

export default CommentSection;
