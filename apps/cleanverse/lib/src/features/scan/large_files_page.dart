// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/data/protection.dart';
import 'package:cleanverse/src/features/settings/app_settings.dart';
import 'package:cleanverse/src/data/removal.dart';
import 'package:cleanverse/src/features/cleanup/removal_dialog.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/features/scan/needs_scan.dart';
import 'package:cleanverse/src/features/scan/smart_scan_page.dart';

enum LargeFileFilter { all, large, old }

enum LargeFileSort { size, oldest }

/// Files not modified for this long count as "old". Modification time is
/// used because last-opened time is unreliable across platforms.
const oldFileAge = Duration(days: 365);

class LargeFilesPage extends StatefulWidget {
  const LargeFilesPage({
    super.key,
    required this.model,
    required this.onNavigate,
    this.now,
    this.settings,
  });
  final AppSettings? settings;
  final FolderScanViewModel model;
  final ValueChanged<Section> onNavigate;

  /// Injectable clock for tests.
  final DateTime Function()? now;

  @override
  State<LargeFilesPage> createState() => _LargeFilesPageState();
}

class _LargeFilesPageState extends State<LargeFilesPage> {
  LargeFileFilter filter = LargeFileFilter.all;
  LargeFileSort sort = LargeFileSort.size;
  final Set<String> selected = {};

  Future<void> _remove(List<LargeFile> files) async {
    final model = widget.model;
    final root = model.root;
    if (root == null) return;
    final items = [
      for (final file in files)
        if (selected.contains(file.path))
          RemovalItem(
            path: file.path,
            label: p.basename(file.path),
            bytes: file.bytes,
            recommended: RemovalMode.trash,
            allowedRoot: root,
          ),
    ];
    if (items.isEmpty) return;
    final outcomes = await runRemovalFlow(
      context,
      title: 'Remove selected files',
      items: items,
      warnings: const [
        'These are your own files. Files in cloud-synced folders may also be removed from your other devices.',
      ],
    );
    if (outcomes == null || !mounted) return;
    setState(selected.clear);
    await model.rescan();
  }

