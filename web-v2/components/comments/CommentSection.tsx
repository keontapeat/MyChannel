'use client';

// CommentSection — YouTube-parity comments.
//   • Pinned-first ordering, Top/Newest sort
//   • One-level threaded replies ("View N replies")
//   • Per-user like persistence (users/{uid}/commentLikes/{commentId})
//   • Creator hearts + "Creator" badge
//   • Rich text: clickable timestamps + @mentions
//
// Index-friendly: the main page uses a single-field orderBy (existing index) and
// filters top-level client-side; replies use an equality-only query (no composite
// index) sorted client-side.

import { useState, useEffect, useRef } from 'react';
import { ThumbsUp, Reply, ChevronDown, MoreVertical, Heart, Loader2, Check } from 'lucide-react';
import {
  collection, query, orderBy, onSnapshot, serverTimestamp,
  doc, getDoc, where, getDocs,
  limit, startAfter, writeBatch, type QueryDocumentSnapshot, type DocumentData,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import { appendVideoEngagement, recordVideoEngagement } from '@/lib/firebase/video-engagement';
import { formatViewCount } from '@/lib/utils/format';

interface CommentSectionProps {
  videoId: string;
  commentCount: number;
  creatorId?: string;
}

type SortOrder = 'top' | 'new';
const PAGE_SIZE = 20;

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
  creatorHearted: boolean;
  parentCommentId: string | null;
}

function mapDoc(d: QueryDocumentSnapshot<DocumentData>): CommentDoc {
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
    creatorHearted: data.creatorHearted ?? false,
    parentCommentId: data.parentCommentId ?? null,
  };
}

function timeAgo(date: Date): string {
  const secs = Math.floor((Date.now() - date.getTime()) / 1000);
  if (secs < 60) return `${secs}s ago`;
  if (secs < 3600) return `${Math.floor(secs / 60)}m ago`;
  if (secs < 86400) return `${Math.floor(secs / 3600)}h ago`;
  if (secs < 604800) return `${Math.floor(secs / 86400)}d ago`;
  return date.toLocaleDateString();
}

// Rich text: clickable timestamps (seek player) + @mentions (search link).
const COMMENT_RE = /(\B@[A-Za-z0-9_.]{2,})|(\b(?:\d{1,2}:)?[0-5]?\d:[0-5]\d\b)/g;
function renderCommentText(text: string): React.ReactNode[] {
  const out: React.ReactNode[] = [];
  let last = 0; let m: RegExpExecArray | null; let k = 0;
  COMMENT_RE.lastIndex = 0;
  while ((m = COMMENT_RE.exec(text)) !== null) {
    const [full, mention, ts] = m;
    if (m.index > last) out.push(text.slice(last, m.index));
    if (mention) {
      out.push(<a key={`m${k++}`} href={`/search?q=${encodeURIComponent(mention)}`} className="text-[rgb(var(--color-primary))] hover:underline">{mention}</a>);
    } else if (ts) {
      const parts = ts.split(':').map(Number);
      const secs = parts.length === 3 ? parts[0] * 3600 + parts[1] * 60 + parts[2] : parts[0] * 60 + parts[1];
      out.push(
        <button key={`t${k++}`} onClick={() => { window.dispatchEvent(new CustomEvent('mychannel:player-seek', { detail: { time: secs } })); window.scrollTo({ top: 0, behavior: 'smooth' }); }}
          className="text-[rgb(var(--color-primary))] hover:underline font-medium">{ts}</button>
      );
    }
    last = m.index + full.length;
  }
  if (last < text.length) out.push(text.slice(last));
  return out;
}

