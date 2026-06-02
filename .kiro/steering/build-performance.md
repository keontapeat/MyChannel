---
inclusion: fileMatch
fileMatchPattern: '**/*.swift'
---

# Build Performance — Keep Compile Times Fast (YouTube-Senior Bar)

The iOS app is large (~2,600 Swift files, ~417k LOC). Clean builds are inherently
heavy, but the thing that wrecks the **edit → build → run** loop is a small number
of Swift expressions that take seconds (sometimes tens of seconds) to *type-check*.
One bad `body` getter can cost more than thousands of normal files combined.

This file is the standard for keeping builds fast. It applies to all Swift work.

## How To Measure (don't guess)

Fresh data beats stale reports. The repo has tooling for this:

```bash
# Full clean build with Swift timing flags, then ranked report:
scripts/measure_build_times.sh

# Faster incremental measurement:
scripts/measure_build_times.sh --no-clean

# Re-rank an existing xcodebuild log without rebuilding:
scripts/measure_build_times.sh --rank-only build_timing.log
python3 scripts/rank_slow_compiles.py full_build.log full_build2.log
```

Run `measure_build_times.sh` in a real terminal — it calls `xcodebuild`, which
blocks and must not run inside the agent. The Debug target already passes
`-warn-long-function-bodies=100` and `-warn-long-expression-type-checking=100`,
so any normal build log already contains `took NNNms to type-check` warnings the
ranking script can parse.

Note: `slow_build_warnings.txt` at the repo root is a **one-off snapshot and goes
stale fast** (many files change between sessions). Regenerate; don't trust it.

## The Patterns That Cause Slow Type-Checking

1. **Giant SwiftUI `body` getters.** A single `body` with dozens of chained
   modifiers / nested stacks forces the solver to type the whole tree at once.
   Fix: split into small `@ViewBuilder private var fooSection: some View` pieces
   (or `private func fooRow(...) -> some View`). This is the single biggest win.
2. **Long `??` optional-coalescing chains.** `a ?? b ?? c ?? d ?? e` inside a
   larger expression multiplies the overload search. Fix: pull it into a helper
   with an **explicit return type**, or assign to a typed local first.
3. **Large multi-argument initializers built inline** (e.g. `Video(...)`,
   `FreeMovie(...)`) combined with `.init` shorthand. Fix: use the explicit type
   name (`Video(...)` not `.init(...)`) and pre-type each computed argument in a
   `let` with an explicit type before the call.
4. **Chained generic closures** like `.map { ... }.compactMap { $0 }`. Fix:
   collapse to one `compactMap { ... }` and annotate the result type
   (`let xs: [Foo] = arr.compactMap { ... }`).
5. **Heavy ternaries / arithmetic in view modifiers** (colors, frames, opacities
   computed inline). Fix: precompute outside `body` (see `ios-swift` perf rules).

## Rules When Writing Swift

- Keep `body` small. If a view's `body` is more than ~30–40 lines or has several
  distinct visual regions, break it into `@ViewBuilder` sub-views.
- Prefer explicit types on non-trivial `let`s in hot paths — it short-circuits
  inference. Don't over-annotate trivial locals.
- Use the concrete type name for initializers in services/models, not `.init`.
- If you add a new view/service and a build warns it `took >100ms to type-check`,
  treat that as a defect and refactor before moving on (Definition of Done).
- Don't put `#Preview` blocks in pure-logic files (services/models). Previews drag
  SwiftUI into the file's compile graph for no UI benefit. Keep previews in the
  view files they belong to.

## Project-Level Settings (already correct — don't regress)

Debug config is tuned for fast iteration; preserve these:
- `SWIFT_COMPILATION_MODE = incremental` (Debug), `wholemodule` (Release).
- `SWIFT_OPTIMIZATION_LEVEL = -Onone` (Debug).
- `ONLY_ACTIVE_ARCH = YES` (Debug), `COMPILER_INDEX_STORE_ENABLE = NO`,
  `DEBUG_INFORMATION_FORMAT = dwarf` (Debug; dsym only for Release).

Do **not** flip Debug to `wholemodule` or raise Debug optimization — it makes
incremental builds far slower.

## Web (`web-v2/`) — Already Fast

The Next.js static-export build is healthy (compiles in ~1.5s, ~10s end-to-end).
No action needed. Keep `output: 'export'` + `images.unoptimized: true` (required
for Firebase Hosting). Ignore `next.config.optimized.mjs` — it uses
`output: 'standalone'`/headers/rewrites that are incompatible with the static
export and would break the Hosting deploy.
