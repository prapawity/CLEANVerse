import 'dart:io';

// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';

// Shared scan helpers used by Home and the review pages. The old Smart
// Scan page is now Home (features/home/home_page.dart).

/// Files at or above this size are highlighted as "large" in summaries.
const largeFileThreshold = 50 * 1024 * 1024;

bool get desktopScanSupported =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// Real progress only: counts come from the scanner, never estimated.
class ScanProgressPanel extends StatelessWidget {
  const ScanProgressPanel({super.key, required this.model});
  final FolderScanViewModel model;

  @override
  Widget build(BuildContext context) {
    final progress = model.progress;
    final comparing = progress?.phase == ScanPhase.comparing;
    final status = model.cancelling
        ? 'Stopping the scan…'
        : comparing
        ? 'Comparing files: ${progress!.compared} of ${progress.toCompare} checked.'
        : 'Scanning: ${progress?.filesSeen ?? 0} files found so far.';
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: CvSpace.md),
              Expanded(
                child: Text(
                  comparing ? 'Comparing file contents' : 'Reading folder',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: CvSpace.md),
          Tooltip(
            message: model.root ?? '',
            child: Text(
              'Folder: ${model.root}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: CvColors.muted),
            ),
          ),
          const SizedBox(height: CvSpace.lg),
          Semantics(liveRegion: true, child: Text(status)),
          const SizedBox(height: CvSpace.sm),
          LinearProgressIndicator(
            value: comparing && progress!.toCompare > 0
                ? progress.compared / progress.toCompare
                : null,
          ),
          const SizedBox(height: CvSpace.xl),
          OutlinedButton(
            onPressed: model.cancelling ? null : model.cancel,
            child: Text(model.cancelling ? 'Cancelling…' : 'Cancel scan'),
          ),
          const SizedBox(height: CvSpace.sm),
          const Text(
            'Cancelling keeps the partial results found so far.',
            style: TextStyle(color: CvColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
