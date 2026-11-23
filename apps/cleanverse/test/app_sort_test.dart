import 'dart:async';

import 'package:cleanverse/src/features/uninstall/app_catalog.dart';
import 'package:cleanverse/src/features/uninstall/uninstall_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _Catalog extends AppCatalog {
  _Catalog()
    : super(environment: const {}, folders: const [], systemFolders: const []);
  @override
  Future<List<InstalledApp>> listApps() async => [
    for (final n in ['A', 'B', 'C'])
      InstalledApp(name: n, bundleId: 'com.example.$n', path: '/Apps/$n.app'),
  ];
}

void main() {
  test('size order stays put while sizes are still measured', () async {
    final pending = <String, Completer<int>>{};
    final model = UninstallViewModel(
      catalog: _Catalog(),
      measure: (path) => (pending[path] = Completer<int>()).future,
      sizeConcurrency: 3,
    );
    addTearDown(model.dispose);
    await model.loadApps();
    await Future<void>.delayed(Duration.zero);
    pending['/Apps/A.app']!.complete(10);
    await Future<void>.delayed(Duration.zero);

    model.setSort(AppSort.size);
    final before = model.visibleApps.map((a) => a.name).toList();
    expect(before.first, 'A');

    // C turns out to be the biggest, but the list must not jump yet.
    pending['/Apps/C.app']!.complete(999);
    await Future<void>.delayed(Duration.zero);
    expect(model.visibleApps.map((a) => a.name).toList(), before);

    // Once measuring finishes, the real order is shown.
    pending['/Apps/B.app']!.complete(1);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(model.measuringSizes, isFalse);
    expect(model.visibleApps.map((a) => a.name).toList(), ['C', 'A', 'B']);
  });
}
