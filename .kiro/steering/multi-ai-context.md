# Multi-AI Working Context

**Heads up for every new chat:** The user runs multiple AI assistants at the same time across different chats/sessions, all working on this same workspace.

Keep this in mind without needing to be told:

- **Expect concurrent changes.** Files may be created, edited, or deleted by another AI while you work. Re-read a file right before editing it instead of trusting an earlier snapshot.
- **Watch for conflicts.** If something looks unexpectedly different from what you last saw (new files, changed code, moved logic), assume another assistant did it. Don't undo or overwrite their work without checking first.
- **Stay in your lane.** Make focused, scoped changes. Avoid broad refactors or sweeping deletions that could clobber work happening in parallel.
- **Verify before destructive actions.** Because others are active, double-check before deleting, force-pushing, or doing anything hard to reverse.
- **Don't assume you have full context.** Recent commits, files, or decisions may have come from another session. When in doubt, look at the current state of the repo rather than relying on memory.

No need to ask the user to confirm this setup each time. Just operate with the awareness that you're one of several AIs collaborating on this codebase.
