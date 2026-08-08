'use client';

// Community Tab — YouTube parity
// Supports text posts, image posts, polls, and link posts from creators
// Viewers can like and comment on posts

import { useState, useEffect, useRef } from 'react';
import {
  Image as ImageIcon, BarChart2, Link as LinkIcon, X, ThumbsUp,
  MessageSquare, Share2, MoreVertical, ChevronLeft, Loader2,
} from 'lucide-react';
import Link from 'next/link';
import {
  collection, query, orderBy, limit, getDoc, getDocs, addDoc, setDoc,
  deleteDoc, doc, serverTimestamp, onSnapshot,
  startAfter, type QueryDocumentSnapshot, type DocumentData,
} from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';
import { StorageService } from '@/lib/firebase/storage';

type PostType = 'text' | 'image' | 'poll' | 'link';

interface PollOption {
  text: string;
  votes: number;
}

interface CommunityPost {
  id: string;
  creatorId: string;
  creatorName: string;
  creatorAvatar: string;
  isVerified: boolean;
  type: PostType;
  text: string;
  imageURL?: string;
  linkURL?: string;
  linkTitle?: string;
  poll?: PollOption[];
  userVoteIndex?: number;
  likeCount: number;
  commentCount: number;
  isLiked: boolean;
  createdAt: Date;
}

const PAGE_SIZE = 12;

function timeAgo(date: Date): string {
  const secs = Math.floor((Date.now() - date.getTime()) / 1000);
  if (secs < 60) return `${secs}s ago`;
  if (secs < 3600) return `${Math.floor(secs / 60)}m ago`;
  if (secs < 86400) return `${Math.floor(secs / 3600)}h ago`;
  if (secs < 604800) return `${Math.floor(secs / 86400)}d ago`;
  return date.toLocaleDateString();
}

async function hydrateCommunityState(
  items: CommunityPost[],
  userId: string | undefined,
): Promise<CommunityPost[]> {
  if (!userId) return items;
  return Promise.all(items.map(async (post) => {
    try {
      const [like, vote] = await Promise.all([
        getDoc(doc(db, 'communityPosts', post.id, 'likes', userId)),
        post.poll
          ? getDoc(doc(db, 'communityPosts', post.id, 'votes', userId))
          : Promise.resolve(null),
      ]);
      const optionIndex = vote?.data()?.optionIndex;
      return {
        ...post,
        isLiked: like.exists(),
        userVoteIndex: Number.isInteger(optionIndex) ? optionIndex : undefined,
      };
    } catch {
      return post;
    }
  }));
}

function PollWidget({
  options,
  userVoteIndex,
  onVote,
}: {
  options: PollOption[];
  userVoteIndex?: number;
  onVote: (index: number) => void;
}) {
  const totalVotes = options.reduce((s, o) => s + o.votes, 0);
  const hasVoted = userVoteIndex !== undefined;

  return (
    <div className="mt-3 space-y-2">
      {options.map((opt, i) => {
        const pct = totalVotes > 0 ? Math.round((opt.votes / totalVotes) * 100) : 0;
        return (
          <button
            key={i}
            onClick={() => !hasVoted && onVote(i)}
            disabled={hasVoted}
            className={`relative w-full text-left px-4 py-2.5 rounded-full border text-[13px] font-medium overflow-hidden transition-all ${
              hasVoted
                ? userVoteIndex === i
                  ? 'border-[rgb(var(--color-primary))] text-[rgb(var(--color-primary))]'
                  : 'border-[rgb(var(--color-border))] text-[rgb(var(--color-text-primary))]'
                : 'border-[rgb(var(--color-border))] text-[rgb(var(--color-text-primary))] hover:border-[rgb(var(--color-primary))] hover:bg-[rgb(var(--color-surface-hover))]'
            }`}
          >
            {hasVoted && (
              <div
                className="absolute inset-y-0 left-0 bg-[rgb(var(--color-primary))]/10 rounded-full transition-all"
                style={{ width: `${pct}%` }}
              />
            )}
            <span className="relative flex items-center justify-between">
              <span>{opt.text}</span>
              {hasVoted && <span className="text-[12px] font-bold">{pct}%</span>}
            </span>
          </button>
        );
      })}
      {hasVoted && (
        <p className="text-[11px] text-[rgb(var(--color-text-tertiary))] text-right">
          {totalVotes.toLocaleString()} vote{totalVotes !== 1 ? 's' : ''}
        </p>
      )}
    </div>
  );
}

