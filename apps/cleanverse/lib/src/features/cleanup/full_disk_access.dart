import 'dart:io';

import 'package:path/path.dart' as p;

/// macOS Full Disk Access. There is no public API to query it, so this
/// tries to read locations macOS protects. Nothing is read beyond a
/// directory listing or opening a file; contents are never kept.
enum FullDiskAccess { granted, denied, unknown }

/// Settings pane for Privacy & Security → Full Disk Access.
const fullDiskAccessSettingsUrl =
    'x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles';

typedef ProbeAccess = Future<bool?> Function(String path);

/// true = readable, false = permission denied, null = missing/other.
Future<bool?> _probe(String path) async {
  try {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).list(followLinks: false).take(1).toList();
      return true;
    }
    if (type == FileSystemEntityType.file) {
      final f = await File(path).open();
      await f.close();
      return true;
    }
    return null;
  } on FileSystemException catch (e) {
    final code = e.osError?.errorCode;
    // EPERM (1) or EACCES (13): blocked by privacy protection.
    return code == 1 || code == 13 ? false : null;
  }
}

List<String> protectedProbePaths(String home) => [
  p.join(home, 'Library', 'Application Support', 'com.apple.TCC', 'TCC.db'),
  p.join(home, 'Library', 'Safari'),
  p.join(home, 'Library', 'Mail'),
];

Future<FullDiskAccess> checkFullDiskAccess({
  String? home,
  ProbeAccess? probe,
}) async {
  final base = home ?? Platform.environment['HOME'];
  if (base == null || base.isEmpty) return FullDiskAccess.unknown;
  final check = probe ?? _probe;
  var denied = false;
  for (final path in protectedProbePaths(base)) {
    final result = await check(path);
    if (result == true) return FullDiskAccess.granted;
    if (result == false) denied = true;
  }
  return denied ? FullDiskAccess.denied : FullDiskAccess.unknown;
}

Future<bool> openFullDiskAccessSettings() async {
  try {
    final r = await Process.run('open', [fullDiskAccessSettingsUrl]);
    return r.exitCode == 0;
  } on ProcessException {
    return false;
  }
}
