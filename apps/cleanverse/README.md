# CLEANVerse Flutter preview

The app follows a scan → summary → review flow: **Smart Scan** reads a chosen folder once, and its summary links to **Space Lens** (largest folders with drill-down, file types), **Large & old files** (size and age filters), **Duplicates** and **Developer**. Code lives in `lib/src/pages/`, with shared tokens in `theme.dart` and components in `ui.dart`. See `../../docs/PRODUCT_FLOW.md`.

The desktop preview offers a user-selected, read-only folder scan, session-only folder exclusions, a file-type breakdown, top-level folder totals, and displays up to 100 largest files. Detected folders can be explored and rescanned while preserving scan options and exclusions; the back control rescans the previous folder. Folder totals include files encountered beneath each first-level folder, show up to 20 groups, and can combine groups after the first 5,000. Breakdown sizes are logical bytes of files encountered, can double-count hard links, and are not physical or reclaimable storage. Optional matching compares file size and streamed SHA-256 for up to 20,000 files. It displays up to 50 groups and 20 paths per group, with skipped items reported; hard links may appear as separate paths. Matches are candidates, not a guarantee of reclaimable space or a basis for automatic deletion. It does not modify or delete files. A separate example uses fixed sample data. Mobile scanning is not implemented. Platform hosts exist for Windows, macOS, Linux, Android and iOS; host generation is not a claim that they were built or tested.

Use Flutter 3.50.1, then run:

```sh
flutter pub get
flutter run
flutter analyze
flutter test
```

## Windows preview from GitHub Actions

Successful Windows CI runs upload an experimental, unsigned `CLEANVerse-Windows-preview-<commit>` artifact, retained for 14 days. Open the repository's Actions tab, select a successful **Flutter checks** run for the desired commit, and download its artifact. Extract the entire ZIP and run `cleanverse.exe` from the extracted folder; keep the accompanying DLLs and `data` folder next to it. GitHub may require signing in to download artifacts. This is a development preview, not a signed installer or production release.

A push with `[preview-only]` in its commit message runs a separate Windows build-only job and produces a `CLEANVerse-Windows-untested-<commit>` artifact. That job does not run format checks, analysis or tests; ordinary push and pull-request checks remain unchanged.

An optional developer-folder scan identifies some project dependency and build directories and reports observed logical sizes, which are not reclaimable-space estimates. Users can select discovered folders and review an in-memory plan; cleanup and moving to Trash remain disabled. See `../../docs/DEVELOPER_STORAGE.md` for criteria and limitations. Platform-specific builds require the relevant Flutter toolchain. On Windows, Flutter plugins require symlink support (typically Windows Developer Mode). Apple builds require macOS and Xcode; Android requires the Android SDK. Exclusions match normalized paths and do not detect all aliases or hard links. Scanning skips links where identified but cannot guarantee scope confinement if a directory is replaced during a scan; use only trusted, stable folders. macOS and Linux scanning and native picker behavior remain unverified. See `../../docs/` for scope, safety, research and next steps.
