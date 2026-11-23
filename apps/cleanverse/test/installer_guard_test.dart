import 'dart:io';

import 'package:cleanverse/src/features/update/installer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cv_install');
    await File(p.join(dir.path, 'cleanverse.exe')).writeAsString('x');
    await File(p.join(dir.path, 'flutter_windows.dll')).writeAsString('x');
    await Directory(p.join(dir.path, 'data')).create();
  });
  tearDown(() => dir.delete(recursive: true));

  test('a folder with only the app can be updated in place', () async {
    expect(await holdsOnlyApp(dir.path, 'cleanverse.exe'), isTrue);
  });

  test('a shared folder such as Downloads is never emptied', () async {
    await File(p.join(dir.path, 'tax-return.pdf')).writeAsString('mine');
    expect(await holdsOnlyApp(dir.path, 'cleanverse.exe'), isFalse);
  });

  test('a stray folder also counts as shared', () async {
    await Directory(p.join(dir.path, 'Photos')).create();
    expect(await holdsOnlyApp(dir.path, 'cleanverse.exe'), isFalse);
  });
}
