// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/data/removal.dart';
import 'package:cleanverse/src/features/cleanup/removal_dialog.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/features/scan/needs_scan.dart';

/// Exact-content matches. Review only; no removal or space estimates.
class DuplicatesPage extends StatefulWidget {
  const DuplicatesPage({
    super.key,
    required this.model,
    required this.onNavigate,
  });
  final FolderScanViewModel model;
  final ValueChanged<Section> onNavigate;

  @override
  State<DuplicatesPage> createState() => _DuplicatesPageState();
}

class _DuplicatesPageState extends State<DuplicatesPage> {
  final Set<String> selected = {};
  FolderScanViewModel get model => widget.model;
  ValueChanged<Section> get onNavigate => widget.onNavigate;

  /// At least one copy in every group must stay unselected.
  bool canSelect(List<LargeFile> group, LargeFile file) =>
      selected.contains(file.path) ||
      group.where((f) => !selected.contains(f.path)).length > 1;

  void selectAllButFirst(List<List<LargeFile>> groups) => setState(() {
    for (final group in groups) {
      for (final file in group.skip(1)) {
        selected.add(file.path);
      }
    }
  });

  Future<void> _remove(List<List<LargeFile>> groups) async {
    final root = model.root;
    if (root == null) return;
    // Re-check the keep-one rule before acting.
    for (final group in groups) {
      if (group.every((f) => selected.contains(f.path))) return;
    }
    final items = [
      for (final group in groups)
        for (final file in group)
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
      title: 'Remove duplicate copies',
      items: items,
      warnings: const [
        'At least one copy in every group is kept. Hard-linked copies share storage, '
            'so removing them may free less space than shown.',
      ],
    );
    if (outcomes == null || !mounted) return;
    setState(selected.clear);
    await model.rescan();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      const header = PageHeader(
        title: 'Duplicates',
        subtitle: 'Files with identical contents in this scope.',
      );
      final gate = needsScan(
        model,
        onNavigate,
        icon: Icons.file_copy_outlined,
        title: 'No matching files checked yet',
      );
      if (gate != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [header, gate],
        );
      }
      if (!model.findDuplicates) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            EmptyState(
              icon: Icons.file_copy_outlined,
              title: 'Matching was not part of this scan',
              message:
                  'Turn on matching to compare file contents locally with SHA-256. '
                  'This reads every candidate file and can take a while.',
              action: FilledButton.icon(
                onPressed: () => model.enableAndRescan(duplicates: true),
                icon: const Icon(Icons.refresh_rounded, size: 19),
                label: const Text('Turn on and scan again'),
              ),
            ),
          ],
        );
      }
      final result = model.result!;
      final groups = [...result.duplicates]
        ..sort(
          (a, b) =>
              (b.first.bytes * b.length).compareTo(a.first.bytes * a.length),
        );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          Text(
            'Matching groups: ${groups.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: CvSpace.sm),
          const Callout(
            'Matches have the same size and SHA-256 hash. Hard links may appear '
            'separately; no space savings are estimated. Always keep at least one copy.',
          ),
          if (result.cancelled || result.skipped > 0)
            const Callout(
              'Some files were skipped or the scan was cancelled, so matches may be missing.',
              tone: CalloutTone.caution,
            ),
          if (groups.isEmpty)
            const EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'No matching files found',
              message: 'No files in this scope had identical contents.',
            )
          else ...[
            const Text(
              'Showing up to 50 groups and 20 paths per group, largest first.',
              style: TextStyle(color: CvColors.muted, fontSize: 13),
            ),
            const SizedBox(height: CvSpace.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: model.busy
                    ? null
                    : () => selectAllButFirst(groups.take(50).toList()),
                icon: const Icon(Icons.library_add_check_outlined),
                label: const Text('Select all but one copy in each group'),
              ),
            ),
            for (final group in groups.take(50))
              _GroupCard(
                group: group,
                isSelected: (f) => selected.contains(f.path),
                canSelect: (f) => !model.busy && canSelect(group, f),
                onChanged: (f, value) => setState(
                  () => value ? selected.add(f.path) : selected.remove(f.path),
                ),
              ),
            Container(
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
                    selected.isEmpty
                        ? 'Select copies to remove'
                        : '${plural(selected.length, 'copy', 'copies')} selected',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  FilledButton.icon(
                    onPressed: selected.isEmpty || model.busy
                        ? null
                        : () => _remove(groups.take(50).toList()),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text('Move to ${trashName()}'),
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

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.isSelected,
    required this.canSelect,
    required this.onChanged,
  });
  final List<LargeFile> group;
  final bool Function(LargeFile) isSelected;
  final bool Function(LargeFile) canSelect;
  final void Function(LargeFile, bool) onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(CvSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                iconForCategory(categoryForPath(group.first.path)),
                color: CvColors.violet,
              ),
              const SizedBox(width: CvSpace.md),
              Expanded(
                child: Text(
                  p.basename(group.first.path),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: CvSpace.sm),
              Flexible(
                child: Text(
                  '${group.length} matching files · ${formatBytes(group.first.bytes)} each',
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: CvColors.muted, fontSize: 12),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          for (final file in group.take(20))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected(file),
                    onChanged: canSelect(file)
                        ? (value) => onChanged(file, value ?? false)
                        : null,
                    semanticLabel: 'Select copy ${file.path}',
                  ),
                  const SizedBox(width: CvSpace.xs),
                  Expanded(child: SelectableText(file.path)),
                  if (!isSelected(file) && !canSelect(file))
                    const Padding(
                      padding: EdgeInsets.only(left: CvSpace.sm),
                      child: StatusChip('Kept', color: CvColors.mint),
                    ),
                ],
              ),
            ),
          if (group.length > 20)
            Text(
              '${group.length - 20} more not shown',
              style: const TextStyle(color: CvColors.muted, fontSize: 12),
            ),
        ],
      ),
    ),
  );
}
