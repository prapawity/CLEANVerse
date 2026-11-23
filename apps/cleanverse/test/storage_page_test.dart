import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/data/scan_history.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/features/scan/duplicates_page.dart';
import 'package:cleanverse/src/features/scan/large_files_page.dart';
import 'package:cleanverse/src/features/scan/space_lens_page.dart';
import 'package:cleanverse/src/features/storage/storage_page.dart';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Synthetic large result. Paths are fake; nothing touches the disk.
class LargeFolderScanner implements FolderScanner {
  LargeFolderScanner({
    this.files = 2000,
    this.groups = 300,
    this.folders = 200,
  });
  final int files;
  final int groups;
  final int folders;

  @override
  Future<FolderScanResult> scan(
    String path,
    bool Function() cancelled, {
    List<String> exclusions = const [],
    bool findDuplicates = false,
    bool findDevFolders = false,
    void Function(ScanProgress)? onProgress,
    void Function(FolderScanResult partial)? onPartial,
  }) async => FolderScanResult(
    [
      for (var i = 0; i < files; i++)
        LargeFile(
          'chosen/deep/nested/folder/with/a/long/name/file_$i.bin',
          (files - i) * 1024 * 1024,
          modified: DateTime(2020 + i % 7, 1, 1),
        ),
    ],
    0,
    false,
    filesSeen: files,
    totalBytes: files * 1024,
    storageCategories: const [
      StorageCategory('Documents', 2048, 1),
      StorageCategory('Videos', 4096, 2),
    ],
    folderSummaries: [
      for (var i = 0; i < folders; i++)
        FolderSummary(
          'chosen/folder_$i',
          (folders - i) * 1000,
          3,
          folderPath: 'chosen/folder_$i',
        ),
    ],
    duplicates: findDuplicates
        ? [
            for (var g = 0; g < groups; g++)
              [
                LargeFile('chosen/a/dup_$g.txt', 1000 + g),
                LargeFile('chosen/b/dup_$g.txt', 1000 + g),
              ],
          ]
        : const [],
  );
}

Future<FolderScanViewModel> _model(
  WidgetTester tester, {
  bool duplicates = false,
}) async {
  final model = FolderScanViewModel(LargeFolderScanner(), () async => 'chosen');
  addTearDown(model.dispose);
  await model.start();
  if (duplicates) await model.enableAndRescan(duplicates: true);
  return model;
}

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(1280, 800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: page),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _storage(
  FolderScanViewModel model, {
  int tab = 0,
  ValueNotifier<ScanComparison?>? growth,
}) => StoragePage(
  initialTab: tab,
  files: LargeFilesPage(
    model: model,
    onNavigate: (_) {},
    now: () => DateTime(2026, 11, 22),
  ),
  folders: SpaceLensPage(model: model, onNavigate: (_) {}, growth: growth),
  duplicates: DuplicatesPage(model: model, onNavigate: (_) {}),
);

