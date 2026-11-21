# CLEANVerse Flutter preview

The desktop preview offers a user-selected, read-only folder scan, session-only folder exclusions, a file-type breakdown based on extensions, and displays up to 100 largest files. Breakdown sizes are logical bytes of files encountered, can double-count hard links, and are not physical or reclaimable storage. Optional matching compares file size and streamed SHA-256 for up to 20,000 files. It displays up to 50 groups and 20 paths per group, with skipped items reported; hard links may appear as separate paths. Matches are candidates, not a guarantee of reclaimable space or a basis for automatic deletion. It does not modify or delete files. A separate example uses fixed sample data. Mobile scanning is not implemented. Platform hosts exist for Windows, macOS, Linux, Android and iOS; host generation is not a claim that they were built or tested.

Use Flutter 3.50.1, then run:

```sh
flutter pub get
flutter run
flutter analyze
flutter test
```

An optional developer-folder scan identifies some project dependency and build directories and reports observed logical sizes, which are not reclaimable-space estimates. It does not delete them. See `../../docs/DEVELOPER_STORAGE.md` for criteria and limitations. Platform-specific builds require the relevant Flutter toolchain. On Windows, Flutter plugins require symlink support (typically Windows Developer Mode). Apple builds require macOS and Xcode; Android requires the Android SDK. Exclusions match normalized paths and do not detect all aliases or hard links. Scanning skips links where identified but cannot guarantee scope confinement if a directory is replaced during a scan; use only trusted, stable folders. macOS and Linux scanning and native picker behavior remain unverified. See `../../docs/` for scope, safety, research and next steps.
