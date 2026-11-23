import 'dart:io';

import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/features/cleanup/cleanup_view_model.dart';
import 'package:cleanverse/src/features/cleanup/cleanup_page.dart';
import 'package:cleanverse/src/features/cleanup/junk_catalog.dart';
import 'package:cleanverse/src/features/example/demo_scan.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/features/developer/developer_page.dart';
import 'package:cleanverse/src/features/developer/git_guard.dart';
import 'package:cleanverse/src/features/scan/large_files_page.dart';
import 'package:cleanverse/src/app/ui.dart';

import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFolderScanner implements FolderScanner {
  int scans = 0;
  @override
  Future<FolderScanResult> scan(
    String path,
    bool Function() cancelled, {
    List<String> exclusions = const [],
    bool findDuplicates = false,
    bool findDevFolders = false,
    void Function(ScanProgress)? onProgress,
  }) async {
    scans++;
    return FolderScanResult(
      [
        LargeFile(
          'chosen/movie.mp4',
          80 * 1024 * 1024,
          modified: DateTime(2020, 1, 1),
        ),
        LargeFile('chosen/example.txt', 2048, modified: DateTime(2026, 11, 1)),
      ],
      1,
      false,
      filesSeen: 2,
      totalBytes: 80 * 1024 * 1024 + 2048,
      storageCategories: const [StorageCategory('Documents', 2048, 1)],
      folderSummaries: const [
        FolderSummary('chosen/project', 2048, 1, folderPath: 'chosen/project'),
      ],
      duplicates: findDuplicates
          ? const [
              [LargeFile('chosen/a.txt', 10), LargeFile('chosen/b.txt', 10)],
            ]
          : const [],
      devFolders: findDevFolders
          ? const [
              DevFolder(
                'chosen/project/node_modules',
                'Node.js dependencies',
                'Review before cleanup.',
                projectMarker: 'chosen/project/package.json',
              ),
              DevFolder(
                'chosen/cache',
                'Gradle global caches',
                'Shared cache.',
                locationSource: 'GRADLE_USER_HOME environment variable',
              ),
            ]
          : const [],
    );
  }
}

class PendingFolderScanner implements FolderScanner {
  final completion = Completer<FolderScanResult>();
  @override
  Future<FolderScanResult> scan(
    String path,
    bool Function() cancelled, {
    List<String> exclusions = const [],
    bool findDuplicates = false,
    bool findDevFolders = false,
    void Function(ScanProgress)? onProgress,
  }) {
    onProgress?.call(const ScanProgress(ScanPhase.comparing, 20, 2, 4));
    return completion.future;
  }
}

