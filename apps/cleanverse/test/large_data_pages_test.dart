// Large-data checks for Clean up, Apps and Developer: lazy rendering,
// scrolling, no overflow at 700×800 and at 200% text. Fakes only: no real
// file system access, no commands and nothing is removed.
import 'dart:async';
import 'dart:io';

import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/features/cleanup/cleanup_page.dart';
import 'package:cleanverse/src/features/cleanup/cleanup_view_model.dart';
import 'package:cleanverse/src/features/cleanup/junk_catalog.dart';
import 'package:cleanverse/src/features/developer/developer_page.dart';
import 'package:cleanverse/src/features/developer/git_guard.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/features/uninstall/app_catalog.dart';
import 'package:cleanverse/src/features/uninstall/uninstall_view_model.dart';
import 'package:cleanverse/src/features/uninstall/uninstall_page.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _long =
    '/Users/someone/Library/Containers/com.example.very.long.identifier/Data/Library/Caches/deeply/nested/folder';

Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(1280, 800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCleanVerseTheme(),
      home: Scaffold(body: page),
    ),
  );
  await tester.pump();
}

/// Scrolls the page's main list until [finder] is built, then brings it
/// clear of the pinned bar.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    400,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 400,
  );
  await tester.ensureVisible(finder);
  await tester.pump();
}

List<MeasuredJunk> junk(int count) => [
  for (var i = 0; i < count; i++)
    MeasuredJunk(
      JunkTarget(
        group: JunkGroup.values[i % 3],
        label: 'Junk location $i',
        path: '$_long/junk$i',
        note: 'A cache that rebuilds by itself when the app needs it again.',
        risk: i % 4 == 0 ? JunkRisk.caution : JunkRisk.safe,
      ),
      (count - i) * 1024 * 1024,
    ),
];

class FakeCatalog extends AppCatalog {
  FakeCatalog({this.appCount = 150, this.leftoverCount = 120})
    : super(environment: const {}, folders: const [], systemFolders: const []);
  final int appCount;
  final int leftoverCount;
  bool running = false;

  @override
  Future<List<InstalledApp>> listApps() async => [
    for (var i = 0; i < appCount; i++)
      InstalledApp(
        name: 'App ${i.toString().padLeft(3, '0')} with a fairly long name',
        bundleId: 'com.example.app$i',
        path: '/Applications/App$i.app',
        version: '1.$i',
      ),
  ];

  @override
  Future<List<Leftover>> findLeftovers(InstalledApp app) async => [
    for (var i = 0; i < leftoverCount; i++)
      Leftover(
        path: '$_long/leftover$i',
        kind: i.isEven ? LeftoverKind.cache : LeftoverKind.support,
        risk: i.isEven ? JunkRisk.safe : JunkRisk.risky,
        byName: i % 5 == 0,
      ),
    for (var i = 0; i < 3; i++)
      Leftover(
        path: '/Library/LaunchDaemons/com.example.daemon$i.plist',
        kind: LeftoverKind.system,
        risk: JunkRisk.risky,
      ),
  ];

  @override
  Future<bool?> isRunning(InstalledApp app) async => running;
}

/// Bundle sizes wait until the test releases them; everything else is
/// measured at once. Tracks how many run at the same time.
class FakeMeasure {
  final pending = <Completer<int>>[];
  int inFlight = 0;
  int maxInFlight = 0;

  Future<int> call(String path) {
    if (!path.endsWith('.app')) return Future.value(4096);
    final c = Completer<int>();
    pending.add(c);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    return c.future.whenComplete(() => inFlight--);
  }

  Future<void> releaseAll(WidgetTester tester) async {
    var n = 0;
    while (pending.isNotEmpty) {
      final batch = List.of(pending);
      pending.clear();
      for (final c in batch) {
        c.complete(1024 * 1024 * (++n % 7 == 0 ? 900 : n));
      }
      await tester.pump();
    }
  }
}

