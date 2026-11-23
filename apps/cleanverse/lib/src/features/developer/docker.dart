import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum DockerState { notInstalled, notRunning, ready, timedOut, failed }

class DockerUsageRow {
  const DockerUsageRow({
    required this.type,
    required this.total,
    required this.active,
    required this.size,
    required this.reclaimable,
  });
  final String type;
  final String total;
  final String active;
  final String size;
  final String reclaimable;
}

class DockerReport {
  const DockerReport(this.state, {this.rows = const [], this.detail});
  final DockerState state;
  final List<DockerUsageRow> rows;
  final String? detail;
}

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> args,
);

Future<ProcessResult> _defaultRunner(String executable, List<String> args) =>
    Process.run(
      executable,
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    ).timeout(const Duration(seconds: 25));

/// Errors Docker prints when the CLI exists but no daemon answers.
bool looksLikeDaemonDown(String stderr) {
  final text = stderr.toLowerCase();
  return text.contains('failed to connect to the docker api') ||
      text.contains('cannot connect to the docker daemon') ||
      text.contains('is the docker daemon running') ||
      text.contains('dockerdesktoplinuxengine') ||
      text.contains('the system cannot find the file specified') ||
      text.contains('error during connect');
}

/// Uses only the official Docker CLI. Clean actions use `docker ... prune`,
/// which Docker itself guarantees never removes images or volumes in use.
class DockerTools {
  DockerTools({ProcessRunner? runner}) : _run = runner ?? _defaultRunner;
  final ProcessRunner _run;

  Future<DockerReport> usage() async {
    final ProcessResult result;
    try {
      result = await _run('docker', ['system', 'df', '--format', '{{json .}}']);
    } on ProcessException {
      return const DockerReport(DockerState.notInstalled);
    } on TimeoutException {
      return const DockerReport(DockerState.timedOut);
    }
    final stderr = '${result.stderr}';
    if (result.exitCode != 0) {
      return DockerReport(
        looksLikeDaemonDown(stderr)
            ? DockerState.notRunning
            : DockerState.failed,
        detail: stderr.trim(),
      );
    }
    final rows = <DockerUsageRow>[];
    for (final line in LineSplitter.split('${result.stdout}')) {
      try {
        final json = jsonDecode(line);
        if (json is! Map<String, dynamic>) continue;
        rows.add(
          DockerUsageRow(
            type: '${json['Type'] ?? ''}',
            total: '${json['TotalCount'] ?? ''}',
            active: '${json['Active'] ?? ''}',
            size: '${json['Size'] ?? ''}',
            reclaimable: '${json['Reclaimable'] ?? ''}',
          ),
        );
      } on FormatException {
        continue;
      }
    }
    return DockerReport(DockerState.ready, rows: rows);
  }

  /// Starts Docker Desktop where it is installed in the standard place.
  /// Returns false when it cannot be started automatically.
  Future<bool> startDesktop() async {
    try {
      if (Platform.isWindows) {
        final exe = await findWindowsDockerDesktop();
        if (exe == null) return false;
        await Process.start(exe, const [], mode: ProcessStartMode.detached);
        return true;
      }
      if (Platform.isMacOS) {
        final result = await Process.run('open', ['-a', 'Docker']);
        return result.exitCode == 0;
      }
      if (Platform.isLinux) {
        final result = await Process.run('systemctl', [
          '--user',
          'start',
          'docker-desktop',
        ]);
        return result.exitCode == 0;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  /// Waits for the daemon after starting Docker Desktop.
  Future<DockerReport> waitUntilReady({
    Duration timeout = const Duration(seconds: 120),
    Duration interval = const Duration(seconds: 4),
    bool Function()? cancelled,
  }) async {
    final deadline = DateTime.now().add(timeout);
    var report = await usage();
    // While the engine boots, docker can fail fast or hang; keep waiting.
    while ((report.state == DockerState.notRunning ||
            report.state == DockerState.timedOut) &&
        DateTime.now().isBefore(deadline) &&
        !(cancelled?.call() ?? false)) {
      await Future<void>.delayed(interval);
      report = await usage();
    }
    return report;
  }

  /// Runs an official prune command; returns Docker's summary line.
  Future<String> prune(DockerPrune kind) async {
    try {
      final result = await _run('docker', kind.args);
      final out = '${result.stdout}';
      if (result.exitCode != 0) {
        return 'Docker could not clean: ${'${result.stderr}'.trim()}';
      }
      final summary = LineSplitter.split(out)
          .where((l) => l.toLowerCase().contains('reclaimed'))
          .toList();
      return summary.isEmpty ? 'Done.' : summary.last.trim();
    } on ProcessException {
      return 'Docker CLI is not available.';
    } on TimeoutException {
      return 'Docker did not finish in time; it may still be cleaning.';
    }
  }
}

/// Finds `Docker Desktop.exe`: next to the docker CLI on PATH (installs on
/// other drives), from the uninstall registry entry, then default folders.
Future<String?> findWindowsDockerDesktop({
  Future<ProcessResult> Function(String, List<String>)? run,
}) async {
  final exec = run ?? Process.run;
  final candidates = <String>[];
  try {
    final where = await exec('where', ['docker']);
    for (final line in LineSplitter.split('${where.stdout}')) {
      final path = line.trim();
      // <install>\resources\bin\docker.exe
      final marker = path.toLowerCase().lastIndexOf(r'\resources\bin\');
      if (marker > 0) {
        candidates.add('${path.substring(0, marker)}\\Docker Desktop.exe');
      }
    }
  } catch (_) {}
  for (final hive in ['HKLM', 'HKCU']) {
    try {
      final reg = await exec('reg', [
        'query',
        '$hive\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Docker Desktop',
        '/v',
        'InstallLocation',
      ]);
      final match = RegExp(r'InstallLocation\s+REG_\w+\s+(.+)')
          .firstMatch('${reg.stdout}');
      if (match != null) {
        candidates.add('${match[1]!.trim()}\\Docker Desktop.exe');
      }
    } catch (_) {}
  }
  for (final base in [
    Platform.environment['ProgramFiles'],
    r'C:\Program Files',
  ]) {
    if (base != null) {
      candidates.add('$base\\Docker\\Docker\\Docker Desktop.exe');
    }
  }
  for (final candidate in candidates) {
    if (await File(candidate).exists()) return candidate;
  }
  return null;
}

enum DockerPrune {
  buildCache(
    'Build cache',
    'Cached layers from docker build. Future builds may be slower once.',
    ['builder', 'prune', '--force'],
  ),
  danglingImages(
    'Unused image layers',
    'Untagged ("dangling") images not used by any container.',
    ['image', 'prune', '--force'],
  ),
  stoppedContainers(
    'Stopped containers',
    'Containers that are not running. Their writable data is removed.',
    ['container', 'prune', '--force'],
  );

  const DockerPrune(this.label, this.description, this.args);
  final String label;
  final String description;
  final List<String> args;
}
