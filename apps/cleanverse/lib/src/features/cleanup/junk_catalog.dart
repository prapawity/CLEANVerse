import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:cleanverse/src/features/developer/cleanup_plan.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/data/removal.dart';

enum JunkGroup {
  system(
    'System junk',
    'Temporary files, crash dumps, logs and thumbnail caches in your user account.',
  ),
  browser(
    'Browser cache',
    'Cached web content only. Cookies, history, passwords and bookmarks are not touched.',
  ),
  developer(
    'Developer caches',
    'Package manager and build tool caches. Tools download or rebuild them when needed.',
  );

  const JunkGroup(this.title, this.description);
  final String title;
  final String description;
}

/// How much care a location needs before cleaning. Shown on every item so
/// the user can judge it; it never selects anything.
enum JunkRisk {
  safe('Safe', 'Rebuilt automatically. Nothing you made is stored here.'),
  caution(
    'Caution',
    'Rebuilt or re-downloaded, but an app may need closing, run slower once, or need network access.',
  ),
  risky(
    'Risky',
    'May hold data that cannot be rebuilt. Moved to the bin by default; review before cleaning.',
  );

  const JunkRisk(this.label, this.explanation);
  final String label;
  final String explanation;
}

/// A known junk location. Every path is derived from the user's own
/// profile; nothing requires administrator rights.
class JunkTarget {
  const JunkTarget({
    required this.group,
    required this.label,
    required this.path,
    required this.note,
    this.scope = RemovalScope.contents,
    this.recommended = RemovalMode.permanent,
    this.keepNames = const {},
    this.closeApp,
    this.risk = JunkRisk.safe,
  });
  final JunkGroup group;
  final String label;
  final String path;
  final String note;
  final RemovalScope scope;
  final RemovalMode recommended;
  final Set<String> keepNames;

  /// App that should be closed first, if any.
  final String? closeApp;

  final JunkRisk risk;

  RemovalItem toItem(int bytes) => RemovalItem(
    path: path,
    label: label,
    bytes: bytes,
    recommended: recommended,
    allowedRoot: scope == RemovalScope.contents ? path : p.dirname(path),
    scope: scope,
    keepNames: keepNames,
  );
}

