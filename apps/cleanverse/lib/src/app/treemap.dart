import 'dart:math' as math;

// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';

class TreemapEntry {
  const TreemapEntry({
    required this.label,
    required this.bytes,
    required this.color,
    this.onTap,
  });
  final String label;
  final int bytes;
  final Color color;
  final VoidCallback? onTap;
}

/// Squarified treemap (Bruls et al.). Each tile is a labelled button, so the
/// map stays usable with a keyboard and screen reader; the list below it
/// remains the accessible source of exact values.
class Treemap extends StatelessWidget {
  const Treemap({super.key, required this.entries, this.height = 260});
  final List<TreemapEntry> entries;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final items = entries.where((e) => e.bytes > 0).toList()
          ..sort((a, b) => b.bytes.compareTo(a.bytes));
        final rects = squarify([
          for (final e in items) e.bytes.toDouble(),
        ], Rect.fromLTWH(0, 0, constraints.maxWidth, height));
        final total = items.fold<int>(0, (s, e) => s + e.bytes);
        return Stack(
          children: [
            for (var i = 0; i < items.length; i++)
              Positioned.fromRect(
                rect: rects[i].deflate(1.5),
                child: _Tile(entry: items[i], total: total),
              ),
          ],
        );
      },
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.entry, required this.total});
  final TreemapEntry entry;
  final int total;

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : entry.bytes / total * 100;
    final description =
        '${entry.label}, ${formatBytes(entry.bytes)}, ${share.toStringAsFixed(share < 1 ? 1 : 0)} percent';
    return Semantics(
      button: entry.onTap != null,
      label: description,
      excludeSemantics: true,
      child: Tooltip(
        message: '${entry.label} · ${formatBytes(entry.bytes)}',
        child: Material(
          color: entry.color.withValues(alpha: .22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: entry.color.withValues(alpha: .7)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: entry.onTap,
            child: LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth < 56 || c.maxHeight < 34) {
                  return const SizedBox.expand();
                }
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: CvColors.text,
                        ),
                      ),
                      if (c.maxHeight >= 52)
                        Text(
                          formatBytes(entry.bytes),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            fontSize: 12,
                            color: CvColors.muted,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays out [values] (sorted descending) inside [bounds].
List<Rect> squarify(List<double> values, Rect bounds) {
  final total = values.fold<double>(0, (s, v) => s + v);
  if (values.isEmpty || total <= 0 || bounds.isEmpty) {
    return [for (final _ in values) Rect.zero];
  }
  final scale = bounds.width * bounds.height / total;
  final areas = [for (final v in values) v * scale];
  final result = <Rect>[];
  var rect = bounds;
  var row = <double>[];

  double worst(List<double> r, double side) {
    if (r.isEmpty) return double.infinity;
    final sum = r.fold<double>(0, (s, v) => s + v);
    final maxV = r.reduce(math.max), minV = r.reduce(math.min);
    final s2 = sum * sum, w2 = side * side;
    return math.max(w2 * maxV / s2, s2 / (w2 * minV));
  }

  void layoutRow(List<double> r) {
    final sum = r.fold<double>(0, (s, v) => s + v);
    if (rect.width >= rect.height) {
      final w = sum / rect.height;
      var y = rect.top;
      for (final a in r) {
        final h = a / w;
        result.add(Rect.fromLTWH(rect.left, y, w, h));
        y += h;
      }
      rect = Rect.fromLTRB(rect.left + w, rect.top, rect.right, rect.bottom);
    } else {
      final h = sum / rect.width;
      var x = rect.left;
      for (final a in r) {
        final w = a / h;
        result.add(Rect.fromLTWH(x, rect.top, w, h));
        x += w;
      }
      rect = Rect.fromLTRB(rect.left, rect.top + h, rect.right, rect.bottom);
    }
  }

  for (final area in areas) {
    final side = math.min(rect.width, rect.height);
    if (row.isEmpty || worst([...row, area], side) <= worst(row, side)) {
      row.add(area);
    } else {
      layoutRow(row);
      row = [area];
    }
  }
  if (row.isNotEmpty) layoutRow(row);
  return result;
}
