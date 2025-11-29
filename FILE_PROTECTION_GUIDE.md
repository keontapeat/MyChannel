# 🛡️🔥 MYCHANNEL NUCLEAR FILE PROTECTION GUIDE 🔥🛡️

## Your Files Are Now BULLETPROOF! 💪

This guide explains all the protection systems in place to prevent AI/Cursor from accidentally deleting your files.

---

## 🛡️ Protection Systems Active

### 1. Git Pre-Commit Hook
**Location:** `.git/hooks/pre-commit`

**What it does:**
- ✅ Blocks commits that delete critical files
- ✅ Blocks mass deletions (>5 files)
- ✅ Blocks deletion of multiple Swift files (>2)
- ✅ Warns about any source file deletions

**Protected directories:**
- `MyChannel/Core/`
- `MyChannel/Features/`
- `MyChannel/App/`
- `MyChannel.xcodeproj/`
- `web-v2/app/`
- `web-v2/components/`
- `web-v2/lib/`
- `services/`
- `firebase/`

**Bypass (use with EXTREME caution):**
```bash
git commit --no-verify
```

---

### 2. Cursor Rules
**Location:** `.cursorrules`

**What it does:**
- ✅ Tells AI to NEVER use Delete tool
- ✅ Tells AI to use StrReplace (not Write) for edits
- ✅ Lists all protected files and directories
- ✅ Provides safe command guidelines

---

### 3. Nuclear Backup System
**Location:** `scripts/nuclear-backup.sh`

**What it does:**
- ✅ Creates timestamped backup of entire project
- ✅ Keeps last 10 backups automatically
- ✅ Creates restore script for each backup
- ✅ Generates file manifest

**Run before AI sessions:**
```bash
./scripts/nuclear-backup.sh
```

**Backups stored at:**
```
/Users/keonta/Documents/MyChannel-Backups/
```

---

### 4. File Recovery Tool
**Location:** `scripts/recover-deleted.sh`

**What it does:**
- ✅ Shows all deleted files
- ✅ Provides recovery commands
- ✅ Lists available backups
- ✅ Step-by-step recovery guide

**Run if something goes wrong:**
```bash
./scripts/recover-deleted.sh
```

---

### 5. Pre/Post AI Session Scripts

**Before AI session:**
```bash
./scripts/pre-ai-session.sh
```
- Creates backup
- Counts files
- Verifies protection

**After AI session:**
```bash
./scripts/post-ai-session.sh
```
- Checks for deleted files
- Compares file counts
- Verifies critical files

---

### 6. File Watchdog (Optional)
**Location:** `scripts/file-watchdog.sh`

**What it does:**
- ✅ Real-time monitoring for deletions
- ✅ macOS notifications on file deletion
- ✅ Logs all deletions

**Run in background:**
```bash
./scripts/file-watchdog.sh &
```

---

## 🚀 Quick Commands

### Recovery
```bash
# Restore single file
git restore path/to/file.swift

# Restore staged file
git restore --staged path/to/file.swift

# Restore all files to last commit
git checkout HEAD -- .

# Find when file was deleted
git log --all --full-history -- path/to/file.swift

# Restore from specific commit
git checkout abc1234 -- path/to/file.swift
```

### Backup
```bash
# Create backup
./scripts/nuclear-backup.sh

# View backups
ls -la ~/Documents/MyChannel-Backups/

# Restore from backup
~/Documents/MyChannel-Backups/backup_XXXXXXXX/RESTORE.sh
```

### Session Management
```bash
# Before coding with AI
./scripts/pre-ai-session.sh

# After coding with AI
./scripts/post-ai-session.sh
```

---

## 📋 Protection Checklist

Before every AI coding session:
- [ ] Run `./scripts/pre-ai-session.sh`
- [ ] Verify backup was created
- [ ] Note current file counts

After every AI coding session:
- [ ] Run `./scripts/post-ai-session.sh`
- [ ] Check for any deleted files
- [ ] Verify file counts match

If files were deleted:
- [ ] Run `./scripts/recover-deleted.sh`
- [ ] Use `git restore` to recover
- [ ] Or restore from backup

---

## 🔥 Why Files Get Deleted

Common causes of accidental deletions:
1. **AI uses Write instead of StrReplace** - Overwrites file
2. **AI misunderstands request** - Deletes "old" code
3. **AI runs rm commands** - Direct deletion
4. **Build errors** - AI tries to "fix" by deleting
5. **Refactoring gone wrong** - Moves then loses files

---

## 🛡️ How We Prevent This

1. **Pre-commit hook** - Last line of defense before commit
2. **Cursor rules** - AI knows not to delete
3. **Regular backups** - Always have recovery option
4. **File monitoring** - Know when something is deleted
5. **Session scripts** - Before/after checks

---

## 📞 Emergency Recovery

If everything goes wrong:

1. **Check git reflog:**
```bash
git reflog
git checkout <commit-hash>
```

2. **Restore from backup:**
```bash
ls ~/Documents/MyChannel-Backups/
# Find most recent backup
~/Documents/MyChannel-Backups/backup_XXXXXXXX/RESTORE.sh
```

3. **Clone fresh from remote:**
```bash
cd ..
mv MyChannel MyChannel-broken
git clone <your-repo-url>
```

---

## 🔥 YOU'RE PROTECTED! GO BUILD! 🔥

Your files are now protected by multiple layers of defense:
- ✅ Git hooks
- ✅ Cursor rules
- ✅ Automatic backups
- ✅ Recovery tools
- ✅ Session monitoring

**NO MORE ACCIDENTAL DELETIONS!** 💪🔥