class BigDevScanner implements FolderScanner {
  BigDevScanner(this.count);
  final int count;
  String? lastPath;
  bool? lastFindDev;

  @override
  Future<FolderScanResult> scan(
    String path,
    bool Function() cancelled, {
    List<String> exclusions = const [],
    bool findDuplicates = false,
    bool findDevFolders = false,
    void Function(ScanProgress)? onProgress,
    void Function(FolderScanResult partial)? onPartial,
  }) async {
    lastPath = path;
    lastFindDev = findDevFolders;
    return FolderScanResult(
      const [],
      0,
      false,
      devFolders: [
        for (var i = 0; i < count; i++)
          i % 3 == 2
              ? DevFolder(
                  '$_long/tool$i',
                  'Gradle global caches',
                  'Shared cache. Downloaded again when needed.',
                  logicalBytes: i * 1000,
                  locationSource: 'GRADLE_USER_HOME environment variable',
                )
              : DevFolder(
                  '$_long/project$i/node_modules',
                  'Node.js dependencies',
                  'Reinstall with npm install.',
                  logicalBytes: i * 1000,
                  projectMarker: '$_long/project$i/package.json',
                ),
      ],
    );
  }
}

void main() {
  setUp(() {
    gitGuard = GitGuard(
      git: (args, dir) async => ProcessResult(0, 1, '', ''),
      modified: (_) async => null,
    );
  });

  group('Clean up with 80 locations', () {
    Future<CleanupViewModel> pumpCleanup(
      WidgetTester tester, {
      Size size = const Size(1280, 800),
      double textScale = 1,
    }) async {
      final model = CleanupViewModel(
        loader: () async => fail('must not rescan'),
      );
      addTearDown(model.dispose);
      model.found = junk(80);
      await pumpPage(
        tester,
        CleanupPage(model: model, onNavigate: (_) {}),
        size: size,
        textScale: textScale,
      );
      return model;
    }

    testWidgets('search opens matching groups and narrows rows', (
      tester,
    ) async {
      await pumpCleanup(tester);
      await tester.tap(find.text('Review all'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'location 42');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('Showing 1 of 80'), findsOneWidget);
      expect(find.text('Junk location 42'), findsOneWidget);
      expect(find.text('Junk location 41'), findsNothing);
    });

    testWidgets('simple view first, groups collapsed, rows lazy', (
      tester,
    ) async {
      final model = await pumpCleanup(tester);
      expect(find.text('Clean safe junk…'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      await tester.tap(find.text('Review all'));
      await tester.pump();
      // Three collapsed group headers, nothing selected.
      expect(find.byType(Checkbox), findsNWidgets(3));
      expect(find.text('Nothing selected'), findsOneWidget);
      await tester.tap(find.textContaining('System junk'));
      await tester.pump();
      final built = find.textContaining('Junk location ').evaluate().length;
      expect(built, greaterThan(0));
      expect(built, lessThan(27), reason: 'rows build lazily');
      await scrollTo(tester, find.text('Junk location 78'));
      expect(find.text('Junk location 78'), findsOneWidget);
      // The selection bar stays pinned while scrolling.
      expect(find.text('Nothing selected'), findsOneWidget);
      expect(model.selected, isEmpty);
    });

    testWidgets('Clean safe junk lists exactly the Safe items', (tester) async {
      final model = await pumpCleanup(tester);
      await tester.tap(find.text('Clean safe junk…'));
      await tester.pumpAndSettle();
      expect(find.text('Clean safe junk'), findsOneWidget);
      expect(find.textContaining('${model.safe.length} items ·'), findsOne);
      expect(model.safe.length, 60);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(model.selected, isEmpty);
    });

    for (final (size, scale) in [
      (const Size(700, 800), 1.0),
      (const Size(1280, 800), 2.0),
      (const Size(700, 800), 2.0),
    ]) {
      testWidgets('no overflow at $size, text $scale', (tester) async {
        await pumpCleanup(tester, size: size, textScale: scale);
        await tester.tap(find.text('Review all'));
        await tester.pump();
        for (final g in JunkGroup.values) {
          await scrollTo(tester, find.textContaining(g.title));
          await tester.tap(find.textContaining(g.title));
          await tester.pump();
        }
        await scrollTo(tester, find.text('Junk location 79'));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Apps with 150 apps', () {
    Future<(UninstallViewModel, FakeMeasure, FakeCatalog)> pumpApps(
      WidgetTester tester, {
      Size size = const Size(1280, 800),
      double textScale = 1,
    }) async {
      final measure = FakeMeasure();
      final catalog = FakeCatalog();
      final model = UninstallViewModel(catalog: catalog, measure: measure.call);
      addTearDown(model.dispose);
      await pumpPage(
        tester,
        UninstallPage(model: model, supported: true),
        size: size,
        textScale: textScale,
      );
      await tester.pump();
      return (model, measure, catalog);
    }

    testWidgets('list is usable while sizes are measured in background', (
      tester,
    ) async {
      final (model, measure, _) = await pumpApps(tester);
      expect(find.textContaining('App 000'), findsOneWidget);
      expect(find.text('Measuring…'), findsWidgets);
      expect(measure.maxInFlight, lessThanOrEqualTo(model.sizeConcurrency));
      final rows = find.textContaining('with a fairly long name');
      expect(rows.evaluate().length, lessThan(30), reason: 'rows are lazy');
      await measure.releaseAll(tester);
      expect(measure.maxInFlight, lessThanOrEqualTo(model.sizeConcurrency));
      expect(model.appSizes.length, 150);
      expect(find.text('Measuring…'), findsNothing);
      await tester.tap(find.text('Name A to Z'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Largest first').last);
      await tester.pumpAndSettle();
      final first = model.visibleApps.first;
      expect(
        model.appSizes[first.path],
        model.appSizes.values.reduce((a, b) => a > b ? a : b),
      );
      await tester.enterText(find.byType(TextField), 'App 149');
      await tester.pump(const Duration(milliseconds: 300)); // search debounce
      expect(model.visibleApps, hasLength(1));
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 300));
      await scrollTo(tester, find.textContaining('App 149'));
    });

    testWidgets('detail selects nothing until the primary action', (
      tester,
    ) async {
      final (model, measure, _) = await pumpApps(tester);
      await measure.releaseAll(tester);
      await tester.tap(find.textContaining('App 000'));
      await tester.pumpAndSettle();
      expect(model.selected, isEmpty);
      expect(find.text('Nothing selected'), findsOneWidget);
      final boxes = find.byType(Checkbox).evaluate().length;
      expect(boxes, lessThan(40), reason: 'leftover rows are lazy');
      await tester.tap(find.text('Move app and its files to Trash…'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Uninstall App 000'), findsOneWidget);
      expect(find.textContaining('120 items ·'), findsOneWidget);
      expect(find.textContaining('moved to the Trash'), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      // Nothing removed; the user can now untick items on the page.
      expect(model.lastOutcomes, isNull);
      expect(model.selected, hasLength(120));
      expect(find.text('Move 120 items to Trash…'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(find.text('Move 119 items to Trash…'), findsOneWidget);
      // System-wide items are listed, never selectable.
      await scrollTo(tester, find.text('System-wide items'));
      await scrollTo(
        tester,
        find.text('/Library/LaunchDaemons/com.example.daemon2.plist'),
      );
      expect(model.selected.any((l) => !l.removable), isFalse);
    });

    testWidgets('running app cannot be uninstalled', (tester) async {
      final (model, measure, catalog) = await pumpApps(tester);
      catalog.running = true;
      await measure.releaseAll(tester);
      await tester.tap(find.textContaining('App 000'));
      await tester.pumpAndSettle();
      expect(find.textContaining('is running. Quit it'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Move app and its files to Trash…'),
      );
      expect(button.onPressed, isNull);
      expect(model.selected, isEmpty);
    });

    for (final (size, scale) in [
      (const Size(700, 800), 1.0),
      (const Size(700, 800), 2.0),
    ]) {
      testWidgets('no overflow at $size, text $scale', (tester) async {
        final (_, measure, _) = await pumpApps(
          tester,
          size: size,
          textScale: scale,
        );
        await scrollTo(tester, find.textContaining('App 060'));
        await measure.releaseAll(tester);
        await tester.tap(find.textContaining('App 060'));
        await tester.pumpAndSettle();
        await scrollTo(
          tester,
          find.text('/Library/LaunchDaemons/com.example.daemon2.plist'),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Developer with 300 folders', () {
    Future<(FolderScanViewModel, BigDevScanner)> pumpDev(
      WidgetTester tester, {
      bool scanned = true,
      Size size = const Size(1280, 800),
      double textScale = 1,
    }) async {
      final scanner = BigDevScanner(300);
      final model = FolderScanViewModel(scanner, () async => fail('no picker'));
      addTearDown(model.dispose);
      if (scanned) {
        model.findDevFolders = true;
        model.root = '/home/someone';
        await model.rescan();
      }
      await pumpPage(
        tester,
        DeveloperPage(model: model, onNavigate: (_) {}),
        size: size,
        textScale: textScale,
      );
      return (model, scanner);
    }

    testWidgets('search finds folders across sections', (tester) async {
      await pumpDev(tester);
      await tester.enterText(find.byType(TextField), 'gradle');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      final shown = find.textContaining(RegExp(r'^Showing \d+ of 300'));
      expect(shown, findsOneWidget);
      expect(find.textContaining('Node.js dependencies'), findsNothing);
    });

    testWidgets('without a scan, one action scans the home folder', (
      tester,
    ) async {
      final (model, scanner) = await pumpDev(tester, scanned: false);
      expect(find.text('Scan home folder'), findsOneWidget);
      await tester.tap(find.text('Scan home folder'));
      await tester.pumpAndSettle();
      expect(scanner.lastFindDev, isTrue);
      expect(
        scanner.lastPath,
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'],
      );
      expect(model.result!.devFolders, hasLength(300));
      expect(find.text('Project folders · 200'), findsOneWidget);
    });

    testWidgets('long sections start collapsed and rows are lazy', (
      tester,
    ) async {
      final (model, _) = await pumpDev(tester);
      expect(find.text('Project folders · 200'), findsOneWidget);
      expect(find.text('Tool caches · 100'), findsOneWidget);
      expect(find.text('Docker'), findsOneWidget);
      expect(find.text('Package managers'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      await tester.tap(find.text('Project folders · 200'));
      await tester.pump();
      final built = find.byType(Checkbox).evaluate().length;
      expect(built, greaterThan(0));
      expect(built, lessThan(30), reason: 'rows build lazily');
      await scrollTo(tester, find.text('Show 50 more'));
      await tester.tap(find.text('Show 50 more'));
      await tester.pump();
      await scrollTo(tester, find.text('Show 50 more'));
      expect(find.text('Nothing selected'), findsOneWidget);
      expect(model.selectedCleanupCount, 0);
    });

    for (final (size, scale) in [
      (const Size(700, 800), 1.0),
      (const Size(700, 800), 2.0),
    ]) {
      testWidgets('no overflow at $size, text $scale', (tester) async {
        await pumpDev(tester, size: size, textScale: scale);
        await scrollTo(tester, find.text('Project folders · 200'));
        await tester.tap(find.text('Project folders · 200'));
        await tester.pump();
        await scrollTo(tester, find.text('Tool caches · 100'));
        await tester.tap(find.text('Tool caches · 100'));
        await tester.pump();
        await scrollTo(tester, find.text('Package managers'));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
