import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:cleanverse/src/features/scan/desktop_scan.dart';

/// Totals from one completed scan. Stores folder paths and sizes only:
/// no file names, hashes or contents. Kept on this computer, opt-in.
class ScanSnapshot {
  const ScanSnapshot({
    required this.root,
    required this.time,
    required this.totalBytes,
    required this.folders,
    this.partial = false,
  });
  final String root;
  final DateTime time;
  final int totalBytes;
  final Map<String, int> folders;
  final bool partial;

  factory ScanSnapshot.fromResult(
    String root,
    FolderScanResult result, {
    DateTime? time,
  }) => ScanSnapshot(
    root: p.normalize(root),
    time: time ?? DateTime.now(),
    totalBytes: result.totalBytes,
    partial: result.skipped > 0,
    folders: {
      for (final f in result.folderSummaries)
        if (f.folderPath != null) p.normalize(f.folderPath!): f.bytes,
    },
  );

  Map<String, Object?> toJson() => {
    'root': root,
    'time': time.toIso8601String(),
    'totalBytes': totalBytes,
    'partial': partial,
    'folders': folders,
  };

  static ScanSnapshot? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final root = json['root'];
    final time = DateTime.tryParse('${json['time']}');
    final total = json['totalBytes'];
    final folders = json['folders'];
    if (root is! String || time == null || total is! int) return null;
    return ScanSnapshot(
      root: root,
      time: time,
      totalBytes: total,
      partial: json['partial'] == true,
      folders: {
        if (folders is Map<String, dynamic>)
          for (final e in folders.entries)
            if (e.value is int) e.key: e.value as int,
      },
    );
  }
}

class FolderGrowth {
  const FolderGrowth(this.path, this.before, this.after);
  final String path;
  final int before;
  final int after;
  int get delta => after - before;
  bool get isNew => before == 0;
}

class ScanComparison {
  const ScanComparison({
    required this.previous,
    required this.current,
    required this.grew,
  });
  final ScanSnapshot previous;
  final ScanSnapshot current;

  /// Folders that grew, largest growth first.
  final List<FolderGrowth> grew;
  int get totalDelta => current.totalBytes - previous.totalBytes;

  /// A skipped folder in either scan makes the comparison approximate.
  bool get approximate => previous.partial || current.partial;
}

ScanComparison compareSnapshots(
  ScanSnapshot previous,
  ScanSnapshot current, {
  int limit = 10,
}) {
  final grew = [
    for (final e in current.folders.entries)
      if (e.value > (previous.folders[e.key] ?? 0))
        FolderGrowth(e.key, previous.folders[e.key] ?? 0, e.value),
  ]..sort((a, b) => b.delta.compareTo(a.delta));
  return ScanComparison(
    previous: previous,
    current: current,
    grew: grew.take(limit).toList(),
  );
}

/// JSON file of recent snapshots. Best effort: a corrupt file is replaced.
class ScanHistoryStore {
  ScanHistoryStore(this.file, {this.maxSnapshots = 30});
  final File file;
  final int maxSnapshots;

  Future<List<ScanSnapshot>> load() async {
    try {
      if (!await file.exists()) return [];
      final json = jsonDecode(await file.readAsString());
      if (json is! List) return [];
      return [for (final item in json) ?ScanSnapshot.fromJson(item)];
    } catch (_) {
      return [];
    }
  }

  /// Saves [snapshot] and compares it with the latest earlier scan of the
  /// same folder. Returns null on the first scan of a folder.
  Future<ScanComparison?> record(ScanSnapshot snapshot) async {
    final all = await load();
    ScanSnapshot? previous;
    for (final s in all.reversed) {
      if (p.equals(s.root, snapshot.root)) {
        previous = s;
        break;
      }
    }
    all.add(snapshot);
    final kept = all.length > maxSnapshots
        ? all.sublist(all.length - maxSnapshots)
        : all;
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode([for (final s in kept) s.toJson()]));
    } catch (_) {
      // History is best effort; the comparison still shows.
    }
    return previous == null ? null : compareSnapshots(previous, snapshot);
  }

  Future<void> clear() async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
