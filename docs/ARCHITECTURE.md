# Architecture

Status: partly implemented (desktop). Decision date: 2026-11-21; layout adopted 2026-11-22.

## Stack and boundaries

Flutter/Dart for presentation and shared orchestration, with platform-specific adapters for permissions, enumeration, metadata and later removal. Follow Flutter's separation of UI and data: views and view models, repositories as sources of truth, and services wrapping platform APIs. Use immutable models, unidirectional state, and constructor injection. Start with Flutter SDK primitives; add dependencies only for a demonstrated need. Pigeon platform channels are the default for typed native bridges when necessary; verify each plugin on each supported platform. Native code: Windows C++, macOS/iOS Swift, Android Kotlin## Implemented layout

```text
apps/cleanverse/lib/
  main.dart                       entry point
  src/app/                        composition and shared UI
    app.dart                      MaterialApp, HomeScreen shell, Section navigation, update banner
    theme.dart                    design tokens (CvColors, CvSpace, CvRadius) and ThemeData
    ui.dart                       shared components (Panel, Callout, EmptyState, formatBytes...)
    treemap.dart                  squarified treemap widget
  src/data/
    removal.dart                  RemovalItem, executeRemoval, platform TrashBackend (Recycle Bin / Finder / gio)
  src/features/
    scan/                         LocalFolderScanner + FolderScanViewModel; Smart Scan, Space Lens,
                                  Large & old files, Duplicates pages
    cleanup/                      junk catalog (system, browser, developer caches), CleanupViewModel,
                                  confirm/result dialogs, Clean up page
    developer/                    developer quick check, cleanup plan, Developer page
    settings/                     AppSettings (settings.json), Settings page
    update/                       signed GitHub Releases updater (manifest, service, installer, view model)
    example/                      sample data page
apps/cleanverse/tool/release/     sign_manifest.dart (keygen, signed latest.json)
.github/workflows/release.yml     tag v* -> test -> build Win/macOS/Linux -> signed draft release
```

Rules: pages depend on view models; view models depend on `data/` and platform services; `data/` never imports Flutter widgets. Imports use `package:cleanverse/src/...`. One `FolderScanViewModel`, `CleanupViewModel`, `AppSettings` and `UpdateViewModel` are owned by `HomeScreen` and injectable for tests.

## Updates

Same model as GITVerse by PRAPAWITY's Tauri updater, implemented in Dart:

1. On start (at most once a day, if enabled) the app downloads `releases/latest/download/latest.json` and `latest.json.sig` from GitHub. These are static files, so the anonymous API rate limit does not apply.
2. The Ed25519 signature is checked against the public key compiled in with `--dart-define=CLEANVERSE_UPDATE_KEY`. Builds without a key never check.
3. Newer, non-prerelease versions for the current platform are offered in a banner and on the Settings page; the user can skip a version.
4. On confirmation the asset is downloaded over HTTPS (redirects only to GitHub hosts), size-limited, and verified by SHA-256 from the signed manifest.
5. Install handoff: Windows zip — a helper script waits for the app to exit, keeps `<install>.previous`, replaces files and relaunches (falls back to showing the file if the folder is not writable); macOS — opens the DMG; Linux — replaces an AppImage, otherwise reveals the tarball.

Release: set secret `UPDATE_SIGNING_KEY` and variable `UPDATE_PUBLIC_KEY` (generate with `dart run tool/release/sign_manifest.dart keygen`; back up the private key), bump `version` in pubspec.yaml, push tag `vX.Y.Z`, review the draft release and publish. Not yet done: Windows Authenticode, Apple notarization, Linux AppImage packaging, delta updates.

s layout does not exist yet.

## Data flow and contracts

User action → view model → scan repository → capability-aware platform service → scoped enumeration → normalized results → UI. Scans must not block the UI, must expose truthful progress and cancellation, and report per-item failures. Android content URIs and PhotoKit identifiers are opaque handles, not paths. Revalidate permissions on each operation.

- `CapabilitySet`: supported operations, scope, recoverability and permission state per platform/channel; unknown differs from unavailable.
- `ScanRequest`: explicit roots or authorized media scope and exclusions; never default to a whole device.
- `ScanEvent`: started, progress, partial result, warning, completed, cancelled, failed. Never present a partial scan as complete.
- `ItemRef`: opaque platform identifier, display name, size and modification time if known, plus identity metadata for revalidation. Results are snapshots.
- `RemovalPlan` (future): explicitly selected item references and operation mode; revalidate at execution and report per-item outcomes. No implicit permanent-delete fallback.

## Data and release

Start in memory; add local persistence when required. SQLite is a candidate for structured history, not a mandatory first dependency. Define retention and deletion before persisting sensitive data. No backend, account, analytics, or network access in the first slice. Pin Flutter and application dependencies when the first runnable app is created. CI should run format, analyze and tests, and build each platform on appropriate runners. Apple builds require macOS and Xcode. Rust is deferred until profiling demonstrates a benefit.

Sources: [Flutter architecture](https://docs.flutter.dev/app-architecture/recommendations), [Pigeon](https://docs.flutter.dev/interop/pigeon), [supported platforms](https://docs.flutter.dev/reference/supported-platforms).

