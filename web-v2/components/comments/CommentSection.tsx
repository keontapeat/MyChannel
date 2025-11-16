'use client';

import { useState } from 'react';
import { MessageSquare } from 'lucide-react';
import { formatViewCount } from '@/lib/utils/format';

interface CommentSectionProps {
  videoId: string;
  commentCount: number;
}

const CommentSection = ({ videoId, commentCount }: CommentSectionProps) => {
  const [commentText, setCommentText] = useState('');

  return (
    <div className="space-y-4">
      <h3 className="text-lg font-semibold text-[rgb(var(--color-text-primary))] flex items-center gap-2">
        <MessageSquare size={20} />
        {formatViewCount(commentCount)} Comments
      </h3>

      {/* Comment Input */}
      <div className="flex gap-3">
        <img
          src="https://i.pravatar.cc/150?img=2"
          alt="Your avatar"
          className="w-10 h-10 rounded-full flex-shrink-0"
        />

        <div className="flex-1">
          <textarea
            value={commentText}
            onChange={(e) => setCommentText(e.target.value)}
            placeholder="Add a comment..."
            className="w-full px-0 py-2 bg-transparent text-sm text-[rgb(var(--color-text-primary))] placeholder:text-[rgb(var(--color-text-tertiary))] border-b border-[rgb(var(--color-border))] focus:border-[rgb(var(--color-primary))] outline-none resize-none"
            rows={1}
          />

          {commentText && (
            <div className="flex items-center justify-end gap-2 mt-2">
              <button
                onClick={() => setCommentText('')}
                className="px-4 py-2 text-sm font-medium text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] rounded-full transition-colors"
              >
                Cancel
              </button>
              <button className="btn-youtube">
                Comment
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Comments List */}
      <div className="space-y-4 mt-6">
        <div className="text-center text-sm text-[rgb(var(--color-text-secondary))] py-8">
          Comments will appear here
        </div>
      </div>
    </div>
  );
};

export default CommentSection;

