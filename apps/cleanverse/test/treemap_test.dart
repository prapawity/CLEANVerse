import 'dart:ui';

import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/app/treemap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('squarify fills the bounds proportionally', () {
    const bounds = Rect.fromLTWH(0, 0, 600, 400);
    final rects = squarify([6, 6, 4, 3, 2, 2, 1], bounds);
    expect(rects, hasLength(7));
    final area = rects.fold<double>(0, (s, r) => s + r.width * r.height);
    expect(area, closeTo(600 * 400, 0.01));
    expect(
      rects.first.width * rects.first.height,
      closeTo(240000 * 6 / 24, 0.01),
    );
    for (final r in rects) {
      expect(bounds.inflate(0.001).contains(r.topLeft), isTrue);
      expect(r.bottomRight.dx, lessThanOrEqualTo(600.001));
      expect(r.bottomRight.dy, lessThanOrEqualTo(400.001));
    }
  });

  test('squarify handles empty and zero input', () {
    expect(squarify([], const Rect.fromLTWH(0, 0, 10, 10)), isEmpty);
    expect(squarify([0, 0], const Rect.fromLTWH(0, 0, 10, 10)), [
      Rect.zero,
      Rect.zero,
    ]);
  });

  test('build artifacts get their own category', () {
    expect(categoryForPath('out/flutter_windows.dll.pdb'), 'Build output');
    expect(categoryForPath('build/app.dill'), 'Build output');
    expect(categoryForPath('notes.txt'), 'Documents');
  });
}
