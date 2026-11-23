import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';

import 'package:cleanverse/src/features/developer/cleanup_plan.dart';

class LargeFile {
  const LargeFile(this.path, this.bytes, {this.modified});
  final String path;
  final int bytes;

  /// Last modification time observed during the scan, if known. This is not
  /// a last-opened time; access times are unreliable across platforms.
  final DateTime? modified;
}

@immutable
class StorageCategory {
  const StorageCategory(this.label, this.bytes, this.fileCount);
  final String label;
  final int bytes;
  final int fileCount;
}

@immutable
class FolderSummary {
  const FolderSummary(
    this.label,
    this.bytes,
    this.fileCount, {
    this.folderPath,
  });
  final String label;
  final int bytes;
  final int fileCount;
  final String? folderPath;
}

String categoryForPath(String path) {
  final extension = p.extension(path).toLowerCase();
  if (const {
    '.pdb',
    '.dill',
    '.obj',
    '.o',
    '.a',
    '.lib',
    '.exp',
    '.ilk',
    '.pch',
    '.ipch',
    '.class',
    '.pyc',
    '.dex',
    '.tlog',
  }.contains(extension)) {
    return 'Build output';
  }
  if (const {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.heic',
    '.svg',
    '.raw',
    '.tif',
    '.tiff',
  }.contains(extension)) {
    return 'Images';
  }
  if (const {
    '.mp4',
    '.mov',
    '.mkv',
    '.avi',
    '.webm',
    '.m4v',
  }.contains(extension)) {
    return 'Videos';
  }
  if (const {
    '.mp3',
    '.wav',
    '.m4a',
    '.flac',
    '.ogg',
    '.aac',
  }.contains(extension)) {
    return 'Audio';
  }
  if (const {
    '.pdf',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.odt',
    '.ods',
    '.txt',
    '.rtf',
  }.contains(extension)) {
    return 'Documents';
  }
  if (const {
    '.zip',
    '.gz',
    '.tar',
    '.7z',
    '.rar',
    '.bz2',
    '.xz',
    '.dmg',
    '.iso',
  }.contains(extension)) {
    return 'Archives & disk images';
  }
  if (const {
    '.dart',
    '.swift',
    '.kt',
    '.java',
    '.py',
    '.rs',
    '.go',
    '.js',
    '.ts',
    '.tsx',
    '.jsx',
    '.c',
    '.cc',
    '.cpp',
    '.h',
    '.hpp',
    '.css',
    '.html',
    '.json',
    '.yaml',
    '.yml',
    '.toml',
    '.xml',
    '.sh',
    '.sql',
  }.contains(extension)) {
    return 'Code & configuration';
  }
  return 'Other';
}

class FolderScanResult {
  const FolderScanResult(
    this.files,
    this.skipped,
    this.cancelled, {
    this.duplicates = const [],
    this.devFolders = const [],
    this.storageCategories = const [],
    this.folderSummaries = const [],
    this.filesSeen = 0,
    this.totalBytes = 0,
  });
  final List<LargeFile> files;

  /// Number of regular files observed in the scanned scope.
  final int filesSeen;

  /// Sum of logical file sizes observed. Not physical or reclaimable space.
  final int totalBytes;
  final int skipped;
  final bool cancelled;
  final List<List<LargeFile>> duplicates;
  final List<DevFolder> devFolders;
  final List<StorageCategory> storageCategories;
  final List<FolderSummary> folderSummaries;
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
    this.risk = CleanupRisk.review,
  });
  final String path;
  final String category;
  final String note;
  final int logicalBytes;
  final String? projectMarker;
  final DateTime? modified;
  final String? locationSource;
  final CleanupRisk risk;
}

