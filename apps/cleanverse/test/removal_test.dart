import 'dart:io';

import 'package:cleanverse/src/features/cleanup/junk_catalog.dart';
import 'package:cleanverse/src/data/protection.dart';
import 'package:cleanverse/src/data/removal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class FakeTrash implements TrashBackend {
  FakeTrash({this.fail = false});
  final bool fail;
  final moved = <String>[];
  @override
  Future<Map<String, String?>> moveToTrash(List<String> paths) async {
    if (!fail) moved.addAll(paths);
    return {for (final path in paths) path: fail ? 'no trash' : null};
  }
}

void main() {
  late Directory sandbox;
  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('cv_removal');
  });
  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  Future<File> file(String relative, int size) async {
    final f = File(p.join(sandbox.path, relative));
    await f.parent.create(recursive: true);
    await f.writeAsBytes(List.filled(size, 1));
    return f;
  }

  test('contents scope empties a folder but keeps it and kept names', () async {
    await file('cache/a.bin', 100);
    await file('cache/sub/b.bin', 50);
    await file('cache/keep/c.bin', 10);
    final cache = p.join(sandbox.path, 'cache');
    final outcomes = await executeRemoval([
      RemovalItem(
        path: cache,
        label: 'cache',
        bytes: 160,
        recommended: RemovalMode.permanent,
        allowedRoot: cache,
        scope: RemovalScope.contents,
        keepNames: const {'keep'},
      ),
    ], trash: FakeTrash());
    expect(outcomes.single.status, RemovalStatus.removed);
    expect(outcomes.single.freedBytes, 150);
    expect(await Directory(cache).exists(), isTrue);
    expect(await File(p.join(cache, 'keep', 'c.bin')).exists(), isTrue);
    expect(await File(p.join(cache, 'a.bin')).exists(), isFalse);
  });

  test('trash mode never falls back to permanent deletion', () async {
    final f = await file('docs/report.pdf', 20);
    final trash = FakeTrash(fail: true);
    final outcomes = await executeRemoval([
      RemovalItem(
        path: f.path,
        label: 'report',
        bytes: 20,
        recommended: RemovalMode.trash,
        allowedRoot: sandbox.path,
      ),
    ], trash: trash);
    expect(outcomes.single.status, RemovalStatus.failed);
    expect(await f.exists(), isTrue);
  });

  test('trash mode hands the path to the backend', () async {
    final f = await file('docs/old.zip', 20);
    final trash = FakeTrash();
    final outcomes = await executeRemoval(
      [
        RemovalItem(
          path: f.path,
          label: 'old',
          bytes: 20,
          recommended: RemovalMode.permanent,
          allowedRoot: sandbox.path,
        ),
      ],
      override: RemovalMode.trash,
      trash: trash,
    );
    expect(outcomes.single.status, RemovalStatus.movedToTrash);
    expect(trash.moved, [f.path]);
    expect(outcomes.single.freedBytes, 0);
  });

  test('items outside the reviewed location are skipped', () async {
    final f = await file('other/secret.txt', 5);
    final outcomes = await executeRemoval([
      RemovalItem(
        path: f.path,
        label: 'secret',
        bytes: 5,
        recommended: RemovalMode.permanent,
        allowedRoot: p.join(sandbox.path, 'cache'),
      ),
    ], trash: FakeTrash());
    expect(outcomes.single.status, RemovalStatus.skipped);
    expect(await f.exists(), isTrue);
  });

  test('missing items are reported, not treated as errors', () async {
    final outcomes = await executeRemoval([
      RemovalItem(
        path: p.join(sandbox.path, 'gone'),
        label: 'gone',
        bytes: 0,
        recommended: RemovalMode.permanent,
        allowedRoot: sandbox.path,
      ),
    ], trash: FakeTrash());
    expect(outcomes.single.status, RemovalStatus.skipped);
    expect(outcomes.single.message, 'Already gone.');
  });

  test('measureBytes skips kept names at the top level', () async {
    await file('m/a', 30);
    await file('m/skip/b', 70);
    expect(await measureBytes(p.join(sandbox.path, 'm')), 100);
    expect(
      await measureBytes(p.join(sandbox.path, 'm'), skipNames: {'skip'}),
      30,
    );
  });

  test('catalog finds browser cache folders per profile', () async {
    final local = p.join(sandbox.path, 'Local');
    await file('Local/Google/Chrome/User Data/Default/Cache/x', 1);
    await file('Local/Google/Chrome/User Data/Profile 2/Cache/x', 1);
    await file('Local/Google/Chrome/User Data/System Profile/Cache/x', 1);
    final targets = await junkTargets(
      {'USERPROFILE': sandbox.path, 'LOCALAPPDATA': local},
      windows: true,
      macos: false,
    );
    final chrome = targets
        .where(
          (t) =>
              t.group == JunkGroup.browser &&
              t.label.contains('Cache ·') == false,
        )
        .where((t) => t.label.endsWith('· Cache'))
        .map((t) => t.label)
        .toList();
    expect(
      chrome,
      containsAll(['Chrome · Default · Cache', 'Chrome · Profile 2 · Cache']),
    );
    expect(chrome.any((l) => l.contains('System Profile')), isFalse);
    expect(
      targets.where((t) => t.group == JunkGroup.system).map((t) => t.label),
      contains('Temporary files'),
    );
  });

  test('dry run changes nothing and reports what would happen', () async {
    final f = await file('cache/a.bin', 100);
    final cache = p.join(sandbox.path, 'cache');
    final logFile = File(p.join(sandbox.path, 'history.jsonl'));
    final outcomes = await executeRemoval(
      [
        RemovalItem(
          path: cache,
          label: 'cache',
          bytes: 100,
          recommended: RemovalMode.permanent,
          allowedRoot: cache,
          scope: RemovalScope.contents,
        ),
      ],
      trash: FakeTrash(),
      dryRun: true,
      log: OperationLog(logFile),
    );
    expect(outcomes.single.status, RemovalStatus.previewed);
    expect(outcomes.single.message, contains('1 entry'));
    expect(await f.exists(), isTrue);
    expect(await logFile.exists(), isFalse);
  });

  test('ignored paths are never removed', () async {
    final keep = await file('cache/keep/me.txt', 10);
    await file('cache/junk.bin', 10);
    final cache = p.join(sandbox.path, 'cache');
    final ignore = IgnoreList([p.join(cache, 'keep')]);
    final whole = await executeRemoval(
      [
        RemovalItem(
          path: cache,
          label: 'cache',
          bytes: 20,
          recommended: RemovalMode.permanent,
          allowedRoot: sandbox.path,
        ),
      ],
      trash: FakeTrash(),
      ignore: ignore,
    );
    expect(whole.single.status, RemovalStatus.skipped);
    final contents = await executeRemoval(
      [
        RemovalItem(
          path: cache,
          label: 'cache',
          bytes: 20,
          recommended: RemovalMode.permanent,
          allowedRoot: cache,
          scope: RemovalScope.contents,
        ),
      ],
      trash: FakeTrash(),
      ignore: ignore,
    );
    expect(contents.single.status, RemovalStatus.removed);
    expect(await keep.exists(), isTrue);
    expect(await File(p.join(cache, 'junk.bin')).exists(), isFalse);
  });

  test('real removals are written to the operation log', () async {
    final f = await file('old.zip', 10);
    final log = OperationLog(File(p.join(sandbox.path, 'h', 'history.jsonl')));
    await executeRemoval(
      [
        RemovalItem(
          path: f.path,
          label: 'old.zip',
          bytes: 10,
          recommended: RemovalMode.trash,
          allowedRoot: sandbox.path,
        ),
      ],
      trash: FakeTrash(),
      log: log,
    );
    final entries = await log.read();
    expect(entries.single.label, 'old.zip');
    expect(entries.single.status, 'movedToTrash');
    await log.clear();
    expect(await log.read(), isEmpty);
  });
}
