import 'package:cleanverse/src/app.dart';
import 'package:cleanverse/src/demo_scan.dart';
import 'package:cleanverse/src/desktop_scan.dart';
import 'package:cleanverse/src/folder_scan_card.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFolderScanner implements FolderScanner {
  @override
  Future<FolderScanResult> scan(
    String path,
    bool Function() cancelled, {
    List<String> exclusions = const [],
  }) async =>
      const FolderScanResult([LargeFile('chosen/example.txt', 2048)], 1, false);
}

void main() {
  testWidgets('narrow screen supports enlarged text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(CleanVerseApp(repository: DemoScanRepository()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview explains its scope and shows examples', (tester) async {
    await tester.pumpWidget(CleanVerseApp(repository: DemoScanRepository()));
    expect(find.textContaining('example data only'), findsOneWidget);
    expect(find.text('Holiday video.mp4'), findsNothing);
    await tester.ensureVisible(find.text('Show example results'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show example results'));
    await tester.pumpAndSettle();
    expect(find.text('Holiday video.mp4'), findsOneWidget);
    expect(find.text('These are not files from your device.'), findsOneWidget);
  });

  testWidgets('folder scan shows selected scope and incomplete results', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FolderScanCard(
            scanner: FakeFolderScanner(),
            pickFolder: () async => 'chosen',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose and scan folder'));
    await tester.pumpAndSettle();
    expect(find.text('Folder: chosen'), findsOneWidget);
    expect(find.text('chosen/example.txt'), findsOneWidget);
    expect(find.textContaining('Results may be incomplete'), findsOneWidget);
  });
}
