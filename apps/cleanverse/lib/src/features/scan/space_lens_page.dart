// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/treemap.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/features/scan/needs_scan.dart';

/// Storage map: largest folders with drill-down, plus a file-type breakdown.
class SpaceLensPage extends StatelessWidget {
  const SpaceLensPage({
    super.key,
    required this.model,
    required this.onNavigate,
  });
  final FolderScanViewModel model;
  final ValueChanged<Section> onNavigate;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      const header = PageHeader(
        title: 'Space Lens',
        subtitle: 'See which folders and file types use the most space.',
      );
      final gate = needsScan(
        model,
        onNavigate,
        icon: Icons.donut_large_rounded,
        title: 'No storage map yet',
      );
      if (gate != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [header, gate],
        );
      }
      final result = model.result!;
      final partial = result.cancelled || result.skipped > 0;
      final folders = result.folderSummaries;
      final categories = result.storageCategories;
      final folderTotal = folders.fold<int>(0, (s, f) => s + f.bytes);
      final categoryTotal = categories.fold<int>(0, (s, c) => s + c.bytes);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (model.canGoBack)
                      Padding(
                        padding: const EdgeInsets.only(right: CvSpace.sm),
                        child: IconButton.outlined(
                          tooltip: 'Back to previous folder',
                          onPressed: model.goBack,
                          icon: const Icon(Icons.arrow_back),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName(model.root!),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SelectableText(
                            'Folder: ${model.root}',
                            style: const TextStyle(
                              color: CvColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatBytes(result.totalBytes),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (partial) ...[
                  const SizedBox(height: CvSpace.md),
                  const Callout(
                    'Folder totals are partial because the scan was cancelled or items were skipped.',
                    tone: CalloutTone.caution,
                  ),
                ],
                const SectionTitle(
                  'Largest folders in this scope',
                  detail: 'Up to 20 top-level groups. Select a tile or Explore to look inside a folder.',
                ),
                if (folders.isEmpty)
                  const Text('No files found in the scanned scope.')
                else ...[
                  Treemap(
                    height: MediaQuery.sizeOf(context).width < 600 ? 200 : 280,
                    entries: [
                      for (var i = 0; i < folders.length; i++)
                        TreemapEntry(
                          label: folders[i].folderPath == null
                              ? folders[i].label
                              : displayName(folders[i].label),
                          bytes: folders[i].bytes,
                          color: CvColors.seriesAt(i),
                          onTap: folders[i].folderPath == null || model.busy
                              ? null
                              : () => model.openFolder(folders[i].folderPath!),
                        ),
                    ],
                  ),
                  const SizedBox(height: CvSpace.lg),
                  for (var i = 0; i < folders.length; i++)
                    _FolderRow(
                      summary: folders[i],
                      color: CvColors.seriesAt(i),
                      share: folderTotal == 0
                          ? 0
                          : folders[i].bytes / folderTotal,
                      onExplore: folders[i].folderPath == null || model.busy
                          ? null
                          : () => model.openFolder(folders[i].folderPath!),
                    ),
                ],
              ],
            ),
          ),
          if (categories.isNotEmpty) ...[
            const SectionTitle(
              'Storage by file type',
              detail: 'Based on file extensions. Logical sizes, not physical or reclaimable disk space.',
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < categories.length; i++)
                    _CategoryRow(
                      category: categories[i],
                      color: CvColors.seriesAt(i),
                      total: categoryTotal,
                    ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.summary,
    required this.color,
    required this.share,
    required this.onExplore,
  });
  final FolderSummary summary;
  final Color color;
  final double share;
  final VoidCallback? onExplore;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Swatch(color),
        const SizedBox(width: CvSpace.md),
        Icon(
          summary.folderPath == null
              ? Icons.description_outlined
              : Icons.folder_outlined,
          size: 20,
          color: CvColors.muted,
        ),
        const SizedBox(width: CvSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary.folderPath == null
                    ? summary.label
                    : displayName(summary.label),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${formatBytes(summary.bytes)} · ${(share * 100).toStringAsFixed(share < .01 ? 1 : 0)}% · ${plural(summary.fileCount, 'file')}',
                style: const TextStyle(color: CvColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        if (summary.folderPath != null)
          TextButton.icon(
            onPressed: onExplore,
            icon: const Icon(Icons.chevron_right_rounded),
            label: Text(
              'Explore',
              semanticsLabel: 'Explore ${displayName(summary.label)}',
            ),
          ),
      ],
    ),
  );
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.color,
    required this.total,
  });
  final StorageCategory category;
  final Color color;
  final int total;

  @override
  Widget build(BuildContext context) {
    final label =
        '${category.label}, ${formatBytes(category.bytes)}, ${plural(category.fileCount, 'file')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Semantics(
        label: label,
        child: ExcludeSemantics(
          child: Row(
            children: [
              Icon(iconForCategory(category.label), size: 20, color: color),
              const SizedBox(width: CvSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category.label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${formatBytes(category.bytes)} · ${plural(category.fileCount, 'file')}',
                          style: const TextStyle(
                            color: CvColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : category.bytes / total,
                        minHeight: 6,
                        color: color,
                        backgroundColor: CvColors.raised,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
