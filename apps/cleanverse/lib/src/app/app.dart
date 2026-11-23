import 'dart:io';

// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/features/cleanup/cleanup_view_model.dart';
import 'package:cleanverse/src/features/example/demo_scan.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/data/protection.dart';
import 'package:cleanverse/src/features/cleanup/cleanup_page.dart';
import 'package:cleanverse/src/data/scan_history.dart';
import 'package:cleanverse/src/features/cleanup/full_disk_access_banner.dart';
import 'package:cleanverse/src/features/developer/developer_page.dart';
import 'package:cleanverse/src/features/scan/duplicates_page.dart';
import 'package:cleanverse/src/features/example/example_page.dart';
import 'package:cleanverse/src/features/scan/large_files_page.dart';
import 'package:cleanverse/src/features/scan/smart_scan_page.dart';
import 'package:cleanverse/src/features/settings/settings_page.dart';
import 'package:cleanverse/src/features/scan/space_lens_page.dart';
import 'package:cleanverse/src/features/settings/app_settings.dart';
import 'package:cleanverse/src/features/update/update_view_model.dart';
import 'package:cleanverse/src/app/theme.dart';

/// Workspace areas. One scan feeds every review area, similar to the
/// scan → summary → review flow used by mainstream storage tools.
enum Section {
  smartScan('Smart Scan', Icons.radar_rounded),
  cleanup('Clean up', Icons.cleaning_services_outlined),
  spaceLens('Space Lens', Icons.donut_large_rounded),
  largeFiles('Large & old files', Icons.inventory_outlined),
  duplicates('Duplicates', Icons.file_copy_outlined),
  developer('Developer', Icons.code_rounded),
  example('Example scan', Icons.science_outlined),
  settings('Settings', Icons.settings_outlined);

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
  });
  final ScanRepository repository;
  final FolderScanner? scanner;
  final Future<String?> Function()? pickFolder;
  final CleanupViewModel? cleanup;

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
  });
  final ScanRepository repository;
  final FolderScanner? scanner;
  final Future<String?> Function()? pickFolder;
  final CleanupViewModel? cleanup;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ScanViewModel example = ScanViewModel(widget.repository);
  late final FolderScanViewModel scan = FolderScanViewModel(
    widget.scanner ?? LocalFolderScanner(),
    widget.pickFolder ?? chooseFolder,
  );
  late final CleanupViewModel cleanup = widget.cleanup ?? CleanupViewModel();
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
    settings.load().then((_) async {
      try {
        activeOperationLog = await settings.operationLog();
      } catch (_) {
        // No app data folder (for example in tests): history is disabled.
      }
      await updates.checkIfDue();
    });
  }

  Section section = Section.smartScan;
  final _scrollController = ScrollController();

  void _go(Section value) {
    if (value == section) return;
    setState(() => section = value);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  void dispose() {
    example.dispose();
    scan.dispose();
    if (widget.cleanup == null) cleanup.dispose();
    updates.dispose();
    settings.dispose();
    growth.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _page() => switch (section) {
    Section.smartScan => SmartScanPage(
      model: scan,
      onNavigate: _go,
      growth: growth,
      historyEnabled: settings.keepScanHistory,
    ),
    Section.cleanup => CleanupPage(
      model: cleanup,
      onNavigate: _go,
      settings: settings,
      fullDiskAccess: Platform.isMacOS ? const FullDiskAccessBanner() : null,
    ),
    Section.spaceLens => SpaceLensPage(model: scan, onNavigate: _go),
    Section.largeFiles => LargeFilesPage(
      model: scan,
      onNavigate: _go,
      settings: settings,
    ),
    Section.duplicates => DuplicatesPage(model: scan, onNavigate: _go),
    Section.developer => DeveloperPage(model: scan, onNavigate: _go),
    Section.example => ExamplePage(model: example),
    Section.settings => SettingsPage(settings: settings, updates: updates),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return ListenableBuilder(
            listenable: scan,
            builder: (context, _) => Row(
              children: [
                if (wide)
                  _Sidebar(
                    selected: section,
                    onSelected: _go,
                    badges: _badges(scan),
                  ),
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
                        _CompactNav(
                          selected: section,
                          onSelected: _go,
                          badges: _badges(scan),
                        ),
                      Expanded(
                        child: Scrollbar(
                          controller: _scrollController,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              wide ? 40 : 16,
                              wide ? 32 : 20,
                              wide ? 40 : 16,
                              48,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1080,
                                ),
                                child: KeyedSubtree(
                                  key: ValueKey(section),
                                  child: _page(),
                                ),
                              ),
                            ),
                          ),
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

/// Result counts shown beside navigation items once a scan has finished.
Map<Section, String> _badges(FolderScanViewModel model) {
  final result = model.result;
  if (result == null || model.busy) return const {};
  return {
    if (result.files.isNotEmpty) Section.largeFiles: '${result.files.length}',
    if (model.findDuplicates) Section.duplicates: '${result.duplicates.length}',
    if (model.findDevFolders) Section.developer: '${result.devFolders.length}',
  };
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

const _navGroups = [
  ('Scan', [Section.smartScan, Section.cleanup]),
  ('Review', [Section.spaceLens, Section.largeFiles, Section.duplicates]),
  ('Tools', [Section.developer]),
  ('Learn', [Section.example]),
  ('App', [Section.settings]),
];

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.onSelected,
    required this.badges,
  });
  final Section selected;
  final ValueChanged<Section> onSelected;
  final Map<Section, String> badges;

  @override
  Widget build(BuildContext context) => Container(
    width: 240,
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
                  padding: EdgeInsets.fromLTRB(20, 22, 16, 18),
                  child: _Brand(),
                ),
                for (final (title, items) in _navGroups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
                    child: Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        color: CvColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  for (final item in items)
                    _NavItem(
                      section: item,
                      selected: item == selected,
                      badge: badges[item],
                      onPressed: () => onSelected(item),
                    ),
                ],
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: _PrivacyCard(),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xff22283a),
      borderRadius: BorderRadius.circular(CvRadius.md),
      border: Border.all(color: const Color(0xff343d55)),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 17, color: CvColors.mint),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Private by design',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'Scans stay on this device. Nothing is removed until you confirm.',
          style: TextStyle(color: CvColors.muted, fontSize: 12, height: 1.45),
        ),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.selected,
    required this.onPressed,
    this.badge,
  });
  final Section section;
  final bool selected;
  final VoidCallback onPressed;
  final String? badge;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    child: Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? const Color(0xff293a50) : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(11),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 22,
                    decoration: BoxDecoration(
                      color: selected ? CvColors.cyan : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    section.icon,
                    size: 19,
                    color: selected ? CvColors.cyan : CvColors.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      section.label,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xffeff7ff)
                            : CvColors.muted,
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: CvColors.raised,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        badge!,
                        semanticsLabel: '$badge results',
                        style: const TextStyle(
                          fontSize: 11,
                          color: CvColors.text,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Narrow-window navigation: a scrollable row of choice chips.
class _CompactNav extends StatelessWidget {
  const _CompactNav({
    required this.selected,
    required this.onSelected,
    required this.badges,
  });
  final Section selected;
  final ValueChanged<Section> onSelected;
  final Map<Section, String> badges;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: CvColors.outlineSoft)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final item in Section.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(item.icon, size: 16),
                label: Text(
                  badges[item] == null
                      ? item.label
                      : '${item.label} · ${badges[item]}',
                ),
                selected: item == selected,
                onSelected: (_) => onSelected(item),
              ),
            ),
        ],
      ),
    ),
  );
}

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
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CvColors.outlineSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: wide
                ? Text(
                    root == null ? section.label : 'Scope: $root',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: root == null ? 15 : 13,
                      fontWeight: root == null
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: root == null ? CvColors.text : CvColors.muted,
                    ),
                  )
                : const _Brand(compact: true),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.lock_outline_rounded,
            size: 15,
            color: CvColors.mint,
            semanticLabel: 'On this device',
          ),
          if (wide) ...[
            const SizedBox(width: 6),
            const ExcludeSemantics(
              child: Text(
                'On this device',
                style: TextStyle(color: Color(0xffb8c6d7), fontSize: 12),
              ),
            ),
          ],
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
