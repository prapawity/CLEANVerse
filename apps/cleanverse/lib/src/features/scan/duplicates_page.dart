// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:cleanverse/src/app/list_toolbar.dart';
import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/data/removal.dart';
import 'package:cleanverse/src/features/cleanup/removal_dialog.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/features/scan/needs_scan.dart';

/// Groups shown at first and added by each "Show more".
const duplicateGroupPageSize = 50;

/// Paths listed inside one expanded group.
const _pathsPerGroup = 20;

/// Exact-content matches, with removal of user-selected extra copies.
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

enum DuplicateSort { space, copies, fileSize, name }

class _DuplicatesPageState extends State<DuplicatesPage> {
  String query = '';
  late DuplicateSort sort = rememberedSort(
    context,
    'duplicates',
    DuplicateSort.space,
  );
  final Set<String> selected = {};

  /// Group keys (first path) the user expanded or collapsed explicitly.
  final Map<String, bool> _expanded = {};
  int shown = duplicateGroupPageSize;
  FolderScanViewModel get model => widget.model;

  /// At least one copy in every group must stay unselected.
  bool canSelect(List<LargeFile> group, LargeFile file) =>
      selected.contains(file.path) ||
      group.where((f) => !selected.contains(f.path)).length > 1;

  void selectAllButFirst(List<List<LargeFile>> groups) => setState(() {
    for (final group in groups) {
      for (final file in group.skip(1).take(_pathsPerGroup - 1)) {
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
      final gate = needsScan(
        model,
        widget.onNavigate,
        icon: Icons.file_copy_outlined,
        title: 'No duplicates checked yet',
      );
      if (gate != null) return StorageScroll(header: [gate]);
      if (!model.findDuplicates) {
        return StorageScroll(
          header: [
            EmptyState(
              icon: Icons.file_copy_outlined,
              title: 'Find files with identical contents',
              message:
                  'Scans ${displayName(model.root!)} again and compares file contents on this computer. Large folders can take a while.',
              action: FilledButton(
                onPressed: model.busy
                    ? null
                    : () => model.enableAndRescan(duplicates: true),
                child: const Text('Find duplicates'),
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
      // Search and sort whole groups; the order inside a group (first copy
      // is the one kept) never changes.
      final listed = [
        for (final g in groups)
          if (g.any((f) => matchesQuery(query, [p.basename(f.path), f.path])))
            g,
      ];
      switch (sort) {
        case DuplicateSort.space:
          break; // groups is already sorted by space used
        case DuplicateSort.copies:
          listed.sort((a, b) => b.length.compareTo(a.length));
        case DuplicateSort.fileSize:
          listed.sort((a, b) => b.first.bytes.compareTo(a.first.bytes));
        case DuplicateSort.name:
          listed.sort(
            (a, b) => p
                .basename(a.first.path)
                .toLowerCase()
                .compareTo(p.basename(b.first.path).toLowerCase()),
          );
      }
      final count = listed.length < shown ? listed.length : shown;
      final collapseByDefault = listed.length > 3 && query.isEmpty;
      final extraBytes = groups.fold<int>(
        0,
        (s, g) => s + g.first.bytes * (g.length - 1),
      );
      final selectedBytes = [
        for (final g in groups)
          for (final f in g)
            if (selected.contains(f.path)) f.bytes,
      ].fold<int>(0, (s, b) => s + b);
      return StorageScroll(
        header: [
          Text(
            groups.isEmpty
                ? 'No duplicates found'
                : '${plural(groups.length, 'group')} of duplicates · up to ${formatBytes(extraBytes)} in extra copies',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: CvSpace.xs),
          const Text(
            'Copies have the same size and SHA-256 hash. Hard links share storage, so you may free less. One copy in each group is always kept.',
            style: TextStyle(color: CvColors.muted, fontSize: 13),
          ),
          if (result.cancelled || result.skipped > 0)
            const Padding(
              padding: EdgeInsets.only(top: CvSpace.sm),
              child: Callout(
                'Some files were skipped or the scan was cancelled, so matches may be missing.',
                tone: CalloutTone.caution,
              ),
            ),
          if (groups.isNotEmpty) ...[
            const SizedBox(height: CvSpace.md),
            ListToolbar<DuplicateSort>(
              hint: 'Search by file name or folder',
              initialQuery: query,
              onQuery: (v) => setState(() {
                query = v;
                shown = duplicateGroupPageSize;
              }),
              sort: sort,
              sortOptions: const [
                SortOption(DuplicateSort.space, 'Most space used'),
                SortOption(DuplicateSort.copies, 'Most copies'),
                SortOption(DuplicateSort.fileSize, 'Largest file'),
                SortOption(DuplicateSort.name, 'Name A to Z'),
              ],
              onSort: (v) => setState(() {
                sort = v;
                rememberSort(context, 'duplicates', v);
                shown = duplicateGroupPageSize;
              }),
            ),
            MatchCount(
              shown: listed.length,
              total: groups.length,
              active: query.isNotEmpty,
            ),
            if (listed.isEmpty && query.isNotEmpty)
              NoMatches(
                query: query,
                onClear: () => setState(() => query = ''),
              ),
          ],
          if (listed.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: model.busy
                    ? null
                    : () => selectAllButFirst(listed.take(count).toList()),
                child: const Text('Select all but one copy in each group'),
              ),
            ),
        ],
        slivers: [
          SliverList.builder(
            itemCount: count,
            itemBuilder: (context, i) {
              final group = listed[i];
              final key = group.first.path;
              return _Group(
                group: group,
                expanded: _expanded[key] ?? !collapseByDefault,
                onToggle: () => setState(
                  () =>
                      _expanded[key] = !(_expanded[key] ?? !collapseByDefault),
                ),
                isSelected: (f) => selected.contains(f.path),
                canSelect: (f) => !model.busy && canSelect(group, f),
                onChanged: (f, value) => setState(
                  () => value ? selected.add(f.path) : selected.remove(f.path),
                ),
              );
            },
          ),
          if (listed.length > count)
            SliverToBoxAdapter(
              child: ShowMoreButton(
                remaining: listed.length - count,
                onPressed: () =>
                    setState(() => shown += duplicateGroupPageSize),
              ),
            ),
        ],
        bottomBar: groups.isEmpty
            ? null
            : SelectionBar(
                status: selected.isEmpty
                    ? 'Select copies to remove'
                    : '${plural(selected.length, 'copy', 'copies')} selected · ${formatBytes(selectedBytes)}',
                action: FilledButton(
                  onPressed: selected.isEmpty || model.busy
                      ? null
                      : () => _remove(groups),
                  child: Text('Move to ${trashName()}…'),
                ),
              ),
      );
    },
  );
}

class _Group extends StatelessWidget {
  const _Group({
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.isSelected,
    required this.canSelect,
    required this.onChanged,
  });
  final List<LargeFile> group;
  final bool expanded;
  final VoidCallback onToggle;
  final bool Function(LargeFile) isSelected;
  final bool Function(LargeFile) canSelect;
  final void Function(LargeFile, bool) onChanged;

  @override
  Widget build(BuildContext context) {
    final name = p.basename(group.first.path);
    final picked = group.where(isSelected).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(CvRadius.sm),
          child: Semantics(
            button: true,
            expanded: expanded,
            label: '$name, ${group.length} copies',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: CvSpace.sm),
              child: Row(
                children: [
                  Icon(
                    expanded
                        ? Icons.expand_more_rounded
                        : Icons.chevron_right_rounded,
                    color: CvColors.muted,
                  ),
                  const SizedBox(width: CvSpace.sm),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: CvSpace.sm),
                  Flexible(
                    child: Text(
                      [
                        '${group.length} × ${formatBytes(group.first.bytes)}',
                        if (picked > 0) '$picked selected',
                      ].join(' · '),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CvColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...[
          for (final file in group.take(_pathsPerGroup))
            Padding(
              padding: const EdgeInsets.only(left: CvSpace.lg),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected(file),
                    onChanged: canSelect(file)
                        ? (value) => onChanged(file, value ?? false)
                        : null,
                    semanticLabel: 'Select copy ${file.path}',
                  ),
                  Expanded(child: PathLine(file.path, copy: true)),
                  if (!isSelected(file) && !canSelect(file))
                    const Padding(
                      padding: EdgeInsets.only(left: CvSpace.sm),
                      child: Text(
                        'Kept',
                        style: TextStyle(color: CvColors.mint, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          if (group.length > _pathsPerGroup)
            Padding(
              padding: const EdgeInsets.only(left: 56, bottom: CvSpace.sm),
              child: Text(
                '${group.length - _pathsPerGroup} more copies not shown',
                style: const TextStyle(color: CvColors.muted, fontSize: 12),
              ),
            ),
        ],
        const Divider(height: 1, color: CvColors.outlineSoft),
      ],
    );
  }
}