Future<void> pumpApp(
  WidgetTester tester,
  FolderScanner scanner, {
  Size size = const Size(1400, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    CleanVerseApp(
      repository: DemoScanRepository(),
      scanner: scanner,
      pickFolder: () async => 'chosen',
    ),
  );
}

/// Sidebar items come before page content in the tree.
Future<void> openSection(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // No real git processes inside widget tests.
    gitGuard = GitGuard(
      git: (args, dir) async => ProcessResult(0, 1, '', ''),
      modified: (_) async => null,
    );
  });

  testWidgets('shows real matching progress and cancellation state', (
    tester,
  ) async {
    final scanner = PendingFolderScanner();
    await pumpApp(tester, scanner);
    await tester.tap(find.text('Choose and scan folder'));
    await tester.pump();
    expect(find.text('Comparing files: 2 of 4 checked.'), findsOneWidget);
    await tester.tap(find.text('Cancel scan'));
    await tester.pump();
    expect(find.text('Stopping the scan…'), findsOneWidget);
    scanner.completion.complete(const FolderScanResult([], 0, true));
    await tester.pumpAndSettle();
    expect(find.text('Scan cancelled. Results are partial.'), findsOneWidget);
  });

  testWidgets('narrow screen supports enlarged text without overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, FakeFolderScanner(), size: const Size(375, 812));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Choose and scan folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose and scan folder'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Scan summary'), findsOneWidget);
  });

  testWidgets('summary links each category to its review page', (tester) async {
    await pumpApp(tester, FakeFolderScanner());
    await tester.tap(find.text('Choose and scan folder'));
    await tester.pumpAndSettle();
    expect(find.text('Scan summary'), findsOneWidget);
    expect(find.text('Folder: chosen'), findsOneWidget);
    expect(find.textContaining('Results may be incomplete'), findsOneWidget);
    expect(find.text('1 file · 80.0 MiB'), findsOneWidget);
    expect(find.text('Not included'), findsNWidgets(2));
    // Tiles are ordered Space Lens, Large & old, Duplicates, Developer.
    await tester.tap(find.text('Review').first);
    await tester.pumpAndSettle();
    expect(find.text('Largest folders in this scope'), findsOneWidget);
    expect(find.text('Storage by file type'), findsOneWidget);
    expect(find.bySemanticsLabel('Documents, 2.0 KiB, 1 file'), findsOneWidget);
    expect(find.textContaining('Folder totals are partial'), findsOneWidget);
  });

  testWidgets('review pages ask for a scan first', (tester) async {
    await pumpApp(tester, FakeFolderScanner());
    await openSection(tester, 'Large & old files');
    expect(find.text('No files to review yet'), findsOneWidget);
    await tester.tap(find.text('Go to Smart Scan'));
    await tester.pumpAndSettle();
    expect(find.text('Choose and scan folder'), findsOneWidget);
  });

  testWidgets('large files filter by size and age', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = FolderScanViewModel(
      FakeFolderScanner(),
      () async => 'chosen',
    );
    addTearDown(model.dispose);
    await model.start();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LargeFilesPage(
              model: model,
              onNavigate: (_) {},
              now: () => DateTime(2026, 11, 22),
            ),
          ),
        ),
      ),
    );
    expect(find.text('chosen/example.txt'), findsOneWidget);
    expect(find.text('chosen/movie.mp4'), findsOneWidget);
    await tester.tap(find.text('50 MiB+'));
    await tester.pumpAndSettle();
    expect(find.text('chosen/example.txt'), findsNothing);
    expect(find.text('chosen/movie.mp4'), findsOneWidget);
    await tester.tap(find.text('Older than a year'));
    await tester.pumpAndSettle();
    expect(find.text('chosen/movie.mp4'), findsOneWidget);
    expect(find.text('chosen/example.txt'), findsNothing);
  });

  testWidgets('preview explains its scope and shows examples', (tester) async {
    await pumpApp(tester, FakeFolderScanner());
    await openSection(tester, 'Example scan');
    expect(find.textContaining('example data only'), findsOneWidget);
    expect(find.text('Holiday video.mp4'), findsNothing);
    await tester.tap(find.text('Show example results'));
    await tester.pumpAndSettle();
    expect(find.text('Holiday video.mp4'), findsOneWidget);
    expect(find.text('These are not files from your device.'), findsOneWidget);
  });

  testWidgets('opt-in matching shows groups without removal controls', (
    tester,
  ) async {
    final scanner = FakeFolderScanner();
    await pumpApp(tester, scanner);
    await tester.tap(find.text('Choose and scan folder'));
    await tester.pumpAndSettle();
    await openSection(tester, 'Duplicates');
    expect(find.text('Matching was not part of this scan'), findsOneWidget);
    await tester.tap(find.text('Turn on and scan again'));
    await tester.pumpAndSettle();
    expect(scanner.scans, 2);
    expect(find.text('Matching groups: 1'), findsOneWidget);
    expect(find.text('chosen/a.txt'), findsOneWidget);
    expect(find.text('chosen/b.txt'), findsOneWidget);
    expect(find.textContaining('Delete'), findsNothing);
  });

  testWidgets('developer folder review shows detected category', (
    tester,
  ) async {
    await pumpApp(tester, FakeFolderScanner());
    await tester.tap(find.text('Find developer folders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose and scan folder'));
    await tester.pumpAndSettle();
    await openSection(tester, 'Developer');
    expect(find.text('Developer folders: 2'), findsOneWidget);
    expect(find.text('Project folders'), findsOneWidget);
    expect(find.text('Tool storage candidates'), findsOneWidget);
    expect(find.textContaining('Node.js dependencies'), findsWidgets);
    expect(
      find.text('Project marker: chosen/project/package.json'),
      findsOneWidget,
    );
    expect(
      find.text('Review required · Ownership and active use not verified'),
      findsNWidgets(2),
    );
    expect(
      find.text('Location source: GRADLE_USER_HOME environment variable'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Sizes are logical bytes scanned'),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.bySemanticsLabel('Select Node.js dependencies for review'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsLabel('Select Node.js dependencies for review'),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 selected for review'), findsOneWidget);
    await tester.ensureVisible(find.text('Review and clean'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review and clean'));
    await tester.pumpAndSettle();
    expect(find.text('Clean developer folders'), findsOneWidget);
    expect(find.text('Recommended for each item'), findsOneWidget);
    // Cancelling removes nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Clean developer folders'), findsNothing);
  });

  testWidgets('clean up lists junk by group and selects nothing', (
    tester,
  ) async {
    final cleanup = CleanupViewModel(loader: () async => const [], trash: null);
    addTearDown(cleanup.dispose);
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      CleanVerseApp(repository: DemoScanRepository(), cleanup: cleanup),
    );
    await openSection(tester, 'Clean up');
    expect(find.text('Find junk'), findsOneWidget);
    await tester.tap(find.text('Find junk'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to clean'), findsOneWidget);
    expect(find.text('Select what to clean'), findsOneWidget);
  });

  testWidgets('risk chips show label and explanation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [for (final r in JunkRisk.values) RiskChip(r)],
          ),
        ),
      ),
    );
    for (final r in JunkRisk.values) {
      expect(find.text(r.label), findsOneWidget);
      expect(find.byTooltip(r.explanation), findsOneWidget);
    }
  });

  test('formatBytes uses binary units', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(2048), '2.0 KiB');
    expect(formatBytes(80 * 1024 * 1024), '80.0 MiB');
  });
}
