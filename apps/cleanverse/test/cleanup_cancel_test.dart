import 'dart:io';

import 'package:cleanverse/src/features/cleanup/cleanup_view_model.dart';
import 'package:cleanverse/src/features/cleanup/junk_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'cancelling the junk check stops measuring and keeps no stale state',
    () async {
      final dir = await Directory.systemTemp.createTemp('cv_cancel');
      addTearDown(() => dir.delete(recursive: true));
      final targets = <JunkTarget>[];
      for (var i = 0; i < 20; i++) {
        final f = File(p.join(dir.path, 'loc$i', 'x.bin'));
        await f.create(recursive: true);
        await f.writeAsBytes(List.filled(10, 0));
        targets.add(
          JunkTarget(
            group: JunkGroup.system,
            label: 'loc$i',
            path: p.join(dir.path, 'loc$i'),
            note: 'fixture',
          ),
        );
      }
      final model = CleanupViewModel(loader: () async => targets);
      addTearDown(model.dispose);
      final scan = model.scan();
      model.cancelScan();
      await scan;
      expect(model.scanning, isFalse);
      expect(model.found!.length, lessThan(20));

      // A later scan is not affected by the earlier cancel.
      await model.scan();
      expect(model.found!.length, 20);
    },
  );
}
