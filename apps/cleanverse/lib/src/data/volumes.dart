import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One drive or volume and how full it is.
class Volume {
  const Volume({
    required this.path,
    required this.name,
    required this.totalBytes,
    required this.freeBytes,
    this.internal = false,
    this.removable = false,
    this.isSystem = false,
  });
  final String path;
  final String name;
  final int totalBytes;
  final int freeBytes;
  final bool internal;
  final bool removable;

  /// The drive the system and home folder live on.
  final bool isSystem;

  int get usedBytes => (totalBytes - freeBytes).clamp(0, totalBytes);
  double get usedFraction => totalBytes == 0 ? 0 : usedBytes / totalBytes;
}

typedef Run = Future<ProcessResult> Function(String exe, List<String> args);

/// Lists drives. macOS asks the system through a native channel (same
/// numbers as Finder, including purgeable space); Windows uses PowerShell;
/// Linux uses `df`. Read-only; returns an empty list when unavailable.
class VolumeReader {
  VolumeReader({MethodChannel? channel, Run? run, String? os})
    : _channel = channel ?? const MethodChannel('cleanverse/volumes'),
      _run = run ?? ((e, a) => Process.run(e, a, stdoutEncoding: utf8)),
      _os = os ?? Platform.operatingSystem;
  final MethodChannel _channel;
  final Run _run;
  final String _os;

  Future<List<Volume>> list() async {
    try {
      final volumes = switch (_os) {
        'macos' => await _mac(),
        'windows' => await _windows(),
        _ => await _df(),
      };
      volumes.sort((a, b) {
        if (a.isSystem != b.isSystem) return a.isSystem ? -1 : 1;
        return b.totalBytes.compareTo(a.totalBytes);
      });
      return volumes;
    } catch (_) {
      return const [];
    }
  }

  Future<List<Volume>> _mac() async {
    final raw = await _channel.invokeListMethod<Map>('list') ?? const [];
    return [
      for (final m in raw)
        Volume(
          path: '${m['path']}',
          name: '${m['name']}',
          totalBytes: (m['total'] as num).toInt(),
          freeBytes: (m['free'] as num).toInt(),
          internal: m['internal'] == true,
          removable: m['removable'] == true,
          isSystem: m['root'] == true || m['path'] == '/',
        ),
    ];
  }

  Future<List<Volume>> _windows() async {
    final r = await _run('powershell', [
      '-NoProfile',
      '-Command',
      'Get-CimInstance Win32_LogicalDisk -Filter "DriveType=2 or DriveType=3" | '
          'Select-Object DeviceID,VolumeName,Size,FreeSpace,DriveType | ConvertTo-Json',
    ]);
    if (r.exitCode != 0) return const [];
    var json = jsonDecode('${r.stdout}');
    if (json is Map) json = [json];
    final systemDrive = (Platform.environment['SystemDrive'] ?? 'C:')
        .toUpperCase();
    return [
      for (final d in (json as List).whereType<Map>())
        if (d['Size'] != null)
          Volume(
            path: '${d['DeviceID']}\\',
            name: (d['VolumeName'] as String?)?.isNotEmpty == true
                ? '${d['VolumeName']} (${d['DeviceID']})'
                : 'Local Disk (${d['DeviceID']})',
            totalBytes: (d['Size'] as num).toInt(),
            freeBytes: (d['FreeSpace'] as num? ?? 0).toInt(),
            internal: d['DriveType'] == 3,
            removable: d['DriveType'] == 2,
            isSystem: '${d['DeviceID']}'.toUpperCase() == systemDrive,
          ),
    ];
  }

  /// `df -kP`: real filesystems only (no tmpfs, overlay, snap loops).
  Future<List<Volume>> _df() async {
    final r = await _run('df', ['-kP']);
    if (r.exitCode != 0) return const [];
    return parseDf('${r.stdout}');
  }
}

List<Volume> parseDf(String output) {
  final out = <Volume>[];
  for (final line in const LineSplitter().convert(output).skip(1)) {
    final cols = line.trim().split(RegExp(r'\s+'));
    if (cols.length < 6) continue;
    final fs = cols[0];
    final mount = cols.sublist(5).join(' ');
    if (!fs.startsWith('/dev/') || fs.startsWith('/dev/loop')) continue;
    if (mount.startsWith('/boot') || mount.startsWith('/snap')) continue;
    final total = int.tryParse(cols[1]);
    final free = int.tryParse(cols[3]);
    if (total == null || free == null || total == 0) continue;
    out.add(
      Volume(
        path: mount,
        name: mount == '/' ? 'System' : mount.split('/').last,
        totalBytes: total * 1024,
        freeBytes: free * 1024,
        internal: true,
        isSystem: mount == '/',
      ),
    );
  }
  return out;
}

/// Holds the drive list for the dashboard; reloaded after scans and cleans.
class VolumesModel extends ChangeNotifier {
  VolumesModel({VolumeReader? reader}) : reader = reader ?? VolumeReader();
  final VolumeReader reader;
  List<Volume>? volumes;
  bool loading = false;
  bool _disposed = false;

  Volume? get system {
    final list = volumes;
    if (list == null || list.isEmpty) return null;
    return list.firstWhere((v) => v.isSystem, orElse: () => list.first);
  }

  Future<void> load() async {
    if (loading) return;
    loading = true;
    if (!_disposed) notifyListeners();
    try {
      volumes = await reader.list();
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
