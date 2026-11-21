import 'dart:io';

import 'package:cleanverse/src/desktop_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
