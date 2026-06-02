# File Safety & Destructive-Action Rules

This is a large, valuable codebase where multiple people and AIs work in parallel. Protecting existing work is the top priority.

## Never Delete Without Explicit Confirmation
- Do not delete source files (`.swift`, `.ts`, `.tsx`, `.js`, `.mjs`), config files (`.json`, `.yaml`, `.yml`), or Xcode project files (`.xcodeproj`, `.pbxproj`) without the user explicitly asking.
- Be especially careful with these directories:
  - `MyChannel/Core/`, `MyChannel/Features/`, `MyChannel/App/`
  - `MyChannel.xcodeproj/`
  - `web-v2/app/`, `web-v2/components/`, `web-v2/lib/`
  - `services/`, `functions/`, `cloud-functions/`, `firebase/`
  - `.github/`
- Critical files to never delete: `MyChannel/App/MyChannelApp.swift`, `MyChannel/Core/Config/AppConfig.swift`, `MyChannel/Core/Config/AppSecrets.swift`, `MyChannel/Core/Theme/AppTheme.swift`, `MyChannel.xcodeproj/project.pbxproj`, `web-v2/package.json`, `web-v2/next.config.ts`, `firebase.json`, `firestore.rules`, `.swiftlint.yml`.

## Never Run Destructive Commands Without Approval
- No `rm -rf`, `git reset --hard`, `git clean -fd`, `git push --force`, or `find ... -delete`.
- No bulk file moves or mass renames without confirming first.
- If a command could delete or overwrite multiple files, stop and ask.

## Safe Editing Defaults
- Prefer targeted string replacement over full-file rewrites for existing files. Full overwrites risk clobbering parallel changes.
- Re-read a file immediately before editing it — another AI/session may have changed it.
- Preserve existing imports and code. Add, don't replace, unless the task is explicitly a rewrite.
- Verify a file exists and check its current content before editing.

## If a File Is Accidentally Lost
1. Stop immediately.
2. Recover with `git restore <path>` or `git checkout HEAD -- <path>`.
3. Tell the user what happened.

## Note on AppleDouble Files
This repo contains many `._*` files (macOS AppleDouble metadata). Ignore them — never edit them, and don't treat them as real source. The real file is the one without the `._` prefix.
