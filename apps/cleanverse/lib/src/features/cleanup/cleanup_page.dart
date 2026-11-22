// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/features/cleanup/cleanup_view_model.dart';
import 'package:cleanverse/src/features/settings/app_settings.dart';
import 'package:cleanverse/src/features/cleanup/junk_catalog.dart';
import 'package:cleanverse/src/features/cleanup/removal_dialog.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';

IconData _groupIcon(JunkGroup group) => switch (group) {
  JunkGroup.system => Icons.computer_rounded,
  JunkGroup.browser => Icons.public_rounded,
  JunkGroup.developer => Icons.code_rounded,
};

/// One-click junk check across known cache locations, then a reviewed clean.
class CleanupPage extends StatelessWidget {
  const CleanupPage({
    super.key,
    required this.model,
    required this.onNavigate,
    this.settings,
  });
  final CleanupViewModel model;
  final ValueChanged<Section> onNavigate;
  final AppSettings? settings;

  Future<void> _clean(BuildContext context) async {
    final selected = model.selected;
    final apps = {
      for (final junk in selected)
        if (junk.target.closeApp != null) junk.target.closeApp!,
    };
    await runRemovalFlow(
      context,
      title: 'Clean selected junk',
      items: [for (final junk in selected) junk.item],
      warnings: [
        if (apps.isNotEmpty)
          'Close ${apps.join(', ')} first. Caches in use are skipped.',
      ],
      execute: (override) => model.clean(override: override),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final found = model.found;
      final total = (found ?? const []).fold<int>(0, (s, j) => s + j.bytes);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Clean up',
            subtitle: 'Find temporary files, browser caches and developer caches that are safe to rebuild.',
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (model.scanning) ...[
                  Text(
                    'Checking junk locations…',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: CvSpace.md),
                  const LinearProgressIndicator(),
                ] else if (model.cleaning) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'Cleaning: ${model.progressDone} of ${model.progressTotal} done',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: CvSpace.md),
                  LinearProgressIndicator(
                    value: model.progressTotal == 0
                        ? null
                        : model.progressDone / model.progressTotal,
                  ),
                ] else if (found == null) ...[
                  Text(
                    'Find junk on this computer',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: CvSpace.sm),
                  const Text(
                    'Checks known locations in your user account only. No administrator '
                    'rights, nothing is selected or removed until you confirm.',
                    style: TextStyle(color: CvColors.muted),
                  ),
                  const SizedBox(height: CvSpace.xl),
                  FilledButton.icon(
                    onPressed: model.scan,
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text('Find junk'),
                  ),
                ] else ...[
                  Wrap(
                    spacing: CvSpace.lg,
                    runSpacing: CvSpace.md,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatBytes(total),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'found in ${plural(found.length, 'location')}',
                            style: const TextStyle(color: CvColors.muted),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: model.scan,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Check again'),
                      ),
                    ],
                  ),
                ],
                if (model.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: CvSpace.md),
                    child: Callout(model.error!, tone: CalloutTone.caution),
                  ),
              ],
            ),
          ),
          if (found != null && !model.scanning) ...[
            for (final group in JunkGroup.values)
              if (model.inGroup(group).isNotEmpty)
                _GroupSection(model: model, group: group, settings: settings),
            if (found.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: CvSpace.lg),
                child: EmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Nothing to clean',
                  message: 'No junk was found in the known locations.',
                ),
              ),
            const SizedBox(height: CvSpace.lg),
            const Callout(
              'Project folders such as node_modules and build output are in Developer. '
              'Large and duplicate files are in their own review areas.',
            ),
            _ActionBar(model: model, onClean: () => _clean(context)),
          ],
        ],
      );
    },
  );
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.model,
    required this.group,
    this.settings,
  });
  final AppSettings? settings;
  final CleanupViewModel model;
  final JunkGroup group;

  @override
  Widget build(BuildContext context) {
    final items = model.inGroup(group);
    final bytes = items.fold<int>(0, (s, j) => s + j.bytes);
    final allSelected = items.every(model.isSelected);
    final someSelected = items.any(model.isSelected);
    return Padding(
      padding: const EdgeInsets.only(top: CvSpace.lg),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: Checkbox(
              tristate: true,
              value: allSelected ? true : (someSelected ? null : false),
              onChanged: model.busy
                  ? null
                  : (_) => model.selectGroup(group, !allSelected),
              semanticLabel: 'Select all ${group.title}',
            ),
            title: Row(
              children: [
                Icon(_groupIcon(group), size: 20, color: CvColors.violet),
                const SizedBox(width: CvSpace.sm),
                Expanded(
                  child: Text(
                    group.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  formatBytes(bytes),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            subtitle: Text(
              group.description,
              style: const TextStyle(color: CvColors.muted, fontSize: 12),
            ),
            children: [
              for (final junk in items)
                CheckboxListTile(
                  value: model.isSelected(junk),
                  onChanged: model.busy
                      ? null
                      : (value) => model.toggle(junk, value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.only(left: 8),
                  title: Text(junk.target.label),
                  subtitle: Text(
                    '${junk.target.note}\n${junk.target.path}',
                    style: const TextStyle(color: CvColors.muted, fontSize: 12),
                  ),
                  isThreeLine: true,
                  secondary: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatBytes(junk.bytes),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (settings != null)
                        IconButton(
                          tooltip: 'Ignore ${junk.target.label}',
                          icon: const Icon(Icons.visibility_off_outlined),
                          onPressed: model.busy
                              ? null
                              : () async {
                                  await settings!.ignorePath(junk.target.path);
                                  model.hide(junk);
                                },
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.model, required this.onClean});
  final CleanupViewModel model;
  final VoidCallback onClean;

  @override
  Widget build(BuildContext context) {
    final count = model.selected.length;
    return Container(
      margin: const EdgeInsets.only(top: CvSpace.sm),
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
                ? 'Select what to clean'
                : '${plural(count, 'location')} selected · ${formatBytes(model.selectedBytes)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          FilledButton.icon(
            onPressed: count == 0 || model.busy ? null : onClean,
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('Review and clean'),
          ),
        ],
      ),
    );
  }
}
