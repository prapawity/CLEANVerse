import 'dart:io';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'desktop_scan.dart';
import 'cleanup_plan.dart';

class FolderScanCard extends StatefulWidget {
  const FolderScanCard({super.key, this.scanner, this.pickFolder});
  final FolderScanner? scanner;
  final Future<String?> Function()? pickFolder;
  @override
  State<FolderScanCard> createState() => _FolderScanCardState();
}

class _FolderScanCardState extends State<FolderScanCard> {
  late final model = FolderScanViewModel(
    widget.scanner ?? LocalFolderScanner(),
    widget.pickFolder ?? chooseFolder,
  );
  bool get supported =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Find large files',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          supported
              ? 'Choose a folder to scan locally. Nothing will be changed or deleted.'
              : 'Folder scanning is available on desktop. Mobile scanning is not available yet.',
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: model.findDuplicates,
            onChanged: supported && !model.busy
                ? (value) => model.setFindDuplicates(value ?? false)
                : null,
            title: const Text('Find matching files'),
            subtitle: const Text(
              'Compares SHA-256 hashes locally for up to 20,000 files. This can take longer.',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: model.findDevFolders,
            onChanged: supported && !model.busy
                ? (value) => model.setFindDevFolders(value ?? false)
                : null,
            title: const Text('Find developer folders'),
            subtitle: const Text(
              'Identify project folders and possible global caches inside the selected scope. No files are removed.',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
        if (model.busy && !model.pickingExclusion)
          OutlinedButton(
            onPressed: model.cancelling ? null : model.cancel,
            child: Text(model.cancelling ? 'Cancelling…' : 'Cancel scan'),
          )
        else if (!model.busy)
          FilledButton.icon(
            onPressed: supported ? model.start : null,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose and scan folder'),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: supported && !model.busy ? model.addExclusion : null,
          icon: const Icon(Icons.folder_off_outlined),
          label: const Text('Exclude a folder'),
        ),
        if (model.exclusions.isNotEmpty) ...[
          const Text('Excluded from future scans for this session:'),
          for (final path in model.exclusions)
            ListTile(
              title: SelectableText(path),
              trailing: IconButton(
                tooltip: 'Remove exclusion',
                onPressed: model.busy
                    ? null
                    : () => model.removeExclusion(path),
                icon: const Icon(Icons.close),
              ),
            ),
        ],
        if (model.busy)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    model.pickingExclusion
                        ? 'Choose a folder to exclude.'
                        : model.root == null
                        ? 'Choose a folder to scan.'
                        : model.cancelling
                        ? 'Stopping the scan…'
                        : model.progress?.phase == ScanPhase.comparing
                        ? 'Comparing files: ${model.progress!.compared} of ${model.progress!.toCompare} checked.'
                        : 'Scanning: ${model.progress?.filesSeen ?? 0} files found so far.',
                  ),
                ),
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
            ),
          ),
        if (model.root != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SelectableText('Folder: ${model.root}'),
          ),
        if (model.canGoBack)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: model.goBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to previous folder'),
            ),
          ),
        if (model.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              model.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (model.result case final result?) ...[
          const SizedBox(height: 12),
          Text(
            result.cancelled
                ? 'Scan cancelled. Results are partial.'
                : result.skipped > 0
                ? 'Scan finished with skipped items. Results may be incomplete.'
                : 'Scan finished.',
          ),
          Text(
            'Skipped or inaccessible items: ${result.skipped}. Showing up to 100 largest files.',
          ),
          if (result.files.isEmpty)
            const Text('No files found in the scanned scope.'),
          if (result.storageCategories.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Storage by file type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Text(
              'Based on file extensions in this scan. Logical file sizes can include hard links and are not physical or reclaimable disk space.',
            ),
            if (result.cancelled || result.skipped > 0)
              const Text(
                'This breakdown is partial because the scan was cancelled or items were skipped.',
              ),
            _StorageBreakdown(categories: result.storageCategories),
          ],
          if (result.folderSummaries.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Largest folders in this scope',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Text(
              'Showing up to 20 top-level groups with files found. Sizes are logical, may overlap physical storage and may be incomplete.',
            ),
            if (result.cancelled || result.skipped > 0)
              const Text(
                'Folder totals are partial because the scan was cancelled or items were skipped.',
              ),
            for (final summary in result.folderSummaries)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(summary.label),
                      Text(
                        '${formatBytes(summary.bytes)} · ${summary.fileCount} ${summary.fileCount == 1 ? 'file' : 'files'} scanned',
                      ),
                      if (summary.folderPath != null)
                        TextButton.icon(
                          onPressed: model.busy
                              ? null
                              : () => model.openFolder(summary.folderPath!),
                          icon: const Icon(Icons.folder_open_outlined),
                          label: const Text('Explore folder'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
          if (model.findDuplicates) ...[
            const SizedBox(height: 12),
            Text('Matching groups: ${result.duplicates.length}'),
            const Text(
              'Matches have the same size and SHA-256 hash. Hard links may appear separately; no space savings are estimated.',
            ),
            const Text('Showing up to 50 groups and 20 paths per group.'),
            for (final group in result.duplicates.take(50))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${group.length} matching files · ${formatBytes(group.first.bytes)} each',
                      ),
                      for (final file in group.take(20))
                        SelectableText(file.path),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Largest files',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          if (model.findDevFolders) ...[
            const SizedBox(height: 12),
            const Text(
              'Developer Cleanup',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Text(
              'Select folders to review. Cleanup and removal are not available yet.',
            ),
            Text('Developer folders: ${result.devFolders.length}'),
            const Text(
              'Candidates use project markers or possible cache locations. Sizes are logical bytes scanned, may be incomplete and are not reclaimable-space estimates. Up to 200 are shown.',
            ),
            if (result.devFolders.any((folder) => folder.projectMarker != null))
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Project folders',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            for (final folder in result.devFolders.where(
              (folder) => folder.projectMarker != null,
            ))
              _developerFolderCard(
                folder,
                selected: model.isCleanupSelected(folder.path),
                onSelected: (selected) =>
                    model.selectCleanupCandidate(folder.path, selected),
              ),
            if (result.devFolders.any((folder) => folder.projectMarker == null))
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Tool storage candidates',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            for (final folder in result.devFolders.where(
              (folder) => folder.projectMarker == null,
            ))
              _developerFolderCard(
                folder,
                selected: model.isCleanupSelected(folder.path),
                onSelected: (selected) =>
                    model.selectCleanupCandidate(folder.path, selected),
              ),
            if (result.devFolders.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('${model.selectedCleanupCount} selected for review'),
              OutlinedButton.icon(
                onPressed: model.cleanupPlan == null
                    ? null
                    : () => _showCleanupReview(context, model.cleanupPlan!),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Review selection'),
              ),
            ],
          ],
          for (final file in result.files)
            Card(
              child: ListTile(
                title: SelectableText(file.path),
                trailing: Text(formatBytes(file.bytes)),
              ),
            ),
        ],
      ],
    ),
  );
}

