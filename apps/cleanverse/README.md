# CLEANVerse Flutter preview

Phase 1 is a read-only UI preview using fixed sample data. It does not access, scan, select, or remove real files. Platform hosts are generated for Windows, macOS, Linux, Android and iOS; host generation alone is not a claim that they were built or tested.

Use Flutter 3.50.1, then run:

```sh
flutter pub get
flutter run
flutter analyze
flutter test
```

Platform-specific builds require the relevant Flutter toolchain. Apple builds require macOS and Xcode; Android requires the Android SDK. See the project documentation in `../../docs/` for scope, safety, platform research and next steps.
