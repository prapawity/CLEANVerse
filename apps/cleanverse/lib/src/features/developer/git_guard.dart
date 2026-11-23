import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Projects touched within this window are treated as in active use.
const recentActivityWindow = Duration(days: 7);

class ProjectActivity {
  const ProjectActivity({
    required this.projectDir,
    this.isGitRepo = false,
    this.uncommitted = 0,
    this.lastCommit,
    this.markerModified,
    this.gitAvailable = true,
  });
  final String projectDir;
  final bool isGitRepo;

  /// Changed or untracked files reported by `git status` (ignored files such
  /// as node_modules are not counted).
  final int uncommitted;
  final DateTime? lastCommit;
  final DateTime? markerModified;
  final bool gitAvailable;

  DateTime? get lastActivity => [lastCommit, markerModified]
      .whereType<DateTime>()
      .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);

  bool recentlyActive(DateTime now) {
    final last = lastActivity;
    return last != null && now.difference(last) < recentActivityWindow;
  }

  /// Worth a warning before cleaning this project's artifacts.
  bool needsAttention(DateTime now) => uncommitted > 0 || recentlyActive(now);
}

typedef GitRunner = Future<ProcessResult> Function(
  List<String> args,
  String workingDir,
);

Future<ProcessResult> _defaultGit(List<String> args, String dir) => Process.run(
  'git',
  args,
  workingDirectory: dir,
  stdoutEncoding: utf8,
  stderrEncoding: utf8,
).timeout(const Duration(seconds: 10));

/// Read-only git checks. Never modifies the repository.
class GitGuard {
  GitGuard({GitRunner? git, Future<DateTime?> Function(String path)? modified})
    : _git = git ?? _defaultGit,
      _modified = modified ?? _fileModified;
  final GitRunner _git;
  final Future<DateTime?> Function(String path) _modified;

  static Future<DateTime?> _fileModified(String path) async {
    try {
      return (await File(path).stat()).modified;
    } catch (_) {
      return null;
    }
  }

  final Map<String, Future<ProjectActivity>> _cache = {};

  /// [markerPath] is the project file that identified the project, for
  /// example package.json or pubspec.yaml.
  Future<ProjectActivity> inspect(String markerPath) =>
      _cache.putIfAbsent(markerPath, () => _inspect(markerPath));

  void clear() => _cache.clear();

  Future<ProjectActivity> _inspect(String markerPath) async {
    final dir = p.dirname(markerPath);
    final markerModified = await _modified(markerPath);
    try {
      final inside = await _git(['rev-parse', '--is-inside-work-tree'], dir);
      if (inside.exitCode != 0 || '${inside.stdout}'.trim() != 'true') {
        return ProjectActivity(projectDir: dir, markerModified: markerModified);
      }
      final status = await _git([
        'status',
        '--porcelain',
        '--untracked-files=normal',
        '--',
        '.',
      ], dir);
      final changed = LineSplitter.split('${status.stdout}')
          .where((l) => l.trim().isNotEmpty)
          .length;
      final log = await _git(['log', '-1', '--format=%cI'], dir);
      return ProjectActivity(
        projectDir: dir,
        isGitRepo: true,
        uncommitted: status.exitCode == 0 ? changed : 0,
        lastCommit: DateTime.tryParse('${log.stdout}'.trim()),
        markerModified: markerModified,
      );
    } on ProcessException {
      return ProjectActivity(
        projectDir: dir,
        markerModified: markerModified,
        gitAvailable: false,
      );
    } on TimeoutException {
      return ProjectActivity(projectDir: dir, markerModified: markerModified);
    }
  }
}
