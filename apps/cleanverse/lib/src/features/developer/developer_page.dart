// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/data/removal.dart';
import 'package:cleanverse/src/features/cleanup/removal_dialog.dart';
import 'package:cleanverse/src/features/developer/cleanup_plan.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/features/developer/developer_quick_check.dart';
import 'package:cleanverse/src/features/developer/git_guard.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/features/scan/smart_scan_page.dart';

/// Developer Cleanup: discover project and tool storage, select items for an
/// in-memory review. Moving to Trash stays disabled until the safety gate.
class DeveloperPage extends StatelessWidget {
  const DeveloperPage({
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
      final busy = model.busy && model.root != null && !model.pickingExclusion;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Developer',
            subtitle: 'Review dependencies, build output and tool caches, then clean what you choose.',
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick check',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'Looks only at known tool locations. It does not traverse folders or calculate sizes.',
                  style: TextStyle(color: CvColors.muted, fontSize: 13),
                ),
                DeveloperQuickCheck(
                  enabled: desktopScanSupported && !model.busy,
                  exclusions: model.exclusions,
                ),
              ],
            ),
          ),
          const SectionTitle(
            'Developer Cleanup',
            detail: 'Candidates found by the folder scan, using project markers or possible cache locations.',
          ),
          if (busy)
            ScanProgressPanel(model: model)
          else if (result == null || !model.findDevFolders)
            EmptyState(
              icon: Icons.code_rounded,
              title: result == null
                  ? 'Scan a projects folder'
                  : 'Developer folders were not part of this scan',
              message: 'Turn on "Find developer folders" and scan a folder such as your projects directory.',
              action: FilledButton.icon(
                onPressed: !desktopScanSupported || model.busy
                    ? null
                    : result == null
                    ? () {
                        if (!model.findDevFolders) {
                          model.setFindDevFolders(true);
                        }
                        model.start();
                      }
                    : () => model.enableAndRescan(devFolders: true),
                icon: const Icon(Icons.folder_open_outlined, size: 19),
                label: Text(
                  result == null
                      ? 'Choose and scan folder'
                      : 'Turn on and scan again',
                ),
              ),
            )
          else
            _Candidates(model: model, result: result),
        ],
      );
    },
  );
}

class _Candidates extends StatelessWidget {
  const _Candidates({required this.model, required this.result});
  final FolderScanViewModel model;
  final FolderScanResult result;

  @override
  Widget build(BuildContext context) {
    final projects = result.devFolders
        .where((f) => f.projectMarker != null)
        .toList();
    final tools = result.devFolders
        .where((f) => f.projectMarker == null)
        .toList();
    final plan = model.cleanupPlan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Developer folders: ${result.devFolders.length}'),
        const SizedBox(height: CvSpace.sm),
        const Callout(
          'Sizes are logical bytes scanned, may be incomplete and are not '
          'reclaimable-space estimates. Up to 200 are shown. Select folders, then review and clean.',
        ),
        if (projects.isNotEmpty) ...[
          const SectionTitle('Project folders'),
          for (final folder in projects) _card(folder),
        ],
        if (tools.isNotEmpty) ...[
          const SectionTitle('Tool storage candidates'),
          for (final folder in tools) _card(folder),
        ],
        if (result.devFolders.isEmpty)
          const EmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'No developer folders found',
            message: 'No project dependencies or known tool caches were found in this scope.',
          )
        else
          // Sticky-feeling action bar at the end of the list.
          Container(
            margin: const EdgeInsets.only(top: CvSpace.lg),
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
              children: [
                Text(
                  '${model.selectedCleanupCount} selected for review',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                OutlinedButton.icon(
                  onPressed: plan == null
                      ? null
                      : () => cleanDeveloperSelection(context, model, plan),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Review and clean'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _card(DevFolder folder) => _DevFolderCard(
    folder: folder,
    activity: folder.projectMarker == null
        ? null
        : gitGuard.inspect(folder.projectMarker!),
    selected: model.isCleanupSelected(folder.path),
    onSelected: (value) => model.selectCleanupCandidate(folder.path, value),
  );
}

class _DevFolderCard extends StatelessWidget {
  const _DevFolderCard({
    required this.folder,
    required this.selected,
    required this.onSelected,
    this.activity,
  });
  final DevFolder folder;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Future<ProjectActivity>? activity;

  @override
  Widget build(BuildContext context) {
    final important = folder.risk == CleanupRisk.potentiallyImportant;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CvRadius.md),
        side: BorderSide(
          color: selected ? CvColors.cyan : CvColors.outline,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) => onSelected(value ?? false),
              semanticLabel: 'Select ${folder.category} for review',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: CvSpace.sm,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${folder.category} · ${formatBytes(folder.logicalBytes)} scanned',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        StatusChip(
                          important
                              ? 'May contain important data'
                              : 'Review required',
                          color: important ? CvColors.amber : CvColors.violet,
                        ),
                        if (activity != null)
                          FutureBuilder<ProjectActivity>(
                            future: activity,
                            builder: (context, snap) {
                              final a = snap.data;
                              if (a == null) return const SizedBox.shrink();
                              return Wrap(
                                spacing: CvSpace.sm,
                                runSpacing: 4,
                                children: _activityChips(a, DateTime.now()),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      folder.path,
                      style: const TextStyle(
                        color: CvColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (folder.locationSource != null)
                      Text('Location source: ${folder.locationSource}'),
                    if (folder.projectMarker != null)
                      SelectableText('Project marker: ${folder.projectMarker}'),
                    if (folder.modified != null)
                      Text(
                        'Folder modified: ${folder.modified!.toLocal().toString().split('.').first} (not last used)',
                      ),
                    Text(
                      important
                          ? 'May contain important data · Ownership and active use not verified'
                          : 'Review required · Ownership and active use not verified',
                      style: const TextStyle(
                        color: CvColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    Text(folder.note, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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

List<Widget> _activityChips(ProjectActivity a, DateTime now) => [
  if (a.uncommitted > 0)
    StatusChip(
      'Uncommitted changes (${a.uncommitted})',
      color: CvColors.amber,
      icon: Icons.edit_note_rounded,
    ),
  if (a.recentlyActive(now))
    const StatusChip(
      'Active in the last 7 days',
      color: CvColors.amber,
      icon: Icons.schedule_rounded,
    ),
  if (a.isGitRepo && a.uncommitted == 0 && !a.recentlyActive(now))
    const StatusChip('Git clean', color: CvColors.mint),
  if (!a.isGitRepo && a.gitAvailable && !a.recentlyActive(now))
    const StatusChip('Not in git', color: CvColors.muted),
];

/// Shared read-only git checks for project candidates.
/// Replaceable in tests.
GitGuard gitGuard = GitGuard();
