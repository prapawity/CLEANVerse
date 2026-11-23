// PageScroll arguments follow reading order: header content, then lists.
// ignore_for_file: sort_child_properties_last
import 'dart:io';
import 'dart:math' as math;

// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:cleanverse/src/app/list_toolbar.dart';
import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/data/removal.dart';
import 'package:cleanverse/src/features/cleanup/removal_dialog.dart';
import 'package:cleanverse/src/features/developer/cleanup_plan.dart';
import 'package:cleanverse/src/features/developer/developer_quick_check.dart';
import 'package:cleanverse/src/features/developer/docker.dart';
import 'package:cleanverse/src/features/developer/docker_panel.dart';
import 'package:cleanverse/src/features/developer/git_guard.dart';
import 'package:cleanverse/src/features/developer/tool_commands.dart';
import 'package:cleanverse/src/features/developer/tool_commands_panel.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/features/scan/smart_scan_page.dart';

enum _DevSection { projects, tools, docker, packages }

/// Pro tools for developers: project dependencies and build output, tool
/// caches, Docker and package-manager commands on one page. Uses the home
/// scan when it ran with developer detection; otherwise offers one scan.
class DeveloperPage extends StatefulWidget {
  const DeveloperPage({
    super.key,
    required this.model,
    required this.onNavigate,
    this.docker,
    this.toolCommands,
  });
  final FolderScanViewModel model;
  final ValueChanged<Section> onNavigate;

  /// Replaceable in tests so no real commands run.
  final DockerTools? docker;
  final ToolCommands? toolCommands;

  @override
  State<DeveloperPage> createState() => _DeveloperPageState();
}

enum DevSort { size, name, oldest, kind }

class _DeveloperPageState extends State<DeveloperPage> {
  static const _pageSize = 50;
  String query = '';
  late DevSort sort = rememberedSort(context, 'developer', DevSort.size);

