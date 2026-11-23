import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:cleanverse/src/data/protection.dart';

/// How an item is removed. [trash] is recoverable until the user empties it;
/// [permanent] frees space immediately and cannot be undone.
enum RemovalMode { trash, permanent }

/// Whether the target path itself is removed, or only what is inside it
/// (used for shared cache roots such as %TEMP% that must keep existing).
enum RemovalScope { whole, contents }

class RemovalItem {
  const RemovalItem({
    required this.path,
    required this.label,
    required this.bytes,
    required this.recommended,
    required this.allowedRoot,
    this.scope = RemovalScope.whole,
    this.keepNames = const {},
  });

  final String path;
  final String label;

  /// Logical size observed at review time.
  final int bytes;
  final RemovalMode recommended;

  /// The removal must stay inside this folder. Checked again before acting.
  final String allowedRoot;
  final RemovalScope scope;

  /// For [RemovalScope.contents]: direct children with these names are kept
  /// (for example browser caches that are listed as their own item).
  final Set<String> keepNames;
}

enum RemovalStatus {
  removed,
  movedToTrash,
  partial,
  skipped,
  failed,

  /// Dry run: checks passed and this would be removed. Nothing changed.
  previewed,
}

class RemovalOutcome {
  const RemovalOutcome(
    this.item,
    this.status,
    this.mode, {
    this.message,
    this.freedBytes = 0,
  });
  final RemovalItem item;
  final RemovalStatus status;
  final RemovalMode mode;
  final String? message;

  /// Bytes deleted permanently. Trash moves free nothing until emptied.
  final int freedBytes;
}

/// Moves paths to the platform's recoverable trash. Implementations must
/// never fall back to permanent deletion.
abstract interface class TrashBackend {
  /// Returns an error message per path, or null on success.
  Future<Map<String, String?>> moveToTrash(List<String> paths);
}

/// True when [path] is a link (symlink, or a junction on Windows). Trash
/// backends refuse links because the system Trash would move the target.
bool _isLink(String path) =>
    FileSystemEntity.typeSync(path, followLinks: false) ==
    FileSystemEntityType.link;

const _linkRefused = 'This is a link; links are never moved to the Trash.';

TrashBackend platformTrash() {
  if (Platform.isWindows) return WindowsRecycleBin();
  if (Platform.isMacOS) return MacTrash();
  return LinuxTrash();
}

/// Uses the .NET VisualBasic FileSystem API through PowerShell, which sends
/// items to the Recycle Bin. Paths are passed through a temporary file, not
/// the command line, so they are never interpreted as code.
class WindowsRecycleBin implements TrashBackend {
  static const _script = r'''
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName Microsoft.VisualBasic
$fs = [Microsoft.VisualBasic.FileIO.FileSystem]
foreach ($path in [System.IO.File]::ReadAllLines($env:CLEANVERSE_LIST, [System.Text.Encoding]::UTF8)) {
  if ($path -eq '') { continue }
  try {
    if ([System.IO.Directory]::Exists($path)) {
      $fs::DeleteDirectory($path, 'OnlyErrorDialogs', 'SendToRecycleBin', 'ThrowException')
    } elseif ([System.IO.File]::Exists($path)) {
      $fs::DeleteFile($path, 'OnlyErrorDialogs', 'SendToRecycleBin', 'ThrowException')
    } else { throw 'Item no longer exists.' }
    [Console]::Out.WriteLine('OK' + "`t" + $path)
  } catch {
    [Console]::Out.WriteLine('ERR' + "`t" + $path + "`t" + ($_.Exception.Message -replace "`r|`n", ' '))
  }
}
''';

  @override
  Future<Map<String, String?>> moveToTrash(List<String> paths) async {
    final results = <String, String?>{
      for (final path in paths)
        path: _isLink(path)
            ? _linkRefused
            : 'Recycle Bin did not report a result.',
    };
    paths = [
      for (final path in paths)
        if (results[path] != _linkRefused) path,
    ];
    if (paths.isEmpty) return results;
    final dir = await Directory.systemTemp.createTemp('cleanverse');
    try {
      final list = File(p.join(dir.path, 'paths.txt'));
      await list.writeAsString(paths.join('\n'), encoding: utf8);
      final script = File(p.join(dir.path, 'trash.ps1'));
      await script.writeAsString(_script, encoding: utf8);
      final run = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          script.path,
        ],
        environment: {'CLEANVERSE_LIST': list.path},
        stdoutEncoding: utf8,
      );
      for (final line in LineSplitter.split(run.stdout as String)) {
        final parts = line.split('\t');
        if (parts.length >= 2 && results.containsKey(parts[1])) {
          results[parts[1]] = parts[0] == 'OK'
              ? null
              : (parts.length > 2
                    ? parts[2]
                    : 'Could not move to Recycle Bin.');
        }
      }
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
    return results;
  }
}