function CommentRow({
  comment, videoId, creatorId, isReply, onReply,
}: {
  comment: CommentDoc;
  videoId: string;
  creatorId?: string;
  isReply?: boolean;
  onReply: (parentId: string, name: string) => void;
}) {
  const [liked, setLiked] = useState(false);
  const [localLikes, setLocalLikes] = useState(comment.likeCount);
  const [hearted, setHearted] = useState(comment.creatorHearted);
  const [replies, setReplies] = useState<CommentDoc[]>([]);
  const [repliesOpen, setRepliesOpen] = useState(false);
  const [loadingReplies, setLoadingReplies] = useState(false);

  const uid = auth?.currentUser?.uid;
  const isCreator = !!uid && uid === creatorId;
  const commenterIsCreator = !!creatorId && comment.userId === creatorId;

  // Load this user's like state for the comment
  useEffect(() => {
    if (!uid) return;
    let cancelled = false;
    getDoc(doc(db, 'users', uid, 'commentLikes', comment.id))
      .then((s) => { if (!cancelled) setLiked(s.exists()); })
      .catch(() => {});
    return () => { cancelled = true; };
  }, [uid, comment.id]);

  const handleLike = async () => {
    const next = !liked;
    setLiked(next);
    setLocalLikes((count) => Math.max(0, count + (next ? 1 : -1)));
    try {
      if (!uid) throw new Error('Authentication required');
      const markerRef = doc(db, 'users', uid, 'commentLikes', comment.id);
      const batch = writeBatch(db);
      if (next) {
        batch.set(markerRef, { value: 'like', videoId, createdAt: serverTimestamp() });
      } else {
        batch.delete(markerRef);
      }
      appendVideoEngagement(batch, videoId, next ? 'comment_like' : 'comment_unlike', {
        sessionId: comment.id,
      });
      await batch.commit();
    } catch {
      setLiked(!next);
      setLocalLikes((count) => Math.max(0, count + (next ? -1 : 1)));
    }
  };

  const handleHeart = async () => {
    if (!isCreator) return;
    const next = !hearted;
    setHearted(next);
    try {
      await recordVideoEngagement(videoId, next ? 'comment_heart' : 'comment_unheart', {
        sessionId: comment.id,
      });
    } catch {
      setHearted(!next);
    }
  };

  const loadReplies = async () => {
    if (repliesOpen) { setRepliesOpen(false); return; }
    setRepliesOpen(true);
    if (replies.length > 0) return;
    setLoadingReplies(true);
    try {
      // Equality-only query (no composite index); sort client-side
      const snap = await getDocs(query(
        collection(db, 'videos', videoId, 'comments'),
        where('parentCommentId', '==', comment.id),
        limit(100),
      ));
      const list = snap.docs.map(mapDoc).sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
      setReplies(list);
    } finally {
      setLoadingReplies(false);
    }
  };

  // Refresh this thread when a new reply is posted to it
  useEffect(() => {
    const onRefresh = (e: Event) => {
      const pid = (e as CustomEvent<{ parentId: string }>).detail?.parentId;
      if (pid !== comment.id) return;
      if (repliesOpen) {
        getDocs(query(
          collection(db, 'videos', videoId, 'comments'),
          where('parentCommentId', '==', comment.id),
          limit(100),
        )).then((snap) => {
          setReplies(snap.docs.map(mapDoc).sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime()));
        }).catch(() => {});
      }
    };
    window.addEventListener('mychannel:comment-thread-refresh', onRefresh as EventListener);
    return () => window.removeEventListener('mychannel:comment-thread-refresh', onRefresh as EventListener);
  }, [comment.id, repliesOpen, videoId]);

  return (
    <div className="flex gap-3">
      <img
        src={comment.avatarURL || `https://i.pravatar.cc/150?u=${comment.userId}`}
        alt={comment.displayName}
        loading="lazy"
        className={`${isReply ? 'w-7 h-7' : 'w-9 h-9'} rounded-full flex-shrink-0 mt-0.5`}
      />

      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 mb-1 flex-wrap">
          {comment.isPinned && !isReply && (
            <span className="text-[11px] text-[rgb(var(--color-text-secondary))] font-medium w-full">📌 Pinned by creator</span>
          )}
          <span className={`text-[13px] font-semibold ${commenterIsCreator ? 'bg-[rgb(var(--color-text-primary))] text-[rgb(var(--color-background))] px-2 py-0.5 rounded-full' : 'text-[rgb(var(--color-text-primary))]'}`}>
            {comment.displayName}
          </span>
          <span className="text-[12px] text-[rgb(var(--color-text-tertiary))]">{timeAgo(comment.createdAt)}</span>
        </div>

        <p className="text-[13.5px] text-[rgb(var(--color-text-primary))] whitespace-pre-wrap break-words leading-snug">
          {renderCommentText(comment.text)}
        </p>

        <div className="flex items-center gap-1 mt-1.5">
          <button
            onClick={handleLike}
            className={`flex items-center gap-1 px-2 py-1 rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors text-[12px] ${liked ? 'text-[rgb(var(--color-primary))]' : 'text-[rgb(var(--color-text-secondary))]'}`}
            aria-label="Like comment"
          >
            <ThumbsUp size={14} fill={liked ? 'currentColor' : 'none'} />
            {localLikes > 0 && <span>{formatViewCount(localLikes)}</span>}
          </button>

          <button
            onClick={() => onReply(isReply ? (comment.parentCommentId ?? comment.id) : comment.id, comment.displayName)}
            className="flex items-center gap-1 px-2 py-1 rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors text-[12px] text-[rgb(var(--color-text-secondary))]"
          >
            <Reply size={14} /> Reply
          </button>

          {/* Creator heart */}
          {(hearted || isCreator) && (
            <button
              onClick={handleHeart}
              disabled={!isCreator}
              aria-label={hearted ? 'Creator hearted' : 'Heart this comment'}
              className={`p-1 rounded-full transition-colors ${isCreator ? 'hover:bg-[rgb(var(--color-surface-hover))]' : ''}`}
            >
              <Heart size={14} className={hearted ? 'text-red-500' : 'text-[rgb(var(--color-text-tertiary))]'} fill={hearted ? 'currentColor' : 'none'} />
            </button>
          )}
        </div>

        {/* Replies toggle */}
        {!isReply && comment.replyCount > 0 && (
          <button
            onClick={loadReplies}
            className="flex items-center gap-1.5 mt-1.5 px-2 py-1 rounded-full text-[13px] font-semibold text-[rgb(var(--color-primary))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
          >
            {loadingReplies ? <Loader2 size={14} className="animate-spin" /> : <ChevronDown size={14} className={repliesOpen ? 'rotate-180 transition-transform' : 'transition-transform'} />}
            {comment.replyCount} {comment.replyCount === 1 ? 'reply' : 'replies'}
          </button>
        )}

        {/* Replies list */}
        {repliesOpen && replies.length > 0 && (
          <div className="mt-3 space-y-4">
            {replies.map((r) => (
              <CommentRow key={r.id} comment={r} videoId={videoId} creatorId={creatorId} isReply onReply={onReply} />
            ))}
          </div>
        )}
      </div>

      <button className="p-1 rounded-full hover:bg-[rgb(var(--color-surface-hover))] transition-colors flex-shrink-0 self-start mt-1" aria-label="More options">
        <MoreVertical size={16} className="text-[rgb(var(--color-text-tertiary))]" />
      </button>
    </div>
  );
}

