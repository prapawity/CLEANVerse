import 'package:cleanverse/src/app/app_icon.dart';
import 'package:cleanverse/src/data/app_icons.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// 1×1 transparent PNG.
final _png = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/app_icon');
  var calls = 0;

  setUp(() {
    calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls++;
          return (call.arguments as Map)['path'] == '/A.app' ? _png : null;
        });
  });

  test('icons are cached and unsupported platforms return null', () async {
    final icons = AppIcons(channel: channel, supported: true);
    expect(await icons.png('/A.app'), isNotNull);
    await icons.png('/A.app');
    expect(calls, 1);
    final off = AppIcons(channel: channel, supported: false);
    expect(await off.png('/A.app'), isNull);
    expect(calls, 1);
  });

  test('cache is bounded', () async {
    final icons = AppIcons(channel: channel, supported: true, maxCached: 2);
    for (final p in ['/1', '/2', '/3', '/1']) {
      await icons.png(p);
    }
    expect(calls, 4); // '/1' was evicted and loaded again
  });

  testWidgets('falls back to a generic icon when none is available', (
    tester,
  ) async {
    final icons = AppIcons(channel: channel, supported: true);
    await tester.pumpWidget(
      MaterialApp(home: AppIcon('/missing.app', icons: icons)),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.apps_rounded), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('shows the real icon when available', (tester) async {
    final icons = AppIcons(channel: channel, supported: true);
    await tester.pumpWidget(MaterialApp(home: AppIcon('/A.app', icons: icons)));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });
}
