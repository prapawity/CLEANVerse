# Developer storage discovery

Status: experimental read-only discovery, 2026-11-21. No deletion or whole-machine scan is implemented. The user selects the scan root and exclusions; scope, symlink and partial-result limitations remain those of the desktop scanner.

## Supported candidates

Within the chosen root, detect `node_modules` with a parent `package.json`, `target` with a parent `Cargo.toml`, `.dart_tool` with a parent `pubspec.yaml`, `.gradle` with a parent Gradle settings/build file, SwiftPM `.build` with `Package.swift`, CocoaPods `Pods` with `Podfile` or `Podfile.lock`, and Python `.pytest_cache`/`.mypy_cache` with a recognized project or tool marker in the parent. These patterns identify candidates, not proof that content is disposable. Show the marker and directory modification time; that time is not last use. Limit results to 200 and report overflow in skipped items. Preserve user data and never run tool commands or delete files automatically.

Sizes sum logical file lengths observed during traversal. They may be partial, can count hard links or nested candidates more than once, and do not measure physical storage or reclaimable bytes.

### Possible global caches

The scanner recognizes Gradle `caches` under `GRADLE_USER_HOME`, Cargo `registry/cache` under `CARGO_HOME`, the Dart package cache under `PUB_CACHE`, and npm `_cacache` under `npm_config_cache` / `NPM_CONFIG_CACHE`, or the documented platform defaults if no corresponding environment variable is set. On macOS it additionally identifies the conventional Xcode `DerivedData` and `Archives` locations as unverified candidates. Archives are not cache: they can contain unique release builds and symbols. These are detected only when the candidate directory is inside or is the selected root and is not excluded. Relative or invalid configured paths are skipped rather than silently replaced by a default. The label identifies whether the path came from an environment variable or a possible default; tool configuration files, Xcode preferences, command-line overrides, and child-process environments are not inspected, so a path is a candidate and may not be the active location. No tool commands are run. Global cache paths may contain valuable shared or manually modified data and must never be automatically deleted.

## Why cleanup needs a separate design

Project dependency and build directories may contain local edits, unavailable packages or active build state. Deleting may break offline builds, require downloads and slow rebuilds. Gradle caches can be shared and concurrently locked; Cargo home also contains config and credentials and its internal structure is not stable. npm describes its cache as self-healing, so blanket cleanup is not always beneficial. Custom environment variables and tool configuration can move cache locations.

Before implementing removal, design an explicit allowlist per tool, identify ownership and active processes, validate identities and scope at operation time, distinguish Trash support and permanent operations, disclose downstream effects, and complete `SAFETY.md` release gates. Do not classify whole home directories or credentials as caches. Whole-machine discovery needs an explicit drive/scope picker, permissions, exclusions, filesystem boundaries and honest partial-results reporting.

Sources: [Gradle dependency cache](https://docs.gradle.org/current/userguide/dependency_caching.html), [Gradle user home](https://docs.gradle.org/current/userguide/directory_layout.html), [Cargo home](https://doc.rust-lang.org/cargo/guide/cargo-home.html), [Dart package cache](https://dart.dev/tools/pub/cmd/pub-get), [npm cache](https://docs.npmjs.com/cli/v9/commands/npm-cache/), [npm configuration](https://docs.npmjs.com/cli/v11/commands/npm/), [Xcode build settings](https://developer.apple.com/documentation/xcode/configuring-the-build-settings-of-a-target/), [Xcode archives](https://developer.apple.com/documentation/xcode/testing-a-release-build).
