# Delivery roadmap

## Phase 0 — foundations (current)

Validate product boundaries and platform research. Establish project documentation, safe-development rules, and initial threat model. Keep the existing Python prototype labeled experimental; do not expand destructive functionality until the safety gate is met.

## Phase 1 — runnable Flutter foundation (in progress)

Create Flutter project with Windows, macOS, Linux, Android and iOS hosts; pin SDK and configure format/analyze/test CI. Build a capability-aware shell, accessibility baseline, navigation and honest unsupported states. Add a fake scan repository and unit/widget tests; no real file access or deletion. Build and test on available hosts; mark other platforms unverified.

## Phase 2 — read-only scan adapters

In progress: desktop folder selection, session-only path exclusions, an extension-based storage breakdown, largest-file listing, optional size/SHA-256 matching, project artifact discovery and limited global cache candidates are implemented read-only, with cancellation and partial results. Matching has a 20,000-file cap and does not identify hard links. Further work must validate native picker builds, race-resistant scope confinement, cache configurations, exclusion aliases, file identity and macOS/Linux behavior. Android: selected documents and permitted media. iOS: authorized photos and documents. Validate on named OS versions and devices. Set performance budgets after measuring representative devices.

## Phase 3 — review and recoverable removal

In progress: Developer Cleanup supports explicit selection and an in-memory review of discovered project and tool storage candidates. Moving to Trash is disabled. Complete platform-specific threat review. Implement recovery-capable operations only where verified; report per-item outcomes and skip unsupported operations. Complete the safety test matrix before a limited beta with an incident response path.

## Phase 4 — expansion

Evaluate cleanup rules, persistence, subscriptions and cloud features independently. Security scanning needs a separately qualified engine, validation and product decision.

## Release gates

A platform is supported only after its build, permissions, accessibility, failure modes and integration tests pass on named OS versions and devices. Store acceptance is not assumed. Pricing and minimum supported versions remain product decisions.

## Market-informed priorities (2026-11-22)

From the market gap analysis (CleanMyMac, DaisyDisk, StorageRadar, WizTree, WinDirStat, BleachBit, Czkawka, Mole, npkill, ClearDisk). Done: signed GitHub Releases auto-update, settings persistence, feature-based layout.

- Done 2026-11-22: dry-run preview in every removal dialog, local removal history (Settings), ignore list enforced by the removal engine, git-status and 7-day activity guard on project folders, Docker status/start/prune via official commands.
- Done 2026-11-23: per-item risk labels (Safe / Caution / Risky) in Clean up, with explanation tooltip, screen-reader text and a confirmation warning for Risky items.
- Now: verify risk labels and the cleanup flow on real Windows, macOS and Linux builds.
- Done 2026-11-23: official clean commands for Homebrew (`brew cleanup`, with `--dry-run` preview), npm (`npm cache clean --force`) and pub (`dart pub cache clean --force`) in Developer, each behind a confirmation showing the exact command. Verified read-only commands on macOS; clean commands only tested with fake runners.
- Done 2026-11-23: macOS distribution decision (owner): direct distribution, App Sandbox removed so Clean up, Docker and tool commands can reach user caches; not eligible for the Mac App Store as-is. Optional Full Disk Access banner in Clean up (detects denied access by probing protected paths, opens System Settings, dismissible).
- Done 2026-11-23: opt-in scan history (off by default) with a "What grew" card on the scan summary, comparing with the previous finished scan of the same folder. Stores folder paths and logical sizes only, last 30 scans, locally; turning it off deletes the file.
- Done 2026-11-23: wider developer cache catalog (Yarn, pnpm, Bun, CocoaPods, Carthage, SwiftPM, Maven, NuGet, Go build, Composer, Deno, Playwright, Puppeteer, Hugging Face, JetBrains, VS Code, Electron, node-gyp). Per-user paths only; sources and unverified defaults listed in `DEVELOPER_STORAGE.md`. Tested with env maps and temporary fixtures only.
- Later: app uninstaller, scheduled checks and low-disk alerts with tray icon, similar-photo detection, cloud storage cleanup, CLI.
- Distribution: Developer ID signing with hardened runtime and notarization (required now that the sandbox is off), winget and Homebrew; avoid the Mac App Store sandbox for developer caches.
