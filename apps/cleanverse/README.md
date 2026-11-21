# CLEANVerse Flutter preview

The desktop preview offers a user-selected, read-only folder scan and displays up to 100 largest files. It does not modify or delete files. A separate example uses fixed sample data. Duplicate detection, exclusions and mobile scanning are not implemented. Platform hosts exist for Windows, macOS, Linux, Android and iOS; host generation is not a claim that they were built or tested.

Use Flutter 3.50.1, then run:

```sh
flutter pub get
flutter run
flutter analyze
flutter test
```

Platform-specific builds require the relevant Flutter toolchain. On Windows, Flutter plugins require symlink support (typically Windows Developer Mode). Apple builds require macOS and Xcode; Android requires the Android SDK. Scanning skips links where identified but cannot guarantee scope confinement if a directory is replaced during a scan; use only trusted, stable folders. macOS and Linux scanning and native picker behavior remain unverified. See `../../docs/` for scope, safety, research and next steps.
