import 'dart:io';

// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cleanverse/src/features/cleanup/cleanup_view_model.dart';
import 'package:cleanverse/src/features/example/demo_scan.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/data/protection.dart';
import 'package:cleanverse/src/features/cleanup/cleanup_page.dart';
import 'package:cleanverse/src/data/scan_history.dart';
import 'package:cleanverse/src/features/uninstall/uninstall_page.dart';
import 'package:cleanverse/src/features/storage/storage_page.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/data/volumes.dart';
import 'package:cleanverse/src/app/list_toolbar.dart';
import 'package:cleanverse/src/features/uninstall/uninstall_view_model.dart';
import 'package:cleanverse/src/features/cleanup/full_disk_access_banner.dart';
import 'package:cleanverse/src/features/developer/developer_page.dart';
import 'package:cleanverse/src/features/scan/duplicates_page.dart';
import 'package:cleanverse/src/features/example/example_page.dart';
import 'package:cleanverse/src/features/scan/large_files_page.dart';
import 'package:cleanverse/src/features/home/home_page.dart';
import 'package:cleanverse/src/features/settings/settings_page.dart';
import 'package:cleanverse/src/features/scan/space_lens_page.dart';
import 'package:cleanverse/src/features/settings/app_settings.dart';
import 'package:cleanverse/src/features/update/update_view_model.dart';
import 'package:cleanverse/src/app/theme.dart';

/// Workspace areas. One scan feeds every review area, similar to the
/// scan → summary → review flow used by mainstream storage tools.
enum Section {
  home('Home', Icons.home_outlined),
  cleanup('Clean up', Icons.cleaning_services_outlined),
  storage('Storage', Icons.pie_chart_outline_rounded),
  apps('Apps', Icons.apps_rounded),
  developer('Developer', Icons.code_rounded),
  settings('Settings', Icons.settings_outlined),

  // Not in the menu: opened from other pages (old routes, kept until the
  // redesign tracks remove them).
  spaceLens('Folders', Icons.donut_large_rounded),
  largeFiles('Biggest files', Icons.inventory_outlined),
  duplicates('Duplicates', Icons.file_copy_outlined),
  example('Sample data', Icons.science_outlined);

  const Section(this.label, this.icon);
  final String label;
  final IconData icon;
}

class CleanVerseApp extends StatelessWidget {
  const CleanVerseApp({
    super.key,
    required this.repository,
    this.scanner,
    this.pickFolder,
    this.cleanup,
    this.homeFolder,
    this.volumes,
    this.uninstall,
  });
  final ScanRepository repository;
  final FolderScanner? scanner;
  final Future<String?> Function()? pickFolder;
  final CleanupViewModel? cleanup;

  /// Default scan scope for Home; the user's home folder when null.
  final String? Function()? homeFolder;

  /// Drive list for the dashboard (tests inject a fake).
  final VolumesModel? volumes;

