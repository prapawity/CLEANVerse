// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'demo_scan.dart';
import 'folder_scan_card.dart';

const canvasColor = Color(0xff141626);
const panelColor = Color(0xff1d2032);
const borderColor = Color(0xff353b53);
const mutedColor = Color(0xffaeb8d0);
const cyanColor = Color(0xff73d5fb);
const violetColor = Color(0xffc2a7f5);

class CleanVerseApp extends StatelessWidget {
  const CleanVerseApp({super.key, required this.repository});
  final ScanRepository repository;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: cyanColor,
      brightness: Brightness.dark,
      primary: cyanColor,
      surface: panelColor,
    );
    return MaterialApp(
      title: 'CLEANVerse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: canvasColor,
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: const Color(0xffedf0fc),
          displayColor: const Color(0xfff5f6ff),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xff24283d),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: borderColor),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: cyanColor,
            foregroundColor: const Color(0xff102031),
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xffd7e4f9),
            minimumSize: const Size(0, 48),
            side: const BorderSide(color: Color(0xff505b77)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: HomeScreen(repository: repository),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});
  final ScanRepository repository;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ScanViewModel model = ScanViewModel(widget.repository);
  final _scrollController = ScrollController();
  final _sampleKey = GlobalKey();
  final _developerKey = GlobalKey();

  void _scrollToOverview() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToDeveloper() => _scrollTo(_developerKey);

  void _scrollToSample() => _scrollTo(_sampleKey);

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    model.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Row(
            children: [
              if (wide)
                _Sidebar(
                  onOverview: _scrollToOverview,
                  onDeveloper: _scrollToDeveloper,
                  onSample: _scrollToSample,
                ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(wide: wide),
                    Expanded(
                      child: Scrollbar(
                        controller: _scrollController,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(
                            wide ? 40 : 20,
                            wide ? 36 : 24,
                            wide ? 40 : 20,
                            48,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1120),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FolderScanCard(developerKey: _developerKey),
                                  const SizedBox(height: 24),
                                  _SamplePanel(key: _sampleKey, model: model),
                                  const SizedBox(height: 24),
                                  const _Footnote(),
                                ],
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
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.max,
    children: [
      ExcludeSemantics(
        child: Image.asset(
          'assets/brand/cleanverse-brush-proposal.png',
          width: compact ? 36 : 44,
          height: compact ? 36 : 44,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
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
                      color: cyanColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: 'Verse',
                    style: TextStyle(
                      color: violetColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 19, letterSpacing: -.5),
            ),
            Text(
              'by PRAPAWITY',
              style: TextStyle(
                color: mutedColor.withValues(alpha: .9),
                fontSize: 10,
                letterSpacing: .2,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.onOverview,
    required this.onDeveloper,
    required this.onSample,
  });
  final VoidCallback onOverview;
  final VoidCallback onDeveloper;
  final VoidCallback onSample;
  @override
  Widget build(BuildContext context) => Container(
    width: 232,
    decoration: const BoxDecoration(
      color: Color(0xff191b2c),
      border: Border(right: BorderSide(color: Color(0xff2e3248))),
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
                  padding: EdgeInsets.fromLTRB(20, 22, 16, 30),
                  child: _Brand(),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Workspace',
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _NavItem(
                  icon: Icons.space_dashboard_outlined,
                  label: 'Storage overview',
                  selected: true,
                  onPressed: onOverview,
                ),
                const SizedBox(height: 4),
                _NavItem(
                  icon: Icons.code_rounded,
                  label: 'Developer',
                  onPressed: onDeveloper,
                ),
                const SizedBox(height: 4),
                _NavItem(
                  icon: Icons.science_outlined,
                  label: 'Example scan',
                  onPressed: onSample,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xff22283a),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xff343d55)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 17,
                              color: cyanColor,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Private by design',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Scans stay on this device. No files are removed.',
                          style: TextStyle(
                            color: mutedColor,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Material(
      color: selected ? const Color(0xff293a50) : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(11),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? cyanColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(icon, size: 19, color: selected ? cyanColor : mutedColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? const Color(0xffeff7ff) : mutedColor,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.wide});
  final bool wide;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 68),
    padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 20, vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xff292d42))),
    ),
    child: Row(
      children: [
        if (wide)
          const Expanded(
            child: Text(
              'Storage overview',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          )
        else
          const Expanded(child: _Brand(compact: true)),
        const SizedBox(width: 8),
        const Icon(
          Icons.lock_outline_rounded,
          size: 15,
          color: Color(0xffa4e3d0),
        ),
        const SizedBox(width: 6),
        const Text(
          'On this device',
          style: TextStyle(color: Color(0xffb8c6d7), fontSize: 12),
        ),
      ],
    ),
  );
}

class _SamplePanel extends StatelessWidget {
  const _SamplePanel({super.key, required this.model});
  final ScanViewModel model;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xff1b1e30),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: const Icon(Icons.science_outlined, color: violetColor),
        title: const Text(
          'Explore an example',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'See sample results without scanning your files.',
          style: TextStyle(color: mutedColor, fontSize: 13),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          ListenableBuilder(
            listenable: model,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This preview uses example data only. It does not access or change files on your device.',
                  style: TextStyle(color: mutedColor, height: 1.4),
                ),
                const SizedBox(height: 16),
                if (model.status == ScanStatus.scanning)
                  OutlinedButton(
                    onPressed: model.cancel,
                    child: const Text('Cancel preview'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: model.start,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      model.status == ScanStatus.complete
                          ? 'Run example again'
                          : 'Show example results',
                    ),
                  ),
                if (model.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      model.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (model.status == ScanStatus.scanning)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (model.status == ScanStatus.complete) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Example results',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'These are not files from your device.',
                    style: TextStyle(color: mutedColor),
                  ),
                  const SizedBox(height: 8),
                  for (final item in model.items)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(item.name),
                        subtitle: Text(item.category),
                        trailing: Text(item.size),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Footnote extends StatelessWidget {
  const _Footnote();
  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.info_outline_rounded, size: 16, color: mutedColor),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'Early preview · Desktop scanning is read-only. Cleanup and mobile scanning are not available yet.',
          style: TextStyle(color: mutedColor, fontSize: 12, height: 1.5),
        ),
      ),
    ],
  );
}
