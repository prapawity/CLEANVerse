// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'demo_scan.dart';
import 'folder_scan_card.dart';

class CleanVerseApp extends StatelessWidget {
  const CleanVerseApp({super.key, required this.repository});
  final ScanRepository repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CLEANVerse',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff215e83)),
      scaffoldBackgroundColor: const Color(0xfff3f7f8),
    ),
    home: HomeScreen(repository: repository),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});
  final ScanRepository repository;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ScanViewModel model = ScanViewModel(widget.repository);
  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'CLEANVerse',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      backgroundColor: Colors.transparent,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListenableBuilder(
            listenable: model,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              children: [
                const Text(
                  'A little more room to breathe.',
                  style: TextStyle(
                    fontSize: 32,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Understand your storage, one thoughtful step at a time.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                const FolderScanCard(),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xffdceef1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_awesome_outlined,
                        size: 32,
                        color: Color(0xff215e83),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Explore a sample scan',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This preview uses example data only. It does not access or change files on your device.',
                      ),
                      const SizedBox(height: 20),
                      if (model.status == ScanStatus.scanning)
                        OutlinedButton(
                          onPressed: model.cancel,
                          child: const Text('Cancel preview'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: model.start,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            model.status == ScanStatus.complete
                                ? 'Run example again'
                                : 'Show example results',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (model.error != null)
                  Text(
                    model.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (model.status == ScanStatus.scanning)
                  const LinearProgressIndicator(),
                if (model.status == ScanStatus.complete) ...[
                  const Text(
                    'Example results',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text('These are not files from your device.'),
                  const SizedBox(height: 12),
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
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'What is available now',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Desktop folder scanning is read-only. Duplicate detection, mobile scanning and file removal are not available yet.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
