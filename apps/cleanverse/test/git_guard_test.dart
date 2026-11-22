import 'dart:io';

import 'package:cleanverse/src/features/developer/git_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dirty repository needs attention', () async {
    final guard = GitGuard(
      git: (args, dir) async => switch (args.first) {
        'rev-parse' => ProcessResult(1, 0, 'true\n', ''),
        'status' => ProcessResult(1, 0, ' M lib/main.dart\n?? notes.txt\n', ''),
        _ => ProcessResult(1, 0, '2020-01-01T00:00:00+00:00\n', ''),
      },
    );
    final a = await guard.inspect('/nowhere/app/package.json');
    expect(a.isGitRepo, isTrue);
    expect(a.uncommitted, 2);
    expect(a.needsAttention(DateTime(2026)), isTrue);
  });

  test('clean, old repository does not need attention', () async {
    final guard = GitGuard(
      git: (args, dir) async => switch (args.first) {
        'rev-parse' => ProcessResult(1, 0, 'true\n', ''),
        'status' => ProcessResult(1, 0, '', ''),
        _ => ProcessResult(1, 0, '2020-01-01T00:00:00+00:00\n', ''),
      },
    );
    final a = await guard.inspect('/nowhere/app/package.json');
    expect(a.needsAttention(DateTime(2026)), isFalse);
  });

  test('recent commit counts as active', () async {
    final now = DateTime.now();
    final guard = GitGuard(
      git: (args, dir) async => switch (args.first) {
        'rev-parse' => ProcessResult(1, 0, 'true\n', ''),
        'status' => ProcessResult(1, 0, '', ''),
        _ => ProcessResult(
          1,
          0,
          '${now.subtract(const Duration(days: 2)).toIso8601String()}\n',
          '',
        ),
      },
    );
    final a = await guard.inspect('/nowhere/app/package.json');
    expect(a.recentlyActive(now), isTrue);
  });

  test('missing git is not treated as a repository', () async {
    final guard = GitGuard(
      git: (args, dir) async => throw const ProcessException('git', []),
    );
    final a = await guard.inspect('/nowhere/app/package.json');
    expect(a.isGitRepo, isFalse);
    expect(a.gitAvailable, isFalse);
  });
}