/// Locations to check. Existence is checked when measuring.
Future<List<JunkTarget>> junkTargets(
  Map<String, String> env, {
  required bool windows,
  required bool macos,
}) async {
  String? abs(String? value) =>
      value != null && value.trim().isNotEmpty && p.isAbsolute(value)
      ? p.normalize(value)
      : null;
  final home = abs(env[windows ? 'USERPROFILE' : 'HOME']);
  if (home == null) return const [];
  final targets = <JunkTarget>[];

  // ---- System junk ----
  if (windows) {
    final local = abs(env['LOCALAPPDATA']) ?? p.join(home, 'AppData', 'Local');
    final temp = abs(env['TEMP']) ?? p.join(local, 'Temp');
    targets.addAll([
      JunkTarget(
        group: JunkGroup.system,
        label: 'Temporary files',
        path: temp,
        note: 'Files apps left in your Temp folder. Files in use are skipped.',
      ),
      JunkTarget(
        group: JunkGroup.system,
        label: 'Crash dumps',
        path: p.join(local, 'CrashDumps'),
        note: 'Memory dumps written when apps crashed.',
      ),
      JunkTarget(
        group: JunkGroup.system,
        label: 'DirectX shader cache',
        path: p.join(local, 'D3DSCache'),
        note: 'Rebuilt automatically; games may load slower once.',
      ),
      JunkTarget(
        group: JunkGroup.system,
        label: 'Windows error reports',
        path: p.join(local, 'Microsoft', 'Windows', 'WER', 'ReportArchive'),
        note: 'Already-sent error reports.',
      ),
    ]);
  } else if (macos) {
    targets.addAll([
      JunkTarget(
        group: JunkGroup.system,
        label: 'User app caches',
        path: p.join(home, 'Library', 'Caches'),
        note: 'Caches apps rebuild when needed. Some apps may sign in again or re-download offline content. Browser and developer caches are listed separately.',
        risk: JunkRisk.caution,
        keepNames: const {
          'Google',
          'com.microsoft.edgemac',
          'Firefox',
          'pip',
          'com.apple.Safari',
        },
      ),
      JunkTarget(
        group: JunkGroup.system,
        label: 'User logs',
        path: p.join(home, 'Library', 'Logs'),
        note: 'Diagnostic logs written by apps.',
      ),
    ]);
  } else {
    final cache = abs(env['XDG_CACHE_HOME']) ?? p.join(home, '.cache');
    targets.addAll([
      JunkTarget(
        group: JunkGroup.system,
        label: 'User app caches',
        path: cache,
        note: 'Caches apps rebuild when needed. Some apps may sign in again or re-download offline content. Browser and developer caches are listed separately.',
        risk: JunkRisk.caution,
        keepNames: const {
          'google-chrome',
          'microsoft-edge',
          'mozilla',
          'pip',
          'thumbnails',
        },
      ),
      JunkTarget(
        group: JunkGroup.system,
        label: 'Thumbnail cache',
        path: p.join(cache, 'thumbnails'),
        note: 'Preview images regenerated by the file manager.',
      ),
    ]);
  }

  // ---- Browser caches (cache folders only) ----
  Future<void> chromium(String label, String userData, String app) async {
    for (final profile in await _children(userData)) {
      final name = p.basename(profile);
      if (name != 'Default' && !name.startsWith('Profile ')) continue;
      for (final folder in ['Cache', 'Code Cache', 'GPUCache']) {
        targets.add(
          JunkTarget(
            group: JunkGroup.browser,
            label: '$label · $name · $folder',
            path: p.join(profile, folder),
            note: 'Pages may load slower once. You stay signed in.',
            closeApp: app,
            risk: JunkRisk.caution,
          ),
        );
      }
    }
  }

  Future<void> firefox(String profiles) async {
    for (final profile in await _children(profiles)) {
      targets.add(
        JunkTarget(
          group: JunkGroup.browser,
          label: 'Firefox · ${p.basename(profile)} · cache2',
          path: p.join(profile, 'cache2'),
          note: 'Pages may load slower once. You stay signed in.',
          closeApp: 'Firefox',
          risk: JunkRisk.caution,
        ),
      );
    }
  }

  if (windows) {
    final local = abs(env['LOCALAPPDATA']) ?? p.join(home, 'AppData', 'Local');
    await chromium(
      'Chrome',
      p.join(local, 'Google', 'Chrome', 'User Data'),
      'Chrome',
    );
    await chromium(
      'Edge',
      p.join(local, 'Microsoft', 'Edge', 'User Data'),
      'Edge',
    );
    await firefox(p.join(local, 'Mozilla', 'Firefox', 'Profiles'));
  } else if (macos) {
    final caches = p.join(home, 'Library', 'Caches');
    await chromium('Chrome', p.join(caches, 'Google', 'Chrome'), 'Chrome');
    await chromium('Edge', p.join(caches, 'Microsoft Edge'), 'Edge');
    await firefox(p.join(caches, 'Firefox', 'Profiles'));
  } else {
    final cache = abs(env['XDG_CACHE_HOME']) ?? p.join(home, '.cache');
    await chromium('Chrome', p.join(cache, 'google-chrome'), 'Chrome');
    await chromium('Edge', p.join(cache, 'microsoft-edge'), 'Edge');
    await firefox(p.join(cache, 'mozilla', 'firefox'));
  }

  // ---- Developer global caches (reuses scanner knowledge) ----
  for (final folder in globalCacheCandidates(
    env,
    windows: windows,
    macos: macos,
  )) {
    final important = folder.risk == CleanupRisk.potentiallyImportant;
    targets.add(
      JunkTarget(
        group: JunkGroup.developer,
        label: folder.category,
        path: folder.path,
        note: folder.note,
        scope: RemovalScope.whole,
        // Possibly unique data (e.g. Xcode archives) goes to Trash.
        recommended: important ? RemovalMode.trash : RemovalMode.permanent,
        // Re-downloads need network and time; archives may be unique.
        risk: important ? JunkRisk.risky : JunkRisk.caution,
      ),
    );
  }
  return targets;
}

Future<List<String>> _children(String path) async {
  try {
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return const [];
    }
    final result = <String>[];
    await for (final entity in Directory(path).list(followLinks: false)) {
      if (entity is Directory) result.add(entity.path);
    }
    return result;
  } on FileSystemException {
    return const [];
  }
}
