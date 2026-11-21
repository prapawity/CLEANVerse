import 'dart:async';

import 'package:cleanverse/src/demo_scan.dart';
import 'package:flutter_test/flutter_test.dart';

class PendingRepository implements ScanRepository {
  final completer = Completer<List<ScanItem>>();
  @override
  Future<List<ScanItem>> scanExample() => completer.future;
}

class FailingRepository implements ScanRepository {
  @override
  Future<List<ScanItem>> scanExample() => Future.error(StateError('failed'));
}

void main() {
  test('cancel discards late results', () async {
    final repository = PendingRepository();
    final model = ScanViewModel(repository);
    final future = model.start();
    expect(model.status, ScanStatus.scanning);
    model.cancel();
    repository.completer.complete([
      const ScanItem('example', '1 B', 'Example'),
    ]);
    await future;
    expect(model.status, ScanStatus.idle);
    expect(model.items, isEmpty);
    model.dispose();
  });

  test('failure returns to idle with a useful message', () async {
    final model = ScanViewModel(FailingRepository());
    await model.start();
    expect(model.status, ScanStatus.idle);
    expect(model.error, isNotNull);
    model.dispose();
  });
}
