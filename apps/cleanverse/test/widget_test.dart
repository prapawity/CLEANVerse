import 'package:cleanverse/src/app.dart';
import 'package:cleanverse/src/demo_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preview explains its scope and shows examples', (tester) async {
    await tester.pumpWidget(CleanVerseApp(repository: DemoScanRepository()));
    expect(find.textContaining('example data only'), findsOneWidget);
    expect(find.text('Holiday video.mp4'), findsNothing);
    await tester.tap(find.text('Show example results'));
    await tester.pumpAndSettle();
    expect(find.text('Holiday video.mp4'), findsOneWidget);
    expect(find.text('These are not files from your device.'), findsOneWidget);
  });
}