  List<DevFolder> _arrange(Iterable<DevFolder> folders) {
    final list = [
      for (final f in folders)
        if (matchesQuery(query, [f.category, f.path, f.projectMarker, f.note]))
          f,
    ];
    int bySize(DevFolder a, DevFolder b) =>
        b.logicalBytes.compareTo(a.logicalBytes);
    switch (sort) {
      case DevSort.size:
        list.sort(bySize);
      case DevSort.name:
        list.sort(
          (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
        );
      case DevSort.oldest:
        // Least recently changed first; unknown dates last.
        list.sort((a, b) {
          final am = a.modified, bm = b.modified;
          if (am == null && bm == null) return bySize(a, b);
          if (am == null) return 1;
          if (bm == null) return -1;
          final c = am.compareTo(bm);
          return c != 0 ? c : bySize(a, b);
        });
      case DevSort.kind:
        list.sort((a, b) {
          final c = a.category.compareTo(b.category);
          return c != 0 ? c : bySize(a, b);
        });
    }
    return list;
  }

  FolderScanViewModel get model => widget.model;

  /// Explicit user choices; otherwise short sections start open.
  final Map<_DevSection, bool> _open = {};
  final Map<_DevSection, int> _shown = {};

  bool _isOpen(_DevSection s, int count) => _open[s] ?? count <= 5;
  int _limit(_DevSection s) => _shown[s] ?? _pageSize;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final result = model.result;
      final scanning = model.busy && model.root != null;
      final haveDev = result != null && model.findDevFolders && !scanning;
      final folders = haveDev ? result.devFolders : const <DevFolder>[];
      final projects = _arrange(folders.where((f) => f.projectMarker != null));
      final tools = _arrange(folders.where((f) => f.projectMarker == null));
      return PageScroll(
        children: [
          const PageHeader(
            title: 'Developer',
            subtitle:
                'Pro tools: project dependencies, build output, tool caches, Docker and '
                'package-manager commands. Nothing is selected until you choose.',
          ),
          if (scanning)
            ScanProgressPanel(model: model)
          else if (!haveDev)
            _ScanPrompt(model: model, hasOtherResult: result != null)
          else ...[
            _ScanSummary(model: model, result: result),
            if (folders.isNotEmpty) ...[
              const SizedBox(height: CvSpace.lg),
              ListToolbar<DevSort>(
                hint: 'Search by tool, project or path',
                initialQuery: query,
                onQuery: (v) => setState(() {
                  query = v;
                  _shown.clear();
                }),
                sort: sort,
                sortOptions: const [
                  SortOption(DevSort.size, 'Largest first'),
                  SortOption(DevSort.oldest, 'Least recently changed'),
                  SortOption(DevSort.kind, 'By type'),
                  SortOption(DevSort.name, 'Path A to Z'),
                ],
                onSort: (v) => setState(() {
                  sort = v;
                  rememberSort(context, 'developer', v);
                  _shown.clear();
                }),
              ),
              MatchCount(
                shown: projects.length + tools.length,
                total: folders.length,
                active: query.isNotEmpty,
              ),
              if (query.isNotEmpty && projects.isEmpty && tools.isEmpty)
                NoMatches(
                  query: query,
                  onClear: () => setState(() => query = ''),
                ),
            ],
          ],
        ],
        slivers: [
          if (haveDev) ...[
            ..._folderSection(
              _DevSection.projects,
              'Project folders',
              'Dependencies and build output inside your projects. Source files are never listed.',
              projects,
            ),
            ..._folderSection(
              _DevSection.tools,
              'Tool caches',
              'Shared caches found by the scan. Tools download or rebuild them when needed.',
              tools,
              footer: DeveloperQuickCheck(
                enabled: desktopScanSupported && !model.busy,
                exclusions: model.exclusions,
              ),
            ),
          ] else
            ..._section(
              _DevSection.tools,
              'Tool caches',
              'Known tool locations. A scan adds their sizes.',
              count: 0,
              body: DeveloperQuickCheck(
                enabled: desktopScanSupported && !model.busy,
                exclusions: model.exclusions,
              ),
            ),
          ..._section(
            _DevSection.docker,
            'Docker',
            'Images, containers and build cache, cleaned with Docker\'s own prune commands.',
            count: 99,
            body: DockerPanel(
              enabled: desktopScanSupported,
              tools: widget.docker,
            ),
          ),
          ..._section(
            _DevSection.packages,
            'Package managers',
            'Homebrew, npm and pub caches, cleaned by each tool\'s own command.',
            count: 99,
            body: ToolCommandsPanel(
              enabled: desktopScanSupported,
              windows: Platform.isWindows,
              tools: widget.toolCommands,
            ),
          ),
        ],
        bottomBar: haveDev && folders.isNotEmpty ? _bottomBar() : null,
      );
    },
  );

  Widget _bottomBar() {
    final plan = model.cleanupPlan;
    final count = model.selectedCleanupCount;
    final bytes = (plan?.candidates ?? const <CleanupCandidate>[]).fold<int>(
      0,
      (s, c) => s + c.logicalBytes,
    );
    return SelectionBar(
      status: count == 0
          ? 'Nothing selected'
          : '${plural(count, 'folder')} selected · ${formatBytes(bytes)} scanned',
      action: FilledButton(
        onPressed: plan == null || model.busy
            ? null
            : () => cleanDeveloperSelection(context, model, plan),
        child: const Text('Review and clean…'),
      ),
    );
  }

  List<Widget> _section(
    _DevSection id,
    String title,
    String detail, {
    required int count,
    required Widget body,
  }) {
    final open = _isOpen(id, count);
    return [
      SliverToBoxAdapter(
        child: _SectionHeader(
          title: title,
          detail: detail,
          expanded: open,
          onToggle: () => setState(() => _open[id] = !open),
        ),
      ),
      if (open)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: CvSpace.lg),
            child: body,
          ),
        ),
    ];
  }

  List<Widget> _folderSection(
    _DevSection id,
    String title,
    String detail,
    List<DevFolder> items, {
    Widget? footer,
  }) {
    // A search opens every section that has matches.
    final open =
        (query.isNotEmpty && items.isNotEmpty) || _isOpen(id, items.length);
    final bytes = items.fold<int>(0, (s, f) => s + f.logicalBytes);
    final shown = math.min(items.length, _limit(id));
    return [
      SliverToBoxAdapter(
        child: _SectionHeader(
          title: '$title · ${items.length}',
          detail: detail,
          trailing: items.isEmpty ? null : formatBytes(bytes),
          expanded: open,
          onToggle: () => setState(() => _open[id] = !open),
        ),
      ),
      if (open) ...[
        if (items.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: CvSpace.md),
              child: Text(
                'None found in this scan.',
                style: TextStyle(color: CvColors.muted),
              ),
            ),
          ),
        SliverList.builder(
          itemCount: shown,
          itemBuilder: (context, i) {
            final folder = items[i];
            return _DevFolderRow(
              folder: folder,
              activity: folder.projectMarker == null
                  ? null
                  : gitGuard.inspect(folder.projectMarker!),
              selected: model.isCleanupSelected(folder.path),
              onSelected: model.busy
                  ? null
                  : (v) => model.selectCleanupCandidate(folder.path, v),
            );
          },
        ),
        if (shown < items.length)
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _shown[id] = shown + _pageSize),
                child: Text(
                  'Show ${math.min(_pageSize, items.length - shown)} more',
                ),
              ),
            ),
          ),
        if (footer != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: CvSpace.lg),
              child: footer,
            ),
          ),
      ],
    ];
  }
}

