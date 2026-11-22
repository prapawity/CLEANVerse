import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:cleanverse/src/data/protection.dart';

/// Small local preferences file (`settings.json` in the app support
/// folder). Holds preferences and the user's ignore list; scan results
/// are never stored.
class AppSettings extends ChangeNotifier {
  AppSettings({Future<Directory> Function()? location})
    : _location = location ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _location;

  bool autoCheckUpdates = true;
  DateTime? lastUpdateCheck;
  String? skippedVersion;
  final IgnoreList ignoreList = IgnoreList();
  bool _loaded = false;

  /// Removal history file next to the settings.
  Future<OperationLog> operationLog() async =>
      OperationLog(File(p.join((await _location()).path, 'history.jsonl')));

  Future<void> ignorePath(String path) async {
    if (ignoreList.add(path)) await save();
  }

  Future<void> unignorePath(String path) async {
    if (ignoreList.remove(path)) await save();
  }

  bool get loaded => _loaded;

  Future<File> _file() async =>
      File(p.join((await _location()).path, 'settings.json'));

  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        if (json is Map<String, dynamic>) {
          autoCheckUpdates = json['autoCheckUpdates'] != false;
          lastUpdateCheck = DateTime.tryParse('${json['lastUpdateCheck']}');
          final skipped = json['skippedVersion'];
          skippedVersion = skipped is String ? skipped : null;
          final ignored = json['ignoredPaths'];
          if (ignored is List) {
            for (final path in ignored.whereType<String>()) {
              ignoreList.add(path);
            }
          }
        }
      }
    } catch (_) {
      // A corrupt file falls back to defaults.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'autoCheckUpdates': autoCheckUpdates,
          'lastUpdateCheck': lastUpdateCheck?.toIso8601String(),
          'skippedVersion': skippedVersion,
          'ignoredPaths': ignoreList.paths,
        }),
      );
    } catch (_) {
      // Settings are best effort.
    }
    notifyListeners();
  }

  Future<void> setAutoCheckUpdates(bool value) async {
    autoCheckUpdates = value;
    await save();
  }
}