/// Asks Finder to move items to the Trash. The path is passed as an argument,
/// not embedded in the script.
class MacTrash implements TrashBackend {
  // One osascript call per batch: starting osascript once per item takes
  // minutes for a few hundred items. Each path is still tried on its own.
  static const _script = [
    'on run argv',
    'set out to ""',
    'repeat with p in argv',
    'try',
    'tell application "Finder" to delete (POSIX file (contents of p) as alias)',
    'set out to out & "OK" & tab & (contents of p) & linefeed',
    'on error',
    'set out to out & "ERR" & tab & (contents of p) & linefeed',
    'end try',
    'end repeat',
    'return out',
    'end run',
  ];

  @override
  Future<Map<String, String?>> moveToTrash(List<String> paths) async {
    const failed = 'Finder could not move this item to the Trash.';
    final results = <String, String?>{};
    final queue = <String>[];
    for (final path in paths) {
      if (_isLink(path)) {
        results[path] = _linkRefused;
      } else {
        results[path] = failed; // until Finder reports success
        queue.add(path);
      }
    }
    for (var i = 0; i < queue.length; i += 200) {
      final batch = queue.sublist(i, (i + 200).clamp(0, queue.length));
      final run = await Process.run('osascript', [
        for (final line in _script) ...['-e', line],
        ...batch,
      ], stdoutEncoding: utf8);
      for (final line in LineSplitter.split('${run.stdout}')) {
        final tab = line.indexOf('\t');
        if (tab < 0) continue;
        final path = line.substring(tab + 1);
        if (line.startsWith('OK') && results.containsKey(path)) {
          results[path] = null;
        }
      }
    }
    return results;
  }
}

/// Uses `gio trash` (GLib), falling back to `trash-put`. If neither exists
/// the item is skipped; it is never deleted permanently instead.
class LinuxTrash implements TrashBackend {
  @override
  Future<Map<String, String?>> moveToTrash(List<String> paths) async {
    final results = <String, String?>{};
    for (final path in paths) {
      results[path] = await _trash(path);
    }
    return results;
  }

  Future<String?> _trash(String path) async {
    if (_isLink(path)) return _linkRefused;
    for (final command in [
      ['gio', 'trash', '--', path],
      ['trash-put', '--', path],
    ]) {
      try {
        final run = await Process.run(command.first, command.sublist(1));
        if (run.exitCode == 0) return null;
      } on ProcessException {
        continue;
      }
    }
    return 'No supported Trash tool (gio or trash-put) is available.';
  }
}

/// Logical size of a file or folder, without following links.
Future<int> measureBytes(
  String path, {
  Set<String> skipNames = const {},
}) async {
  var total = 0;
  try {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.file) return (await File(path).length());
    if (type != FileSystemEntityType.directory) return 0;
    final pending = <Directory>[Directory(path)];
    var top = true;
    while (pending.isNotEmpty) {
      final dir = pending.removeLast();
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (top && skipNames.contains(p.basename(entity.path))) continue;
          if (entity is Directory) {
            pending.add(entity);
          } else if (entity is File) {
            try {
              total += await entity.length();
            } on FileSystemException {
              // Locked or vanished: not counted.
            }
          }
        }
      } on FileSystemException {
        // Unreadable folder: not counted.
      }
      top = false;
    }
  } on FileSystemException {
    return total;
  }
  return total;
}

/// Refuses obviously dangerous targets regardless of the catalog.
String? safetyProblem(RemovalItem item) {
  final path = p.normalize(p.absolute(item.path));
  final root = p.normalize(p.absolute(item.allowedRoot));
  if (p.split(path).length < 3) return 'Refusing to remove a top-level folder.';
  final inside = item.scope == RemovalScope.contents
      ? p.equals(path, root) || p.isWithin(root, path)
      : p.isWithin(root, path) || p.equals(path, root);
  if (!inside) return 'Item is outside the reviewed location.';
  for (final env in ['USERPROFILE', 'HOME']) {
    final home = Platform.environment[env];
    if (home != null &&
        home.isNotEmpty &&
        p.equals(path, p.normalize(home)) &&
        item.scope == RemovalScope.whole) {
      return 'Refusing to remove the home folder.';
    }
  }
  return null;
}

/// Removes the given items one by one and reports each outcome. Items are
/// re-checked immediately before acting; links are never followed.
Future<List<RemovalOutcome>> executeRemoval(
  List<RemovalItem> items, {
  RemovalMode? override,
  TrashBackend? trash,
  void Function(int done, int total)? onProgress,
  bool Function()? cancelled,
  bool dryRun = false,
  IgnoreList? ignore,
  OperationLog? log,
}) async {
  final backend = trash ?? platformTrash();
  final ignored = ignore ?? activeIgnoreList;
  final outcomes = <RemovalOutcome>[];
  var done = 0;
  for (final item in items) {
    final mode = override ?? item.recommended;
    if (cancelled?.call() ?? false) {
      outcomes.add(
        RemovalOutcome(
          item,
          RemovalStatus.skipped,
          mode,
          message: 'Cancelled.',
        ),
      );
      continue;
    }
    outcomes.add(await _removeOne(item, mode, backend, dryRun, ignored));
    onProgress?.call(++done, items.length);
  }
  if (!dryRun) {
    final now = DateTime.now();
    await (log ?? activeOperationLog)?.append([
      for (final o in outcomes)
        LoggedOperation(
          time: now,
          label: o.item.label,
          path: o.item.path,
          mode: o.mode.name,
          status: o.status.name,
          freedBytes: o.freedBytes,
          observedBytes: o.item.bytes,
          message: o.message,
        ),
    ]);
  }
  return outcomes;
}