Widget _developerFolderCard(
  DevFolder folder, {
  required bool selected,
  required ValueChanged<bool> onSelected,
}) => Card(
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${folder.category} · ${formatBytes(folder.logicalBytes)} scanned',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        SelectableText(folder.path),
        if (folder.locationSource != null)
          Text('Location source: ${folder.locationSource}'),
        if (folder.projectMarker != null)
          SelectableText('Project marker: ${folder.projectMarker}'),
        if (folder.modified != null)
          Text(
            'Folder modified: ${folder.modified!.toLocal().toString().split('.').first} (not last used)',
          ),
        Text(
          folder.risk == CleanupRisk.potentiallyImportant
              ? 'May contain important data · Ownership and active use not verified'
              : 'Review required · Ownership and active use not verified',
        ),
        Text(folder.note),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: selected,
          onChanged: (value) => onSelected(value ?? false),
          title: Text('Select ${folder.category} for review'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    ),
  ),
);

Future<void> _showCleanupReview(
  BuildContext context,
  CleanupPlan plan,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('Review developer folders'),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText('Scan scope: ${plan.scope}'),
            if (plan.partial)
              const Text('The scan was incomplete; this list may omit items.'),
            const SizedBox(height: 12),
            const Text(
              'These are scan snapshots. Items may have changed. Shared caches, hard links and offline dependencies can make sizes misleading. Nothing will be moved or deleted.',
            ),
            for (final item in plan.candidates) ...[
              const Divider(height: 24),
              Text(
                item.category,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              SelectableText(item.path),
              Text(
                item.risk == CleanupRisk.potentiallyImportant
                    ? 'May contain important data — review carefully'
                    : 'Review required — safety and active use are not verified',
              ),
              Text(
                'Observed logical size: ${formatBytes(item.logicalBytes)}; reclaimable space is unknown.',
              ),
              if (item.projectMarker != null)
                SelectableText('Project marker: ${item.projectMarker}'),
              if (item.locationSource != null)
                Text('Location source: ${item.locationSource}'),
              Text(item.note),
            ],
            const SizedBox(height: 16),
            const Text(
              'Moving to Trash is unavailable until platform-specific safety checks are completed.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      const FilledButton(
        onPressed: null,
        child: Text('Move to Trash unavailable'),
      ),
      TextButton(
        onPressed: () => Navigator.of(dialogContext).pop(),
        child: const Text('Close'),
      ),
    ],
  ),
);

class _StorageBreakdown extends StatelessWidget {
  const _StorageBreakdown({required this.categories});
  final List<StorageCategory> categories;

  @override
  Widget build(BuildContext context) {
    final total = categories.fold<int>(
      0,
      (sum, category) => sum + category.bytes,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Scanned logical size: ${formatBytes(total)}'),
        ),
        for (final category in categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${category.label}: ${formatBytes(category.bytes)} · ${category.fileCount} ${category.fileCount == 1 ? 'file' : 'files'}',
                ),
                const SizedBox(height: 4),
                Semantics(
                  label:
                      '${category.label}, ${formatBytes(category.bytes)}, ${category.fileCount} ${category.fileCount == 1 ? 'file' : 'files'}',
                  child: ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : category.bytes / total,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String formatBytes(int bytes) {
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  double value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}
