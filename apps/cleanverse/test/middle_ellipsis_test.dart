import 'package:cleanverse/src/app/ui.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long paths keep the start and the file name', (tester) async {
    const path =
        '/Users/someone/Library/Application Support/Some Vendor/Deep/Folder/report-final.pdf';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 220, child: MiddleEllipsisText(path)),
          ),
        ),
      ),
    );
    final shown = tester.widget<Text>(find.byType(Text)).data!;
    expect(shown, contains('…'));
    expect(shown, startsWith('/U'));
    expect(shown, endsWith('.pdf'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('short text is unchanged', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MiddleEllipsisText('/tmp/a.txt'))),
    );
    expect(find.text('/tmp/a.txt'), findsOneWidget);
  });
}
