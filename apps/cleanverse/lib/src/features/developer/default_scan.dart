import 'dart:io';

import 'package:cleanverse/src/features/scan/desktop_scan.dart';

/// Home folder used for the default developer scan, or null if unknown.
String? defaultScanRoot([Map<String, String>? env]) {
  final e = env ?? Platform.environment;
  final home = e['HOME'] ?? e['USERPROFILE'];
  return home == null || home.isEmpty ? null : home;
}

/// Temporary fallback until track A's `FolderScanViewModel.startDefault()`
/// lands. Dart resolves an instance method before an extension method, so
/// once the view model has its own `startDefault()` this extension is
/// unused and can be deleted by the integrator.
extension DeveloperDefaultScan on FolderScanViewModel {
  /// Scans the home folder with developer detection on, without asking the
  /// user to pick a folder. Read-only.
  Future<void> startDefault() async {
    if (busy) return;
    final home = defaultScanRoot();
    // The page disables its button when no home folder is known.
    if (home == null) return;
    findDevFolders = true;
    root = home;
    await rescan();
  }
}
