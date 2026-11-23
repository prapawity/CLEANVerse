// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/app/list_toolbar.dart';
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

enum LargeFileSort { size, smallest, oldest, newest, name }

/// Files not modified for this long count as "old". Modification time is
/// used because last-opened time is unreliable across platforms.
const oldFileAge = Duration(days: 365);

/// Rows shown at first and added by each "Show more".
const largeFilesPageSize = 50;

String _age(DateTime? modified, DateTime now) {
  if (modified == null) return 'Unknown age';
  final days = now.difference(modified).inDays;
  if (days < 1) return 'Today';
  if (days < 31) return '${plural(days, 'day')} old';
  if (days < 365) return '${plural(days ~/ 30, 'month')} old';
  return '${plural(days ~/ 365, 'year')} old';
}

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
  late LargeFileSort sort = rememberedSort(
    context,
    'largeFiles',
    LargeFileSort.size,
  );
  String query = '';
  int shown = largeFilesPageSize;
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

  List<LargeFile> _visible(List<LargeFile> files, DateTime now) {
    final ignored = activeIgnoreList;
    final list = files.where((file) {
      if (ignored?.covers(file.path) ?? false) return false;
      if (!matchesQuery(query, [p.basename(file.path), file.path])) {
        return false;
      }
      return switch (filter) {
        LargeFileFilter.all => true,
        LargeFileFilter.large => file.bytes >= largeFileThreshold,
        LargeFileFilter.old =>
          file.modified != null && now.difference(file.modified!) >= oldFileAge,
      };
    }).toList();
    int bySize(LargeFile a, LargeFile b) => b.bytes.compareTo(a.bytes);
    int byDate(LargeFile a, LargeFile b, {required bool oldest}) {
      final am = a.modified, bm = b.modified;
      if (am == null && bm == null) return bySize(a, b);
      if (am == null) return 1; // unknown age goes last either way
      if (bm == null) return -1;
      final c = oldest ? am.compareTo(bm) : bm.compareTo(am);
      return c != 0 ? c : bySize(a, b);
    }

    switch (sort) {
      case LargeFileSort.size:
        list.sort(bySize);
      case LargeFileSort.smallest:
        list.sort((a, b) => a.bytes.compareTo(b.bytes));
      case LargeFileSort.oldest:
        list.sort((a, b) => byDate(a, b, oldest: true));
      case LargeFileSort.newest:
        list.sort((a, b) => byDate(a, b, oldest: false));
      case LargeFileSort.name:
        list.sort(
          (a, b) => p
              .basename(a.path)
              .toLowerCase()
              .compareTo(p.basename(b.path).toLowerCase()),
        );
    }
    return list;
  }

  Widget _controls() => ListToolbar<LargeFileSort>(
    hint: 'Search by name or folder',
    initialQuery: query,
    onQuery: (v) => setState(() {
      query = v;
      shown = largeFilesPageSize;
    }),
    sort: sort,
    sortOptions: const [
      SortOption(LargeFileSort.size, 'Largest first'),
      SortOption(LargeFileSort.smallest, 'Smallest first'),
      SortOption(LargeFileSort.oldest, 'Oldest first'),
      SortOption(LargeFileSort.newest, 'Newest first'),
      SortOption(LargeFileSort.name, 'Name A to Z'),
    ],
    onSort: (v) => setState(() {
      sort = v;
      rememberSort(context, 'largeFiles', v);
      shown = largeFilesPageSize;
    }),
    trailing: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<LargeFileFilter>(
        segments: const [
          ButtonSegment(value: LargeFileFilter.all, label: Text('All')),
          ButtonSegment(value: LargeFileFilter.large, label: Text('50 MiB+')),
          ButtonSegment(
            value: LargeFileFilter.old,
            label: Text('Older than a year'),
          ),
        ],
        selected: {filter},
        showSelectedIcon: false,
        onSelectionChanged: (value) => setState(() {
          filter = value.first;
          shown = largeFilesPageSize;
        }),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final gate = needsScan(
        widget.model,
        widget.onNavigate,
        icon: Icons.inventory_outlined,
        title: 'No files to review yet',
      );
      if (gate != null) return StorageScroll(header: [gate]);
      final now = (widget.now ?? DateTime.now)();
      final result = widget.model.result!;
      final visible = _visible(result.files, now);
      final count = visible.length < shown ? visible.length : shown;
      final busy = widget.model.busy;
      final selectedBytes = result.files
          .where((f) => selected.contains(f.path))
          .fold<int>(0, (s, f) => s + f.bytes);
      return StorageScroll(
        header: [
          Text(
            '${plural(visible.length, 'file')} · '
            '${formatBytes(visible.fold<int>(0, (s, f) => s + f.bytes))}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: CvSpace.xs),
          const Text(
            'The largest files in this scan. Age is the last change, not the last time you opened it.',
            style: TextStyle(color: CvColors.muted, fontSize: 13),
          ),
          if (result.cancelled || result.skipped > 0)
            const Padding(
              padding: EdgeInsets.only(top: CvSpace.sm),
              child: Callout(
                'This list may be incomplete because the scan was cancelled or items were skipped.',
                tone: CalloutTone.caution,
              ),
            ),
          const SizedBox(height: CvSpace.md),
          _controls(),
          MatchCount(
            shown: visible.length,
            total: result.files.length,
            active: query.isNotEmpty || filter != LargeFileFilter.all,
          ),
          const SizedBox(height: CvSpace.md),
          if (result.files.isEmpty)
            const Text('No files found in the scanned scope.')
          else if (visible.isEmpty && query.isNotEmpty)
            NoMatches(query: query, onClear: () => setState(() => query = ''))
          else if (visible.isEmpty)
            const Text(
              'No files match this filter. Choose All to see every file.',
              style: TextStyle(color: CvColors.muted),
            ),
        ],
        slivers: [
          SliverList.separated(
            itemCount: count,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: CvColors.outlineSoft),
            itemBuilder: (context, i) {
              final file = visible[i];
              return _FileRow(
                file: file,
                age: _age(file.modified, now),
                selected: selected.contains(file.path),
                onIgnore: widget.settings == null || busy
                    ? null
                    : () async {
                        await widget.settings!.ignorePath(file.path);
                        setState(() => selected.remove(file.path));
                      },
                onChanged: busy
                    ? null
                    : (value) => setState(
                        () => value
                            ? selected.add(file.path)
                            : selected.remove(file.path),
                      ),
              );
            },
          ),
          if (visible.length > count)
            SliverToBoxAdapter(
              child: ShowMoreButton(
                remaining: visible.length - count,
                onPressed: () => setState(() => shown += largeFilesPageSize),
              ),
            ),
        ],
        bottomBar: result.files.isEmpty
            ? null
            : SelectionBar(
                summary: selected.isEmpty
                    ? 'Select files to remove'
                    : '${plural(selected.length, 'file')} selected · ${formatBytes(selectedBytes)}',
                actionLabel: 'Move to ${trashName()}…',
                onAction: selected.isEmpty || busy
                    ? null
                    : () => _remove(result.files),
              ),
      );
    },
  );
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.age,
    required this.selected,
    required this.onChanged,
    this.onIgnore,
  });
  final LargeFile file;
  final String age;
  final bool selected;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onIgnore;

  @override
  Widget build(BuildContext context) {
    final name = p.basename(file.path);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CvSpace.xs),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: onChanged == null
                ? null
                : (value) => onChanged!(value ?? false),
            semanticLabel: 'Select $name',
          ),
          const SizedBox(width: CvSpace.xs),
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
                PathLine(file.path),
              ],
            ),
          ),
          const SizedBox(width: CvSpace.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatBytes(file.bytes),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                age,
                style: const TextStyle(color: CvColors.muted, fontSize: 12),
              ),
            ],
          ),
          if (onIgnore != null)
            IconButton(
              tooltip: 'Ignore this file',
              icon: const Icon(
                Icons.visibility_off_outlined,
                size: 18,
                color: CvColors.muted,
              ),
              onPressed: onIgnore,
            ),
        ],
      ),
    );
  }
}
