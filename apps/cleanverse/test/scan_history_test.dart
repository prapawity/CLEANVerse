import 'dart:io';

import 'package:cleanverse/src/data/scan_history.dart';
import 'package:cleanverse/src/features/scan/what_grew_card.dart';
import 'package:cleanverse/src/features/settings/app_settings.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ScanSnapshot snap(
  Map<String, int> folders, {
  DateTime? time,
  bool partial = false,
}) => ScanSnapshot(
  root: '/r',
  time: time ?? DateTime(2026, 11, 1),
  totalBytes: folders.values.fold(0, (a, b) => a + b),
  folders: folders,
  partial: partial,
);

void main() {
  late Directory sandbox;
  setUp(() async => sandbox = await Directory.systemTemp.createTemp('cv_hist'));
  tearDown(() => sandbox.delete(recursive: true));

  test('comparison lists only folders that grew, largest first', () {
    final c = compareSnapshots(
      snap({'/r/a': 100, '/r/b': 500, '/r/c': 50}),
      snap({'/r/a': 400, '/r/b': 200, '/r/c': 60, '/r/new': 1000}),
    );
    expect(c.grew.map((g) => g.path), ['/r/new', '/r/a', '/r/c']);
    expect(c.grew.first.isNew, isTrue);
    expect(c.totalDelta, 1660 - 650);
  });

  test('first scan of a folder has no comparison; second one does', () async {
    final store = ScanHistoryStore(File('${sandbox.path}/h.json'));
    expect(await store.record(snap({'/r/a': 1})), isNull);
    final c = await store.record(snap({'/r/a': 5}));
    expect(c!.grew.single.delta, 4);
    expect((await store.load()).length, 2);
  });

  test('other folders are not compared', () async {
    final store = ScanHistoryStore(File('${sandbox.path}/h.json'));
    await store.record(snap({'/r/a': 1}));
    final other = ScanSnapshot(
      root: '/other',
      time: DateTime(2026),
      totalBytes: 1,
      folders: const {},
    );
    expect(await store.record(other), isNull);
  });

  test('history keeps a bounded number of snapshots', () async {
    final store = ScanHistoryStore(
      File('${sandbox.path}/h.json'),
      maxSnapshots: 3,
    );
    for (var i = 0; i < 5; i++) {
      await store.record(snap({'/r/a': i}));
    }
    expect((await store.load()).length, 3);
  });

  test('corrupt history file is treated as empty', () async {
    final file = File('${sandbox.path}/h.json')..writeAsStringSync('{nope');
    expect(await ScanHistoryStore(file).load(), isEmpty);
  });

  test('history is off by default and turning it off deletes it', () async {
    final settings = AppSettings(location: () async => sandbox);
    await settings.load();
    expect(settings.keepScanHistory, isFalse);
    await settings.setKeepScanHistory(true);
    await (await settings.scanHistory()).record(snap({'/r/a': 1}));
    final file = File('${sandbox.path}/scan_history.json');
    expect(file.existsSync(), isTrue);
    await settings.setKeepScanHistory(false);
    expect(file.existsSync(), isFalse);
    final reloaded = AppSettings(location: () async => sandbox);
    await reloaded.load();
    expect(reloaded.keepScanHistory, isFalse);
  });

  testWidgets('card explains opt-in when history is off', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WhatGrewCard(comparison: null, historyEnabled: false),
        ),
      ),
    );
    expect(
      find.textContaining('Turn on scan history in Settings'),
      findsOneWidget,
    );
  });

  testWidgets('card shows growth relative to the scanned folder', (
    tester,
  ) async {
    final c = compareSnapshots(
      snap({'/r/a': 100}),
      snap({'/r/a': 300, '/r/b': 50}, partial: true),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WhatGrewCard(comparison: c, historyEnabled: true)),
      ),
    );
    expect(find.text('What grew since 2026-11-01'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.textContaining('approximate'), findsOneWidget);
  });
}