  /// App list for the uninstaller and dashboard (tests inject a fake).
  final UninstallViewModel? uninstall;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CLEANVerse',
    debugShowCheckedModeBanner: false,
    theme: buildCleanVerseTheme(),
    home: HomeScreen(
      repository: repository,
      scanner: scanner,
      pickFolder: pickFolder,
      cleanup: cleanup,
      homeFolder: homeFolder,
      volumes: volumes,
      uninstall: uninstall,
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    this.scanner,
    this.pickFolder,
    this.cleanup,
    this.homeFolder,
    this.volumes,
    this.uninstall,
  });
  final ScanRepository repository;
  final FolderScanner? scanner;
  final Future<String?> Function()? pickFolder;
  final CleanupViewModel? cleanup;
  final String? Function()? homeFolder;

  /// Drive list for the dashboard (tests inject a fake).
  final VolumesModel? volumes;

  /// App list for the uninstaller and dashboard (tests inject a fake).
  final UninstallViewModel? uninstall;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ScanViewModel example = ScanViewModel(widget.repository);
  late final FolderScanViewModel scan = FolderScanViewModel(
    widget.scanner ?? LocalFolderScanner(),
    widget.pickFolder ?? chooseFolder,
    homeFolder: widget.homeFolder,
  );
  late final CleanupViewModel cleanup = widget.cleanup ?? CleanupViewModel();
  late final UninstallViewModel uninstall =
      widget.uninstall ?? UninstallViewModel();
  late final VolumesModel volumes = widget.volumes ?? VolumesModel();
  final AppSettings settings = AppSettings();
  late final UpdateViewModel updates = UpdateViewModel(settings: settings);
  final ValueNotifier<ScanComparison?> growth = ValueNotifier(null);

  Future<void> _recordScan(String root, FolderScanResult result) async {
    growth.value = null;
    if (!settings.keepScanHistory) return;
    try {
      final store = await settings.scanHistory();
      growth.value = await store.record(ScanSnapshot.fromResult(root, result));
    } catch (_) {
      // No app data folder: history is unavailable.
    }
  }

  @override
  void initState() {
    super.initState();
    activeIgnoreList = settings.ignoreList;
    scan.onScanCompleted = _recordScan;
    volumes.load();
    settings.load().then((_) async {
      try {
        activeOperationLog = await settings.operationLog();
      } catch (_) {
        // No app data folder (for example in tests): history is disabled.
      }
      await updates.checkIfDue();
    });
  }

  Section section = Section.home;
  void _go(Section value) {
    if (value == section) return;
    setState(() => section = value);
  }

  @override
  void dispose() {
    example.dispose();
    scan.dispose();
    if (widget.cleanup == null) cleanup.dispose();
    updates.dispose();
    settings.dispose();
    growth.dispose();
    if (widget.uninstall == null) uninstall.dispose();
    if (widget.volumes == null) volumes.dispose();
    super.dispose();
  }

  Widget _page() => switch (section) {
    Section.home => HomePage(
      model: scan,
      cleanup: cleanup,
      uninstall: uninstall,
      onNavigate: _go,
      growth: growth,
      historyEnabled: settings.keepScanHistory,
      appsSupported: Platform.isMacOS,
      volumes: volumes,
    ),
    Section.cleanup => CleanupPage(
      model: cleanup,
      onNavigate: _go,
      settings: settings,
      fullDiskAccess: Platform.isMacOS ? const FullDiskAccessBanner() : null,
    ),
    Section.apps => UninstallPage(
      model: uninstall,
      supported: Platform.isMacOS,
    ),
    Section.storage ||
    Section.largeFiles ||
    Section.spaceLens ||
    Section.duplicates => StoragePage(
      initialTab: switch (section) {
        Section.spaceLens => 1,
        Section.duplicates => 2,
        _ => 0,
      },
      files: LargeFilesPage(model: scan, onNavigate: _go, settings: settings),
      folders: SpaceLensPage(model: scan, onNavigate: _go, growth: growth),
      duplicates: DuplicatesPage(model: scan, onNavigate: _go),
    ),
    Section.developer => DeveloperPage(model: scan, onNavigate: _go),
    Section.example => ExamplePage(model: example),
    Section.settings => SettingsPage(
      settings: settings,
      updates: updates,
      onTrySample: () => _go(Section.example),
    ),
  };

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      // Cmd+F on macOS, Ctrl+F elsewhere: jump to the page's search box.
      SingleActivator(
        LogicalKeyboardKey.keyF,
        meta: Platform.isMacOS,
        control: !Platform.isMacOS,
      ): () =>
          SearchFocus.focusActive(),
    },
    child: Focus(autofocus: true, child: _scaffold(context)),
  );

  Widget _scaffold(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return ListenableBuilder(
            listenable: scan,
            builder: (context, _) => Row(
              children: [
                if (wide) _Sidebar(selected: section, onSelected: _go),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(wide: wide, section: section, model: scan),
                      _UpdateBanner(
                        updates: updates,
                        onOpen: () => _go(Section.settings),
                        visible: section != Section.settings,
                      ),
                      if (!wide)
                        _CompactNav(selected: section, onSelected: _go),
                      Expanded(
                        child: KeyedSubtree(
                          key: ValueKey(section),
                          child: _page(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand({this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'CLEANVerse by PRAPAWITY',
    child: ExcludeSemantics(
      child: Row(
        children: [
          Image.asset(
            'assets/brand/cleanverse-brush-proposal.png',
            width: compact ? 32 : 40,
            height: compact ? 32 : 40,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'CLEAN',
                        style: TextStyle(
                          color: CvColors.cyan,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: 'Verse',
                        style: TextStyle(
                          color: CvColors.violet,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 18, letterSpacing: -.5),
                ),
                if (!compact)
                  Text(
                    'by PRAPAWITY',
                    style: TextStyle(
                      color: CvColors.muted.withValues(alpha: .9),
                      fontSize: 10,
                      letterSpacing: .2,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Menu items. Apps is macOS only; Settings sits at the bottom.
List<(String?, List<Section>)> get _navGroups => [
  (
    null,
    [
      Section.home,
      Section.cleanup,
      Section.storage,
      if (Platform.isMacOS) Section.apps,
    ],
  ),
  ('Pro tools', [Section.developer]),
];

List<Section> get _navSections => [
  for (final (_, items) in _navGroups) ...items,
  Section.settings,
];

/// Menu item that represents [section] (hidden routes map to Storage).
Section _navOwner(Section section) => switch (section) {
  Section.largeFiles ||
  Section.spaceLens ||
  Section.duplicates => Section.storage,
  Section.example => Section.settings,
  _ => section,
};

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelected});
  final Section selected;
  final ValueChanged<Section> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    width: 220,
    decoration: const BoxDecoration(
      color: CvColors.sidebar,
      border: Border(right: BorderSide(color: CvColors.outlineSoft)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 22, 16, 22),
                  child: _Brand(),
                ),
                for (final (title, items) in _navGroups) ...[
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 6),
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: CvColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: .4,
                          ),
                        ),
                      ),
                    ),
                  for (final item in items)
                    _NavItem(
                      section: item,
                      selected: item == _navOwner(selected),
                      onPressed: () => onSelected(item),
                    ),
                ],
                const Spacer(),
                _NavItem(
                  section: Section.settings,
                  selected: _navOwner(selected) == Section.settings,
                  onPressed: () => onSelected(Section.settings),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.selected,
    required this.onPressed,
  });
  final Section section;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
    child: Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? CvColors.raised : Colors.transparent,
        borderRadius: BorderRadius.circular(CvRadius.sm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(CvRadius.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    section.icon,
                    size: 18,
                    color: selected ? CvColors.cyan : CvColors.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      section.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? CvColors.text : CvColors.muted,
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Narrow-window navigation: one scrollable row of plain tabs.
class _CompactNav extends StatelessWidget {
  const _CompactNav({required this.selected, required this.onSelected});
  final Section selected;
  final ValueChanged<Section> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: CvColors.outlineSoft)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (final item in _navSections)
            _CompactTab(
              section: item,
              selected: item == _navOwner(selected),
              onPressed: () => onSelected(item),
            ),
        ],
      ),
    ),
  );
}

class _CompactTab extends StatelessWidget {
  const _CompactTab({
    required this.section,
    required this.selected,
    required this.onPressed,
  });
  final Section section;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: onPressed,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: selected ? CvColors.cyan : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          section.label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? CvColors.text : CvColors.muted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

/// Current page title and, once chosen, the scan scope.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.wide,
    required this.section,
    required this.model,
  });
  final bool wide;
  final Section section;
  final FolderScanViewModel model;

  @override
  Widget build(BuildContext context) {
    final root = model.root;
    final home = model.homeFolder();
    final scope = root == null
        ? null
        : home != null && root == home
        ? 'Home folder'
        : root;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CvColors.outlineSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (wide)
                  Text(
                    _navOwner(section).label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  const Flexible(child: _Brand(compact: true)),
                if (scope != null) ...[
                  const SizedBox(width: CvSpace.md),
                  const ExcludeSemantics(
                    child: Text('·', style: TextStyle(color: CvColors.muted)),
                  ),
                  const SizedBox(width: CvSpace.md),
                  Flexible(
                    child: OneLinePath(
                      scope,
                      prefix: wide ? 'Scope: ' : '',
                      style: const TextStyle(
                        color: CvColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: CvSpace.md),
          Tooltip(
            message: 'Scans and results stay on this device.',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: CvColors.mint,
                  semanticLabel: 'On this device',
                ),
                if (wide) ...[
                  const SizedBox(width: 6),
                  const ExcludeSemantics(
                    child: Text(
                      'On this device',
                      style: TextStyle(color: CvColors.muted, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({
    required this.updates,
    required this.onOpen,
    required this.visible,
  });
  final UpdateViewModel updates;
  final VoidCallback onOpen;
  final bool visible;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updates,
    builder: (context, _) {
      final manifest = updates.available;
      if (!visible || manifest == null) return const SizedBox.shrink();
      return Material(
        color: CvColors.cyan.withValues(alpha: .1),
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.system_update_alt_rounded,
                  size: 18,
                  color: CvColors.cyan,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'CLEANVerse ${manifest.version} is available.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const Text(
                  'View',
                  style: TextStyle(
                    color: CvColors.cyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