/// Candidates only; a tool's config file or command-line flags may override these paths.
List<DevFolder> globalCacheCandidates(
  Map<String, String> env, {
  required bool windows,
  bool macos = false,
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
  final npmValue = env['npm_config_cache'] ?? env['NPM_CONFIG_CACHE'];
  final npmOverride = absolute(npmValue);
  final pipOverride = absolute(env['PIP_CACHE_DIR']);
  final moduleOverride = absolute(env['GOMODCACHE']);
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
  final npmConfigured = npmValue?.trim().isNotEmpty ?? false;
  final npmHome = npmConfigured
      ? npmOverride
      : (windows
            ? (localAppData == null ? null : p.join(localAppData, 'npm-cache'))
            : (home == null ? null : p.join(home, '.npm')));
  final xcodeHome = macos && home != null
      ? p.join(home, 'Library', 'Developer', 'Xcode')
      : null;
  final xdgConfigured = configured('XDG_CACHE_HOME');
  final xdgCache = absolute(env['XDG_CACHE_HOME']);
  final pipHome = configured('PIP_CACHE_DIR')
      ? pipOverride
      : windows
      ? (localAppData == null ? null : p.join(localAppData, 'pip', 'Cache'))
      : xdgConfigured
      ? (xdgCache == null ? null : p.join(xdgCache, 'pip'))
      : macos
      ? (home == null ? null : p.join(home, 'Library', 'Caches', 'pip'))
      : (home == null ? null : p.join(home, '.cache', 'pip'));
  final pathList = env['GOPATH'];
  final firstGoPath = configured('GOPATH')
      ? absolute(pathList!.split(windows ? ';' : ':').first)
      : (home == null ? null : p.join(home, 'go'));
  final moduleCache = configured('GOMODCACHE')
      ? moduleOverride
      : (firstGoPath == null ? null : p.join(firstGoPath, 'pkg', 'mod'));
  // Per-user cache root used by many tools: LOCALAPPDATA on Windows,
  // ~/Library/Caches on macOS, XDG_CACHE_HOME or ~/.cache elsewhere.
  // An invalid XDG_CACHE_HOME is not replaced by a default.
  final userCache = windows
      ? localAppData
      : macos
      ? (home == null ? null : p.join(home, 'Library', 'Caches'))
      : xdgConfigured
      ? xdgCache
      : (home == null ? null : p.join(home, '.cache'));
  const defaultSource =
      'Default location; other tool configuration may override it';
  const unverifiedSource =
      'Conventional location (not confirmed in tool documentation); configuration may differ';
  String? pick(String name, String? fallback) =>
      configured(name) ? absolute(env[name]) : fallback;
  String source(String name, String fallback) =>
      configured(name) ? '$name environment variable' : fallback;
  String? under(String? base, List<String> parts) =>
      base == null ? null : p.joinAll([base, ...parts]);
  final extra = <DevFolder>[];
  void add(
    String? path,
    String category,
    String note,
    String locationSource, {
    CleanupRisk risk = CleanupRisk.review,
  }) {
    if (path == null) return;
    extra.add(
      DevFolder(
        path,
        category,
        note,
        locationSource: locationSource,
        risk: risk,
      ),
    );
  }

  add(
    pick(
      'YARN_CACHE_FOLDER',
      windows
          ? under(localAppData, ['Yarn', 'Cache'])
          : macos
          ? under(home, ['Library', 'Caches', 'Yarn'])
          : under(userCache, ['yarn']),
    ),
    'Yarn classic package cache',
    'Packages may need to be downloaded again; offline installs can stop working.',
    source('YARN_CACHE_FOLDER', unverifiedSource),
  );
  add(
    under(pick('YARN_GLOBAL_FOLDER', under(home, ['.yarn', 'berry'])), [
      'cache',
    ]),
    'Yarn (Berry) global cache',
    'Projects without their own offline cache will download packages again.',
    source('YARN_GLOBAL_FOLDER', defaultSource),
  );
  final pnpmStore = configured('PNPM_HOME')
      ? under(absolute(env['PNPM_HOME']), ['store'])
      : configured('XDG_DATA_HOME')
      ? under(absolute(env['XDG_DATA_HOME']), ['pnpm', 'store'])
      : windows
      ? under(localAppData, ['pnpm', 'store'])
      : macos
      ? under(home, ['Library', 'pnpm', 'store'])
      : under(home, ['.local', 'share', 'pnpm', 'store']);
  add(
    pnpmStore,
    'pnpm content store',
    'Projects hard-link files from this store, so sizes may be counted twice; pnpm store prune is the tool\'s own cleanup.',
    configured('PNPM_HOME')
        ? 'PNPM_HOME environment variable'
        : configured('XDG_DATA_HOME')
        ? 'XDG_DATA_HOME environment variable'
        : defaultSource,
  );
  add(
    pick('BUN_INSTALL_CACHE_DIR', under(home, ['.bun', 'install', 'cache'])),
    'Bun install cache',
    'Packages may need to be downloaded again on the next install.',
    source('BUN_INSTALL_CACHE_DIR', defaultSource),
  );
  if (macos) {
    add(
      pick('CP_CACHE_DIR', under(home, ['Library', 'Caches', 'CocoaPods'])),
      'CocoaPods download cache',
      'Pods may need to be downloaded again; spec repos are stored elsewhere and are not included.',
      source('CP_CACHE_DIR', defaultSource),
    );
    add(
      under(home, ['Library', 'Caches', 'org.carthage.CarthageKit']),
      'Carthage cache',
      'Dependencies may need to be fetched or built again.',
      unverifiedSource,
    );
    add(
      under(home, ['Library', 'Caches', 'org.swift.swiftpm']),
      'Swift Package Manager cache',
      'Package repositories may need to be cloned again; first builds may be slower.',
      unverifiedSource,
    );
  }
  add(
    under(home, ['.m2', 'repository']),
    'Maven local repository',
    'Also holds artifacts you built with mvn install that may not exist anywhere else.',
    'Default location; Maven settings.xml may override it',
    risk: CleanupRisk.potentiallyImportant,
  );
  add(
    pick('NUGET_PACKAGES', under(home, ['.nuget', 'packages'])),
    'NuGet global packages',
    'Projects must restore packages again; open solutions may hold files in use.',
    source('NUGET_PACKAGES', defaultSource),
  );
  add(
    pick('GOCACHE', under(userCache, ['go-build'])),
    'Go build cache',
    'Builds and tests run slower until the cache is rebuilt.',
    source('GOCACHE', 'Default location; go env -w may override it'),
  );
  final composerCache = configured('COMPOSER_CACHE_DIR')
      ? absolute(env['COMPOSER_CACHE_DIR'])
      : windows
      ? under(localAppData, ['Composer'])
      : configured('COMPOSER_HOME')
      ? under(absolute(env['COMPOSER_HOME']), ['cache'])
      : !macos && xdgConfigured
      ? under(xdgCache, ['composer'])
      : under(home, ['.composer', 'cache']);
  add(
    composerCache,
    'Composer package cache',
    'PHP packages may need to be downloaded again.',
    configured('COMPOSER_CACHE_DIR')
        ? 'COMPOSER_CACHE_DIR environment variable'
        : configured('COMPOSER_HOME') && !windows
        ? 'COMPOSER_HOME environment variable'
        : defaultSource,
  );
  add(
    pick('DENO_DIR', under(userCache, ['deno'])),
    'Deno cache',
    'Remote modules and npm packages may need to be downloaded again.',
    source('DENO_DIR', defaultSource),
  );
  add(
    pick('PLAYWRIGHT_BROWSERS_PATH', under(userCache, ['ms-playwright'])),
    'Playwright browsers',
    'Browsers must be downloaded again with playwright install before tests run.',
    source('PLAYWRIGHT_BROWSERS_PATH', defaultSource),
  );
  add(
    pick('PUPPETEER_CACHE_DIR', under(home, ['.cache', 'puppeteer'])),
    'Puppeteer browsers',
    'Browsers must be downloaded again before Puppeteer can run.',
    source('PUPPETEER_CACHE_DIR', defaultSource),
  );
  final hfHub = configured('HF_HUB_CACHE')
      ? absolute(env['HF_HUB_CACHE'])
      : configured('HF_HOME')
      ? under(absolute(env['HF_HOME']), ['hub'])
      : xdgConfigured
      ? under(xdgCache, ['huggingface', 'hub'])
      : under(home, ['.cache', 'huggingface', 'hub']);
  add(
    hfHub,
    'Hugging Face hub cache',
    'Models and datasets can be very large and slow or costly to download again; gated or removed repos may be unavailable.',
    configured('HF_HUB_CACHE')
        ? 'HF_HUB_CACHE environment variable'
        : configured('HF_HOME')
        ? 'HF_HOME environment variable'
        : defaultSource,
    risk: CleanupRisk.potentiallyImportant,
  );
  add(
    under(userCache, ['JetBrains']),
    'JetBrains IDE caches',
    'Indexes rebuild, but this folder can also hold Local History and logs that cannot be recreated.',
    unverifiedSource,
    risk: CleanupRisk.potentiallyImportant,
  );
  final codeUser = windows
      ? under(absolute(env['APPDATA']), ['Code'])
      : macos
      ? under(home, ['Library', 'Application Support', 'Code'])
      : configured('XDG_CONFIG_HOME')
      ? under(absolute(env['XDG_CONFIG_HOME']), ['Code'])
      : under(home, ['.config', 'Code']);
  add(
    under(codeUser, ['CachedData']),
    'VS Code compiled code cache',
    'VS Code may start slower once; close it first.',
    unverifiedSource,
  );
  add(
    under(codeUser, ['CachedExtensionVSIXs']),
    'VS Code downloaded extension packages',
    'Installed extensions stay; packages may be downloaded again on update.',
    unverifiedSource,
  );
  add(
    pick(
      'ELECTRON_CACHE',
      windows
          ? under(localAppData, ['electron', 'Cache'])
          : under(userCache, ['electron']),
    ),
    'Electron download cache',
    'Electron binaries may need to be downloaded again on install.',
    source('ELECTRON_CACHE', unverifiedSource),
  );
  add(
    windows
        ? under(localAppData, ['node-gyp', 'Cache'])
        : under(userCache, ['node-gyp']),
    'node-gyp headers cache',
    'Node headers may need to be downloaded again for native module builds.',
    unverifiedSource,
  );
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
    if (npmHome != null)
      DevFolder(
        p.join(npmHome, '_cacache'),
        'npm content cache',
        'This shared cache can support offline installs; packages may need to be downloaded again.',
        locationSource: npmConfigured
            ? 'npm_config_cache environment variable'
            : 'Default location; other tool configuration may override it',
      ),
    if (pipHome != null)
      DevFolder(
        pipHome,
        'Python pip package cache',
        'Packages may need to be downloaded again; cached content may be shared.',
        locationSource: configured('PIP_CACHE_DIR')
            ? 'PIP_CACHE_DIR environment variable'
            : xdgConfigured && !windows
            ? 'XDG_CACHE_HOME candidate; pip version and configuration may differ'
            : 'Default location; other tool configuration may override it',
      ),
    if (moduleCache != null)
      DevFolder(
        moduleCache,
        'Go module cache',
        'Modules may be shared by projects and required for offline builds; contents can include private code.',
        locationSource: configured('GOMODCACHE')
            ? 'GOMODCACHE environment variable'
            : configured('GOPATH')
            ? 'First GOPATH entry; Go configuration may override it'
            : 'Default location; Go configuration may override it',
      ),
    ...extra,
    if (xcodeHome != null)
      DevFolder(
        p.join(xcodeHome, 'DerivedData'),
        'Xcode derived data',
        'Build data may be recreated, but active builds can be disrupted and future builds may take longer.',
        locationSource:
            'Possible default location; Xcode settings may use another path',
      ),
    if (xcodeHome != null)
      DevFolder(
        p.join(xcodeHome, 'Archives'),
        'Xcode archives',
        'Archives can contain unique release builds and debug symbols. Do not assume they can be recreated.',
        locationSource:
            'Possible default location; Xcode settings may use another path',
        risk: CleanupRisk.potentiallyImportant,
      ),
    if (xcodeHome != null)
      DevFolder(
        p.join(xcodeHome, 'iOS DeviceSupport'),
        'Xcode iOS device support',
        'May contain device debugging symbols. Removing it can require Xcode to copy them again and affect debugging.',
        locationSource:
            'Conventional location; Xcode versions and settings may differ',
      ),
    if (macos && home != null)
      DevFolder(
        p.join(home, 'Library', 'Developer', 'CoreSimulator', 'Devices'),
        'Simulator device data',
        'May contain simulator apps, settings and user data. Do not assume this data can be recreated.',
        locationSource:
            'Conventional location; Simulator versions and settings may differ',
        risk: CleanupRisk.potentiallyImportant,
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

class _WalkDir {
  const _WalkDir(this.path, this.top, this.devFolders);
  final String path;
  final String? top;
  final List<String> devFolders;
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

enum ScanPhase { discovering, comparing }

@immutable
class ScanProgress {
  const ScanProgress(this.phase, this.filesSeen, this.compared, this.toCompare);
  final ScanPhase phase;
  final int filesSeen;
  final int compared;
  final int toCompare;
}

abstract interface class FolderScanner {
  Future<FolderScanResult> scan(
    String path,
    bool Function() cancelled, {
    List<String> exclusions = const [],
    bool findDuplicates = false,
    bool findDevFolders = false,
    void Function(ScanProgress)? onProgress,
    void Function(FolderScanResult partial)? onPartial,
  });
}

class LocalFolderScanner implements FolderScanner {
  LocalFolderScanner({
    Map<String, String>? environment,
    bool? windows,
    bool? macos,
  }) : environment = environment ?? Platform.environment,
       windows = windows ?? Platform.isWindows,
       macos = macos ?? Platform.isMacOS;
  final Map<String, String> environment;
  final bool windows;
  final bool macos;

  /// Folders read at the same time.
  static const parallelism = 8;

  /// How often [scan] reports results so far through `onPartial`.
  static const partialInterval = Duration(milliseconds: 1500);

  @override
  Future<FolderScanResult> scan(
    String path,
    bool Function() cancelled, {
    List<String> exclusions = const [],
    bool findDuplicates = false,
    bool findDevFolders = false,
    void Function(ScanProgress)? onProgress,
    void Function(FolderScanResult partial)? onPartial,
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
    final files = <LargeFile>[];
    final candidates = <int, List<_Candidate>>{};
    var candidateCount = 0;
    final devFolders = <DevFolder>[];
    final globalCaches = findDevFolders
        ? globalCacheCandidates(environment, windows: windows, macos: macos)
        : <DevFolder>[];
    // Normalized once; looked up for every directory.
    final globalByPath = {
      for (final c in globalCaches) p.normalize(p.absolute(c.path)): c,
    };
    final folderBytes = <String, int>{};
    var skipped = 0;
    var filesSeen = 0;
    final categoryBytes = <String, int>{};
    final categoryCounts = <String, int>{};
    final topFolderBytes = <String, int>{};
    final topFolderCounts = <String, int>{};
    var rootBytes = 0;
    var rootCount = 0;
    var overflowBytes = 0;
    var overflowCount = 0;
    onProgress?.call(const ScanProgress(ScanPhase.discovering, 0, 0, 0));

    /// Records a developer folder; false when the cap is reached.
    Future<bool> recordDevFolder(
      DevFolder candidate,
      FileSystemEntity entity,
    ) async {
      if (devFolders.length >= 200) {
        skipped++;
        return false;
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
          risk: candidate.risk,
        ),
      );
      folderBytes[candidate.path] = 0;
      return true;
    }

    DevFolder? globalFor(String path) =>
        globalByPath.isEmpty ? null : globalByPath[p.normalize(path)];

    void offerFile(LargeFile file) {
      if (files.length >= 100 && file.bytes <= files.last.bytes) return;
      // Keep the list sorted, largest first, at most 100 entries.
      var i = files.length;
      while (i > 0 && files[i - 1].bytes < file.bytes) {
        i--;
      }
      files.insert(i, file);
      if (files.length > 100) files.removeLast();
    }

    FolderScanResult snapshot([
      Map<String, List<LargeFile>> matches = const {},
    ]) => FolderScanResult(
      List.unmodifiable(files.take(100)),
      skipped,
      cancelled(),
      filesSeen: filesSeen,
      totalBytes: categoryBytes.values.fold<int>(0, (sum, v) => sum + v),
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
            risk: folder.risk,
          ),
        ),
      ),
      storageCategories: List.unmodifiable(
        (categoryBytes.entries
            .map(
              (entry) => StorageCategory(
                entry.key,
                entry.value,
                categoryCounts[entry.key]!,
              ),
            )
            .toList()
          ..sort((a, b) => b.bytes.compareTo(a.bytes))),
      ),
      folderSummaries: List.unmodifiable(
        ([
          for (final entry in topFolderBytes.entries)
            FolderSummary(
              entry.key,
              entry.value,
              topFolderCounts[entry.key]!,
              folderPath: entry.key,
            ),
          if (rootCount > 0)
            FolderSummary(
              'Files directly in selected folder',
              rootBytes,
              rootCount,
            ),
          if (overflowCount > 0)
            FolderSummary(
              'Other folders (more than 5,000)',
              overflowBytes,
              overflowCount,
            ),
        ]..sort((a, b) => b.bytes.compareTo(a.bytes))).take(20),
      ),
    );

    var rootDev = const <String>[];
    if (findDevFolders && !isExcluded(root.path)) {
      final match = globalFor(root.path);
      if (match != null && await recordDevFolder(match, root)) {
        rootDev = [match.path];
      }
    }

    // Folders still to read. Each carries its top-level folder (null for
    // the selected folder itself) and the developer folders it is inside,
    // so per-file work needs no path arithmetic.
    final queue = <_WalkDir>[_WalkDir(root.path, null, rootDev)];
    var active = 0;
    Completer<void>? wake;
    void wakeAll() {
      final w = wake;
      wake = null;
      w?.complete();
    }

    final noExclusions = excluded.isEmpty;
    var lastPartial = DateTime.now();

    Future<void> visit(_WalkDir dir) async {
      if (!noExclusions && isExcluded(dir.path)) return;
      if (await FileSystemEntity.type(dir.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        skipped++;
        return;
      }
      await for (final entity in Directory(dir.path).list(followLinks: false)) {
        if (cancelled()) break;
        if (!noExclusions && isExcluded(entity.path)) continue;
        try {
          // list(followLinks: false) reports links as Link, never as the
          // file or folder they point to; links are not followed.
          if (entity is Directory) {
            var inside = dir.devFolders;
            if (findDevFolders) {
              final detected =
                  globalFor(entity.path) ??
                  await classifyDevFolder(entity.path);
              if (detected != null && await recordDevFolder(detected, entity)) {
                inside = [...inside, detected.path];
              }
            }
            queue.add(_WalkDir(entity.path, dir.top ?? entity.path, inside));
            wakeAll();
          } else if (entity is File) {
            final stat = await entity.stat();
            if (stat.type != FileSystemEntityType.file) {
              skipped++;
              continue;
            }
            filesSeen++;
            final size = stat.size;
            final category = categoryForPath(entity.path);
            categoryBytes[category] = (categoryBytes[category] ?? 0) + size;
            categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
            final top = dir.top;
            if (top == null) {
              rootBytes += size;
              rootCount++;
            } else if (topFolderBytes.containsKey(top) ||
                topFolderBytes.length < 5000) {
              topFolderBytes[top] = (topFolderBytes[top] ?? 0) + size;
              topFolderCounts[top] = (topFolderCounts[top] ?? 0) + 1;
            } else {
              overflowBytes += size;
              overflowCount++;
            }
            for (final folder in dir.devFolders) {
              folderBytes[folder] = folderBytes[folder]! + size;
            }
            if (findDuplicates) {
              if (candidateCount < 20000) {
                candidates
                    .putIfAbsent(size, () => [])
                    .add(_Candidate(entity.path, size, stat.modified));
                candidateCount++;
              } else {
                skipped++;
              }
            }
            offerFile(LargeFile(entity.path, size, modified: stat.modified));
            if (filesSeen % 128 == 0) {
              onProgress?.call(
                ScanProgress(ScanPhase.discovering, filesSeen, 0, 0),
              );
              final now = DateTime.now();
              if (onPartial != null &&
                  now.difference(lastPartial) > partialInterval) {
                lastPartial = now;
                onPartial(snapshot());
              }
            }
          } else {
            skipped++;
          }
        } on FileSystemException {
          skipped++;
        }
      }
    }

    // A few folders are read at once; the disk and OS caches handle
    // parallel reads much better than one-at-a-time.
    Future<void> worker() async {
      while (!cancelled()) {
        if (queue.isEmpty) {
          if (active == 0) return;
          await (wake ??= Completer<void>()).future;
          continue;
        }
        final dir = queue.removeLast();
        active++;
        try {
          await visit(dir);
        } on FileSystemException {
          skipped++;
        } finally {
          active--;
          if (active == 0 && (queue.isEmpty || cancelled())) wakeAll();
        }
      }
      wakeAll();
    }

    await Future.wait([for (var i = 0; i < parallelism; i++) worker()]);
    final matches = <String, List<LargeFile>>{};
    if (findDuplicates && !cancelled()) {
      final toCompare = candidates.values
          .where((group) => group.length > 1)
          .fold<int>(0, (total, group) => total + group.length);
      var compared = 0;
      onProgress?.call(
        ScanProgress(ScanPhase.comparing, filesSeen, 0, toCompare),
      );
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
          } finally {
            if (!cancelled()) compared++;
            if (!cancelled() && (compared % 16 == 0 || compared == toCompare)) {
              onProgress?.call(
                ScanProgress(
                  ScanPhase.comparing,
                  filesSeen,
                  compared,
                  toCompare,
                ),
              );
            }
          }
        }
        if (cancelled()) break;
      }
    }
    return snapshot(matches);
  }
}

