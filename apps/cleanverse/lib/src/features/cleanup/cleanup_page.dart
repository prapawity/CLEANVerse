// PageScroll arguments follow reading order: header content, then lists.
// ignore_for_file: sort_child_properties_last
// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/list_toolbar.dart';
import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/features/cleanup/cleanup_view_model.dart';
import 'package:cleanverse/src/features/cleanup/junk_catalog.dart';
import 'package:cleanverse/src/features/cleanup/removal_dialog.dart';
import 'package:cleanverse/src/features/settings/app_settings.dart';

Color riskColor(JunkRisk risk) => switch (risk) {
  JunkRisk.safe => CvColors.mint,
  JunkRisk.caution => CvColors.amber,
  JunkRisk.risky => CvColors.rose,
};

IconData _riskIcon(JunkRisk risk) => switch (risk) {
  JunkRisk.safe => Icons.check_circle_outline_rounded,
  JunkRisk.caution => Icons.info_outline_rounded,
  JunkRisk.risky => Icons.warning_amber_rounded,
};

/// Quiet risk label: icon and colored text, with the explanation as a
/// tooltip and screen-reader text. The word carries the meaning.
class RiskChip extends StatelessWidget {
  const RiskChip(this.risk, {super.key});
  final JunkRisk risk;

  @override
  Widget build(BuildContext context) {
    final color = riskColor(risk);
    return Tooltip(
      message: risk.explanation,
      child: Semantics(
        label: 'Risk: ${risk.label}. ${risk.explanation}',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_riskIcon(risk), size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              risk.label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Junk check across known cache locations. The simple view shows the
/// total and one action; "Review all" opens the grouped list.
class CleanupPage extends StatefulWidget {
  const CleanupPage({
    super.key,
    required this.model,
    required this.onNavigate,
    this.settings,
    this.fullDiskAccess,
  });

  /// macOS only; null hides the banner (other platforms and tests).
  final Widget? fullDiskAccess;
  final CleanupViewModel model;
  final ValueChanged<Section> onNavigate;
  final AppSettings? settings;

  @override
  State<CleanupPage> createState() => _CleanupPageState();
}

enum JunkSort { size, name, safest, riskiest }

class _CleanupPageState extends State<CleanupPage> {
  CleanupViewModel get model => widget.model;
  bool _review = false;
  String query = '';
  late JunkSort sort = rememberedSort(context, 'cleanup', JunkSort.size);

  /// Items of [group] matching the search, in the chosen order.
  List<MeasuredJunk> _listed(JunkGroup group) {
    final items = [
      for (final j in model.inGroup(group))
        if (matchesQuery(query, [j.target.label, j.target.path, j.target.note]))
          j,
    ];
    switch (sort) {
      case JunkSort.size:
        items.sort((a, b) => b.bytes.compareTo(a.bytes));
      case JunkSort.name:
        items.sort(
          (a, b) => a.target.label.toLowerCase().compareTo(
            b.target.label.toLowerCase(),
          ),
        );
      case JunkSort.safest:
        items.sort((a, b) {
          final c = a.target.risk.index.compareTo(b.target.risk.index);
          return c != 0 ? c : b.bytes.compareTo(a.bytes);
        });
      case JunkSort.riskiest:
        items.sort((a, b) {
          final c = b.target.risk.index.compareTo(a.target.risk.index);
          return c != 0 ? c : b.bytes.compareTo(a.bytes);
        });
    }
    return items;
  }

  final Set<JunkGroup> _expanded = {};

  @override
  void initState() {
    super.initState();
    // Default path: check automatically the first time the page opens.
    // Home may already have run it through the same model.
    if (model.found == null && !model.busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && model.found == null && !model.busy) model.scan();
      });
    }
  }

  Future<void> _confirm(String title, List<MeasuredJunk> chosen) async {
    if (chosen.isEmpty) return;
    final risky = [
      for (final junk in chosen)
        if (junk.target.risk == JunkRisk.risky) junk.target.label,
    ];
    final apps = {
      for (final junk in chosen)
        if (junk.target.closeApp != null) junk.target.closeApp!,
    };
    await runRemovalFlow(
      context,
      title: title,
      items: [for (final junk in chosen) junk.item],
      warnings: [
        if (risky.isNotEmpty)
          'Risky: ${risky.join(', ')} may hold data that cannot be rebuilt. '
              'Keep them in the bin until you are sure.',
        if (apps.isNotEmpty)
          'Close ${apps.join(', ')} first. Caches in use are skipped.',
      ],
      execute: (override) => model.clean(override: override, only: chosen),
    );
  }

  void _toggleGroup(JunkGroup group) => setState(
    () => _expanded.contains(group)
        ? _expanded.remove(group)
        : _expanded.add(group),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final found = model.found;
      final showList =
          _review && found != null && found.isNotEmpty && !model.scanning;
      return PageScroll(
        children: [
          const PageHeader(
            title: 'Clean up',
            subtitle:
                'Temporary files and caches that apps rebuild by themselves.',
          ),
          ?widget.fullDiskAccess,
          _Summary(
            model: model,
            reviewing: _review,
            onCleanSafe: () => _confirm('Clean safe junk', model.safe),
            onToggleReview: () => setState(() => _review = !_review),
          ),
          if (showList) ...[
            const SizedBox(height: CvSpace.lg),
            ListToolbar<JunkSort>(
              hint: 'Search locations',
              initialQuery: query,
              onQuery: (v) => setState(() => query = v),
              sort: sort,
              sortOptions: const [
                SortOption(JunkSort.size, 'Largest first'),
                SortOption(JunkSort.name, 'Name A to Z'),
                SortOption(JunkSort.safest, 'Safest first'),
                SortOption(JunkSort.riskiest, 'Riskiest first'),
              ],
              onSort: (v) {
                setState(() => sort = v);
                rememberSort(context, 'cleanup', v);
              },
            ),
            MatchCount(
              shown: [for (final g in JunkGroup.values) ..._listed(g)].length,
              total: found.length,
              active: query.isNotEmpty,
            ),
            if (query.isNotEmpty &&
                JunkGroup.values.every((g) => _listed(g).isEmpty))
              NoMatches(
                query: query,
                onClear: () => setState(() => query = ''),
              ),
          ],
        ],
        slivers: [
          if (showList) ...[
            for (final group in JunkGroup.values)
              if (_listed(group).isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _GroupHeader(
                    model: model,
                    group: group,
                    // A search opens every group that has matches.
                    expanded: query.isNotEmpty || _expanded.contains(group),
                    onToggle: () => _toggleGroup(group),
                  ),
                ),
                if (query.isNotEmpty || _expanded.contains(group))
                  _groupItems(_listed(group)),
              ],
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: CvSpace.xl),
                child: Text(
                  'Project folders such as node_modules are in Developer. '
                  'Large and duplicate files are in Storage.',
                  style: TextStyle(color: CvColors.muted, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
        bottomBar: showList ? _bottomBar() : null,
      );
    },
  );

  Widget _groupItems(List<MeasuredJunk> items) => SliverList.builder(
    itemCount: items.length,
    itemBuilder: (context, i) =>
        _JunkRow(model: model, junk: items[i], settings: widget.settings),
  );

  Widget _bottomBar() {
    final count = model.selected.length;
    return SelectionBar(
      status: count == 0
          ? 'Nothing selected'
          : '${plural(count, 'location')} selected · ${formatBytes(model.selectedBytes)}',
      action: FilledButton.tonal(
        onPressed: count == 0 || model.busy
            ? null
            : () => _confirm('Clean selected junk', model.selected),
        child: const Text('Clean selected…'),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.model,
    required this.reviewing,
    required this.onCleanSafe,
    required this.onToggleReview,
  });
  final CleanupViewModel model;
  final bool reviewing;
  final VoidCallback onCleanSafe;
  final VoidCallback onToggleReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final found = model.found;
    final children = <Widget>[];
    if (model.cleaning) {
      children.addAll([
        Semantics(
          liveRegion: true,
          child: Text(
            'Cleaning: ${model.progressDone} of ${model.progressTotal} done',
            style: theme.titleMedium,
          ),
        ),
        const SizedBox(height: CvSpace.md),
        LinearProgressIndicator(
          value: model.progressTotal == 0
              ? null
              : model.progressDone / model.progressTotal,
        ),
      ]);
    } else if (model.scanning) {
      children.addAll([
        Semantics(
          liveRegion: true,
          child: Text('Checking for junk…', style: theme.titleMedium),
        ),
        const SizedBox(height: CvSpace.md),
        const LinearProgressIndicator(),
      ]);
    } else if (found == null) {
      children.addAll([
        Text('Find junk on this computer', style: theme.titleMedium),
        const SizedBox(height: CvSpace.xs),
        const Text(
          'Checks known locations in your user account. Nothing is selected or removed until you confirm.',
          style: TextStyle(color: CvColors.muted),
        ),
        const SizedBox(height: CvSpace.md),
        FilledButton(onPressed: model.scan, child: const Text('Find junk')),
      ]);
    } else if (found.isEmpty) {
      children.addAll([
        Text('Nothing to clean', style: theme.headlineSmall),
        const SizedBox(height: CvSpace.xs),
        const Text(
          'No junk was found in the known locations.',
          style: TextStyle(color: CvColors.muted),
        ),
        const SizedBox(height: CvSpace.md),
        TextButton(onPressed: model.scan, child: const Text('Check again')),
      ]);
    } else {
      final safe = model.safe;
      final safeBytes = safe.fold<int>(0, (s, j) => s + j.bytes);
      children.addAll([
        Text(
          formatBytes(model.totalBytes),
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
        ),
        Text(
          'found in ${plural(found.length, 'location')}. '
          '${formatBytes(safeBytes)} of it is labelled Safe and rebuilds by itself.',
          style: const TextStyle(color: CvColors.muted),
        ),
        const SizedBox(height: CvSpace.lg),
        Wrap(
          spacing: CvSpace.sm,
          runSpacing: CvSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              onPressed: safe.isEmpty || model.busy ? null : onCleanSafe,
              child: const Text('Clean safe junk…'),
            ),
            TextButton(
              onPressed: onToggleReview,
              child: Text(reviewing ? 'Hide details' : 'Review all'),
            ),
            TextButton(
              onPressed: model.busy ? null : model.scan,
              child: const Text('Check again'),
            ),
          ],
        ),
        const SizedBox(height: CvSpace.sm),
        const Text(
          'Nothing is selected. You see every item before anything is removed.',
          style: TextStyle(color: CvColors.muted, fontSize: 12),
        ),
      ]);
    }
    if (model.error != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: CvSpace.md),
          child: Callout(model.error!, tone: CalloutTone.caution),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: CvSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.model,
    required this.group,
    required this.expanded,
    required this.onToggle,
  });
  final CleanupViewModel model;
  final JunkGroup group;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final items = model.inGroup(group);
    final bytes = items.fold<int>(0, (s, j) => s + j.bytes);
    final allSelected = items.every(model.isSelected);
    final someSelected = items.any(model.isSelected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        rowDivider,
        Semantics(
          button: true,
          expanded: expanded,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: CvSpace.sm),
              child: Row(
                children: [
                  Checkbox(
                    tristate: true,
                    value: allSelected ? true : (someSelected ? null : false),
                    onChanged: model.busy
                        ? null
                        : (_) => model.selectGroup(group, !allSelected),
                    semanticLabel: 'Select all ${group.title}',
                  ),
                  const SizedBox(width: CvSpace.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${group.title} · ${plural(items.length, 'location')}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          group.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: CvColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: CvSpace.sm),
                  SizeText(formatBytes(bytes)),
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
}

class _JunkRow extends StatelessWidget {
  const _JunkRow({required this.model, required this.junk, this.settings});
  final CleanupViewModel model;
  final MeasuredJunk junk;
  final AppSettings? settings;

  @override
  Widget build(BuildContext context) {
    final target = junk.target;
    final selected = model.isSelected(junk);
    return InkWell(
      onTap: model.busy ? null : () => model.toggle(junk, !selected),
      child: Padding(
        padding: const EdgeInsets.only(left: CvSpace.xl, top: 4, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selected,
              onChanged: model.busy
                  ? null
                  : (value) => model.toggle(junk, value ?? false),
              semanticLabel: 'Select ${target.label}',
            ),
            const SizedBox(width: CvSpace.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: CvSpace.sm,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          target.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        RiskChip(target.risk),
                      ],
                    ),
                    Text(
                      target.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CvColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    PathLine(target.path),
                  ],
                ),
              ),
            ),
            const SizedBox(width: CvSpace.sm),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SizeText(formatBytes(junk.bytes)),
            ),
            if (settings != null)
              IconButton(
                tooltip: 'Ignore ${target.label}',
                icon: const Icon(Icons.visibility_off_outlined, size: 18),
                onPressed: model.busy
                    ? null
                    : () async {
                        await settings!.ignorePath(target.path);
                        model.hide(junk);
                      },
              ),
          ],
        ),
      ),
    );
  }
}
