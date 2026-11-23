// PageScroll arguments follow reading order: header content, then lists.
// ignore_for_file: sort_child_properties_last
// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/list_toolbar.dart';
import 'package:cleanverse/src/app/app_icon.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/data/removal.dart';
import 'package:cleanverse/src/features/cleanup/cleanup_page.dart'
    show RiskChip;
import 'package:cleanverse/src/features/cleanup/removal_dialog.dart';
import 'package:cleanverse/src/features/uninstall/app_catalog.dart';
import 'package:cleanverse/src/features/uninstall/uninstall_view_model.dart';

/// Removes an app together with the caches, preferences and data it left in
/// the user's Library. macOS only. Everything goes to the Trash.
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
  late final TextEditingController _search = TextEditingController(
    text: model.query,
  );

  @override
  void initState() {
    super.initState();
    if (widget.supported && model.apps == null) model.loadApps();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The primary action. With nothing ticked it offers every removable
  /// item; the user still reviews the list in the confirmation and can
  /// cancel, untick items on the page and try again.
  Future<void> _uninstall() async {
    final app = model.selectedApp!;
    if (model.selected.isEmpty) model.selectAll(true);
    final selected = model.selected;
    if (selected.isEmpty) return;
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
      return const PageScroll(
        children: [
          PageHeader(
            title: 'Apps',
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
      builder: (context, _) => model.selectedApp == null
          ? _list(context)
          : _detail(context, model.selectedApp!),
    );
  }

  Widget _list(BuildContext context) {
    final loading = model.loadingApps || model.apps == null;
    final apps = model.visibleApps;
    return PageScroll(
      key: const ValueKey('apps-list'),
      children: [
        const PageHeader(
          title: 'Apps',
          subtitle: 'Remove an app with its caches, preferences and data. Everything goes to the Trash.',
        ),
        if (loading)
          const LinearProgressIndicator()
        else ...[
          ListToolbar<AppSort>(
            hint: 'Search apps by name or ID',
            initialQuery: model.query,
            onQuery: model.setQuery,
            sort: model.sort,
            sortOptions: const [
              SortOption(AppSort.name, 'Name A to Z'),
              SortOption(AppSort.size, 'Largest first'),
            ],
            onSort: model.setSort,
          ),
          const SizedBox(height: CvSpace.sm),
          Text(
            '${plural(apps.length, 'app')}${model.measuringSizes ? ' · measuring sizes…' : ''}. '
            'Apple apps are not listed.',
            style: const TextStyle(color: CvColors.muted, fontSize: 12),
          ),
          const SizedBox(height: CvSpace.sm),
          if (apps.isEmpty && model.query.isNotEmpty)
            NoMatches(query: model.query, onClear: () => model.setQuery(''))
          else if (apps.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: CvSpace.md),
              child: Text('No apps found.'),
            ),
        ],
      ],
      slivers: [
        if (!loading)
          SliverList.builder(
            itemCount: apps.length,
            itemBuilder: (context, i) => _AppRow(
              app: apps[i],
              bytes: model.appSizes[apps[i].path],
              onTap: () => model.open(apps[i]),
            ),
          ),
      ],
    );
  }

  Widget _detail(BuildContext context, InstalledApp app) {
    final items = model.removable;
    final total = items.fold<int>(0, (s, l) => s + l.bytes);
    final outcomes = model.lastOutcomes;
    final count = model.selected.length;
    final loading = model.loadingLeftovers;
    final canAct =
        !loading && items.isNotEmpty && !model.busy && model.running != true;
    return PageScroll(
      key: ValueKey('app-${app.path}'),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: model.busy ? null : model.close,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('All apps'),
          ),
        ),
        const SizedBox(height: CvSpace.sm),
        Row(
          children: [
            AppIcon(app.path, size: 56),
            const SizedBox(width: CvSpace.md),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  app.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
          ],
        ),
        PathLine(app.path),
        const SizedBox(height: CvSpace.lg),
        if (loading) ...[
          const Text('Looking for files this app left behind…'),
          const SizedBox(height: CvSpace.sm),
          const LinearProgressIndicator(),
        ] else ...[
          Text(
            formatBytes(total),
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
          ),
          Text(
            'in ${plural(items.length, 'item')}: the app and the files it keeps in your Library.',
            style: const TextStyle(color: CvColors.muted),
          ),
          const SizedBox(height: CvSpace.md),
        ],
        if (model.running == true)
          Callout(
            '${app.name} is running. Quit it before uninstalling.',
            tone: CalloutTone.caution,
          ),
        if (model.running == null && !loading)
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
        if (!loading && items.isNotEmpty)
          SectionTitle(
            'What will be moved',
            detail:
                'Matched by bundle id ${app.bundleId}. Nothing is ticked until you choose; '
                'untick anything you want to keep.',
          ),
      ],
      slivers: [
        if (!loading) ...[
          SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => _LeftoverRow(
              leftover: items[i],
              selected: model.isSelected(items[i]),
              onChanged: model.busy ? null : (v) => model.toggle(items[i], v),
            ),
          ),
          if (model.systemWide.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: SectionTitle(
                'System-wide items',
                detail: 'Installed for all users. CLEANVerse does not remove these; use the app\'s own uninstaller.',
              ),
            ),
            SliverList.builder(
              itemCount: model.systemWide.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: PathLine(model.systemWide[i].path),
              ),
            ),
          ],
        ],
      ],
      bottomBar: loading
          ? null
          : SelectionBar(
              status: count == 0
                  ? 'Nothing selected'
                  : '${plural(count, 'item')} selected · ${formatBytes(model.selectedBytes)}',
              action: FilledButton(
                onPressed: canAct ? _uninstall : null,
                child: Text(
                  count == 0
                      ? 'Move app and its files to Trash…'
                      : 'Move ${plural(count, 'item')} to Trash…',
                ),
              ),
            ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.bytes, required this.onTap});
  final InstalledApp app;
  final int? bytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              AppIcon(app.path, size: 32),
              const SizedBox(width: CvSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${app.bundleId}${app.version != null ? ' · ${app.version}' : ''}',
                      maxLines: 1,
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
              SizeText(
                bytes == null ? 'Measuring…' : formatBytes(bytes!),
                muted: bytes == null,
              ),
              const Icon(Icons.chevron_right_rounded, color: CvColors.muted),
            ],
          ),
        ),
      ),
      rowDivider,
    ],
  );
}

class _LeftoverRow extends StatelessWidget {
  const _LeftoverRow({
    required this.leftover,
    required this.selected,
    required this.onChanged,
  });
  final Leftover leftover;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l = leftover;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selected,
              onChanged: onChanged == null
                  ? null
                  : (v) => onChanged!(v ?? false),
              semanticLabel: 'Select ${l.kind.label} ${l.path}',
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
                          l.kind.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        RiskChip(l.risk),
                        if (l.byName)
                          const Text(
                            'Matched by name',
                            style: TextStyle(
                              color: CvColors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      l.kind.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CvColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    PathLine(l.path),
                  ],
                ),
              ),
            ),
            const SizedBox(width: CvSpace.sm),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SizeText(formatBytes(l.bytes)),
            ),
          ],
        ),
      ),
    );
  }
}