function PostCard({
  post,
  onLike,
  onVote,
  onDelete,
}: {
  post: CommunityPost;
  onLike: (id: string) => void;
  onVote: (id: string, index: number) => void;
  onDelete: (id: string) => void;
}) {
  const [showMenu, setShowMenu] = useState(false);
  const uid = auth?.currentUser?.uid;

  return (
    <div className="bg-[rgb(var(--color-surface))] rounded-2xl border border-[rgb(var(--color-border))] p-4">
      {/* Header */}
      <div className="flex items-center gap-3 mb-3">
        <img
          src={post.creatorAvatar || `https://i.pravatar.cc/150?u=${post.creatorId}`}
          alt={post.creatorName}
          className="w-10 h-10 rounded-full"
        />
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-1.5">
            <Link
              href={`/profile/${post.creatorId}`}
              className="text-[14px] font-semibold text-[rgb(var(--color-text-primary))] hover:underline truncate"
            >
              {post.creatorName}
            </Link>
            {post.isVerified && (
              <span className="text-[rgb(var(--color-text-secondary))]" title="Verified">✓</span>
            )}
          </div>
          <p className="text-[12px] text-[rgb(var(--color-text-tertiary))]">{timeAgo(post.createdAt)}</p>
        </div>
        <div className="relative">
          <button
            onClick={() => setShowMenu((v) => !v)}
            className="p-1.5 hover:bg-[rgb(var(--color-surface-hover))] rounded-full"
            aria-label="Post options"
          >
            <MoreVertical size={16} className="text-[rgb(var(--color-text-secondary))]" />
          </button>
          {showMenu && (
            <>
              <div className="fixed inset-0 z-10" onClick={() => setShowMenu(false)} />
              <div className="absolute right-0 top-8 z-20 w-36 bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] rounded-xl shadow-xl overflow-hidden">
                {uid === post.creatorId && (
                  <button
                    onClick={() => { onDelete(post.id); setShowMenu(false); }}
                    className="flex items-center gap-2 w-full px-3 py-2.5 text-[13px] text-red-500 hover:bg-red-50 dark:hover:bg-red-900/10"
                  >
                    <X size={14} /> Delete
                  </button>
                )}
                <button
                  onClick={() => {
                    navigator.clipboard?.writeText(`${window.location.origin}/community`);
                    setShowMenu(false);
                  }}
                  className="flex items-center gap-2 w-full px-3 py-2.5 text-[13px] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]"
                >
                  <Share2 size={14} /> Copy link
                </button>
              </div>
            </>
          )}
        </div>
      </div>

      {/* Content */}
      <p className="text-[14px] text-[rgb(var(--color-text-primary))] leading-relaxed whitespace-pre-wrap">
        {post.text}
      </p>

      {/* Image */}
      {post.imageURL && (
        <div className="mt-3 rounded-xl overflow-hidden max-h-[400px]">
          <img src={post.imageURL} alt="Post image" className="w-full object-cover" />
        </div>
      )}

      {/* Link preview */}
      {post.linkURL && (
        <a
          href={post.linkURL}
          target="_blank"
          rel="noopener noreferrer"
          className="mt-3 flex items-center gap-3 p-3 rounded-xl border border-[rgb(var(--color-border))] hover:bg-[rgb(var(--color-surface-hover))] transition-colors"
        >
          <LinkIcon size={16} className="text-[rgb(var(--color-primary))] flex-shrink-0" />
          <div className="min-w-0">
            <p className="text-[13px] font-medium text-[rgb(var(--color-text-primary))] truncate">
              {post.linkTitle || post.linkURL}
            </p>
            <p className="text-[11px] text-[rgb(var(--color-text-tertiary))] truncate">{post.linkURL}</p>
          </div>
        </a>
      )}

      {/* Poll */}
      {post.poll && (
        <PollWidget
          options={post.poll}
          userVoteIndex={post.userVoteIndex}
          onVote={(i) => onVote(post.id, i)}
        />
      )}

      {/* Actions */}
      <div className="flex items-center gap-1 mt-3 pt-3 border-t border-[rgb(var(--color-border))]">
        <button
          onClick={() => onLike(post.id)}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[13px] font-medium transition-all hover:bg-[rgb(var(--color-surface-hover))] ${
            post.isLiked ? 'text-[rgb(var(--color-primary))]' : 'text-[rgb(var(--color-text-secondary))]'
          }`}
          aria-label="Like post"
        >
          <ThumbsUp size={15} fill={post.isLiked ? 'currentColor' : 'none'} />
          {post.likeCount > 0 && post.likeCount.toLocaleString()}
        </button>
        <button className="flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[13px] font-medium text-[rgb(var(--color-text-secondary))] hover:bg-[rgb(var(--color-surface-hover))] transition-all">
          <MessageSquare size={15} />
          {post.commentCount > 0 && post.commentCount}
        </button>
      </div>
    </div>
  );
}

// Composer for creating new posts
function PostComposer({ onPosted }: { onPosted: () => void }) {
  const [mode, setMode] = useState<PostType>('text');
  const [text, setText] = useState('');
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState('');
  const [linkURL, setLinkURL] = useState('');
  const [linkTitle, setLinkTitle] = useState('');
  const [pollOptions, setPollOptions] = useState(['', '']);
  const [submitting, setSubmitting] = useState(false);
  const imageRef = useRef<HTMLInputElement>(null);
  const uid = auth?.currentUser?.uid;
  const user = auth?.currentUser;

  if (!uid) {
    return (
      <div className="bg-[rgb(var(--color-surface))] rounded-2xl border border-[rgb(var(--color-border))] p-4 text-center">
        <p className="text-[13px] text-[rgb(var(--color-text-secondary))] mb-3">Sign in to post to the community</p>
        <Link href="/login" className="px-4 py-2 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full hover:opacity-90">
          Sign in
        </Link>
      </div>
    );
  }

  const handleImage = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (!f) return;
    setImageFile(f);
    setImagePreview(URL.createObjectURL(f));
    setMode('image');
  };

  const addPollOption = () => {
    if (pollOptions.length < 5) setPollOptions([...pollOptions, '']);
  };

  const removePollOption = (i: number) => {
    setPollOptions(pollOptions.filter((_, idx) => idx !== i));
  };

  const handleSubmit = async () => {
    if (!text.trim() && mode !== 'poll') return;
    if (mode === 'poll' && pollOptions.filter((o) => o.trim()).length < 2) return;
    setSubmitting(true);

    try {
      let imageURL = '';
      if (imageFile) {
        if (!uid) {
          console.error('Cannot upload community image without an authenticated user');
          setSubmitting(false);
          return;
        }
        imageURL = await StorageService.uploadThumbnail(imageFile, uid, `community_${Date.now()}`);
      }

      const postData: Record<string, any> = {
        creatorId: uid,
        creatorName: user?.displayName ?? 'Creator',
        creatorAvatar: user?.photoURL ?? '',
        isVerified: false,
        type: mode,
        text: text.trim(),
        likeCount: 0,
        commentCount: 0,
        createdAt: serverTimestamp(),
      };

      if (mode === 'image' && imageURL) postData.imageURL = imageURL;
      if (mode === 'link') {
        postData.linkURL = linkURL.trim();
        postData.linkTitle = linkTitle.trim();
      }
      if (mode === 'poll') {
        postData.poll = pollOptions
          .filter((o) => o.trim())
          .map((o) => ({ text: o.trim(), votes: 0 }));
      }

      await addDoc(collection(db, 'communityPosts'), postData);

      setText('');
      setImageFile(null);
      setImagePreview('');
      setLinkURL('');
      setLinkTitle('');
      setPollOptions(['', '']);
      setMode('text');
      onPosted();
    } catch (err) {
      console.error('Failed to post:', err);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="bg-[rgb(var(--color-surface))] rounded-2xl border border-[rgb(var(--color-border))] p-4">
      <div className="flex gap-3">
        <img
          src={user?.photoURL || `https://i.pravatar.cc/150?u=${uid}`}
          alt="You"
          className="w-10 h-10 rounded-full flex-shrink-0"
        />
        <div className="flex-1">
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Share something with your community…"
            rows={3}
            className="w-full bg-transparent text-[14px] text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] border-b border-[rgb(var(--color-border))] focus:border-[rgb(var(--color-primary))] outline-none resize-none pb-2"
          />

          {/* Image preview */}
          {imagePreview && (
            <div className="relative mt-2 inline-block">
              <img src={imagePreview} alt="Preview" className="max-h-48 rounded-xl" />
              <button
                onClick={() => { setImageFile(null); setImagePreview(''); setMode('text'); }}
                className="absolute top-1 right-1 w-6 h-6 bg-black/70 rounded-full flex items-center justify-center"
              >
                <X size={12} className="text-white" />
              </button>
            </div>
          )}

          {/* Link fields */}
          {mode === 'link' && (
            <div className="mt-2 space-y-2">
              <input
                type="url"
                value={linkURL}
                onChange={(e) => setLinkURL(e.target.value)}
                placeholder="https://..."
                className="w-full px-3 py-2 bg-[rgb(var(--color-surface-hover))] border border-[rgb(var(--color-border))] rounded-lg text-[13px] text-[rgb(var(--color-text-primary))] outline-none focus:border-[rgb(var(--color-primary))]"
              />
              <input
                type="text"
                value={linkTitle}
                onChange={(e) => setLinkTitle(e.target.value)}
                placeholder="Link title (optional)"
                className="w-full px-3 py-2 bg-[rgb(var(--color-surface-hover))] border border-[rgb(var(--color-border))] rounded-lg text-[13px] text-[rgb(var(--color-text-primary))] outline-none focus:border-[rgb(var(--color-primary))]"
              />
            </div>
          )}

          {/* Poll fields */}
          {mode === 'poll' && (
            <div className="mt-2 space-y-2">
              {pollOptions.map((opt, i) => (
                <div key={i} className="flex items-center gap-2">
                  <input
                    type="text"
                    value={opt}
                    onChange={(e) => {
                      const next = [...pollOptions];
                      next[i] = e.target.value;
                      setPollOptions(next);
                    }}
                    placeholder={`Option ${i + 1}`}
                    className="flex-1 px-3 py-2 bg-[rgb(var(--color-surface-hover))] border border-[rgb(var(--color-border))] rounded-full text-[13px] text-[rgb(var(--color-text-primary))] outline-none focus:border-[rgb(var(--color-primary))]"
                  />
                  {pollOptions.length > 2 && (
                    <button onClick={() => removePollOption(i)} className="text-[rgb(var(--color-text-tertiary))] hover:text-red-500">
                      <X size={14} />
                    </button>
                  )}
                </div>
              ))}
              {pollOptions.length < 5 && (
                <button
                  onClick={addPollOption}
                  className="text-[12px] text-[rgb(var(--color-primary))] font-medium hover:underline"
                >
                  + Add option
                </button>
              )}
            </div>
          )}

          {/* Toolbar */}
          <div className="flex items-center justify-between mt-3">
            <div className="flex items-center gap-1">
              <button
                onClick={() => imageRef.current?.click()}
                className={`p-2 rounded-full transition-colors ${mode === 'image' ? 'text-[rgb(var(--color-primary))] bg-[rgb(var(--color-primary))]/10' : 'text-[rgb(var(--color-text-secondary))] hover:bg-[rgb(var(--color-surface-hover))]'}`}
                title="Add image"
              >
                <ImageIcon size={18} />
              </button>
              <button
                onClick={() => setMode(mode === 'poll' ? 'text' : 'poll')}
                className={`p-2 rounded-full transition-colors ${mode === 'poll' ? 'text-[rgb(var(--color-primary))] bg-[rgb(var(--color-primary))]/10' : 'text-[rgb(var(--color-text-secondary))] hover:bg-[rgb(var(--color-surface-hover))]'}`}
                title="Create poll"
              >
                <BarChart2 size={18} />
              </button>
              <button
                onClick={() => setMode(mode === 'link' ? 'text' : 'link')}
                className={`p-2 rounded-full transition-colors ${mode === 'link' ? 'text-[rgb(var(--color-primary))] bg-[rgb(var(--color-primary))]/10' : 'text-[rgb(var(--color-text-secondary))] hover:bg-[rgb(var(--color-surface-hover))]'}`}
                title="Add link"
              >
                <LinkIcon size={18} />
              </button>
              <input ref={imageRef} type="file" accept="image/*" onChange={handleImage} className="hidden" />
            </div>
            <button
              onClick={handleSubmit}
              disabled={submitting || (!text.trim() && mode !== 'poll')}
              className="flex items-center gap-2 px-4 py-2 bg-[rgb(var(--color-primary))] text-white text-[13px] font-semibold rounded-full hover:opacity-90 disabled:opacity-50 transition-opacity"
            >
              {submitting && <Loader2 size={13} className="animate-spin" />}
              Post
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function CommunityPageClient() {
  const [posts, setPosts] = useState<CommunityPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [lastDoc, setLastDoc] = useState<QueryDocumentSnapshot<DocumentData> | null>(null);
  const [hasMore, setHasMore] = useState(true);
  const [refresh, setRefresh] = useState(0);
  const uid = auth?.currentUser?.uid;

  const toPost = (d: any, id: string): CommunityPost => ({
    id,
    creatorId: d.creatorId ?? '',
    creatorName: d.creatorName ?? 'Creator',
    creatorAvatar: d.creatorAvatar ?? '',
    isVerified: d.isVerified ?? false,
    type: d.type ?? 'text',
    text: d.text ?? '',
    imageURL: d.imageURL,
    linkURL: d.linkURL,
    linkTitle: d.linkTitle,
    poll: d.poll,
    userVoteIndex: undefined,
    likeCount: d.likeCount ?? 0,
    commentCount: d.commentCount ?? 0,
    isLiked: false,
    createdAt: d.createdAt?.toDate?.() ?? new Date(),
  });

  useEffect(() => {
    let active = true;
    setLoading(true);
    const q = query(
      collection(db, 'communityPosts'),
      orderBy('createdAt', 'desc'),
      limit(PAGE_SIZE)
    );
    const unsub = onSnapshot(q, async (snap) => {
      const mapped = snap.docs.map((d) => toPost(d.data(), d.id));
      const hydrated = await hydrateCommunityState(mapped, uid);
      if (!active) return;
      setPosts(hydrated);
      setLastDoc(snap.docs[snap.docs.length - 1] ?? null);
      setHasMore(snap.docs.length === PAGE_SIZE);
      setLoading(false);
    });
    return () => {
      active = false;
      unsub();
    };
  }, [refresh, uid]);

  const loadMore = async () => {
    if (!lastDoc || loadingMore) return;
    setLoadingMore(true);
    try {
      const q = query(
        collection(db, 'communityPosts'),
        orderBy('createdAt', 'desc'),
        startAfter(lastDoc),
        limit(PAGE_SIZE)
      );
      const snap = await getDocs(q);
      const mapped = snap.docs.map((d) => toPost(d.data(), d.id));
      const hydrated = await hydrateCommunityState(mapped, uid);
      setPosts((prev) => [...prev, ...hydrated]);
      setLastDoc(snap.docs[snap.docs.length - 1] ?? null);
      setHasMore(snap.docs.length === PAGE_SIZE);
    } finally {
      setLoadingMore(false);
    }
  };

  const handleLike = async (postId: string) => {
    if (!uid) return;
    const current = posts.find((post) => post.id === postId);
    if (!current) return;
    const nextLiked = !current.isLiked;

    setPosts((prev) => prev.map((post) =>
      post.id === postId
        ? {
            ...post,
            isLiked: nextLiked,
            likeCount: Math.max(0, post.likeCount + (nextLiked ? 1 : -1)),
          }
        : post
    ));

    const likeRef = doc(db, 'communityPosts', postId, 'likes', uid);
    try {
      if (nextLiked) {
        await setDoc(likeRef, {userId: uid, likedAt: serverTimestamp()});
      } else {
        await deleteDoc(likeRef);
      }
    } catch {
      setPosts((prev) => prev.map((post) =>
        post.id === postId
          ? {
              ...post,
              isLiked: !nextLiked,
              likeCount: Math.max(0, post.likeCount + (nextLiked ? -1 : 1)),
            }
          : post
      ));
    }
  };

  const handleVote = async (postId: string, optionIndex: number) => {
    if (!uid) return;
    const current = posts.find((post) => post.id === postId);
    if (!current?.poll || current.userVoteIndex !== undefined ||
        optionIndex < 0 || optionIndex >= current.poll.length) return;

    setPosts((prev) =>
      prev.map((post) => {
        if (post.id !== postId || !post.poll || post.userVoteIndex !== undefined) return post;
        const poll = post.poll.map((option, index) => ({
          ...option,
          votes: index === optionIndex ? option.votes + 1 : option.votes,
        }));
        return {...post, poll, userVoteIndex: optionIndex};
      })
    );

    try {
      await setDoc(doc(db, 'communityPosts', postId, 'votes', uid), {
        optionIndex,
        votedAt: serverTimestamp(),
      });
    } catch {
      setPosts((prev) => prev.map((post) => {
        if (post.id !== postId || !post.poll || post.userVoteIndex !== optionIndex) return post;
        const poll = post.poll.map((option, index) => ({
          ...option,
          votes: index === optionIndex ? Math.max(0, option.votes - 1) : option.votes,
        }));
        return {...post, poll, userVoteIndex: undefined};
      }));
    }
  };

  const handleDelete = async (postId: string) => {
    if (!confirm('Delete this post?')) return;
    try {
      await deleteDoc(doc(db, 'communityPosts', postId));
      setPosts((prev) => prev.filter((p) => p.id !== postId));
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))] pt-14">
      <div className="max-w-[640px] mx-auto px-4 py-6 pb-24">
        {/* Header */}
        <div className="flex items-center gap-3 mb-6">
          <Link href="/" className="p-2 hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors">
            <ChevronLeft size={20} className="text-[rgb(var(--color-text-primary))]" />
          </Link>
          <div>
            <h1 className="text-[20px] font-bold text-[rgb(var(--color-text-primary))]">Community</h1>
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">Posts from creators you follow</p>
          </div>
        </div>

        {/* Composer */}
        <div className="mb-5">
          <PostComposer onPosted={() => setRefresh((r) => r + 1)} />
        </div>

        {/* Feed */}
        {loading ? (
          <div className="space-y-4">
            {[...Array(3)].map((_, i) => (
              <div key={i} className="h-48 bg-[rgb(var(--color-surface))] rounded-2xl animate-pulse" />
            ))}
          </div>
        ) : posts.length === 0 ? (
          <div className="text-center py-20">
            <MessageSquare size={44} className="mx-auto mb-3 text-[rgb(var(--color-text-tertiary))]" />
            <p className="text-[15px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">No posts yet</p>
            <p className="text-[13px] text-[rgb(var(--color-text-secondary))]">Follow creators to see their community posts</p>
          </div>
        ) : (
          <div className="space-y-4">
            {posts.map((post) => (
              <PostCard
                key={post.id}
                post={post}
                onLike={handleLike}
                onVote={handleVote}
                onDelete={handleDelete}
              />
            ))}
            {hasMore && (
              <button
                onClick={loadMore}
                disabled={loadingMore}
                className="w-full py-3 text-[13px] font-medium text-[rgb(var(--color-primary))] hover:bg-[rgb(var(--color-surface-hover))] rounded-full disabled:opacity-50 flex items-center justify-center gap-2"
              >
                {loadingMore && <Loader2 size={14} className="animate-spin" />}
                {loadingMore ? 'Loading…' : 'Show more'}
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
