import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';

class LargeFile {
  const LargeFile(this.path, this.bytes);
  final String path;
  final int bytes;
}

class FolderScanResult {
  const FolderScanResult(
    this.files,
    this.skipped,
    this.cancelled, {
    this.duplicates = const [],
    this.devFolders = const [],
  });
  final List<LargeFile> files;
  final int skipped;
  final bool cancelled;
  final List<List<LargeFile>> duplicates;
  final List<DevFolder> devFolders;
}

class DevFolder {
  const DevFolder(
    this.path,
    this.category,
    this.note, {
    this.logicalBytes = 0,
    this.projectMarker,
    this.modified,
    this.locationSource,
  });
  final String path;
  final String category;
  final String note;
  final int logicalBytes;
  final String? projectMarker;
  final DateTime? modified;
  final String? locationSource;
}

/// Candidates only; a tool's config file or command-line flags may override these paths.
List<DevFolder> globalCacheCandidates(
  Map<String, String> env, {
  required bool windows,
}) {
  String? absolute(String? value) =>
      value != null && value.trim().isNotEmpty && p.isAbsolute(value)
      ? p.normalize(value)
      : null;
  final home = absolute(env[windows ? 'USERPROFILE' : 'HOME']);
  final localAppData = windows ? absolute(env['LOCALAPPDATA']) : null;
  final gradleOverride = absolute(env['GRADLE_USER_HOME']);
  final cargoOverride = absolute(env['CARGO_HOME']);
  final pubOverride = absolute(env['PUB_CACHE']);
  bool configured(String name) => (env[name]?.trim().isNotEmpty ?? false);
  final gradleHome = configured('GRADLE_USER_HOME')
      ? gradleOverride
      : (home == null ? null : p.join(home, '.gradle'));
  final cargoHome = configured('CARGO_HOME')
      ? cargoOverride
      : (home == null ? null : p.join(home, '.cargo'));
  final pubHome = configured('PUB_CACHE')
      ? pubOverride
      : (windows
            ? (localAppData == null
                  ? null
                  : p.join(localAppData, 'Pub', 'Cache'))
            : (home == null ? null : p.join(home, '.pub-cache')));
  return [
    if (gradleHome != null)
      DevFolder(
        p.join(gradleHome, 'caches'),
        'Gradle global caches',
        'Shared build caches may be in use; builds may need to regenerate or download data.',
        locationSource: gradleOverride == null
            ? 'Default location; other tool configuration may override it'
            : 'GRADLE_USER_HOME environment variable',
      ),
    if (cargoHome != null)
      DevFolder(
        p.join(cargoHome, 'registry', 'cache'),
        'Cargo registry archive cache',
        'Downloaded dependencies may be needed for offline builds.',
        locationSource: cargoOverride == null
            ? 'Default location; other tool configuration may override it'
            : 'CARGO_HOME environment variable',
      ),
    if (pubHome != null)
      DevFolder(
        pubHome,
        'Dart / Flutter package cache',
        'Projects may need to fetch dependencies again; cached content may be shared.',
        locationSource: pubOverride == null
            ? 'Default location; other tool configuration may override it'
            : 'PUB_CACHE environment variable',
      ),
  ];
}

Future<DevFolder?> classifyDevFolder(String path) async {
  final parent = p.dirname(path);
  final name = p.basename(path);
  Future<bool> hasMarker(String filename) async =>
      await FileSystemEntity.type(
        p.join(parent, filename),
        followLinks: false,
      ) ==
      FileSystemEntityType.file;
  if (name == 'node_modules' && await hasMarker('package.json')) {
    return DevFolder(
      path,
      'Node.js dependencies',
      'Reinstalling may require network access and can change the working environment.',
      projectMarker: p.join(parent, 'package.json'),
    );
  }
  if (name == 'target' && await hasMarker('Cargo.toml')) {
    return DevFolder(
      path,
      'Rust build output',
      'Build output is recreated by future builds, which may take longer.',
      projectMarker: p.join(parent, 'Cargo.toml'),
    );
  }
  if (name == '.dart_tool' && await hasMarker('pubspec.yaml')) {
    return DevFolder(
      path,
      'Dart / Flutter project data',
      'Tooling may need to resolve dependencies again.',
      projectMarker: p.join(parent, 'pubspec.yaml'),
    );
  }
  if (name == '.gradle') {
    for (final marker in [
      'settings.gradle',
      'settings.gradle.kts',
      'build.gradle',
      'build.gradle.kts',
    ]) {
      if (await hasMarker(marker)) {
        return DevFolder(
          path,
          'Gradle project cache',
          'Gradle may need to rebuild caches and download dependencies.',
          projectMarker: p.join(parent, marker),
        );
      }
    }
  }
  if (name == '.build' && await hasMarker('Package.swift')) {
    return DevFolder(
      path,
      'Swift package build output',
      'Build output may need to be regenerated and dependencies fetched.',
      projectMarker: p.join(parent, 'Package.swift'),
    );
  }
  if (name == 'Pods') {
    for (final marker in ['Podfile', 'Podfile.lock']) {
      if (await hasMarker(marker)) {
        return DevFolder(
          path,
          'CocoaPods dependencies',
          'Reinstalling pods may require network access and compatible tool versions.',
          projectMarker: p.join(parent, marker),
        );
      }
    }
  }
  if (name == '.pytest_cache' || name == '.mypy_cache') {
    for (final marker in [
      'pyproject.toml',
      'setup.py',
      'setup.cfg',
      'pytest.ini',
      'mypy.ini',
    ]) {
      if (await hasMarker(marker)) {
        return DevFolder(
          path,
          'Python tool cache',
          'The tool may need to recompute cached data.',
          projectMarker: p.join(parent, marker),
        );
      }
    }
  }
  return null;
}

