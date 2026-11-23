// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/data/removal.dart';
import 'package:cleanverse/src/features/cleanup/cleanup_page.dart'
    show RiskChip;
import 'package:cleanverse/src/features/cleanup/removal_dialog.dart';
import 'package:cleanverse/src/features/uninstall/app_catalog.dart';
import 'package:cleanverse/src/features/uninstall/uninstall_view_model.dart';

/// Removes an app together with the caches, preferences and data it left in
/// the user's Library. macOS only.
class UninstallPage extends StatefulWidget {
  const UninstallPage({
    super.key,
    required this.model,
    required this.supported,
  });
  final UninstallViewModel model;
  final bool supported;

  @override
  State<UninstallPage> createState() => _UninstallPageState();
}

class _UninstallPageState extends State<UninstallPage> {
  UninstallViewModel get model => widget.model;

  @override
  void initState() {
    super.initState();
    if (widget.supported && model.apps == null) model.loadApps();
  }

  Future<void> _uninstall() async {
    final app = model.selectedApp!;
    final selected = model.selected;
    final risky = [
      for (final l in selected)
        if (l.kind == LeftoverKind.support || l.kind == LeftoverKind.container)
          l,
    ];
    final byName = selected.where((l) => l.byName).length;
    await runRemovalFlow(
      context,
      title: 'Uninstall ${app.name}',
      allowModeChoice: false,
      items: [
        for (final l in selected) l.toItem('${app.name} · ${l.kind.label}'),
      ],
      warnings: [
        'Quit ${app.name} first. CLEANVerse checks again and stops if it is still running.',
        if (risky.isNotEmpty)
          '${plural(risky.length, 'data folder')} may contain your documents or accounts. '
              'Keep them in the Trash until you are sure.',
        if (byName > 0)
          '${plural(byName, 'item')} matched by name only. Check they belong to ${app.name}.',
      ],
      execute: (override) => model.remove(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.supported) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Uninstaller',
            subtitle: 'Remove an app together with the files it leaves behind.',
          ),
          EmptyState(
            icon: Icons.desktop_mac_outlined,
            title: 'Available on macOS',
            message: 'On Windows, use Settings → Apps → Installed apps. On Linux, use your package manager.',
          ),
        ],
      );
    }
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Uninstaller',
            subtitle:
                'Remove an app together with its caches, preferences and data in your Library. '
                'Everything goes to the Trash.',
          ),
          if (model.selectedApp == null)
            _AppList(model: model)
          else
            _Detail(model: model, onUninstall: _uninstall),
        ],
      ),
    );
  }
}

class _AppList extends StatelessWidget {
  const _AppList({required this.model});
  final UninstallViewModel model;

  @override
  Widget build(BuildContext context) {
    if (model.loadingApps || model.apps == null) {
      return const Panel(child: LinearProgressIndicator());
    }
    final apps = model.visibleApps;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search apps',
            ),
            onChanged: model.setQuery,
          ),
          const SizedBox(height: CvSpace.sm),
          Text(
            '${plural(apps.length, 'app')} in Applications. Apple apps are not listed.',
            style: const TextStyle(color: CvColors.muted, fontSize: 12),
          ),
          const SizedBox(height: CvSpace.sm),
          if (apps.isEmpty)
            const Text('No apps match.')
          else
            for (final app in apps)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.apps_rounded,
                    color: CvColors.violet,
                  ),
                  title: Text(app.name),
                  subtitle: Text(
                    '${app.bundleId}${app.version != null ? ' · ${app.version}' : ''}',
                    style: const TextStyle(color: CvColors.muted, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => model.open(app),
                ),
              ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.model, required this.onUninstall});
  final UninstallViewModel model;
  final VoidCallback onUninstall;

  @override
  Widget build(BuildContext context) {
    final app = model.selectedApp!;
    final items = model.removable;
    final total = items.fold<int>(0, (s, l) => s + l.bytes);
    final allSelected = items.isNotEmpty && items.every(model.isSelected);
    final outcomes = model.lastOutcomes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back to apps',
                    onPressed: model.busy ? null : model.close,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: CvSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          app.path,
                          style: const TextStyle(
                            color: CvColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!model.loadingLeftovers)
                    Text(
                      formatBytes(total),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              if (model.running == true)
                Callout(
                  '${app.name} is running. Quit it before uninstalling.',
                  tone: CalloutTone.caution,
                ),
              if (model.running == null && !model.loadingLeftovers)
                const Callout(
                  'Could not check whether the app is running. Quit it before uninstalling.',
                  tone: CalloutTone.caution,
                ),
              if (outcomes != null && outcomes.isEmpty && model.running == true)
                const Callout(
                  'Nothing was removed because the app is still running.',
                ),
              if (outcomes != null && outcomes.isNotEmpty)
                Semantics(
                  liveRegion: true,
                  child: Callout(
                    '${outcomes.where((o) => o.status == RemovalStatus.movedToTrash).length} of '
                    '${outcomes.length} moved to the Trash. Anything left is listed below.',
                  ),
                ),
            ],
          ),
        ),
        if (model.loadingLeftovers)
          const Padding(
            padding: EdgeInsets.only(top: CvSpace.lg),
            child: Panel(child: LinearProgressIndicator()),
          )
        else ...[
          SectionTitle(
            'Found ${plural(items.length, 'item')}',
            detail:
                'Matched by bundle id ${app.bundleId}. Nothing is selected until you choose.',
          ),
          Panel(
            padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (items.isNotEmpty)
                  Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      value: allSelected,
                      onChanged: model.busy
                          ? null
                          : (v) => model.selectAll(v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Select everything',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                for (final l in items)
                  Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      value: model.isSelected(l),
                      onChanged: model.busy
                          ? null
                          : (v) => model.toggle(l, v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Wrap(
                        spacing: CvSpace.sm,
                        runSpacing: CvSpace.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(l.kind.label),
                          RiskChip(l.risk),
                          if (l.byName)
                            const StatusChip(
                              'Matched by name',
                              color: CvColors.amber,
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${l.kind.description}\n${l.path}',
                        style: const TextStyle(
                          color: CvColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      isThreeLine: true,
                      secondary: Text(
                        formatBytes(l.bytes),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (model.systemWide.isNotEmpty) ...[
            const SectionTitle(
              'System-wide items',
              detail: 'Installed for all users. CLEANVerse does not remove these; use the app\'s own uninstaller.',
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in model.systemWide)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(l.path, style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: CvSpace.lg),
          Container(
            padding: const EdgeInsets.all(CvSpace.lg),
            decoration: BoxDecoration(
              color: CvColors.raised,
              borderRadius: BorderRadius.circular(CvRadius.md),
              border: Border.all(color: CvColors.outline),
            ),
            child: Wrap(
              spacing: CvSpace.lg,
              runSpacing: CvSpace.sm,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  model.selected.isEmpty
                      ? 'Select what to remove'
                      : '${plural(model.selected.length, 'item')} selected · ${formatBytes(model.selectedBytes)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                FilledButton.icon(
                  onPressed:
                      model.selected.isEmpty ||
                          model.busy ||
                          model.running == true
                      ? null
                      : onUninstall,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Review and move to Trash'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
