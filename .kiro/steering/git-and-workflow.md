# Git & Workflow Conventions

Because multiple AIs and sessions touch this repo, git discipline matters.

## Commits
- Only commit when the user explicitly asks. If it's unclear, ask first.
- Stage specific files rather than `git add .` — avoids sweeping up another session's unrelated changes.
- Flag any file that looks like it holds secrets before committing (`.ai_api_key`, `.env*`, anything under a secrets path, `*-config.js` with keys).
- Prefer new commits over `--amend`. Don't rewrite history that may already be pushed.

## Branches & Pushes
- Don't push directly to `main`/`master` unless explicitly asked. Push feature work to a new branch with `git push -u`.
- `git push --force`, `git reset --hard`, and `git clean -fd` require explicit user approval (see file-safety).

## Pull Requests
- Use the platform CLI (`gh pr create` for GitHub). Keep titles under ~70 chars; put detail in the body (summary, what was tested, anything blocked).

## Repo Hygiene
- This repo has a lot of historical clutter: hundreds of `*.md` status/"COMPLETE"/"NUCLEAR" reports, many `._*` AppleDouble files, and many `deploy-*.sh` scripts. Don't generate new status-report markdown files unless the user asks. Treat existing ones as possibly-stale notes, not ground truth.
- Don't run `deploy-*.sh` / `DEPLOY_*.sh` scripts on your own — they can hit production. Confirm first.

## Build / Test Commands
- iOS: SwiftLint via `.swiftlint.yml`. Don't run blocking Xcode/simulator builds in the agent — ask the user to run them.
- Web (`web-v2/`): `npm run lint`, `npm run build`. Don't start `npm run dev` as a blocking command.
- Services: check the relevant `package.json` for the test script; run the suite for the service you changed (e.g. `services/ads` has `test/*.test.mjs`). Prefer single-run over watch mode.

## Deploying Firebase (owner preference)
- The owner is the sole operator and is normally logged into the Firebase CLI (active project `mychannel-ca26d`). When the owner explicitly says to deploy / "get it live" / "ship it", deploy without re-asking for confirmation.
- Scope every deploy to only what changed. Use targeted `--only` flags, never a bare `firebase deploy`:
  - Rules/indexes: `firebase deploy --only firestore:rules,firestore:indexes`
  - Storage rules: `firebase deploy --only storage`
  - Hosting: `firebase deploy --only hosting`
  - Specific functions: `firebase deploy --only functions:<name>`
- Run from the repo root with `--non-interactive`. Verify `firebase use` shows the intended project first.
- Still NEVER auto-run the `deploy-*.sh` / `DEPLOY_*.sh` "NUCLEAR" scripts — those do broad/destructive things. Targeted `firebase deploy --only ...` is the approved path.
- After deploying rules, note any compiler warnings but trust a "released successfully" / "Deploy complete!" result.
