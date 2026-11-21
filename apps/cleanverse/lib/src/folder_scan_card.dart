import 'dart:io';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'desktop_scan.dart';

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
              'Identify project dependencies and build folders inside the selected scope. No files are removed.',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
        if (model.busy && !model.pickingExclusion)
          OutlinedButton(
            onPressed: model.cancel,
            child: const Text('Cancel scan'),
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scanning selected folder…'),
                SizedBox(height: 8),
                LinearProgressIndicator(),
              ],
            ),
          ),
        if (model.root != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SelectableText('Folder: ${model.root}'),
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
            Text('Developer folders: ${result.devFolders.length}'),
            const Text(
              'Candidates identified by folder and project marker. Sizes are logical bytes scanned, may be incomplete and are not reclaimable-space estimates. Up to 200 are shown.',
            ),
            for (final folder in result.devFolders)
              Card(
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
                      if (folder.projectMarker != null)
                        SelectableText(
                          'Project marker: ${folder.projectMarker}',
                        ),
                      if (folder.modified != null)
                        Text(
                          'Folder modified: ${folder.modified!.toLocal().toString().split('.').first} (not last used)',
                        ),
                      const Text(
                        'Review required · Ownership and active use not verified',
                      ),
                      Text(folder.note),
                    ],
                  ),
                ),
              ),
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
