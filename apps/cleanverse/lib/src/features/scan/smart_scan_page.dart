import 'dart:io';

// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';

/// Files at or above this size are highlighted as "large" in summaries.
const largeFileThreshold = 50 * 1024 * 1024;

bool get desktopScanSupported =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// Start here: pick a scope, choose what to look for, scan once, then
/// review each category from the summary.
class SmartScanPage extends StatelessWidget {
  const SmartScanPage({
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
      final result = model.result;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (model.busy && !model.pickingExclusion && model.root != null)
            ScanProgressPanel(model: model)
          else if (result != null)
            _Summary(model: model, result: result, onNavigate: onNavigate)
          else
            _Launcher(model: model),
          if (model.error != null)
            Padding(
              padding: const EdgeInsets.only(top: CvSpace.md),
              child: Callout(model.error!, tone: CalloutTone.caution),
            ),
          if (result != null && !model.busy) ...[
            const SectionTitle('Scan options'),
            _Options(model: model, compact: true),
          ],
        ],
      );
    },
  );
}

class _Launcher extends StatelessWidget {
  const _Launcher({required this.model});
  final FolderScanViewModel model;

  @override
  Widget build(BuildContext context) {
    final supported = desktopScanSupported;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: const Text(
              'Scan a folder',
              style: TextStyle(
                fontSize: 27,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: -.45,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            supported
                ? 'Find out what is taking up space. Choose a folder you own, '
                      'such as Downloads or a projects folder. CLEANVerse reads '
                      'it once and builds a summary you can review.'
                : 'Folder scanning is available on desktop. Mobile scanning is not available yet.',
            style: const TextStyle(
              color: Color(0xffb2bfd4),
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: CvSpace.xl),
          _Options(model: model),
          const SizedBox(height: CvSpace.xl),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: supported && !model.busy ? model.start : null,
                icon: const Icon(Icons.folder_open_outlined, size: 19),
                label: const Text('Choose and scan folder'),
              ),
              OutlinedButton.icon(
                onPressed: supported && !model.busy ? model.addExclusion : null,
                icon: const Icon(Icons.folder_off_outlined, size: 19),
                label: const Text('Exclude a folder'),
              ),
            ],
          ),
          if (model.busy && model.root == null)
            Padding(
              padding: const EdgeInsets.only(top: CvSpace.md),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  model.pickingExclusion
                      ? 'Choose a folder to exclude.'
                      : 'Choose a folder to scan.',
                  style: const TextStyle(color: CvColors.muted),
                ),
              ),
            ),
          const SizedBox(height: CvSpace.md),
          const Row(
            children: [
              Icon(Icons.lock_outline, size: 15, color: CvColors.mint),
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Private scan · Read-only · Nothing is removed until you confirm',
                  style: TextStyle(color: Color(0xffaabbd0), fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What to include in the scan, plus session exclusions.
class _Options extends StatelessWidget {
  const _Options({required this.model, this.compact = false});
  final FolderScanViewModel model;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = desktopScanSupported && !model.busy;
    Widget option({
      required IconData icon,
      required String title,
      required String subtitle,
      required bool value,
      ValueChanged<bool>? onChanged,
    }) => Material(
      color: Colors.transparent,
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        value: value,
        onChanged: onChanged == null ? null : (v) => onChanged(v ?? false),
        secondary: Icon(icon, color: CvColors.violet, size: 20),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xffaab8ce), fontSize: 12),
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );

    return Panel(
      color: CvColors.sunken,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Include in scan',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xffd9e3f4),
            ),
          ),
          option(
            icon: Icons.donut_large_rounded,
            title: 'Storage map and largest files',
            subtitle: 'Always included. Sizes by folder and file type.',
            value: true,
          ),
          option(
            icon: Icons.file_copy_outlined,
            title: 'Find matching files',
            subtitle: 'Compare file contents locally using SHA-256, up to 20,000 files. Slower.',
            value: model.findDuplicates,
            onChanged: enabled ? model.setFindDuplicates : null,
          ),
          option(
            icon: Icons.code_rounded,
            title: 'Find developer folders',
            subtitle: 'Identify project dependencies and possible tool caches in this scope.',
            value: model.findDevFolders,
            onChanged: enabled ? model.setFindDevFolders : null,
          ),
          if (compact && model.result != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'Changing options clears the current results.',
                style: TextStyle(
                  color: CvColors.muted.withValues(alpha: .9),
                  fontSize: 12,
                ),
              ),
            ),
          if (model.exclusions.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'Excluded from scans for this session',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            for (final path in model.exclusions)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.folder_off_outlined, size: 18),
                  title: SelectableText(path),
                  trailing: IconButton(
                    tooltip: 'Remove exclusion',
                    onPressed: model.busy
                        ? null
                        : () => model.removeExclusion(path),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

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
          SelectableText(
            'Folder: ${model.root}',
            style: const TextStyle(color: CvColors.muted),
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

class _Summary extends StatelessWidget {
  const _Summary({
    required this.model,
    required this.result,
    required this.onNavigate,
  });
  final FolderScanViewModel model;
  final FolderScanResult result;
  final ValueChanged<Section> onNavigate;

  @override
  Widget build(BuildContext context) {
    final partial = result.cancelled || result.skipped > 0;
    final large = result.files
        .where((f) => f.bytes >= largeFileThreshold)
        .toList();
    final largeBytes = large.fold<int>(0, (s, f) => s + f.bytes);
    final topFolder = result.folderSummaries.isEmpty
        ? null
        : result.folderSummaries.first;
    final devBytes = result.devFolders.fold<int>(
      0,
      (s, f) => s + f.logicalBytes,
    );

    final tiles = <Widget>[
      _Tile(
        section: Section.spaceLens,
        headline: formatBytes(result.totalBytes),
        detail: topFolder == null
            ? 'No folders with files'
            : 'Largest: ${displayName(topFolder.label)} · ${formatBytes(topFolder.bytes)}',
        onNavigate: onNavigate,
      ),
      _Tile(
        section: Section.largeFiles,
        headline: large.isEmpty
            ? 'None over 50 MiB'
            : '${plural(large.length, 'file')} · ${formatBytes(largeBytes)}',
        detail: 'Files of 50 MiB or more among the 100 largest',
        onNavigate: onNavigate,
      ),
      _Tile(
        section: Section.duplicates,
        headline: model.findDuplicates
            ? plural(result.duplicates.length, 'matching group')
            : 'Not included',
        detail: model.findDuplicates
            ? 'Same size and SHA-256 hash'
            : 'Turn on "Find matching files" to check',
        onNavigate: onNavigate,
      ),
      _Tile(
        section: Section.developer,
        headline: model.findDevFolders
            ? plural(result.devFolders.length, 'candidate')
            : 'Not included',
        detail: model.findDevFolders
            ? '${formatBytes(devBytes)} observed · review required'
            : 'Turn on "Find developer folders" to check',
        onNavigate: onNavigate,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: CvSpace.md,
                runSpacing: CvSpace.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Scan summary',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  StatusChip(
                    result.cancelled
                        ? 'Cancelled · partial'
                        : partial
                        ? 'Finished · incomplete'
                        : 'Finished',
                    color: partial ? CvColors.amber : CvColors.mint,
                    icon: partial
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                  ),
                ],
              ),
              const SizedBox(height: CvSpace.sm),
              SelectableText(
                'Folder: ${model.root}',
                style: const TextStyle(color: CvColors.muted),
              ),
              const SizedBox(height: CvSpace.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  result.cancelled
                      ? 'Scan cancelled. Results are partial.'
                      : result.skipped > 0
                      ? 'Scan finished with skipped items. Results may be incomplete.'
                      : 'Scan finished.',
                ),
              ),
              Text(
                '${plural(result.filesSeen, 'file')} read · '
                '${formatBytes(result.totalBytes)} logical size · '
                'Skipped or inaccessible items: ${result.skipped}',
                style: const TextStyle(color: CvColors.muted, fontSize: 13),
              ),
              const SizedBox(height: CvSpace.lg),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: model.rescan,
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                    label: const Text('Scan again'),
                  ),
                  OutlinedButton.icon(
                    onPressed: model.start,
                    icon: const Icon(Icons.folder_open_outlined, size: 19),
                    label: const Text('Choose another folder'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: CvSpace.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 2 : 1;
            final width =
                (constraints.maxWidth - (columns - 1) * CvSpace.lg) / columns;
            return Wrap(
              spacing: CvSpace.lg,
              runSpacing: CvSpace.lg,
              children: [
                for (final tile in tiles) SizedBox(width: width, child: tile),
              ],
            );
          },
        ),
        const SizedBox(height: CvSpace.lg),
        const Callout(
          'Sizes are logical file sizes found in this scan. They can include '
          'hard links and shared storage, so they are not a promise of '
          'reclaimable disk space. Nothing has been selected or removed; '
          'use the review areas or Clean up to choose what to remove.',
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.section,
    required this.headline,
    required this.detail,
    required this.onNavigate,
  });
  final Section section;
  final String headline;
  final String detail;
  final ValueChanged<Section> onNavigate;

  @override
  Widget build(BuildContext context) => Material(
    color: CvColors.panel,
    borderRadius: BorderRadius.circular(CvRadius.lg),
    child: InkWell(
      borderRadius: BorderRadius.circular(CvRadius.lg),
      onTap: () => onNavigate(section),
      child: Container(
        padding: const EdgeInsets.all(CvSpace.xl - 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CvRadius.lg),
          border: Border.all(color: CvColors.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CvColors.raised,
                borderRadius: BorderRadius.circular(CvRadius.sm),
              ),
              child: Icon(section.icon, color: CvColors.cyan),
            ),
            const SizedBox(width: CvSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.label,
                    style: const TextStyle(
                      color: CvColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    headline,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(color: CvColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: CvSpace.sm),
            Text(
              'Review',
              semanticsLabel: 'Review ${section.label}',
              style: const TextStyle(
                color: CvColors.cyan,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: CvColors.cyan),
          ],
        ),
      ),
    ),
  );
}
