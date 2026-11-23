// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/features/settings/app_settings.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/data/protection.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/features/update/installer.dart';
import 'package:cleanverse/src/features/update/update_view_model.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.updates,
    this.onTrySample,
  });
  final AppSettings settings;
  final UpdateViewModel updates;

  /// Opens the sample-data walkthrough (formerly the Example scan menu).
  final VoidCallback? onTrySample;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([settings, updates]),
    builder: (context, _) => PageScroll(
      maxWidth: 760,
      children: [
        const PageHeader(
          title: 'Settings',
          subtitle:
              'Updates, history and privacy. Everything stays on this device.',
        ),
        if (onTrySample != null) ...[
          const _Group(
            'Sample data',
            detail: 'See how results look without scanning your files.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onTrySample,
              child: const Text('Try with sample data'),
            ),
          ),
        ],
        const _Group('Updates'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current version: ${updates.version ?? '…'}',
              style: const TextStyle(color: CvColors.muted),
            ),
            const SizedBox(height: CvSpace.md),
            if (!updates.configured)
              const Callout(
                'This build has no update signing key, so it does not check for updates. '
                'Official releases from GitHub include it.',
              )
            else ...[
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.autoCheckUpdates,
                  onChanged: settings.setAutoCheckUpdates,
                  title: const Text('Check for updates automatically'),
                  subtitle: const Text(
                    'Once a day, from GitHub Releases. Nothing is downloaded without asking.',
                  ),
                ),
              ),
              const SizedBox(height: CvSpace.sm),
              UpdateStatusView(updates: updates),
            ],
          ],
        ),
        const _Group('Scan history'),
        Material(
          color: Colors.transparent,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.keepScanHistory,
            onChanged: settings.setKeepScanHistory,
            title: const Text('Keep scan history to show what grew'),
            subtitle: const Text(
              'Saves folder paths and sizes from each finished scan (no file names or contents) '
              'in this app\'s data folder. Off by default. Turning it off deletes the history.',
            ),
          ),
        ),
        const _Group(
          'Ignore list',
          detail: 'These paths are never offered for cleanup or removed.',
        ),
        settings.ignoreList.paths.isEmpty
            ? const Text(
                'Nothing ignored. Use the hide button next to an item to add it.',
                style: TextStyle(color: CvColors.muted),
              )
            : Column(
                children: [
                  for (final path in settings.ignoreList.paths)
                    Row(
                      children: [
                        const Icon(
                          Icons.visibility_off_outlined,
                          size: 18,
                          color: CvColors.muted,
                        ),
                        const SizedBox(width: CvSpace.sm),
                        Expanded(child: PathLine(path)),
                        TextButton(
                          onPressed: () => settings.unignorePath(path),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                ],
              ),
        const _Group(
          'Removal history',
          detail: 'Stored only on this device. Includes file paths.',
        ),
        _HistorySection(settings: settings),
        const _Group('Privacy'),
        const Text(
          'Scans, paths and results stay on this device. CLEANVerse sends no telemetry. '
          'The only network request is the optional update check to github.com.',
          style: TextStyle(color: CvColors.muted, height: 1.5),
        ),
      ],
    ),
  );
}

/// Section heading with a hairline above it; keeps Settings one calm page.
class _Group extends StatelessWidget {
  const _Group(this.title, {this.detail});
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: CvSpace.md),
      const Divider(height: 1, color: CvColors.outlineSoft),
      SectionTitle(title, detail: detail),
    ],
  );
}

/// Shared update status and actions, used on the settings page and banner.
class UpdateStatusView extends StatelessWidget {
  const UpdateStatusView({super.key, required this.updates});
  final UpdateViewModel updates;

