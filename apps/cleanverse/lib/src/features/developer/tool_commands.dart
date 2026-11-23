import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cleanverse/src/features/developer/docker.dart'
    show ProcessRunner;

/// A package manager's own clean command. CLEANVerse never deletes these
/// caches itself here; it asks the tool, which knows what is safe.
enum ToolCommand {
  homebrew(
    'Homebrew',
    'Old downloads and outdated versions of installed formulae and casks.',
    'brew',
    ['--version'],
    preview: ['cleanup', '--dry-run'],
    clean: ['cleanup'],
    windows: false,
  ),
  npm(
    'npm cache',
    'Downloaded package tarballs. npm downloads them again when needed.',
    'npm',
    ['--version'],
    clean: ['cache', 'clean', '--force'],
  ),
  pub(
    'Dart & Flutter pub cache',
    'Every downloaded Dart package. Projects need "pub get" again, which needs network access.',
    'dart',
    ['--version'],
    clean: ['pub', 'cache', 'clean', '--force'],
  );

  const ToolCommand(
    this.label,
    this.description,
    this.executable,
    this.versionArgs, {
    this.preview,
    required this.clean,
    this.windows = true,
  });
  final String label;
  final String description;
  final String executable;
  final List<String> versionArgs;

  /// Read-only dry run, when the tool offers one.
  final List<String>? preview;
  final List<String> clean;
  final bool windows;

  String get cleanCommand => '$executable ${clean.join(' ')}';
  bool supportedOn({required bool windows}) => !windows || this.windows;
}

enum ToolStatus { available, notInstalled, failed }

class ToolResult {
  const ToolResult(this.ok, this.output);
  final bool ok;
  final String output;
}

Future<ProcessResult> _defaultRunner(String executable, List<String> args) =>
    Process.run(
      executable,
      args,
      // npm and dart are .cmd/.bat shims on Windows.
      runInShell: Platform.isWindows,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    ).timeout(const Duration(minutes: 3));

/// Keeps output short enough to show; tools can print thousands of lines.
String summarize(String text, {int maxLines = 12}) {
  final lines = LineSplitter.split(text)
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.length <= maxLines) return lines.join('\n');
  return [
    ...lines.take(maxLines),
    '… ${lines.length - maxLines} more lines',
  ].join('\n');
}

class ToolCommands {
  ToolCommands({ProcessRunner? runner}) : _run = runner ?? _defaultRunner;
  final ProcessRunner _run;

  Future<ToolStatus> status(ToolCommand tool) async {
    try {
      final r = await _run(tool.executable, tool.versionArgs);
      return r.exitCode == 0 ? ToolStatus.available : ToolStatus.notInstalled;
    } on ProcessException {
      return ToolStatus.notInstalled;
    } on TimeoutException {
      return ToolStatus.failed;
    }
  }

  Future<ToolResult> preview(ToolCommand tool) => tool.preview == null
      ? Future.value(const ToolResult(true, ''))
      : _exec(tool, tool.preview!);

  Future<ToolResult> clean(ToolCommand tool) => _exec(tool, tool.clean);

  Future<ToolResult> _exec(ToolCommand tool, List<String> args) async {
    try {
      final r = await _run(tool.executable, args);
      final out = summarize('${r.stdout}\n${r.stderr}');
      return ToolResult(
        r.exitCode == 0,
        r.exitCode == 0
            ? (out.isEmpty ? 'Nothing to clean.' : out)
            : '${tool.label} reported an error (exit ${r.exitCode}).\n$out',
      );
    } on ProcessException {
      return ToolResult(false, '${tool.executable} is not available.');
    } on TimeoutException {
      return ToolResult(
        false,
        '${tool.label} did not finish in time; it may still be running.',
      );
    }
  }
}
