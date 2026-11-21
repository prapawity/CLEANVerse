# Developer storage requirements

The owner requested implementation of the DevSpace proposal within CLEANVerse. These are product requirements and target capabilities, not claims that the current app provides them. Retain the cross-platform product; implement platform-specific capabilities only where permissions, policies and testing permit. The user's macOS/SwiftUI proposal informs macOS-native integrations but does not by itself replace the existing Flutter architecture.

## Developer storage intelligence

- Discover and categorize project dependencies, build outputs and global caches separately. Associate project artifacts with their owning project when there is evidence; do not infer that a project is unused solely from modification time.
- Support Xcode, SwiftPM, CocoaPods, Node/npm/pnpm/Yarn, Flutter/Dart, Gradle/Android, Rust/Cargo, Python, Go, Docker/OrbStack and local model storage incrementally. Resolve configurable paths from authoritative tool configuration; distinguish default paths from verified locations.
- Show scope, category, path, project/tool, observed size, meaningful timestamp where available, confidence, possible effects, and risk. Mark unknowns explicitly. Separate logical bytes, occupied physical space and verified reclaimable bytes. Hard links, shared dependencies, sparse files, snapshots, cloud placeholders and concurrent changes can invalidate simple estimates.
- Offer explicitly authorized disk or volume discovery with progress, cancellation, exclusions, access/partial-results reporting and filesystem boundaries. Never imply a mobile app can scan another app's private files. Currently only a user-selected desktop folder is supported.

## Management and trust

- Design a review-first cleanup workflow with no automatic selection, item-level details, changed-item and ownership checks, running-tool warnings, explicit confirmation and per-item outcomes. Use platform Trash where supported; never silently fall back to permanent deletion. Some content, including archives, volumes, databases and project files, must not be treated as disposable based on name alone.
- Add application/leftover discovery with association confidence and explicit review, storage visualization, large/duplicate file exploration, history and restore only after separate platform-specific designs and tests. Do not claim universal undo or automatic malware protection.
- Explore storage trends, scheduled scans and dependency intelligence only after local-first privacy, background permission, measurement and retention designs. Never claim an SDK, dependency or project is unused without defensible evidence.

## Delivery

1. Read-only project discovery, categories and transparent sizes; expand detector catalog and test each platform.
2. Permission-aware storage overview and reviewed native cleanup with recovery and data-loss safeguards; then history and restore where verified.
3. Application association, interactive visualization and cross-project dependency intelligence after dedicated research and validation.

See `DEVELOPER_STORAGE.md`, `SAFETY.md`, `ARCHITECTURE.md` and `ROADMAP.md`. The proposal's examples of “safe” categories are hypotheses, not blanket deletion rules. macOS-specific Xcode/Simulator/Time Machine and Docker APIs require dedicated research and real-host testing.