const CommentSection = ({ videoId, commentCount: initialCount, creatorId }: CommentSectionProps) => {
  const [commentText, setCommentText] = useState('');
  const [replyingTo, setReplyingTo] = useState<{ id: string; name: string } | null>(null);
  const [comments, setComments] = useState<CommentDoc[]>([]);
  const [sort, setSort] = useState<SortOrder>('top');
  const [sortMenuOpen, setSortMenuOpen] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [commentCount, setCommentCount] = useState(initialCount);
  const [loadingMore, setLoadingMore] = useState(false);
  const [lastDoc, setLastDoc] = useState<QueryDocumentSnapshot<DocumentData> | null>(null);
  const [hasMore, setHasMore] = useState(true);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // Sort top-level comments with pinned first
  const sortTopLevel = (list: CommentDoc[]): CommentDoc[] => {
    const topLevel = list.filter((c) => !c.parentCommentId);
    return topLevel.sort((a, b) => {
      if (a.isPinned !== b.isPinned) return a.isPinned ? -1 : 1;
      return sort === 'top'
        ? b.likeCount - a.likeCount
        : b.createdAt.getTime() - a.createdAt.getTime();
    });
  };

  // Real-time listener for first page
  useEffect(() => {
    if (!videoId || videoId === '_fallback') return;
    const colRef = collection(db, 'videos', videoId, 'comments');
    const q = query(colRef, orderBy(sort === 'top' ? 'likeCount' : 'createdAt', 'desc'), limit(PAGE_SIZE));
    const unsub = onSnapshot(q, (snap) => {
      setComments(sortTopLevel(snap.docs.map(mapDoc)));
      setLastDoc(snap.docs[snap.docs.length - 1] ?? null);
      setHasMore(snap.docs.length === PAGE_SIZE);
    });
    return () => unsub();
  }, [videoId, sort]); // eslint-disable-line react-hooks/exhaustive-deps

  const loadMore = async () => {
    if (!lastDoc || loadingMore) return;
    setLoadingMore(true);
    try {
      const colRef = collection(db, 'videos', videoId, 'comments');
      const q = query(colRef, orderBy(sort === 'top' ? 'likeCount' : 'createdAt', 'desc'), startAfter(lastDoc), limit(PAGE_SIZE));
      const snap = await getDocs(q);
      const more = snap.docs.map(mapDoc).filter((c) => !c.parentCommentId);
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
    const parentId = replyingTo?.id ?? null;

    setSubmitting(true);
    try {
      if (!currentUser) throw new Error('Authentication required');
      const colRef = collection(db, 'videos', videoId, 'comments');
      const commentRef = doc(colRef);
      const batch = writeBatch(db);
      batch.set(commentRef, {
        userId, displayName, avatarURL, text,
        createdAt: serverTimestamp(),
        likeCount: 0, replyCount: 0, isPinned: false, creatorHearted: false,
        parentCommentId: parentId,
      });
      appendVideoEngagement(batch, videoId, 'comment', { sessionId: commentRef.id });
      await batch.commit();
      if (parentId) {
        window.dispatchEvent(new CustomEvent('mychannel:comment-thread-refresh', { detail: { parentId } }));
      }
      setCommentText('');
      setReplyingTo(null);
      setCommentCount((n) => n + 1);
    } catch (err) {
      console.error('Failed to post comment:', err);
    } finally {
      setSubmitting(false);
    }
  };

  const handleReply = (parentId: string, name: string) => {
    setReplyingTo({ id: parentId, name });
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
            className="flex items-center gap-1.5 px-3 py-1.5 text-[13px] font-medium text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors"
            onClick={() => setSortMenuOpen((v) => !v)}
            aria-haspopup="menu"
            aria-expanded={sortMenuOpen}
          >
            <ChevronDown size={16} />
            Sort by
          </button>
          {sortMenuOpen && (
            <div role="menu" className="absolute right-0 top-10 w-44 bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] rounded-xl shadow-xl py-1.5 z-50">
              {([['top', 'Top comments'], ['new', 'Newest first']] as const).map(([val, label]) => (
                <button
                  key={val}
                  onClick={() => { setSort(val); setSortMenuOpen(false); }}
                  className="w-full flex items-center justify-between px-4 py-2 text-[13px] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]"
                >
                  {label}
                  {sort === val && <Check size={14} className="text-[rgb(var(--color-primary))]" />}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Reply indicator */}
      {replyingTo && (
        <div className="flex items-center gap-2 text-[12px] text-[rgb(var(--color-text-secondary))] bg-[rgb(var(--color-surface))] px-3 py-1.5 rounded-lg">
          <Reply size={13} />
          Replying to <span className="font-medium text-[rgb(var(--color-primary))]">@{replyingTo.name}</span>
          <button onClick={() => { setReplyingTo(null); setCommentText(''); }} className="ml-auto text-[rgb(var(--color-text-tertiary))] hover:text-[rgb(var(--color-text-primary))]">✕</button>
        </div>
      )}

      {/* Composer */}
      <div className="flex gap-3">
        <img src={avatarSrc} alt="Your avatar" className="w-10 h-10 rounded-full flex-shrink-0" />
        <div className="flex-1">
          <textarea
            ref={textareaRef}
            value={commentText}
            onChange={(e) => setCommentText(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) handleSubmit(); }}
            placeholder="Add a comment..."
            className="w-full px-0 py-2 bg-transparent text-sm text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] border-b border-[rgb(var(--color-border))] focus:border-[rgb(var(--color-primary))] outline-none resize-none"
            rows={1}
          />
          {commentText && (
            <div className="flex items-center justify-end gap-2 mt-2">
              <button onClick={() => { setCommentText(''); setReplyingTo(null); }} className="px-4 py-2 text-sm font-medium text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">Cancel</button>
              <button onClick={handleSubmit} disabled={submitting} className="px-4 py-2 text-sm font-medium bg-[rgb(var(--color-primary))] text-white rounded-full hover:opacity-90 disabled:opacity-50 transition-opacity">
                {submitting ? 'Posting…' : 'Comment'}
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Comments list */}
      <div className="space-y-5 mt-4">
        {comments.length === 0 ? (
          <p className="text-center text-sm text-[rgb(var(--color-text-secondary))] py-8">Be the first to comment</p>
        ) : (
          comments.map((c) => (
            <CommentRow key={c.id} comment={c} videoId={videoId} creatorId={creatorId} onReply={handleReply} />
          ))
        )}
      </div>

      {/* Load more */}
      {hasMore && comments.length > 0 && (
        <button onClick={loadMore} disabled={loadingMore} className="w-full py-2 text-sm font-medium text-[rgb(var(--color-primary))] hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors disabled:opacity-50">
          {loadingMore ? 'Loading…' : 'Show more comments'}
        </button>
      )}
    </div>
  );
};

export default CommentSection;