  @override
  Widget build(BuildContext context) {
    final manifest = updates.available;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        switch (updates.status) {
          UpdateStatus.checking => const Text('Checking for updates…'),
          UpdateStatus.upToDate => const Text('CLEANVerse is up to date.'),
          UpdateStatus.error => Callout(
            updates.error ?? 'Update failed.',
            tone: CalloutTone.caution,
          ),
          UpdateStatus.downloading => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Downloading ${manifest?.version}… ${(updates.progress * 100).toStringAsFixed(0)}%',
              ),
              const SizedBox(height: CvSpace.sm),
              LinearProgressIndicator(value: updates.progress),
            ],
          ),
          UpdateStatus.installing => const Text('Installing…'),
          _ => const SizedBox.shrink(),
        },
        if (manifest != null &&
            updates.status != UpdateStatus.downloading &&
            updates.status != UpdateStatus.installing) ...[
          Text(
            'Version ${manifest.version} is available',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (manifest.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                manifest.notes,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: CvColors.muted, fontSize: 13),
              ),
            ),
          if (updates.result == InstallResult.openedInstaller)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'The installer is open. Finish it, then restart CLEANVerse.',
              ),
            ),
          if (updates.result == InstallResult.savedOnly)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'The verified update was saved. Install it from the folder that opened.',
              ),
            ),
          const SizedBox(height: CvSpace.md),
          Wrap(
            spacing: CvSpace.md,
            runSpacing: CvSpace.sm,
            children: [
              FilledButton.icon(
                onPressed: updates.downloadAndInstall,
                icon: const Icon(Icons.system_update_alt_rounded),
                label: const Text('Download and install'),
              ),
              TextButton(
                onPressed: updates.skip,
                child: const Text('Skip this version'),
              ),
            ],
          ),
        ] else if (updates.status != UpdateStatus.checking &&
            updates.status != UpdateStatus.downloading) ...[
          const SizedBox(height: CvSpace.sm),
          OutlinedButton.icon(
            onPressed: updates.check,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Check now'),
          ),
        ],
      ],
    );
  }
}

class _HistorySection extends StatefulWidget {
  const _HistorySection({required this.settings});
  final AppSettings settings;

  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  late Future<List<LoggedOperation>> entries = _load();

  Future<List<LoggedOperation>> _load() async =>
      (await widget.settings.operationLog()).read(limit: 100);

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear removal history?'),
        content: const Text(
          'Only the history list is cleared. Removed files are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await (await widget.settings.operationLog()).clear();
    setState(() => entries = _load());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<LoggedOperation>>(
    future: entries,
    builder: (context, snapshot) {
      final list = snapshot.data ?? const <LoggedOperation>[];
      if (snapshot.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (list.isEmpty) {
        return const Text(
          'No removals yet.',
          style: TextStyle(color: CvColors.muted),
        );
      }
      final freed = list.fold<int>(0, (s, e) => s + e.freedBytes);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: CvSpace.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${plural(list.length, 'entry', 'entries')} · ${formatBytes(freed)} freed permanently',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextButton.icon(
                onPressed: () => setState(() => entries = _load()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Clear history'),
              ),
            ],
          ),
          const Divider(height: 20),
          for (final e in list.take(100))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    e.mode == 'trash'
                        ? Icons.restore_from_trash_outlined
                        : Icons.delete_forever_outlined,
                    size: 18,
                    color: e.status == 'removed' || e.status == 'movedToTrash'
                        ? CvColors.mint
                        : CvColors.amber,
                  ),
                  const SizedBox(width: CvSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e.label} · ${_statusText(e)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        PathLine(
                          '${formatDate(e.time)} ${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')} · ${e.path}',
                          style: const TextStyle(
                            color: CvColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

String _statusText(LoggedOperation e) => switch (e.status) {
  'removed' => 'deleted, ${formatBytes(e.freedBytes)} freed',
  'movedToTrash' => 'moved to bin',
  'partial' => 'partly cleaned, ${formatBytes(e.freedBytes)} freed',
  'skipped' => 'skipped',
  _ => 'not cleaned',
};
