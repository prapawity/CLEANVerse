import 'dart:io';

import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/features/uninstall/uninstall_view_model.dart';
import 'package:cleanverse/src/features/uninstall/app_catalog.dart';
import 'package:cleanverse/src/data/volumes.dart';
import 'package:cleanverse/src/features/cleanup/cleanup_view_model.dart';
import 'package:cleanverse/src/features/cleanup/cleanup_page.dart';
import 'package:cleanverse/src/features/cleanup/junk_catalog.dart';
import 'package:cleanverse/src/features/example/demo_scan.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/features/developer/developer_page.dart';
import 'package:cleanverse/src/features/developer/git_guard.dart';
import 'package:cleanverse/src/features/scan/large_files_page.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';

import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFolderScanner implements FolderScanner {
  int scans = 0;
  final paths = <String>[];
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
    scans++;
    paths.add(path);
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
    void Function(FolderScanResult partial)? onPartial,
  }) {
    onProgress?.call(const ScanProgress(ScanPhase.comparing, 20, 2, 4));
    return completion.future;
  }
}

/// Sends one "results so far" snapshot, then waits until completed.
class LiveFolderScanner implements FolderScanner {
  final completion = Completer<FolderScanResult>();
  @override
  Future<FolderScanResult> scan(
    String path,
    bool Function() cancelled, {
    List<String> exclusions = const [],
    bool findDuplicates = false,
    bool findDevFolders = false,
    void Function(ScanProgress)? onProgress,
    void Function(FolderScanResult partial)? onPartial,
  }) {
    onProgress?.call(const ScanProgress(ScanPhase.discovering, 500, 0, 0));
    onPartial?.call(
      const FolderScanResult(
        [LargeFile('home/Movies/holiday.mov', 3 * 1024 * 1024 * 1024)],
        0,
        false,
        filesSeen: 500,
        totalBytes: 5 * 1024 * 1024 * 1024,
        folderSummaries: [
          FolderSummary(
            'home/Movies',
            4 * 1024 * 1024 * 1024,
            10,
            folderPath: 'home/Movies',
          ),
        ],
      ),
    );
    return completion.future;
  }
}

class _NoVolumes extends VolumeReader {
  @override
  Future<List<Volume>> list() async => const [];
}

class _NoApps extends AppCatalog {
  _NoApps()
    : super(environment: const {}, folders: const [], systemFolders: const []);
  @override
  Future<List<InstalledApp>> listApps() async => const [];
}

Future<void> pumpApp(
  WidgetTester tester,
  FolderScanner scanner, {
  Size size = const Size(1400, 1000),
  CleanupViewModel? cleanup,
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
      homeFolder: () => 'home',
      cleanup: cleanup ?? CleanupViewModel(loader: () async => const []),
      volumes: VolumesModel(reader: _NoVolumes()),
      uninstall: UninstallViewModel(catalog: _NoApps()),
    ),
  );
}

