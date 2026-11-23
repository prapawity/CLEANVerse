import 'dart:io';

import 'package:cleanverse/src/data/removal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class RecordingTrash implements TrashBackend {
  final moved = <String>[];
  @override
  Future<Map<String, String?>> moveToTrash(List<String> paths) async {
    moved.addAll(paths);
    return {for (final path in paths) path: null};
  }
}

void main() {
  late Directory sandbox;
  late Directory personal;
  late Directory cache;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('cv_links');
    personal = await Directory(p.join(sandbox.path, 'Documents')).create();
    await File(p.join(personal.path, 'thesis.docx')).writeAsString('keep me');
    cache = await Directory(p.join(sandbox.path, 'Caches')).create();
    await File(p.join(cache.path, 'old.cache')).writeAsString('junk');
    await Link(p.join(cache.path, 'shortcut')).create(personal.path);
  });
  tearDown(() => sandbox.delete(recursive: true));

  RemovalItem contents(RemovalMode mode) => RemovalItem(
    path: cache.path,
    label: 'Caches',
    bytes: 4,
    recommended: mode,
    allowedRoot: cache.path,
    scope: RemovalScope.contents,
  );

  test('cleaning a folder never hands links to the Trash', () async {
    final trash = RecordingTrash();
    await executeRemoval([contents(RemovalMode.trash)], trash: trash);
    expect(trash.moved, [p.join(cache.path, 'old.cache')]);
    expect(File(p.join(personal.path, 'thesis.docx')).existsSync(), isTrue);
  });

  test('permanent cleaning skips links and keeps their targets', () async {
    await executeRemoval([contents(RemovalMode.permanent)]);
    expect(File(p.join(cache.path, 'old.cache')).existsSync(), isFalse);
    expect(File(p.join(personal.path, 'thesis.docx')).existsSync(), isTrue);
  });

  test('the macOS Trash refuses a link before asking Finder', () async {
    final link = p.join(cache.path, 'shortcut');
    final result = await MacTrash().moveToTrash([link]);
    expect(result[link], contains('link'));
    expect(Link(link).existsSync(), isTrue);
    expect(File(p.join(personal.path, 'thesis.docx')).existsSync(), isTrue);
  }, skip: !Platform.isMacOS);

  test('the Linux Trash refuses a link', () async {
    final link = p.join(cache.path, 'shortcut');
    final result = await LinuxTrash().moveToTrash([link]);
    expect(result[link], contains('link'));
    expect(Directory(personal.path).existsSync(), isTrue);
  }, skip: Platform.isWindows);

  test(
    'the macOS Trash moves several files in one call and reports each',
    () async {
      final a = File(p.join(sandbox.path, 'a.tmp'))..writeAsStringSync('a');
      final b = File(p.join(sandbox.path, 'b tmp with space.tmp'))
        ..writeAsStringSync('b');
      final missing = p.join(sandbox.path, 'gone.tmp');
      final result = await MacTrash().moveToTrash([a.path, b.path, missing]);
      expect(result[a.path], isNull);
      expect(result[b.path], isNull);
      expect(result[missing], isNotNull);
      expect(a.existsSync() || b.existsSync(), isFalse);
    },
    skip: !Platform.isMacOS,
  );
}
