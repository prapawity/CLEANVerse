import 'dart:io';

import 'package:cleanverse/src/desktop_scan.dart';
import 'package:flutter_test/flutter_test.dart';

class CapturingScanner implements FolderScanner {
  List<String> received = [];
  @override
  Future<FolderScanResult> scan(
    String path,
    bool Function() cancelled, {
    List<String> exclusions = const [],
  }) async {
    received = exclusions;
    return const FolderScanResult([], 0, false);
  }
}

void main() {
  test(
    'view model passes session exclusions and supports removing them',
    () async {
      final root = await Directory.systemTemp.createTemp('cleanverse_test_');
      addTearDown(() => root.delete(recursive: true));
      final selected = <String>[root.path, root.path, root.path];
      final scanner = CapturingScanner();
      final model = FolderScanViewModel(
        scanner,
        () async => selected.removeAt(0),
      );
      addTearDown(model.dispose);
      await model.addExclusion();
      await model.addExclusion();
      expect(model.exclusions, hasLength(1));
      await model.start();
      expect(scanner.received, model.exclusions);
      model.removeExclusion(model.exclusions.single);
      expect(model.exclusions, isEmpty);
      expect(model.result, isNull);
    },
  );

  test(
    'excluded folder and descendants are not scanned, but siblings are',
    () async {
      final root = await Directory.systemTemp.createTemp('cleanverse_test_');
      addTearDown(() => root.delete(recursive: true));
      final excluded = await Directory(
        '${root.path}${Platform.pathSeparator}private',
      ).create();
      final child = await Directory(
        '${excluded.path}${Platform.pathSeparator}child',
      ).create();
      final sibling = await Directory(
        '${root.path}${Platform.pathSeparator}private-other',
      ).create();
      await File('${child.path}${Platform.pathSeparator}secret')
          .writeAsString('secret');
      final visible = await File(
        '${sibling.path}${Platform.pathSeparator}visible',
      ).writeAsString('visible');
      final result = await LocalFolderScanner().scan(
        root.path,
        () => false,
        exclusions: [excluded.path],
      );
      expect(result.files.map((f) => f.path), [visible.path]);
      expect(result.skipped, 0);
    },
  );

  test('excluding the root yields no results', () async {
    final root = await Directory.systemTemp.createTemp('cleanverse_test_');
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}${Platform.pathSeparator}file')
        .writeAsString('data');
    final result = await LocalFolderScanner().scan(
      root.path,
      () => false,
      exclusions: [root.path],
    );
    expect(result.files, isEmpty);
  });

  test('does not traverse a Windows junction', () async {
    if (!Platform.isWindows) return;
    final area = await Directory.systemTemp.createTemp('cleanverse_test_');
    addTearDown(() => area.delete(recursive: true));
    final root = await Directory('${area.path}\\root').create();
    final outside = await Directory('${area.path}\\outside').create();
    await File('${outside.path}\\secret').writeAsString('outside');
    final process = await Process.run('cmd', [
      '/c',
      'mklink',
      '/J',
      '${root.path}\\junction',
      outside.path,
    ]);
    expect(process.exitCode, 0);
    final result = await LocalFolderScanner().scan(root.path, () => false);
    expect(result.files, isEmpty);
    expect(result.skipped, greaterThan(0));
  });

  test('lists selected files in size order and does not change them', () async {
    final root = await Directory.systemTemp.createTemp('cleanverse_test_');
    addTearDown(() => root.delete(recursive: true));
    final first = File('${root.path}${Platform.pathSeparator}small');
    final second = File('${root.path}${Platform.pathSeparator}large');
    await first.writeAsBytes([1]);
    await second.writeAsBytes([1, 2, 3]);
    final result = await LocalFolderScanner().scan(root.path, () => false);
    expect(result.files.map((f) => f.bytes), [3, 1]);
    expect(await second.readAsBytes(), [1, 2, 3]);
    expect(result.cancelled, isFalse);
  });

  test('cancelled scan reports partial state', () async {
    final root = await Directory.systemTemp.createTemp('cleanverse_test_');
    addTearDown(() => root.delete(recursive: true));
    final result = await LocalFolderScanner().scan(root.path, () => true);
    expect(result.cancelled, isTrue);
    expect(result.files, isEmpty);
  });

  test('missing root is rejected', () async {
    final root = await Directory.systemTemp.createTemp('cleanverse_test_');
    addTearDown(() => root.delete(recursive: true));
    expect(
      () => LocalFolderScanner().scan('${root.path}/missing', () => false),
      throwsA(isA<FileSystemException>()),
    );
  });
}
