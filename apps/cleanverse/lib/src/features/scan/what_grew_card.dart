// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/data/scan_history.dart';

String _signed(int bytes) =>
    bytes >= 0 ? '+${formatBytes(bytes)}' : '−${formatBytes(-bytes)}';

String _date(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

/// Compares this scan with the previous scan of the same folder.
class WhatGrewCard extends StatelessWidget {
  const WhatGrewCard({
    super.key,
    required this.comparison,
    required this.historyEnabled,
  });
  final ScanComparison? comparison;
  final bool historyEnabled;

  @override
  Widget build(BuildContext context) {
    final c = comparison;
    if (!historyEnabled) {
      return const Callout(
        'Want to see what grew since last time? Turn on scan history in Settings. '
        'It stays on this computer.',
      );
    }
    if (c == null) {
      return const Callout(
        'Scan history is on. Scan this folder again later to see what grew.',
      );
    }
    final root = c.current.root;
    return Padding(
      padding: const EdgeInsets.only(bottom: CvSpace.md),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up_rounded, color: CvColors.violet),
                const SizedBox(width: CvSpace.sm),
                Expanded(
                  child: Text(
                    'What grew since ${_date(c.previous.time)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  _signed(c.totalDelta),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: c.totalDelta > 0 ? CvColors.amber : CvColors.mint,
                  ),
                ),
              ],
            ),
            Text(
              'Total ${formatBytes(c.previous.totalBytes)} → ${formatBytes(c.current.totalBytes)}. '
              'Logical sizes of the largest folders.',
              style: const TextStyle(color: CvColors.muted, fontSize: 12),
            ),
            if (c.approximate)
              const Padding(
                padding: EdgeInsets.only(top: CvSpace.sm),
                child: Callout(
                  'Some folders were skipped in one of the scans, so this comparison is approximate.',
                  tone: CalloutTone.caution,
                ),
              ),
            const SizedBox(height: CvSpace.sm),
            if (c.grew.isEmpty)
              const Text('No folder grew.')
            else
              for (final g in c.grew)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.isWithin(root, g.path)
                              ? p.relative(g.path, from: root)
                              : g.path,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (g.isNew)
                        const Padding(
                          padding: EdgeInsets.only(right: CvSpace.sm),
                          child: StatusChip('New', color: CvColors.cyan),
                        ),
                      Text(
                        _signed(g.delta),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
