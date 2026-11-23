// Flutter's bundled Material library is used to avoid an extra UI dependency.
import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/data/scan_history.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/treemap.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/features/scan/needs_scan.dart';
import 'package:cleanverse/src/features/scan/what_grew_card.dart';

/// Folder rows shown at first and added by each "Show more".
const folderPageSize = 50;

/// Tiles drawn in the treemap; the list below holds the rest.
const _treemapTiles = 20;

/// Storage map: largest folders with drill-down, plus a file-type breakdown.
class SpaceLensPage extends StatefulWidget {
  const SpaceLensPage({
    super.key,
    required this.model,
    required this.onNavigate,
    this.growth,
  });
  final FolderScanViewModel model;
  final ValueChanged<Section> onNavigate;

  /// Comparison with the previous scan of the same folder, when history is on.
  final ValueListenable<ScanComparison?>? growth;

  @override
  State<SpaceLensPage> createState() => _SpaceLensPageState();
}

class _SpaceLensPageState extends State<SpaceLensPage> {
  int shown = folderPageSize;
  String? _shownRoot;

  FolderScanViewModel get model => widget.model;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([model, ?widget.growth]),
    builder: (context, _) {
      final gate = needsScan(
        model,
        widget.onNavigate,
        icon: Icons.donut_large_rounded,
        title: 'No folder sizes yet',
      );
      if (gate != null) return StorageScroll(header: [gate]);
      if (_shownRoot != model.root) {
        _shownRoot = model.root;
        shown = folderPageSize;
      }
      final result = model.result!;
      final partial = result.cancelled || result.skipped > 0;
      final folders = result.folderSummaries;
      final categories = result.storageCategories;
      final folderTotal = folders.fold<int>(0, (s, f) => s + f.bytes);
      final categoryTotal = categories.fold<int>(0, (s, c) => s + c.bytes);
      final count = folders.length < shown ? folders.length : shown;
      final busy = model.busy;
      VoidCallback? explore(FolderSummary f) => f.folderPath == null || busy
          ? null
          : () => model.openFolder(f.folderPath!);

      return StorageScroll(
        header: [
          WhatGrewSection(comparison: widget.growth?.value),
          Row(
            children: [
              if (model.canGoBack)
                Padding(
                  padding: const EdgeInsets.only(right: CvSpace.sm),
                  child: IconButton(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    PathLine(model.root!),
                  ],
                ),
              ),
              const SizedBox(width: CvSpace.md),
              Text(
                formatBytes(result.totalBytes),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (partial)
            const Padding(
              padding: EdgeInsets.only(top: CvSpace.sm),
              child: Callout(
                'Folder totals are partial because the scan was cancelled or items were skipped.',
                tone: CalloutTone.caution,
              ),
            ),
          const SectionTitle(
            'Largest folders in this scope',
            detail: 'Select a tile or Explore to look inside a folder.',
          ),
          if (folders.isEmpty)
            const Text('No files found in the scanned scope.')
          else ...[
            Treemap(
              height: MediaQuery.sizeOf(context).width < 600 ? 180 : 240,
              entries: [
                for (var i = 0; i < folders.length && i < _treemapTiles; i++)
                  TreemapEntry(
                    label: folders[i].folderPath == null
                        ? folders[i].label
                        : displayName(folders[i].label),
                    bytes: folders[i].bytes,
                    color: CvColors.seriesAt(i),
                    onTap: explore(folders[i]),
                  ),
              ],
            ),
            const SizedBox(height: CvSpace.md),
          ],
        ],
        slivers: [
          SliverList.builder(
            itemCount: count,
            itemBuilder: (context, i) => _FolderRow(
              summary: folders[i],
              color: i < _treemapTiles ? CvColors.seriesAt(i) : CvColors.muted,
              share: folderTotal == 0 ? 0 : folders[i].bytes / folderTotal,
              onExplore: explore(folders[i]),
            ),
          ),
          if (folders.length > count)
            SliverToBoxAdapter(
              child: ShowMoreButton(
                remaining: folders.length - count,
                onPressed: () => setState(() => shown += folderPageSize),
              ),
            ),
          if (categories.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: SectionTitle(
                'Storage by file type',
                detail: 'Based on file extensions. Logical sizes, not reclaimable space.',
              ),
            ),
            SliverList.builder(
              itemCount: categories.length,
              itemBuilder: (context, i) => _CategoryRow(
                category: categories[i],
                color: CvColors.seriesAt(i),
                total: categoryTotal,
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
  Widget build(BuildContext context) {
    final name = summary.folderPath == null
        ? summary.label
        : displayName(summary.label);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Swatch(color),
          const SizedBox(width: CvSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${formatBytes(summary.bytes)} · ${(share * 100).toStringAsFixed(share < .01 ? 1 : 0)}% · ${plural(summary.fileCount, 'file')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: CvColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (summary.folderPath != null)
            TextButton(
              onPressed: onExplore,
              child: Text('Explore', semanticsLabel: 'Explore $name'),
            ),
        ],
      ),
    );
  }
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
    final detail =
        '${formatBytes(category.bytes)}, ${plural(category.fileCount, 'file')}';
    return Semantics(
      container: true,
      label: '${category.label}, $detail',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${formatBytes(category.bytes)} · ${plural(category.fileCount, 'file')}',
                    style: const TextStyle(color: CvColors.muted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : category.bytes / total,
                  minHeight: 4,
                  color: color,
                  backgroundColor: CvColors.raised,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