/// Pumps one page that owns its scrolling, as the shell will host it.
Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(1400, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCleanVerseTheme(),
      home: Scaffold(body: page),
    ),
  );
  await tester.pumpAndSettle();
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
    await tester.tap(find.text('Scan now'));
    await tester.pump();
    expect(find.text('Scanning…'), findsOneWidget);
    expect(find.text('Comparing files: 2 of 4 checked.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Stopping the scan…'), findsOneWidget);
    scanner.completion.complete(const FolderScanResult([], 0, true));
    await tester.pumpAndSettle();
    expect(find.textContaining('results are partial'), findsOneWidget);
  });

  testWidgets('narrow screen supports enlarged text without overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, FakeFolderScanner(), size: const Size(375, 812));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Scan now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan now'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Your biggest files'), findsOneWidget);
  });

  testWidgets('700 px window with enlarged text does not overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, FakeFolderScanner(), size: const Size(700, 700));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Scan now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan now'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Your biggest files'), findsOneWidget);
    await tester.ensureVisible(find.text('Settings').first);
    await openSection(tester, 'Settings');
    expect(tester.takeException(), isNull);
  });

  testWidgets('scan now uses the home folder without a picker', (tester) async {
    final scanner = FakeFolderScanner();
    var junkChecks = 0;
    await pumpApp(
      tester,
      scanner,
      cleanup: CleanupViewModel(
        loader: () async {
          junkChecks++;
          return const [];
        },
      ),
    );
    expect(find.text('Scan now'), findsOneWidget);
    expect(find.text('Choose another folder…'), findsOneWidget);
    // The old options panel is gone from the first screen.
    expect(find.text('Find matching files'), findsNothing);
    await tester.tap(find.text('Scan now'));
    await tester.pumpAndSettle();
    expect(scanner.paths, ['home']);
    expect(junkChecks, 1);
    expect(find.textContaining('in your home folder'), findsOneWidget);
    expect(find.text('80.0 MiB'), findsOneWidget);
    expect(find.text('Developer storage'), findsOneWidget);
    // Nothing is found in junk, so no junk finding is shown.
    expect(find.text('Junk you can clean up'), findsNothing);
    expect(find.text('Scan again'), findsOneWidget);
    expect(find.text('Change folder'), findsOneWidget);
    await tester.tap(find.text('Change folder'));
    await tester.pumpAndSettle();
    expect(scanner.paths, ['home', 'chosen']);
  });

  testWidgets('findings link to their review pages', (tester) async {
    await pumpApp(tester, FakeFolderScanner());
    await tester.tap(find.text('Scan now'));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be read'), findsOneWidget);
    expect(find.text('1 file of 50 MiB or more.'), findsOneWidget);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Project folders · 1'), findsOneWidget);
    await openSection(tester, 'Storage');
    await tester.tap(find.text('Folders'));
    await tester.pumpAndSettle();
    expect(find.text('Largest folders in this scope'), findsOneWidget);
    expect(find.text('Storage by file type'), findsOneWidget);
    // Below the fold inside the page's own scroll view.
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -3000),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Documents, 2.0 KiB, 1 file'), findsOneWidget);
    expect(find.textContaining('Folder totals are partial'), findsOneWidget);
  });

  testWidgets('review pages ask for a scan first', (tester) async {
    await pumpApp(tester, FakeFolderScanner());
    await openSection(tester, 'Storage');
    expect(find.text('No files to review yet'), findsOneWidget);
    await tester.tap(find.text('Go to Home'));
    await tester.pumpAndSettle();
    expect(find.text('Scan now'), findsOneWidget);
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
    await tester.tap(find.text('Settings').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('Try with sample data'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Try with sample data'));
    await tester.pump(const Duration(milliseconds: 500));
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
    await tester.tap(find.text('Scan now'));
    await tester.pumpAndSettle();
    await openSection(tester, 'Storage');
    await tester.tap(find.text('Duplicates'));
    await tester.pumpAndSettle();
    expect(find.text('Find files with identical contents'), findsOneWidget);
    await tester.tap(find.text('Find duplicates'));
    await tester.pumpAndSettle();
    expect(scanner.scans, 2);
    expect(find.textContaining('1 group of duplicates'), findsOneWidget);
    expect(find.text('chosen/a.txt'), findsOneWidget);
    expect(find.text('chosen/b.txt'), findsOneWidget);
    expect(find.textContaining('Delete'), findsNothing);
  });

  testWidgets('developer folder review shows detected category', (
    tester,
  ) async {
    final model = FolderScanViewModel(
      FakeFolderScanner(),
      () async => 'chosen',
    );
    addTearDown(model.dispose);
    model.setFindDevFolders(true);
    await model.start();
    await pumpPage(tester, DeveloperPage(model: model, onNavigate: (_) {}));
    expect(find.text('Project folders · 1'), findsOneWidget);
    expect(find.text('Tool caches · 1'), findsOneWidget);
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
    expect(find.text('Nothing selected'), findsOneWidget);
    await tester.tap(
      find.bySemanticsLabel('Select Node.js dependencies for review'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1 folder selected'), findsOneWidget);
    await tester.tap(find.text('Review and clean…'));
    await tester.pumpAndSettle();
    expect(find.text('Clean developer folders'), findsOneWidget);
    expect(find.text('Recommended for each item'), findsOneWidget);
    // Cancelling removes nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Clean developer folders'), findsNothing);
  });

  testWidgets('clean up checks automatically and selects nothing', (
    tester,
  ) async {
    final cleanup = CleanupViewModel(loader: () async => const [], trash: null);
    addTearDown(cleanup.dispose);
    await pumpPage(tester, CleanupPage(model: cleanup, onNavigate: (_) {}));
    expect(find.text('Nothing to clean'), findsOneWidget);
    expect(find.text('Clean safe junk…'), findsNothing);
    expect(cleanup.selected, isEmpty);
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

  testWidgets('sort choice is remembered when coming back to a page', (
    tester,
  ) async {
    await pumpApp(tester, FakeFolderScanner());
    await tester.tap(find.text('Scan now'));
    await tester.pumpAndSettle();
    await openSection(tester, 'Storage');
    await tester.tap(find.text('Largest first'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest first').last);
    await tester.pumpAndSettle();
    await openSection(tester, 'Home');
    await openSection(tester, 'Storage');
    expect(find.text('Oldest first'), findsOneWidget);
  });

  testWidgets('Home shows results so far while scanning', (tester) async {
    final scanner = LiveFolderScanner();
    await pumpApp(tester, scanner);
    await tester.tap(find.text('Scan now'));
    await tester.pump();
    expect(find.text('5.0 GiB found so far'), findsOneWidget);
    expect(find.text('holiday.mov'), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);
    scanner.completion.complete(
      const FolderScanResult([], 0, false, filesSeen: 500),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('found so far'), findsNothing);
  });
}
