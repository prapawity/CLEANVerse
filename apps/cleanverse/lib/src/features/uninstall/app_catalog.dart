import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:cleanverse/src/data/removal.dart';
import 'package:cleanverse/src/features/cleanup/junk_catalog.dart'
    show JunkRisk;

/// An application bundle found in /Applications or ~/Applications.
class InstalledApp {
  const InstalledApp({
    required this.name,
    required this.bundleId,
    required this.path,
    this.version,
  });
  final String name;
  final String bundleId;
  final String path;
  final String? version;
}

/// What a leftover is, for grouping and explanation.
enum LeftoverKind {
  app('Application', 'The app itself.'),
  cache('Cache', 'Rebuilt by the app if you install it again.'),
  logs('Logs', 'Diagnostic logs.'),
  state('Saved state', 'Window positions restored at launch.'),
  web('Web data', 'Cookies and website storage used inside the app.'),
  preferences('Preferences', 'Your settings for this app.'),
  launchAgent(
    'Background item',
    'Starts a helper at login. Fully stops after you log out or restart.',
  ),
  support(
    'App data',
    'Files the app stored, which can include your documents, libraries or accounts.',
  ),
  container(
    'App container',
    'Everything a sandboxed app stored, which can include your documents.',
  ),
  system(
    'System-wide',
    'Installed for all users. Needs an administrator, so CLEANVerse does not remove it.',
  );

  const LeftoverKind(this.label, this.description);
  final String label;
  final String description;
}

class Leftover {
  const Leftover({
    required this.path,
    required this.kind,
    required this.risk,
    this.byName = false,
    this.bytes = 0,
  });
  final String path;
  final LeftoverKind kind;
  final JunkRisk risk;

  /// Matched by the app's name rather than its bundle id: less certain.
  final bool byName;
  final int bytes;

  bool get removable => kind != LeftoverKind.system;

  Leftover withBytes(int value) => Leftover(
    path: path,
    kind: kind,
    risk: risk,
    byName: byName,
    bytes: value,
  );

  /// Always the Trash: an uninstall can be undone from the Trash.
  RemovalItem toItem(String label) => RemovalItem(
    path: path,
    label: label,
    bytes: bytes,
    recommended: RemovalMode.trash,
    allowedRoot: p.dirname(path),
  );
}

typedef CommandRunner = Future<ProcessResult> Function(
  String executable,
  List<String> args,
);

Future<ProcessResult> _run(String executable, List<String> args) => Process.run(
  executable,
  args,
  stdoutEncoding: utf8,
  stderrEncoding: utf8,
).timeout(const Duration(seconds: 20));

/// Apple apps and CLEANVerse itself are never offered.
bool isProtectedBundleId(String id) {
  final lower = id.toLowerCase();
  return lower.startsWith('com.apple.') || lower.contains('cleanverse');
}

/// Exactly the bundle id, or the id followed by a "." (helpers such as
/// com.example.app.helper). Never a plain prefix: com.example.app must not
/// match com.example.application.
bool matchesBundleId(String name, String id) {
  final n = name.toLowerCase();
  final i = id.toLowerCase();
  return n == i || n.startsWith('$i.');
}

/// Name matching is only used when the name is specific enough.
bool _usableName(String name) =>
    name.length >= 4 &&
    !const {
      'app',
      'apps',
      'helper',
      'update',
      'updater',
      'settings',
      'support',
      'cache',
      'caches',
      'data',
      'default',
      'google',
      'microsoft',
      'adobe',
    }.contains(name.toLowerCase());

class AppCatalog {
  AppCatalog({
    CommandRunner? runner,
    Map<String, String>? environment,
    List<String>? folders,
    this.systemFolders = const [
      '/Library/Application Support',
      '/Library/Caches',
      '/Library/LaunchAgents',
      '/Library/LaunchDaemons',
      '/Library/PrivilegedHelperTools',
    ],
  }) : _runner = runner ?? _run,
       _env = environment ?? Platform.environment,
       _folders = folders; // ignore: prefer_initializing_formals
  final List<String>? _folders;

  /// Listed for information only; never removed.
  final List<String> systemFolders;
  final CommandRunner _runner;
  final Map<String, String> _env;

  String? get home {
    final h = _env['HOME'];
    return h != null && p.isAbsolute(h) ? p.normalize(h) : null;
  }

  List<String> get appFolders =>
      _folders ??
      [
        '/Applications',
        '/Applications/Utilities',
        if (home != null) p.join(home!, 'Applications'),
      ];