class FolderScanViewModel extends ChangeNotifier {
  FolderScanViewModel(
    this.scanner,
    this.pickFolder, {
    String? Function()? homeFolder,
  }) : homeFolder = homeFolder ?? defaultHomeFolder;
  final FolderScanner scanner;
  final Future<String?> Function() pickFolder;

  /// The default scope for [startDefault]: the user's home folder.
  final String? Function() homeFolder;

  /// Called after a scan of a folder finishes without being cancelled.
  void Function(String root, FolderScanResult result)? onScanCompleted;
  bool busy = false;
  bool pickingExclusion = false;
  bool _cancelled = false;
  bool _disposed = false;
  String? root;
  String? error;
  FolderScanResult? result;

  /// Results so far while a scan runs (null otherwise). Shown on Home so
  /// people see the biggest items before the scan ends.
  FolderScanResult? live;
  ScanProgress? progress;
  bool get cancelling => _cancelled;
  bool findDuplicates = false;
  bool findDevFolders = false;
  final List<String> _navigationHistory = [];
  bool get canGoBack => _navigationHistory.isNotEmpty && !busy;
  final Set<String> _selectedCleanupPaths = {};
  bool isCleanupSelected(String path) => _selectedCleanupPaths.contains(path);
  int get selectedCleanupCount => _selectedCleanupPaths.length;

