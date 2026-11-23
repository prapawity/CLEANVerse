import 'dart:io';

import 'package:cleanverse/src/features/developer/cleanup_plan.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  // Pure path resolution only: these paths are never created or touched.
  final home = p.join(Directory.systemTemp.path, 'cv_fake_home');

  DevFolder byCategory(List<DevFolder> list, String category) =>
      list.singleWhere((item) => item.category == category);

  test('Linux defaults resolve inside the profile', () {
    final list = globalCacheCandidates({'HOME': home}, windows: false);
    expect(
      byCategory(list, 'pnpm content store').path,
      p.join(home, '.local', 'share', 'pnpm', 'store'),
    );
    expect(
      byCategory(list, 'Go build cache').path,
      p.join(home, '.cache', 'go-build'),
    );
    expect(
      byCategory(list, 'Bun install cache').path,
      p.join(home, '.bun', 'install', 'cache'),
    );
    expect(
      byCategory(list, 'Hugging Face hub cache').path,
      p.join(home, '.cache', 'huggingface', 'hub'),
    );
    expect(
      byCategory(list, 'VS Code compiled code cache').path,
      p.join(home, '.config', 'Code', 'CachedData'),
    );
    expect(list.any((item) => item.category.startsWith('CocoaPods')), isFalse);
    for (final item in list) {
      expect(p.isWithin(home, item.path), isTrue, reason: item.category);
      expect(item.locationSource, isNotNull);
      expect(item.note, isNotEmpty);
    }
  });

  test('macOS adds Apple tool caches under ~/Library', () {
    final list = globalCacheCandidates(
      {'HOME': home},
      windows: false,
      macos: true,
    );
    expect(
      byCategory(list, 'CocoaPods download cache').path,
      p.join(home, 'Library', 'Caches', 'CocoaPods'),
    );
    expect(
      byCategory(list, 'pnpm content store').path,
      p.join(home, 'Library', 'pnpm', 'store'),
    );
    expect(
      byCategory(list, 'Playwright browsers').path,
      p.join(home, 'Library', 'Caches', 'ms-playwright'),
    );
    expect(
      list.map((item) => item.category),
      containsAll(['Carthage cache', 'Swift Package Manager cache']),
    );
  });

  test('Windows defaults use LOCALAPPDATA and the profile', () {
    final local = p.join(home, 'AppData', 'Local');
    final list = globalCacheCandidates({
      'USERPROFILE': home,
      'LOCALAPPDATA': local,
      'APPDATA': p.join(home, 'AppData', 'Roaming'),
    }, windows: true);
    expect(
      byCategory(list, 'Yarn classic package cache').path,
      p.join(local, 'Yarn', 'Cache'),
    );
    expect(
      byCategory(list, 'NuGet global packages').path,
      p.join(home, '.nuget', 'packages'),
    );
    expect(
      byCategory(list, 'Composer package cache').path,
      p.join(local, 'Composer'),
    );
    expect(
      byCategory(list, 'Playwright browsers').path,
      p.join(local, 'ms-playwright'),
    );
  });

  test('environment overrides win and are labelled', () {
    final custom = p.join(home, 'custom');
    final list = globalCacheCandidates({
      'HOME': home,
      'PNPM_HOME': custom,
      'HF_HOME': custom,
      'GOCACHE': p.join(custom, 'gocache'),
      'NUGET_PACKAGES': p.join(custom, 'nuget'),
    }, windows: false);
    final pnpm = byCategory(list, 'pnpm content store');
    expect(pnpm.path, p.join(custom, 'store'));
    expect(pnpm.locationSource, 'PNPM_HOME environment variable');
    final hf = byCategory(list, 'Hugging Face hub cache');
    expect(hf.path, p.join(custom, 'hub'));
    expect(hf.locationSource, 'HF_HOME environment variable');
    expect(
      byCategory(list, 'Go build cache').locationSource,
      'GOCACHE environment variable',
    );
    expect(
      byCategory(list, 'NuGet global packages').path,
      p.join(custom, 'nuget'),
    );
  });

  test('invalid overrides are skipped without default fallback', () {
    final list = globalCacheCandidates({
      'HOME': home,
      'GOCACHE': 'off',
      'PLAYWRIGHT_BROWSERS_PATH': '0',
      'HF_HUB_CACHE': 'relative/hub',
    }, windows: false);
    final names = list.map((item) => item.category);
    expect(names, isNot(contains('Go build cache')));
    expect(names, isNot(contains('Playwright browsers')));
    expect(names, isNot(contains('Hugging Face hub cache')));
    expect(names, contains('Bun install cache'));
  });

  test('possibly unique data is marked potentially important', () {
    final list = globalCacheCandidates({'HOME': home}, windows: false);
    for (final name in [
      'Maven local repository',
      'Hugging Face hub cache',
      'JetBrains IDE caches',
    ]) {
      expect(
        byCategory(list, name).risk,
        CleanupRisk.potentiallyImportant,
        reason: name,
      );
    }
    for (final name in ['Bun install cache', 'Go build cache']) {
      expect(byCategory(list, name).risk, CleanupRisk.review, reason: name);
    }
  });

  test('scanner reports a new cache from a temporary fixture', () async {
    final root = await Directory.systemTemp.createTemp('cleanverse_test_');
    addTearDown(() => root.delete(recursive: true));
    final bun = await Directory(p.join(root.path, 'bun-cache'))
        .create(recursive: true);
    await File(p.join(bun.path, 'pkg.tgz')).writeAsBytes([1, 2, 3]);
    final scanner = LocalFolderScanner(
      environment: {'BUN_INSTALL_CACHE_DIR': bun.path},
      windows: false,
    );
    final result = await scanner.scan(
      root.path,
      () => false,
      findDevFolders: true,
    );
    final found = byCategory(result.devFolders, 'Bun install cache');
    expect(found.logicalBytes, 3);
    expect(found.locationSource, 'BUN_INSTALL_CACHE_DIR environment variable');
  });
}