class _ScanPrompt extends StatelessWidget {
  const _ScanPrompt({required this.model, required this.hasOtherResult});
  final FolderScanViewModel model;
  final bool hasOtherResult;

  @override
  Widget build(BuildContext context) {
    final home = model.homeFolder();
    return Padding(
      padding: const EdgeInsets.only(bottom: CvSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasOtherResult
                ? 'The last scan did not look for developer folders'
                : 'Find project and tool storage',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: CvSpace.xs),
          const Text(
            'Scans your home folder for dependencies, build output and tool caches. '
            'Read-only: nothing is selected or removed.',
            style: TextStyle(color: CvColors.muted),
          ),
          const SizedBox(height: CvSpace.md),
          FilledButton(
            onPressed: !desktopScanSupported || model.busy || home == null
                ? null
                : model.startDefault,
            child: const Text('Scan home folder'),
          ),
          if (model.error != null)
            Padding(
              padding: const EdgeInsets.only(top: CvSpace.md),
              child: Callout(model.error!, tone: CalloutTone.caution),
            ),
        ],
      ),
    );
  }
}

class _ScanSummary extends StatelessWidget {
  const _ScanSummary({required this.model, required this.result});
  final FolderScanViewModel model;
  final FolderScanResult result;

  @override
  Widget build(BuildContext context) {
    final bytes = result.devFolders.fold<int>(0, (s, f) => s + f.logicalBytes);
    return Padding(
      padding: const EdgeInsets.only(bottom: CvSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatBytes(bytes),
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
          ),
          Text(
            'in ${plural(result.devFolders.length, 'developer folder')}'
            '${result.cancelled ? ' (scan stopped early)' : ''}.',
            style: const TextStyle(color: CvColors.muted),
          ),
          if (model.root != null) PathLine(model.root!, prefix: 'Scanned '),
          const SizedBox(height: CvSpace.xs),
          const Text(
            'Sizes are logical bytes scanned, may be incomplete and are not '
            'reclaimable-space estimates. The scan lists up to 200 folders.',
            style: TextStyle(color: CvColors.muted, fontSize: 12),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: model.busy ? null : model.rescan,
              child: const Text('Scan again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.detail,
    required this.expanded,
    required this.onToggle,
    this.trailing,
  });
  final String title;
  final String detail;
  final bool expanded;
  final VoidCallback onToggle;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      rowDivider,
      Semantics(
        button: true,
        expanded: expanded,
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: CvSpace.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        detail,
                        style: const TextStyle(
                          color: CvColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: CvSpace.sm),
                  SizeText(trailing!),
                ],
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: CvColors.muted,
                  semanticLabel: expanded ? 'Collapse' : 'Expand',
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _DevFolderRow extends StatelessWidget {
  const _DevFolderRow({
    required this.folder,
    required this.selected,
    required this.onSelected,
    this.activity,
  });
  final DevFolder folder;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Future<ProjectActivity>? activity;

  @override
  Widget build(BuildContext context) {
    final important = folder.risk == CleanupRisk.potentiallyImportant;
    const muted = TextStyle(color: CvColors.muted, fontSize: 12);
    return InkWell(
      onTap: onSelected == null ? null : () => onSelected!(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selected,
              onChanged: onSelected == null
                  ? null
                  : (value) => onSelected!(value ?? false),
              semanticLabel: 'Select ${folder.category} for review',
            ),
            const SizedBox(width: CvSpace.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.category,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    PathLine(folder.path),
                    if (folder.projectMarker != null)
                      Text(
                        'Project marker: ${folder.projectMarker}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    if (folder.locationSource != null)
                      Text(
                        'Location source: ${folder.locationSource}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    Text(
                      important
                          ? 'May contain important data · Ownership and active use not verified'
                          : 'Review required · Ownership and active use not verified',
                      style: TextStyle(
                        color: important ? CvColors.amber : CvColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    if (folder.modified != null)
                      Text(
                        'Folder modified ${formatDate(folder.modified!)} (not last used)',
                        style: muted,
                      ),
                    if (activity != null)
                      FutureBuilder<ProjectActivity>(
                        future: activity,
                        builder: (context, snap) {
                          final text = _activityText(snap.data, DateTime.now());
                          if (text == null) return const SizedBox.shrink();
                          return Text(
                            text,
                            style: const TextStyle(
                              color: CvColors.amber,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    Text(
                      folder.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: CvSpace.sm),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SizeText(formatBytes(folder.logicalBytes)),
            ),
          ],
        ),
      ),
    );
  }
}

String? _activityText(ProjectActivity? a, DateTime now) {
  if (a == null) return null;
  final parts = [
    if (a.uncommitted > 0) 'Uncommitted changes (${a.uncommitted})',
    if (a.recentlyActive(now)) 'Active in the last 7 days',
    if (a.isGitRepo && a.uncommitted == 0 && !a.recentlyActive(now))
      'Git clean',
    if (!a.isGitRepo && a.gitAvailable && !a.recentlyActive(now)) 'Not in git',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Confirms and removes the selected developer folders, then rescans.
Future<void> cleanDeveloperSelection(
  BuildContext context,
  FolderScanViewModel model,
  CleanupPlan plan,
) async {
  final items = [
    for (final c in plan.candidates)
      RemovalItem(
        path: c.path,
        label: c.category,
        bytes: c.logicalBytes,
        // Project dependencies go to the bin; shared tool caches that can be
        // downloaded again are deleted; possibly unique data goes to the bin.
        recommended:
            c.projectMarker == null &&
                c.risk != CleanupRisk.potentiallyImportant
            ? RemovalMode.permanent
            : RemovalMode.trash,
        allowedRoot: plan.scope,
      ),
  ];
  final now = DateTime.now();
  final attention = <String>[];
  for (final c in plan.candidates) {
    final marker = c.projectMarker;
    if (marker == null) continue;
    final activity = await gitGuard.inspect(marker);
    if (activity.needsAttention(now)) {
      attention.add(
        '${p.basename(activity.projectDir)}'
        '${activity.uncommitted > 0 ? ' (${activity.uncommitted} uncommitted)' : ' (recently active)'}',
      );
    }
  }
  if (!context.mounted) return;
  final outcomes = await runRemovalFlow(
    context,
    title: 'Clean developer folders',
    items: items,
    warnings: [
      if (plan.partial) 'The scan was incomplete; sizes may be inaccurate.',
      if (attention.isNotEmpty)
        'Projects in active use: ${attention.join(', ')}. Their source files are not '
            'touched, but you will need to reinstall dependencies or rebuild before working on them.',
      'Stop running builds, dev servers and IDE indexing first. Projects need '
          'their dependencies installed again (for example npm install or flutter pub get).',
      if (plan.candidates.any(
        (c) => c.risk == CleanupRisk.potentiallyImportant,
      ))
        'Some items may contain data that cannot be recreated.',
    ],
  );
  if (outcomes != null) {
    gitGuard.clear();
    await model.rescan();
  }
}

/// Shared read-only git checks for project candidates.
/// Replaceable in tests.
GitGuard gitGuard = GitGuard();