  CleanupPlan? get cleanupPlan {
    final scan = result;
    final scope = root;
    if (busy ||
        scan == null ||
        scope == null ||
        _selectedCleanupPaths.isEmpty) {
      return null;
    }
    final candidates = scan.devFolders
        .where((folder) => _selectedCleanupPaths.contains(folder.path))
        .map(
          (folder) => CleanupCandidate(
            path: folder.path,
            category: folder.category,
            note: folder.note,
            logicalBytes: folder.logicalBytes,
            risk: folder.risk,
            projectMarker: folder.projectMarker,
            locationSource: folder.locationSource,
          ),
        )
        .toList();
    return CleanupPlan(
      scope: scope,
      partial: scan.cancelled || scan.skipped > 0,
      candidates: candidates,
    );
  }

  void selectCleanupCandidate(String path, bool selected) {
    if (busy ||
        result == null ||
        !result!.devFolders.any((folder) => folder.path == path)) {
      return;
    }
    if (selected) {
      _selectedCleanupPaths.add(path);
    } else {
      _selectedCleanupPaths.remove(path);
    }
    notifyListeners();
  }

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
        _navigationHistory.clear();
        _selectedCleanupPaths.clear();
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
    progress = null;
    _navigationHistory.clear();
    _selectedCleanupPaths.clear();
    notifyListeners();
  }

  /// Scans the user's home folder without asking for a folder. Developer
  /// folder detection is on; duplicate matching is left out (slow).
  Future<void> startDefault() async {
    if (busy) return;
    final home = homeFolder();
    if (home == null || home.isEmpty) {
      error = 'Could not find your home folder. Choose a folder instead.';
      notifyListeners();
      return;
    }
    findDevFolders = true;
    findDuplicates = false;
    await _start(() async => home);
  }

  /// Asks for a folder, then scans it.
  Future<void> start() => _start(pickFolder);

  Future<void> _start(Future<String?> Function() choose) async {
    if (busy) return;
    busy = true;
    _cancelled = false;
    error = null;
    result = null;
    root = null;
    progress = null;
    _navigationHistory.clear();
    _selectedCleanupPaths.clear();
    notifyListeners();
    try {
      final selected = await choose();
      if (_disposed || _cancelled || selected == null) return;
      root = selected;
      notifyListeners();
      await _scanRoot(selected);
    } catch (_) {
      error = 'Unable to scan this folder. Check access and try again.';
    } finally {
      if (!_disposed) {
        busy = false;
        progress = null;
        notifyListeners();
      }
    }
  }

  Future<void> _scanRoot(String selected) async {
    final scanned = await scanner.scan(
      selected,
      () => _cancelled || _disposed,
      exclusions: List.unmodifiable(_exclusions),
      findDuplicates: findDuplicates,
      findDevFolders: findDevFolders,
      onProgress: (value) {
        if (!_disposed && !_cancelled) {
          progress = value;
          notifyListeners();
        }
      },
      onPartial: (snapshot) {
        if (!_disposed && !_cancelled) {
          live = snapshot;
          notifyListeners();
        }
      },
    );
    live = null;
    if (!_disposed) {
      result = scanned;
      if (!scanned.cancelled) onScanCompleted?.call(selected, scanned);
    }
  }

  Future<void> openFolder(String selected) async {
    if (busy || root == null || result == null) return;
    final currentRoot = root!;
    final valid = result!.folderSummaries.any(
      (entry) =>
          entry.folderPath != null && p.equals(entry.folderPath!, selected),
    );
    if (!valid ||
        !p.isWithin(
          p.normalize(p.absolute(currentRoot)),
          p.normalize(p.absolute(selected)),
        )) {
      return;
    }
    _navigationHistory.add(currentRoot);
    await _navigateTo(selected);
  }

  Future<void> goBack() async {
    if (!canGoBack) return;
    final parent = _navigationHistory.removeLast();
    await _navigateTo(parent);
  }

  Future<void> _navigateTo(String selected) async {
    busy = true;
    _cancelled = false;
    error = null;
    result = null;
    progress = null;
    root = selected;
    _selectedCleanupPaths.clear();
    notifyListeners();
    try {
      await _scanRoot(selected);
    } catch (_) {
      if (!_disposed) {
        error = 'Unable to scan this folder. Check access and try again.';
      }
    } finally {
      if (!_disposed) {
        busy = false;
        progress = null;
        notifyListeners();
      }
    }
  }

  /// Scans the current folder again with the current options, without
  /// asking the user to pick it again.
  Future<void> rescan() async {
    final current = root;
    if (busy || current == null) return;
    _navigationHistory.clear();
    await _navigateTo(current);
  }

  /// Turns an option on and rescans the current scope.
  Future<void> enableAndRescan({
    bool duplicates = false,
    bool devFolders = false,
  }) async {
    if (busy) return;
    final current = root;
    if (duplicates) findDuplicates = true;
    if (devFolders) findDevFolders = true;
    if (current == null) {
      notifyListeners();
      return;
    }
    await rescan();
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
    _navigationHistory.clear();
    _selectedCleanupPaths.clear();
    notifyListeners();
  }

  void setFindDevFolders(bool value) {
    if (busy) return;
    findDevFolders = value;
    result = null;
    root = null;
    _navigationHistory.clear();
    _selectedCleanupPaths.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelled = true;
    super.dispose();
  }
}

/// The current user's home folder (HOME, or USERPROFILE on Windows).
String? defaultHomeFolder() {
  final env = Platform.environment;
  return env['HOME'] ?? env['USERPROFILE'];
}

Future<String?> chooseFolder() =>
    getDirectoryPath(confirmButtonText: 'Choose folder');
