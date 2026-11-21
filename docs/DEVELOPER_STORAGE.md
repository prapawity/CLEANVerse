# Developer storage discovery

Status: experimental read-only discovery, 2026-11-21. No deletion, whole-machine scan, or global cache discovery is implemented. The user selects the scan root and exclusions; scope, symlink and partial-result limitations remain those of the desktop scanner.

## Supported candidates

Within the chosen root, detect `node_modules` with a parent `package.json`, `target` with a parent `Cargo.toml`, `.dart_tool` with a parent `pubspec.yaml`, `.gradle` with a parent Gradle settings/build file, SwiftPM `.build` with `Package.swift`, CocoaPods `Pods` with `Podfile` or `Podfile.lock`, and Python `.pytest_cache`/`.mypy_cache` with a recognized project or tool marker in the parent. These patterns identify candidates, not proof that content is disposable. Show the marker and directory modification time; that time is not last use. Limit results to 200 and report overflow in skipped items. Preserve user data and never run tool commands or delete files automatically.

Sizes sum logical file lengths observed during traversal. They may be partial, can count hard links or nested candidates more than once, and do not measure physical storage or reclaimable bytes.

## Why cleanup needs a separate design

Project dependency and build directories may contain local edits, unavailable packages or active build state. Deleting may break offline builds, require downloads and slow rebuilds. Gradle caches can be shared and concurrently locked; Cargo home also contains config and credentials and its internal structure is not stable. npm describes its cache as self-healing, so blanket cleanup is not always beneficial. Custom environment variables and tool configuration can move cache locations.

Before implementing removal, design an explicit allowlist per tool, identify ownership and active processes, validate identities and scope at operation time, distinguish Trash support and permanent operations, disclose downstream effects, and complete `SAFETY.md` release gates. Do not classify whole home directories or credentials as caches. Whole-machine discovery needs an explicit drive/scope picker, permissions, exclusions, filesystem boundaries and honest partial-results reporting.

Sources: [Gradle dependency cache](https://docs.gradle.org/current/userguide/dependency_caching.html), [Gradle user home](https://docs.gradle.org/current/userguide/directory_layout.html), [Cargo home](https://doc.rust-lang.org/cargo/guide/cargo-home.html), [npm cache](https://docs.npmjs.com/cli/v9/commands/npm-cache/).