  List<LargeFile> _visible(List<LargeFile> files) {
    final now = (widget.now ?? DateTime.now)();
    final ignored = activeIgnoreList;
    final list = files.where((file) {
      if (ignored?.covers(file.path) ?? false) return false;
      return switch (filter) {
        LargeFileFilter.all => true,
        LargeFileFilter.large => file.bytes >= largeFileThreshold,
        LargeFileFilter.old =>
          file.modified != null && now.difference(file.modified!) >= oldFileAge,
      };
    }).toList();
    if (sort == LargeFileSort.oldest) {
      list.sort((a, b) {
        final am = a.modified, bm = b.modified;
        if (am == null && bm == null) return b.bytes.compareTo(a.bytes);
        if (am == null) return 1;
        if (bm == null) return -1;
        return am.compareTo(bm);
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      const header = PageHeader(
        title: 'Large & old files',
        subtitle: 'The biggest files in this scope, so you can decide what to keep, move or archive.',
      );
      final gate = needsScan(
        widget.model,
        widget.onNavigate,
        icon: Icons.inventory_outlined,
        title: 'No files to review yet',
      );
      if (gate != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [header, gate],
        );
      }
      final result = widget.model.result!;
      final visible = _visible(result.files);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const Callout(
            'Showing up to 100 largest files. "Old" means not modified for a year; '
            'it is not a last-opened date. Nothing is selected for you.',
          ),
          if (result.cancelled || result.skipped > 0)
            const Callout(
              'This list may be incomplete because the scan was cancelled or items were skipped.',
              tone: CalloutTone.caution,
            ),
          Wrap(
            spacing: CvSpace.md,
            runSpacing: CvSpace.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<LargeFileFilter>(
                  segments: const [
                    ButtonSegment(
                      value: LargeFileFilter.all,
                      label: Text('All'),
                    ),
                    ButtonSegment(
                      value: LargeFileFilter.large,
                      label: Text('50 MiB+'),
                    ),
                    ButtonSegment(
                      value: LargeFileFilter.old,
                      label: Text('Older than a year'),
                    ),
                  ],
                  selected: {filter},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => filter = value.first),
                ),
              ),
              DropdownButton<LargeFileSort>(
                value: sort,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(CvRadius.sm),
                items: const [
                  DropdownMenuItem(
                    value: LargeFileSort.size,
                    child: Text('Sort: largest first'),
                  ),
                  DropdownMenuItem(
                    value: LargeFileSort.oldest,
                    child: Text('Sort: oldest first'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => sort = value ?? LargeFileSort.size),
              ),
            ],
          ),
          const SizedBox(height: CvSpace.lg),
          Text(
            '${plural(visible.length, 'file')} · ${formatBytes(visible.fold<int>(0, (s, f) => s + f.bytes))}',
            style: const TextStyle(color: CvColors.muted),
          ),
          const SizedBox(height: CvSpace.sm),
          if (result.files.isEmpty)
            const Text('No files found in the scanned scope.')
          else if (visible.isEmpty)
            const EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: 'No files match this filter',
              message: 'Try another filter to see more files.',
            )
          else
            for (final file in visible)
              _FileRow(
                file: file,
                selected: selected.contains(file.path),
                onIgnore: widget.settings == null || widget.model.busy
                    ? null
                    : () async {
                        await widget.settings!.ignorePath(file.path);
                        setState(() => selected.remove(file.path));
                      },
                onChanged: widget.model.busy
                    ? null
                    : (value) => setState(
                        () => value
                            ? selected.add(file.path)
                            : selected.remove(file.path),
                      ),
              ),
          if (result.files.isNotEmpty)
            _SelectionBar(
              count: selected.length,
              bytes: result.files
                  .where((f) => selected.contains(f.path))
                  .fold<int>(0, (s, f) => s + f.bytes),
              onRemove: selected.isEmpty || widget.model.busy
                  ? null
                  : () => _remove(result.files),
            ),
        ],
      );
    },
  );
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.selected,
    required this.onChanged,
    this.onIgnore,
  });
  final LargeFile file;
  final bool selected;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onIgnore;

  @override
  Widget build(BuildContext context) {
    final category = categoryForPath(file.path);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: onChanged == null
                  ? null
                  : (value) => onChanged!(value ?? false),
              semanticLabel: 'Select ${p.basename(file.path)}',
            ),
            Icon(iconForCategory(category), color: CvColors.violet),
            const SizedBox(width: CvSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.basename(file.path),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SelectableText(
                    file.path,
                    style: const TextStyle(color: CvColors.muted, fontSize: 12),
                  ),
                  Text(
                    [
                      category,
                      if (file.modified != null)
                        'Modified ${formatDate(file.modified!)}',
                    ].join(' · '),
                    style: const TextStyle(color: CvColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: CvSpace.md),
            Text(
              formatBytes(file.bytes),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (onIgnore != null)
              IconButton(
                tooltip: 'Ignore this file',
                icon: const Icon(Icons.visibility_off_outlined),
                onPressed: onIgnore,
              ),
          ],
        ),
      ),
    );
  }
}

/// Sticky-style action bar for removing user-selected files.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.bytes,
    required this.onRemove,
  });
  final int count;
  final int bytes;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: CvSpace.md),
    padding: const EdgeInsets.all(CvSpace.lg),
    decoration: BoxDecoration(
      color: CvColors.raised,
      borderRadius: BorderRadius.circular(CvRadius.md),
      border: Border.all(color: CvColors.outline),
    ),
    child: Wrap(
      spacing: CvSpace.lg,
      runSpacing: CvSpace.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(
          count == 0
              ? 'Select files to remove'
              : '${plural(count, 'file')} selected · ${formatBytes(bytes)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        FilledButton.icon(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline_rounded),
          label: Text('Move to ${trashName()}'),
        ),
      ],
    ),
  );
}
