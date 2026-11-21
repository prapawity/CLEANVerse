# Architecture

Status: proposed, not implemented. Decision date: 2026-11-21.

## Stack and boundaries

Flutter/Dart for presentation and shared orchestration, with platform-specific adapters for permissions, enumeration, metadata and later removal. Follow Flutter's separation of UI and data: views and view models, repositories as sources of truth, and services wrapping platform APIs. Use immutable models, unidirectional state, and constructor injection. Start with Flutter SDK primitives; add dependencies only for a demonstrated need. Pigeon platform channels are the default for typed native bridges when necessary; verify each plugin on each supported platform. Native code: Windows C++, macOS/iOS Swift, Android Kotlin, Linux C/C++ when required.

## Proposed layout

```text
apps/cleanverse/       Flutter app and platform hosts
  lib/app/             composition, theme, navigation
  lib/features/scan/   scan views and view models
  lib/domain/          immutable models and repository contracts
  lib/data/            repositories and platform services
  test/                unit and widget tests
  integration_test/    device and host integration tests
packages/              shared packages when genuinely needed
```

The Python prototype remains at the repository root until a deliberate migration. This layout does not exist yet.

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

