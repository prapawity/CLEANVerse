import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Paths the user never wants scanned for cleanup or removed. Enforced by
/// the removal engine as well as hidden in the UI.
class IgnoreList {
  IgnoreList([Iterable<String> paths = const []])
    : _paths = paths.map(_norm).toSet();
  final Set<String> _paths;

  static String _norm(String path) => p.normalize(p.absolute(path));

  List<String> get paths => List.unmodifiable(_paths.toList()..sort());

  /// True when [path] is an ignored path or inside one.
  bool covers(String path) {
    final candidate = _norm(path);
    return _paths.any(
      (i) => p.equals(i, candidate) || p.isWithin(i, candidate),
    );
  }

  /// True when removing [path] would also remove an ignored path.
  bool containsIgnored(String path) {
    final candidate = _norm(path);
    return _paths.any((i) => p.isWithin(candidate, i));
  }

  bool add(String path) => _paths.add(_norm(path));
  bool remove(String path) => _paths.remove(_norm(path));
}

/// One line of the removal history.
class LoggedOperation {
  const LoggedOperation({
    required this.time,
    required this.label,
    required this.path,
    required this.mode,
    required this.status,
    required this.freedBytes,
    required this.observedBytes,
    this.message,
  });
  final DateTime time;
  final String label;
  final String path;
  final String mode;
  final String status;
  final int freedBytes;
  final int observedBytes;
  final String? message;

  Map<String, Object?> toJson() => {
    'time': time.toUtc().toIso8601String(),
    'label': label,
    'path': path,
    'mode': mode,
    'status': status,
    'freedBytes': freedBytes,
    'observedBytes': observedBytes,
    if (message != null) 'message': message,
  };

  static LoggedOperation? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final time = DateTime.tryParse('${json['time']}');
    if (time == null) return null;
    return LoggedOperation(
      time: time.toLocal(),
      label: '${json['label'] ?? ''}',
      path: '${json['path'] ?? ''}',
      mode: '${json['mode'] ?? ''}',
      status: '${json['status'] ?? ''}',
      freedBytes: json['freedBytes'] is int ? json['freedBytes'] as int : 0,
      observedBytes: json['observedBytes'] is int
          ? json['observedBytes'] as int
          : 0,
      message: json['message'] as String?,
    );
  }
}

/// Append-only local history (`history.jsonl`). Contains paths, so it never
/// leaves the device; the user can clear it in Settings.
class OperationLog {
  OperationLog(this.file);
  final File file;

  Future<void> append(Iterable<LoggedOperation> entries) async {
    if (entries.isEmpty) return;
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '${entries.map((e) => jsonEncode(e.toJson())).join('\n')}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // History is best effort; removal results are still shown.
    }
  }

  /// Newest first.
  Future<List<LoggedOperation>> read({int limit = 500}) async {
    try {
      if (!await file.exists()) return const [];
      final lines = await file.readAsLines();
      final entries = <LoggedOperation>[];
      for (final line in lines.reversed) {
        if (entries.length >= limit) break;
        try {
          final entry = LoggedOperation.fromJson(jsonDecode(line));
          if (entry != null) entries.add(entry);
        } on FormatException {
          continue;
        }
      }
      return entries;
    } catch (_) {
      return const [];
    }
  }

  Future<void> clear() async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

/// Shared protection hooks set by the app at start-up. Tests leave them
/// null or set their own.
IgnoreList? activeIgnoreList;
OperationLog? activeOperationLog;
