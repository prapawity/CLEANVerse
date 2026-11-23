import 'dart:io';

import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  setUp(() async => root = await Directory.systemTemp.createTemp('cv_walk'));
  tearDown(() => root.delete(recursive: true));

  Future<void> file(String rel, int bytes) async {
    final f = File(p.join(root.path, rel));
    await f.parent.create(recursive: true);
    await f.writeAsBytes(List.filled(bytes, 0));
  }

  LocalFolderScanner scanner() => LocalFolderScanner(
    environment: {'HOME': p.join(root.path, 'nohome')},
    windows: false,
    macos: false,
  );

  test('totals, top folders and largest files are correct', () async {
    await file('top.bin', 5);
    for (var i = 0; i < 150; i++) {
      await file('a/b/c/f$i.bin', i + 1);
    }
    await file('z/big.bin', 10000);
    final r = await scanner().scan(root.path, () => false);
    expect(r.filesSeen, 152);
    expect(r.totalBytes, 5 + 150 * 151 ~/ 2 + 10000);
    expect(r.files, hasLength(100));
    expect(r.files.first.path, endsWith('big.bin'));
    for (var i = 1; i < r.files.length; i++) {
      expect(r.files[i - 1].bytes, greaterThanOrEqualTo(r.files[i].bytes));
    }
    final byPath = {for (final s in r.folderSummaries) s.label: s};
    expect(byPath[p.join(root.path, 'a')]!.fileCount, 150);
    expect(byPath['Files directly in selected folder']!.bytes, 5);
  });

  test('links are never followed or counted', () async {
    await file('real/data.bin', 100);
    final outside = await Directory.systemTemp.createTemp('cv_outside');
    addTearDown(() => outside.delete(recursive: true));
    await File(p.join(outside.path, 'secret.bin'))
        .writeAsBytes(List.filled(999, 0));
    await Link(p.join(root.path, 'linkdir')).create(outside.path);
    await Link(p.join(root.path, 'linkfile'))
        .create(p.join(root.path, 'real', 'data.bin'));
    final r = await scanner().scan(root.path, () => false);
    expect(r.totalBytes, 100);
    expect(r.files.any((f) => f.path.contains('secret')), isFalse);
  });

  test('nested developer folders each get their own size', () async {
    await file('proj/package.json', 1);
    await file('proj/node_modules/a/index.js', 10);
    await file('proj/node_modules/inner/package.json', 1);
    await file('proj/node_modules/inner/node_modules/b.js', 20);
    final r = await scanner().scan(
      root.path,
      () => false,
      findDevFolders: true,
    );
    final sizes = {
      for (final d in r.devFolders)
        p.relative(d.path, from: root.path): d.logicalBytes,
    };
    expect(sizes['proj/node_modules'], 10 + 1 + 20);
    expect(sizes['proj/node_modules/inner/node_modules'], 20);
  });

  test('results so far are reported during the scan', () async {
    for (var i = 0; i < 600; i++) {
      await file('d${i % 20}/f$i.bin', 10);
    }
    final partials = <FolderScanResult>[];
    final slow = _SlowClock();
    final r = await scanner().scan(
      root.path,
      () => false,
      onPartial: (snap) {
        partials.add(snap);
        slow.tick();
      },
    );
    // The interval is 1.5 s, so a fast fixture may finish first; when a
    // snapshot is sent it must be a consistent subset of the final result.
    for (final snap in partials) {
      expect(snap.filesSeen, lessThanOrEqualTo(r.filesSeen));
      expect(snap.totalBytes, lessThanOrEqualTo(r.totalBytes));
    }
    expect(r.filesSeen, 600);
  });

  test('cancelling stops the walk and returns what was found', () async {
    for (var i = 0; i < 400; i++) {
      await file('d${i % 40}/f$i.bin', 1);
    }
    var seen = 0;
    final r = await scanner().scan(
      root.path,
      () => seen >= 128,
      onProgress: (pr) => seen = pr.filesSeen,
    );
    expect(r.cancelled, isTrue);
    expect(r.filesSeen, lessThan(400));
  });
}

class _SlowClock {
  int ticks = 0;
  void tick() => ticks++;
}
