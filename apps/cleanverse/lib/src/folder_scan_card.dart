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
        if (model.busy && !model.pickingExclusion)
          OutlinedButton(
            onPressed: model.cancel,
            child: const Text('Cancel scan'),
          )
        else if (!model.busy)
          FilledButton.tonalIcon(
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
            child: LinearProgressIndicator(),
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