Future<RemovalOutcome> _removeOne(
  RemovalItem item,
  RemovalMode mode,
  TrashBackend backend,
  bool dryRun,
  IgnoreList? ignored,
) async {
  final problem = safetyProblem(item);
  if (problem != null) {
    return RemovalOutcome(item, RemovalStatus.skipped, mode, message: problem);
  }
  if (ignored != null &&
      (ignored.covers(item.path) ||
          (item.scope == RemovalScope.whole &&
              ignored.containsIgnored(item.path)))) {
    return RemovalOutcome(
      item,
      RemovalStatus.skipped,
      mode,
      message: 'On your ignore list.',
    );
  }
  final type = await FileSystemEntity.type(item.path, followLinks: false);
  if (type == FileSystemEntityType.notFound) {
    return RemovalOutcome(
      item,
      RemovalStatus.skipped,
      mode,
      message: 'Already gone.',
    );
  }
  if (type == FileSystemEntityType.link) {
    return RemovalOutcome(
      item,
      RemovalStatus.skipped,
      mode,
      message: 'Item is a link; links are not followed or removed.',
    );
  }

  // Targets to act on: the item itself, or its direct children.
  final targets = <String>[];
  if (item.scope == RemovalScope.whole) {
    targets.add(item.path);
  } else {
    if (type != FileSystemEntityType.directory) {
      return RemovalOutcome(
        item,
        RemovalStatus.skipped,
        mode,
        message: 'Expected a folder.',
      );
    }
    try {
      await for (final child in Directory(item.path).list(followLinks: false)) {
        // Links are never removed: the Trash (Finder, Recycle Bin) acts on
        // what a link points to, which could be a personal folder.
        if (child is Link) continue;
        if (item.keepNames.contains(p.basename(child.path))) continue;
        if (ignored != null &&
            (ignored.covers(child.path) ||
                ignored.containsIgnored(child.path))) {
          continue;
        }
        targets.add(child.path);
      }
    } on FileSystemException catch (error) {
      return RemovalOutcome(
        item,
        RemovalStatus.failed,
        mode,
        message: error.message,
      );
    }
  }
  if (targets.isEmpty) {
    return RemovalOutcome(
      item,
      RemovalStatus.skipped,
      mode,
      message: 'Nothing to remove.',
    );
  }

  if (dryRun) {
    var bytes = 0;
    for (final target in targets) {
      bytes += await measureBytes(target);
    }
    return RemovalOutcome(
      item,
      RemovalStatus.previewed,
      mode,
      message:
          'Would ${mode == RemovalMode.trash ? 'move to the bin' : 'delete permanently'} '
          '${targets.length} ${targets.length == 1 ? 'entry' : 'entries'} '
          '(about ${_formatSize(bytes)}).',
    );
  }

  var failures = 0;
  var freed = 0;
  String? lastError;
  if (mode == RemovalMode.trash) {
    final results = await backend.moveToTrash(targets);
    for (final target in targets) {
      final error = results[target];
      if (error != null) {
        failures++;
        lastError = error;
      }
    }
  } else {
    for (final target in targets) {
      final size = await measureBytes(target);
      try {
        final childType = await FileSystemEntity.type(
          target,
          followLinks: false,
        );
        if (childType == FileSystemEntityType.directory) {
          // recursive delete removes links themselves, not their targets.
          await Directory(target).delete(recursive: true);
        } else if (childType == FileSystemEntityType.link) {
          await Link(target).delete();
        } else if (childType == FileSystemEntityType.file) {
          await File(target).delete();
        }
        freed += size;
      } on FileSystemException catch (error) {
        // Partially deleted folders still freed some space.
        final remaining = await measureBytes(target);
        freed += (size - remaining).clamp(0, size).toInt();
        failures++;
        lastError = error.osError?.message ?? error.message;
      }
    }
  }
  final status = failures == 0
      ? (mode == RemovalMode.trash
            ? RemovalStatus.movedToTrash
            : RemovalStatus.removed)
      : failures == targets.length
      ? RemovalStatus.failed
      : RemovalStatus.partial;
  return RemovalOutcome(
    item,
    status,
    mode,
    freedBytes: freed,
    message: failures == 0
        ? null
        : '$failures of ${targets.length} entries could not be removed'
              '${lastError == null ? '' : ' (${lastError.trim()})'}. '
              'They may be in use; close the app that uses them and try again.',
  );
}

String _formatSize(int bytes) {
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  double value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}