void main() {
  testWidgets('biggest files builds a bounded lazy list and shows more', (
    tester,
  ) async {
    final model = await _model(tester);
    await _pump(tester, _storage(model));
    expect(tester.takeException(), isNull);
    final built = find.byType(Checkbox).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(largeFilesPageSize));
    // Nothing is preselected.
    expect(find.text('Select files to remove'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -20000));
    await tester.pumpAndSettle();
    expect(find.text('file_49.bin'), findsOneWidget);
    expect(find.text('file_50.bin'), findsNothing);
    await tester.tap(find.text('Show 50 more of 1950'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -20000));
    await tester.pumpAndSettle();
    expect(find.text('file_99.bin'), findsOneWidget);
    expect(find.text('Show 50 more of 1900'), findsOneWidget);
  });

  testWidgets('biggest files sorts by age and keeps the bar pinned', (
    tester,
  ) async {
    final model = await _model(tester);
    await _pump(tester, _storage(model));
    await tester.tap(find.text('Largest first'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest first').last);
    await tester.pumpAndSettle();
    expect(find.text('file_0.bin'), findsOneWidget);
    expect(find.text('file_1.bin'), findsNothing);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.textContaining('1 file selected'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    // The bar sits outside the scroll view, so it is still on screen.
    expect(find.textContaining('1 file selected'), findsOneWidget);
  });

  testWidgets('folders tab lists 200 folders lazily with file types', (
    tester,
  ) async {
    final model = await _model(tester);
    await _pump(tester, _storage(model, tab: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Explore').evaluate().length, lessThan(folderPageSize));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -20000));
    await tester.pumpAndSettle();
    expect(find.text('Show 50 more of 150'), findsOneWidget);
    expect(find.bySemanticsLabel('Documents, 2.0 KiB, 1 file'), findsOneWidget);
  });

  testWidgets('folders tab shows what grew when a comparison exists', (
    tester,
  ) async {
    final model = await _model(tester);
    final growth = ValueNotifier<ScanComparison?>(
      ScanComparison(
        previous: ScanSnapshot(
          root: 'chosen',
          time: DateTime(2026, 11, 20),
          totalBytes: 1000,
          folders: const {},
        ),
        current: ScanSnapshot(
          root: 'chosen',
          time: DateTime(2026, 11, 22),
          totalBytes: 3000,
          folders: const {},
        ),
        grew: [
          for (var i = 0; i < 8; i++) FolderGrowth('chosen/folder_$i', 0, 1000),
        ],
      ),
    );
    addTearDown(growth.dispose);
    await _pump(tester, _storage(model, tab: 1, growth: growth));
    expect(find.text('What grew since 2026-11-20'), findsOneWidget);
    expect(find.text('Show all 8'), findsOneWidget);
  });

  testWidgets('duplicates offers one action, then collapsed lazy groups', (
    tester,
  ) async {
    final model = FolderScanViewModel(
      LargeFolderScanner(),
      () async => 'chosen',
    );
    addTearDown(model.dispose);
    await model.start();
    await _pump(tester, _storage(model, tab: 2));
    expect(find.text('Find duplicates'), findsOneWidget);
    await tester.tap(find.text('Find duplicates'));
    await tester.pumpAndSettle();
    expect(find.textContaining('300 groups of duplicates'), findsOneWidget);
    // Collapsed: no copy checkboxes until a group is opened.
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('dup_299.txt'), findsOneWidget);
    await tester.tap(find.text('dup_299.txt'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNWidgets(2));
    // Keep-one guard: after selecting one copy the other is locked.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.text('Kept'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -40000));
    await tester.pumpAndSettle();
    expect(find.text('Show 50 more of 250'), findsOneWidget);
  });

  testWidgets('empty state sends the user Home', (tester) async {
    final model = FolderScanViewModel(
      LargeFolderScanner(),
      () async => 'chosen',
    );
    addTearDown(model.dispose);
    Section? went;
    await _pump(
      tester,
      LargeFilesPage(model: model, onNavigate: (s) => went = s),
    );
    await tester.tap(find.text('Go to Home'));
    expect(went, Section.home);
  });

  for (final (size, scale) in [
    (const Size(700, 800), 1.0),
    (const Size(700, 800), 2.0),
    (const Size(1280, 800), 2.0),
  ]) {
    testWidgets('no overflow at $size and text $scale', (tester) async {
      final model = await _model(tester, duplicates: true);
      for (var tab = 0; tab < 3; tab++) {
        await _pump(
          tester,
          _storage(model, tab: tab),
          size: size,
          textScale: scale,
        );
        expect(tester.takeException(), isNull, reason: 'tab $tab');
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'tab $tab scrolled');
      }
    });
  }

  group('search and sort', () {
    Future<void> search(WidgetTester tester, String q) async {
      await tester.enterText(find.byType(TextField), q);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }

    testWidgets('biggest files: search narrows, sort reorders', (tester) async {
      final model = await _model(tester);
      await _pump(tester, _storage(model));
      await search(tester, 'file_1999');
      expect(find.text('Showing 1 of 2,000'), findsNothing);
      expect(find.textContaining('Showing 1 of 2000'), findsOneWidget);
      expect(find.text('file_1999.bin'), findsOneWidget);

      await search(tester, '');
      await tester.tap(find.text('Largest first'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smallest first').last);
      await tester.pumpAndSettle();
      expect(find.text('file_1999.bin'), findsOneWidget);
      expect(find.text('file_0.bin'), findsNothing);
    });

    testWidgets('no matches offers a way out', (tester) async {
      final model = await _model(tester);
      await _pump(tester, _storage(model));
      await search(tester, 'nothing-like-this');
      expect(find.text('No matches for "nothing-like-this".'), findsOneWidget);
      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('file_0.bin'), findsOneWidget);
    });

    testWidgets('folders: search by folder name', (tester) async {
      final model = await _model(tester);
      await _pump(tester, _storage(model, tab: 1));
      await search(tester, 'folder_15');
      // folder_15 and folder_150 … folder_159
      expect(find.textContaining('Showing 11 of 200'), findsOneWidget);
    });

    testWidgets('duplicates: search keeps whole groups', (tester) async {
      final model = await _model(tester, duplicates: true);
      await _pump(tester, _storage(model, tab: 2));
      await search(tester, 'dup_7');
      // dup_7 and dup_70 … dup_79
      expect(find.textContaining('Showing 11 of 300'), findsOneWidget);
    });
  });
}