class _Candidate {
  const _Candidate(this.path, this.size, this.modified);
  final String path;
  final int size;
  final DateTime modified;
}

class _DigestSink implements Sink<Digest> {
  Digest? digest;
  @override
  void add(Digest value) => digest = value;
  @override
  void close() {}
}

abstract interface class FolderScanner {
  Future<FolderScanResult> scan(
    String path,
    bool Function() cancelled, {
    List<String> exclusions = const [],
    bool findDuplicates = false,
    bool findDevFolders = false,
  });
}

class LocalFolderScanner implements FolderScanner {
  LocalFolderScanner({Map<String, String>? environment, bool? windows})
    : environment = environment ?? Platform.environment,
      windows = windows ?? Platform.isWindows;
  final Map<String, String> environment;
  final bool windows;
  @override
  Future<FolderScanResult> scan(
    String path,
    bool Function() cancelled, {
    List<String> exclusions = const [],
    bool findDuplicates = false,
    bool findDevFolders = false,
  }) async {
    final excluded = exclusions
        .map((path) => p.normalize(p.absolute(path)))
        .toList(growable: false);
    bool isExcluded(String path) {
      final candidate = p.normalize(p.absolute(path));
      return excluded.any(
        (entry) => p.equals(entry, candidate) || p.isWithin(entry, candidate),
      );
    }

    final root = Directory(path);
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FileSystemException(
        'Selected folder is unavailable or is a link.',
      );
    }
    final pending = <Directory>[root];
    final files = <LargeFile>[];
    final candidates = <int, List<_Candidate>>{};
    var candidateCount = 0;
    final devFolders = <DevFolder>[];
    final globalCaches = findDevFolders
        ? globalCacheCandidates(environment, windows: windows)
        : <DevFolder>[];
    final folderBytes = <String, int>{};
    var skipped = 0;
    Future<void> recordDevFolder(
      DevFolder candidate,
      FileSystemEntity entity,
    ) async {
      if (devFolders.length >= 200) {
        skipped++;
        return;
      }
      final info = await entity.stat();
      devFolders.add(
        DevFolder(
          candidate.path,
          candidate.category,
          candidate.note,
          projectMarker: candidate.projectMarker,
          modified: info.modified,
          locationSource: candidate.locationSource,
        ),
      );
      folderBytes[candidate.path] = 0;
    }

    DevFolder? globalFor(String path) {
      for (final candidate in globalCaches) {
        if (p.equals(
          p.normalize(p.absolute(path)),
          p.normalize(candidate.path),
        )) {
          return candidate;
        }
      }
      return null;
    }

