import 'package:cleanverse/src/features/cleanup/full_disk_access.dart';
import 'package:cleanverse/src/features/cleanup/full_disk_access_banner.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpBanner(
  WidgetTester tester,
  FullDiskAccess access, {
  Future<bool> Function()? open,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: FullDiskAccessBanner(
        check: () async => access,
        openSettings: open ?? () async => true,
      ),
    ),
  ),
);

void main() {
  test('any readable protected path means granted', () async {
    final r = await checkFullDiskAccess(
      home: '/Users/x',
      probe: (path) async => path.endsWith('Safari') ? true : false,
    );
    expect(r, FullDiskAccess.granted);
  });

  test('permission errors mean denied', () async {
    final r = await checkFullDiskAccess(
      home: '/Users/x',
      probe: (_) async => false,
    );
    expect(r, FullDiskAccess.denied);
  });

  test('missing locations are unknown, not denied', () async {
    final r = await checkFullDiskAccess(
      home: '/Users/x',
      probe: (_) async => null,
    );
    expect(r, FullDiskAccess.unknown);
  });

  testWidgets('banner appears only when access is denied', (tester) async {
    await pumpBanner(tester, FullDiskAccess.granted);
    await tester.pump();
    expect(find.text('Optional: allow Full Disk Access'), findsNothing);

    await pumpBanner(tester, FullDiskAccess.unknown);
    await tester.pump();
    expect(find.text('Optional: allow Full Disk Access'), findsNothing);
  });

  testWidgets('denied banner opens settings and can be dismissed', (
    tester,
  ) async {
    var opened = false;
    await pumpBanner(
      tester,
      FullDiskAccess.denied,
      open: () async {
        opened = true;
        return true;
      },
    );
    await tester.pump();
    expect(find.text('Optional: allow Full Disk Access'), findsOneWidget);
    await tester.tap(find.text('Open System Settings'));
    await tester.pump();
    expect(opened, isTrue);
    expect(find.textContaining('turn on CLEANVerse'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pump();
    expect(find.text('Optional: allow Full Disk Access'), findsNothing);
  });
}
