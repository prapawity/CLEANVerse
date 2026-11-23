import 'package:cleanverse/src/data/volumes.dart';
import 'package:cleanverse/src/features/home/storage_breakdown.dart';
import 'package:cleanverse/src/features/home/storage_dashboard.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const gib = 1024 * 1024 * 1024;

class FakeReader extends VolumeReader {
  FakeReader(this.result);
  final List<Volume> result;
  @override
  Future<List<Volume>> list() async => result;
}

const system = Volume(
  path: '/',
  name: 'Macintosh HD',
  totalBytes: 500 * gib,
  freeBytes: 100 * gib,
  internal: true,
  isSystem: true,
);
const usb = Volume(
  path: '/Volumes/Backup',
  name: 'Backup',
  totalBytes: 1000 * gib,
  freeBytes: 50 * gib,
  removable: true,
);

void main() {
  int bytesOf(List<StorageSlice> s, StorageKind k) =>
      s.where((x) => x.kind == k).fold(0, (a, b) => a + b.bytes);

  test('slices add up to the drive and never double count', () {
    final s = breakdown(
      drive: system,
      homeBytes: 250 * gib,
      junkBytes: 20 * gib,
      developerBytes: 30 * gib,
      appsBytes: 40 * gib,
    );
    expect(bytesOf(s, StorageKind.junk), 20 * gib);
    expect(bytesOf(s, StorageKind.developer), 30 * gib);
    expect(bytesOf(s, StorageKind.apps), 40 * gib);
    // Home minus junk and developer data.
    expect(bytesOf(s, StorageKind.files), 200 * gib);
    // 400 used − 290 known.
    expect(bytesOf(s, StorageKind.other), 110 * gib);
    expect(bytesOf(s, StorageKind.free), 100 * gib);
    final total = s.fold<int>(0, (a, b) => a + b.bytes);
    expect(total, system.totalBytes);
  });

  test('over-reported sizes are clamped to used space', () {
    final s = breakdown(
      drive: system,
      homeBytes: 900 * gib,
      junkBytes: 10 * gib,
      appsBytes: 50 * gib,
    );
    final used = s
        .where((x) => x.kind != StorageKind.free)
        .fold<int>(0, (a, b) => a + b.bytes);
    expect(used, system.usedBytes);
    expect(bytesOf(s, StorageKind.other), 0);
  });

  test('df output keeps real filesystems only', () {
    const out =
        '''Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/nvme0n1p2   488281250 300000000 188281250      62% /
tmpfs              8000000         0   8000000       0% /dev/shm
/dev/loop3           56320     56320         0     100% /snap/core/1
/dev/sdb1        976562500 900000000  76562500      93% /media/me/Backup Drive
''';
    final v = parseDf(out);
    expect(v.map((e) => e.path), ['/', '/media/me/Backup Drive']);
    expect(v.first.isSystem, isTrue);
    expect(v.last.name, 'Backup Drive');
    expect(v.first.totalBytes, 488281250 * 1024);
  });

  Future<VolumesModel> pump(
    WidgetTester tester, {
    int? homeBytes,
    Size size = const Size(1000, 900),
    double text = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = VolumesModel(reader: FakeReader([usb, system]));
    addTearDown(model.dispose);
    await model.load();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(text)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: StorageDashboard(
                volumes: model,
                onNavigate: (_) {},
                homeBytes: homeBytes,
                junkBytes: 20 * gib,
                developerBytes: 30 * gib,
                appsBytes: 40 * gib,
                appsSupported: true,
              ),
            ),
          ),
        ),
      ),
    );
    return model;
  }

  testWidgets('before a scan: free space and a prompt', (tester) async {
    await pump(tester);
    expect(find.text('Macintosh HD'), findsOneWidget);
    expect(find.textContaining('free of 500.0 GiB'), findsOneWidget);
    expect(find.textContaining('Scan to see'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
  });

  testWidgets('after a scan: categories with sizes, junk first', (
    tester,
  ) async {
    await pump(tester, homeBytes: 250 * gib);
    for (final label in [
      'Junk you can clean',
      'Apps',
      'Developer',
      'Your files',
      'System and other',
      'Free',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('20.0 GiB'), findsOneWidget);
    expect(find.text('200.0 GiB'), findsOneWidget);
  });

  testWidgets('fits a narrow window at 200% text', (tester) async {
    await pump(
      tester,
      homeBytes: 250 * gib,
      size: const Size(380, 900),
      text: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