  Future<String?> _plistValue(String plist, String key) async {
    try {
      final r = await _runner('plutil', [
        '-extract',
        key,
        'raw',
        '-o',
        '-',
        plist,
      ]);
      if (r.exitCode != 0) return null;
      final value = '${r.stdout}'.trim();
      return value.isEmpty ? null : value;
    } on ProcessException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  Future<InstalledApp?> readApp(String bundlePath) async {
    final plist = p.join(bundlePath, 'Contents', 'Info.plist');
    if (!await File(plist).exists()) return null;
    final id = await _plistValue(plist, 'CFBundleIdentifier');
    if (id == null || isProtectedBundleId(id)) return null;
    final name =
        await _plistValue(plist, 'CFBundleDisplayName') ??
        await _plistValue(plist, 'CFBundleName') ??
        p.basenameWithoutExtension(bundlePath);
    return InstalledApp(
      name: name,
      bundleId: id,
      path: bundlePath,
      version: await _plistValue(plist, 'CFBundleShortVersionString'),
    );
  }

  /// Apps in the standard folders. Links are not followed.
  Future<List<InstalledApp>> listApps() async {
    final bundles = <String>[];
    for (final folder in appFolders) {
      try {
        await for (final e in Directory(folder).list(followLinks: false)) {
          if (e is Directory && e.path.endsWith('.app')) bundles.add(e.path);
        }
      } on FileSystemException {
        continue;
      }
    }
    final apps = <InstalledApp>[];
    // Small batches keep plutil calls from piling up.
    for (var i = 0; i < bundles.length; i += 8) {
      final batch = await Future.wait(bundles.skip(i).take(8).map(readApp));
      apps.addAll(batch.whereType<InstalledApp>());
    }
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return apps;
  }

  /// Everything that belongs to [app] in the user's Library, plus
  /// system-wide items listed for information only.
  Future<List<Leftover>> findLeftovers(InstalledApp app) async {
    final found = <Leftover>[
      Leftover(path: app.path, kind: LeftoverKind.app, risk: JunkRisk.caution),
    ];
    final h = home;
    final id = app.bundleId;
    final name = app.name;
    final lib = h == null ? null : p.join(h, 'Library');

    Future<void> scan(
      String folder,
      LeftoverKind kind,
      JunkRisk risk, {
      bool Function(String name)? match,
      bool allowName = false,
    }) async {
      final test =
          match ??
          (n) =>
              matchesBundleId(p.basenameWithoutExtension(n), id) ||
              matchesBundleId(n, id);
      try {
        await for (final e in Directory(folder).list(followLinks: false)) {
          final base = p.basename(e.path);
          if (test(base)) {
            found.add(Leftover(path: e.path, kind: kind, risk: risk));
          } else if (allowName && _usableName(name) && base == name) {
            found.add(
              Leftover(
                path: e.path,
                kind: kind,
                risk: JunkRisk.risky,
                byName: true,
              ),
            );
          }
        }
      } on FileSystemException {
        // Missing or protected folder: nothing found there.
      }
    }

    if (lib != null) {
      await scan(
        p.join(lib, 'Caches'),
        LeftoverKind.cache,
        JunkRisk.safe,
        allowName: true,
      );
      await scan(p.join(lib, 'HTTPStorages'), LeftoverKind.web, JunkRisk.safe);
      await scan(p.join(lib, 'WebKit'), LeftoverKind.web, JunkRisk.safe);
      await scan(
        p.join(lib, 'Cookies'),
        LeftoverKind.web,
        JunkRisk.safe,
        match: (n) => n.toLowerCase() == '${id.toLowerCase()}.binarycookies',
      );
      await scan(
        p.join(lib, 'Logs'),
        LeftoverKind.logs,
        JunkRisk.safe,
        allowName: true,
      );
      await scan(
        p.join(lib, 'Saved Application State'),
        LeftoverKind.state,
        JunkRisk.safe,
        match: (n) => n.toLowerCase() == '${id.toLowerCase()}.savedstate',
      );
      await scan(
        p.join(lib, 'Preferences'),
        LeftoverKind.preferences,
        JunkRisk.caution,
        match: (n) =>
            n.endsWith('.plist') &&
            matchesBundleId(p.basenameWithoutExtension(n), id),
      );
      await scan(
        p.join(lib, 'Preferences', 'ByHost'),
        LeftoverKind.preferences,
        JunkRisk.caution,
        match: (n) => n.toLowerCase().startsWith('${id.toLowerCase()}.'),
      );
      await scan(
        p.join(lib, 'LaunchAgents'),
        LeftoverKind.launchAgent,
        JunkRisk.caution,
        match: (n) =>
            n.endsWith('.plist') &&
            matchesBundleId(p.basenameWithoutExtension(n), id),
      );
      await scan(
        p.join(lib, 'Application Scripts'),
        LeftoverKind.support,
        JunkRisk.caution,
      );
      await scan(
        p.join(lib, 'Application Support'),
        LeftoverKind.support,
        JunkRisk.risky,
        allowName: true,
      );
      await scan(
        p.join(lib, 'Containers'),
        LeftoverKind.container,
        JunkRisk.risky,
      );
      await scan(
        p.join(lib, 'Group Containers'),
        LeftoverKind.container,
        JunkRisk.risky,
        // TEAMID.<id> or group.<id>
        match: (n) {
          final lower = n.toLowerCase();
          final i = id.toLowerCase();
          return lower == 'group.$i' || lower.endsWith('.$i');
        },
      );
    }

    // System-wide: listed, never removed.
    for (final folder in systemFolders) {
      await scan(folder, LeftoverKind.system, JunkRisk.risky);
    }
    // Remove duplicates (a folder can match more than one rule).
    final seen = <String>{};
    return [
      for (final l in found)
        if (seen.add(p.normalize(l.path))) l,
    ];
  }

  /// True if a process runs from inside the app bundle; null if unknown.
  Future<bool?> isRunning(InstalledApp app) async {
    try {
      final r = await _runner('ps', ['-axo', 'command=']);
      if (r.exitCode != 0) return null;
      final prefix = '${p.normalize(app.path)}/Contents/';
      return LineSplitter.split('${r.stdout}')
          .any((l) => l.trimLeft().startsWith(prefix));
    } on ProcessException {
      return null;
    } on TimeoutException {
      return null;
    }
  }
}
