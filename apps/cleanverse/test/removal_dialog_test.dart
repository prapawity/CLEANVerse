import 'package:cleanverse/src/data/removal.dart';
import 'package:cleanverse/src/features/cleanup/removal_dialog.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('confirmation with 500 items builds lazily and still lists all', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final items = [
      for (var i = 0; i < 500; i++)
        RemovalItem(
          path: '/tmp/fixture/item$i',
          label: 'Item $i',
          bytes: 1024,
          recommended: RemovalMode.trash,
          allowedRoot: '/tmp/fixture',
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                confirmRemoval(context, title: 'Confirm', items: items),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('500 items · 500.0 KiB observed'), findsOneWidget);
    final built = find
        .textContaining(RegExp(r'^Item \d+ · '))
        .evaluate()
        .length;
    expect(built, lessThan(60));
    await tester.dragUntilVisible(
      find.text('Item 499 · 1.0 KiB'),
      find.byType(CustomScrollView),
      const Offset(0, -400),
      maxIteration: 200,
    );
    expect(find.text('Item 499 · 1.0 KiB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
