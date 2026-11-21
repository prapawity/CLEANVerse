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
    bool findDuplicates = false,
    bool findDevFolders = false,
  }) async {
    received = exclusions;
    return const FolderScanResult([], 0, false);
  }
}

void main() {
  test(
    'npm and Xcode locations remain scoped candidates with distinct risks',
    () async {
      final root = await Directory.systemTemp.createTemp('cleanverse_test_');
      addTearDown(() => root.delete(recursive: true));
      final npmHome = await Directory(pJoin(root.path, 'custom-npm')).create();
      final npmCache = await Directory(pJoin(npmHome.path, '_cacache'))
          .create();
      final xcode = await Directory(
        pJoin(pJoin(pJoin(root.path, 'Library'), 'Developer'), 'Xcode'),
      ).create(recursive: true);
      final derived = await Directory(pJoin(xcode.path, 'DerivedData'))
          .create();
      final archives = await Directory(pJoin(xcode.path, 'Archives')).create();
      final scanner = LocalFolderScanner(
        environment: {'HOME': root.path, 'NPM_CONFIG_CACHE': npmHome.path},
        windows: false,
        macos: true,
      );
      final result = await scanner.scan(
        root.path,
        () => false,
        findDevFolders: true,
      );
      final paths = {for (final item in result.devFolders) item.path: item};
      expect(paths[npmCache.path]?.category, 'npm content cache');
      expect(
        paths[npmCache.path]?.locationSource,
        'npm_config_cache environment variable',
      );
      expect(paths[derived.path]?.category, 'Xcode derived data');
      expect(paths[archives.path]?.note, contains('unique release builds'));
      final excluded = await scanner.scan(
        root.path,
        () => false,
        findDevFolders: true,
        exclusions: [xcode.path],
      );
      expect(
        excluded.devFolders.any((item) => item.path == archives.path),
        isFalse,
      );
    },
  );

  test('Xcode defaults are not proposed on non-macOS', () {
    final env = {'HOME': Directory.systemTemp.path};
    final nonMac = globalCacheCandidates(env, windows: false);
    expect(nonMac.any((item) => item.category.startsWith('Xcode')), isFalse);
    final mac = globalCacheCandidates(env, windows: false, macos: true);
    expect(
      mac.where((item) => item.category.startsWith('Xcode')),
      hasLength(2),
    );
  });

  test(
    'global cache candidates honor environment, scope and exclusions',
    () async {
      final root = await Directory.systemTemp.createTemp('cleanverse_test_');
      addTearDown(() => root.delete(recursive: true));
      final gradleHome = await Directory(pJoin(root.path, 'gradle')).create();
      final cache = await Directory(pJoin(gradleHome.path, 'caches')).create();
      await File(pJoin(cache.path, 'artifact')).writeAsBytes([1, 2, 3, 4]);
      final scanner = LocalFolderScanner(
        environment: {'GRADLE_USER_HOME': gradleHome.path},
        windows: false,
      );
      final result = await scanner.scan(
        root.path,
        () => false,
        findDevFolders: true,
      );
      expect(result.devFolders, hasLength(1));
      expect(result.devFolders.single.category, 'Gradle global caches');
      expect(
        result.devFolders.single.locationSource,
        'GRADLE_USER_HOME environment variable',
      );
      expect(result.devFolders.single.logicalBytes, 4);
      expect(
        (await scanner.scan(
          cache.path,
          () => false,
          findDevFolders: true,
        )).devFolders.single.path,
        cache.path,
      );
      expect(
        (await scanner.scan(
          root.path,
          () => false,
          findDevFolders: true,
          exclusions: [gradleHome.path],
        )).devFolders,
        isEmpty,
      );
      expect((await scanner.scan(root.path, () => false)).devFolders, isEmpty);
    },
  );

  test('relative environment override is ignored without default fallback', () {
    final candidates = globalCacheCandidates({
      'HOME': pJoin(Directory.systemTemp.path, 'home'),
      'CARGO_HOME': 'relative',
    }, windows: false);
    expect(
      candidates.any((item) => item.category == 'Cargo registry archive cache'),
      isFalse,
    );
    expect(
      candidates.any((item) => item.category == 'Gradle global caches'),
      isTrue,
    );
  });

  test(
    'classifies developer folders only with a matching parent marker',
    () async {
      final root = await Directory.systemTemp.createTemp('cleanverse_test_');
      addTearDown(() => root.delete(recursive: true));
      final scenarios = [
        ('swift', 'Package.swift', '.build', 'Swift package build output'),
        ('ios', 'Podfile.lock', 'Pods', 'CocoaPods dependencies'),
        ('python', 'pyproject.toml', '.pytest_cache', 'Python tool cache'),
        ('typing', 'mypy.ini', '.mypy_cache', 'Python tool cache'),
        ('gradle', 'settings.gradle.kts', '.gradle', 'Gradle project cache'),
      ];
      for (final (name, marker, folder, _) in scenarios) {
        final project = await Directory(pJoin(root.path, name)).create();
        await File(pJoin(project.path, marker)).writeAsString('');
        await Directory(pJoin(project.path, folder)).create();
      }
      final unrelated = await Directory(pJoin(root.path, 'unrelated')).create();
      await Directory(pJoin(unrelated.path, '.build')).create();
      await Directory(pJoin(unrelated.path, 'Pods')).create();
      await Directory(pJoin(unrelated.path, '.pytest_cache')).create();
      final result = await LocalFolderScanner().scan(
        root.path,
        () => false,
        findDevFolders: true,
      );
      expect(result.devFolders, hasLength(scenarios.length));
      for (final (name, marker, folder, category) in scenarios) {
        final item = result.devFolders.singleWhere(
          (item) => item.path == pJoin(pJoin(root.path, name), folder),
        );
        expect(item.category, category);
        expect(item.projectMarker, pJoin(pJoin(root.path, name), marker));
        expect(item.modified, isNotNull);
      }
    },
  );

  test(
    'developer folders require matching project markers and honor exclusions',
    () async {
      final root = await Directory.systemTemp.createTemp('cleanverse_test_');
      addTearDown(() => root.delete(recursive: true));
      final project = await Directory(pJoin(root.path, 'project')).create();
      await File(pJoin(project.path, 'package.json')).writeAsString('{}');
      final deps = await Directory(pJoin(project.path, 'node_modules'))
          .create();
      await File(pJoin(deps.path, 'cached')).writeAsBytes([1, 2, 3]);
      final falsePositive = await Directory(pJoin(root.path, 'node_modules'))
          .create();
      final excluded = await Directory(pJoin(root.path, 'excluded')).create();
      await File(pJoin(excluded.path, 'Cargo.toml')).writeAsString('');
      await Directory(pJoin(excluded.path, 'target')).create();
      final result = await LocalFolderScanner().scan(
        root.path,
        () => false,
        findDevFolders: true,
        exclusions: [excluded.path],
      );
      expect(result.devFolders.map((item) => item.path), [deps.path]);
      expect(result.devFolders.single.logicalBytes, 3);
      expect(
        result.devFolders.any((item) => item.path == falsePositive.path),
        isFalse,
      );
      expect(
        (await LocalFolderScanner().scan(root.path, () => false)).devFolders,
        isEmpty,
      );
    },
  );
  test(
    'finds matching hashes across all scanned files and respects exclusions',
    () async {
      final root = await Directory.systemTemp.createTemp('cleanverse_test_');
      addTearDown(() => root.delete(recursive: true));
      final excluded = await Directory(
        '${root.path}${Platform.pathSeparator}excluded',
      ).create();
      for (final name in ['a', 'b']) {
        await File('${root.path}${Platform.pathSeparator}$name')
            .writeAsString('same');
      }
      await File('${root.path}${Platform.pathSeparator}different')
          .writeAsString('else');
      await File('${excluded.path}${Platform.pathSeparator}hidden')
          .writeAsString('same');
      final result = await LocalFolderScanner().scan(
        root.path,
        () => false,
        exclusions: [excluded.path],
        findDuplicates: true,
      );
      expect(result.duplicates, hasLength(1));
      expect(
        result.duplicates.single
            .map((item) => item.path.split(Platform.pathSeparator).last)
            .toSet(),
        {'a', 'b'},
      );
    },
  );

  test('matching is opt-in and empty files match', () async {
    final root = await Directory.systemTemp.createTemp('cleanverse_test_');
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}${Platform.pathSeparator}a').writeAsBytes([]);
    await File('${root.path}${Platform.pathSeparator}b').writeAsBytes([]);
    expect(
      (await LocalFolderScanner().scan(root.path, () => false)).duplicates,
      isEmpty,
    );
    expect(
      (await LocalFolderScanner().scan(
        root.path,
        () => false,
        findDuplicates: true,
      )).duplicates.single,
      hasLength(2),
    );
  });

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

String pJoin(String a, String b) => '$a${Platform.pathSeparator}$b';
