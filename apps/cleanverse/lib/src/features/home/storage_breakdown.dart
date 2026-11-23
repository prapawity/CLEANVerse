import 'package:cleanverse/src/data/volumes.dart';

/// One slice of the system drive.
enum StorageKind {
  junk('Junk you can clean', 'Caches, logs and temporary files.'),
  apps('Apps', 'Applications installed in Applications folders.'),
  developer('Developer', 'Project dependencies and build output.'),
  files('Your files', 'Everything else in your home folder.'),
  other('System and other', 'macOS, other users and space not scanned.'),
  free('Free', 'Space available now.');

  const StorageKind(this.label, this.description);
  final String label;
  final String description;
}

class StorageSlice {
  const StorageSlice(this.kind, this.bytes);
  final StorageKind kind;
  final int bytes;
}

/// Splits the system drive into slices without counting anything twice.
///
/// - Junk and developer project folders live inside the home folder, so
///   "Your files" is the home total minus both.
/// - Junk already includes developer *caches*; only project folders
///   (node_modules, build output…) count as Developer.
/// - Apps live outside the home folder on macOS.
/// - "System and other" is whatever used space is left.
/// Sizes are logical (what files report), so slices are approximate.
List<StorageSlice> breakdown({
  required Volume drive,
  int? homeBytes,
  int junkBytes = 0,
  int developerBytes = 0,
  int appsBytes = 0,
}) {
  final used = drive.usedBytes;
  int clamp(int v, int max) => v < 0 ? 0 : (v > max ? max : v);
  var left = used;
  int take(int v) {
    final t = clamp(v, left);
    left -= t;
    return t;
  }

  final junk = take(junkBytes);
  final dev = take(developerBytes);
  final apps = take(appsBytes);
  final files = homeBytes == null
      ? 0
      : take(homeBytes - junkBytes - developerBytes);
  return [
    if (junk > 0) StorageSlice(StorageKind.junk, junk),
    if (apps > 0) StorageSlice(StorageKind.apps, apps),
    if (dev > 0) StorageSlice(StorageKind.developer, dev),
    if (files > 0) StorageSlice(StorageKind.files, files),
    StorageSlice(StorageKind.other, left),
    StorageSlice(StorageKind.free, drive.freeBytes),
  ];
}