    if (findDevFolders && !isExcluded(root.path)) {
      final match = globalFor(root.path);
      if (match != null) await recordDevFolder(match, root);
    }
    while (pending.isNotEmpty && !cancelled()) {
      final directory = pending.removeLast();
      if (isExcluded(directory.path)) continue;
      try {
        if (await FileSystemEntity.type(directory.path, followLinks: false) !=
            FileSystemEntityType.directory) {
          skipped++;
          continue;
        }
        await for (final entity in directory.list(followLinks: false)) {
          if (cancelled()) break;
          if (isExcluded(entity.path)) continue;
          try {
            final type = await FileSystemEntity.type(
              entity.path,
              followLinks: false,
            );
            if (type == FileSystemEntityType.directory) {
              if (findDevFolders) {
                final detected =
                    globalFor(entity.path) ??
                    await classifyDevFolder(entity.path);
                if (detected != null) {
                  await recordDevFolder(detected, entity);
                }
              }
              pending.add(Directory(entity.path));
            } else if (type == FileSystemEntityType.file) {
              final stat = await entity.stat();
              if (stat.type == FileSystemEntityType.file) {
                if (findDevFolders) {
                  for (final folder in devFolders) {
                    if (p.isWithin(folder.path, entity.path)) {
                      folderBytes[folder.path] =
                          folderBytes[folder.path]! + stat.size;
                    }
                  }
                }
                if (findDuplicates) {
                  if (candidateCount < 20000) {
                    candidates
                        .putIfAbsent(stat.size, () => [])
                        .add(_Candidate(entity.path, stat.size, stat.modified));
                    candidateCount++;
                  } else {
                    skipped++;
                  }
                }
                if (files.length < 100 || stat.size > files.last.bytes) {
                  files.add(LargeFile(entity.path, stat.size));
                  files.sort((a, b) => b.bytes.compareTo(a.bytes));
                  if (files.length > 100) files.removeLast();
                }
              } else {
                skipped++;
              }
            } else {
              skipped++;
            }
          } on FileSystemException {
            skipped++;
          }
        }
      } on FileSystemException {
        skipped++;
      }
    }
    files.sort((a, b) => b.bytes.compareTo(a.bytes));
    final matches = <String, List<LargeFile>>{};
    if (findDuplicates && !cancelled()) {
      for (final group in candidates.values.where(
        (group) => group.length > 1,
      )) {
        for (final candidate in group) {
          if (cancelled()) break;
          try {
            if (await FileSystemEntity.type(
                  candidate.path,
                  followLinks: false,
                ) !=
                FileSystemEntityType.file) {
              skipped++;
              continue;
            }
            final before = await File(candidate.path).stat();
            if (before.size != candidate.size ||
                before.modified != candidate.modified) {
              skipped++;
              continue;
            }
            final output = _DigestSink();
            final hash = sha256.startChunkedConversion(output);
            await for (final bytes in File(candidate.path).openRead()) {
              if (cancelled()) break;
              hash.add(bytes);
            }
            hash.close();
            if (cancelled()) break;
            final afterType = await FileSystemEntity.type(
              candidate.path,
              followLinks: false,
            );
            final after = await File(candidate.path).stat();
            if (afterType != FileSystemEntityType.file ||
                after.size != candidate.size ||
                after.modified != candidate.modified) {
              skipped++;
              continue;
            }
            final key = '${candidate.size}:${output.digest}';
            matches
                .putIfAbsent(key, () => [])
                .add(LargeFile(candidate.path, candidate.size));
          } on FileSystemException {
            skipped++;
          }
        }
        if (cancelled()) break;
      }
    }
    return FolderScanResult(
      List.unmodifiable(files.take(100)),
      skipped,
      cancelled(),
      duplicates: List.unmodifiable(
        matches.values
            .where((group) => group.length > 1)
            .map((group) => List<LargeFile>.unmodifiable(group)),
      ),
      devFolders: List.unmodifiable(
        devFolders.map(
          (folder) => DevFolder(
            folder.path,
            folder.category,
            folder.note,
            logicalBytes: folderBytes[folder.path]!,
            projectMarker: folder.projectMarker,
            modified: folder.modified,
            locationSource: folder.locationSource,
          ),
        ),
      ),
    );
  }
}

class FolderScanViewModel extends ChangeNotifier {
  FolderScanViewModel(this.scanner, this.pickFolder);
  final FolderScanner scanner;
  final Future<String?> Function() pickFolder;
  bool busy = false;
  bool pickingExclusion = false;
  bool _cancelled = false;
  bool _disposed = false;
  String? root;
  String? error;
  FolderScanResult? result;
  bool findDuplicates = false;
  bool findDevFolders = false;
  final List<String> _exclusions = [];
  List<String> get exclusions => List.unmodifiable(_exclusions);

  Future<void> addExclusion() async {
    if (busy) return;
    busy = true;
    pickingExclusion = true;
    error = null;
    notifyListeners();
    try {
      final selected = await pickFolder();
      if (_disposed || selected == null) return;
      final normalized = p.normalize(p.absolute(selected));
      if (!_exclusions.any((value) => p.equals(value, normalized))) {
        _exclusions.add(normalized);
        result = null;
        root = null;
      }
    } catch (_) {
      error = 'Unable to select a folder. Try again.';
    } finally {
      if (!_disposed) {
        busy = false;
        pickingExclusion = false;
        notifyListeners();
      }
    }
  }

  void removeExclusion(String path) {
    if (busy) return;
    _exclusions.remove(path);
    result = null;
    root = null;
    notifyListeners();
  }

  Future<void> start() async {
    if (busy) return;
    busy = true;
    _cancelled = false;
    error = null;
    result = null;
    root = null;
    notifyListeners();
    try {
      final selected = await pickFolder();
      if (_disposed || _cancelled || selected == null) return;
      root = selected;
      notifyListeners();
      result = await scanner.scan(
        selected,
        () => _cancelled || _disposed,
        exclusions: List.unmodifiable(_exclusions),
        findDuplicates: findDuplicates,
        findDevFolders: findDevFolders,
      );
    } catch (_) {
      error = 'Unable to scan this folder. Check access and try again.';
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void cancel() {
    _cancelled = true;
    notifyListeners();
  }

  void setFindDuplicates(bool value) {
    if (busy) return;
    findDuplicates = value;
    result = null;
    root = null;
    notifyListeners();
  }

  void setFindDevFolders(bool value) {
    if (busy) return;
    findDevFolders = value;
    result = null;
    root = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelled = true;
    super.dispose();
  }
}

Future<String?> chooseFolder() =>
    getDirectoryPath(confirmButtonText: 'Choose folder');
