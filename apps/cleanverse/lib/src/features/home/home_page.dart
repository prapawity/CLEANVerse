import 'dart:async';
import 'dart:io';

// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/data/scan_history.dart';
import 'package:cleanverse/src/data/volumes.dart';
import 'package:cleanverse/src/features/home/storage_dashboard.dart';
import 'package:cleanverse/src/features/cleanup/cleanup_view_model.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/features/scan/smart_scan_page.dart';
import 'package:cleanverse/src/features/uninstall/uninstall_view_model.dart';

/// Home: one button scans the home folder and checks junk locations, then
/// a short list of findings points to the page that handles each one.
/// Scanning only reads. Nothing is selected or removed here.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.model,
    required this.cleanup,
    required this.onNavigate,
    this.uninstall,
    this.growth,
    this.historyEnabled = false,
    this.appsSupported = false,
    this.volumes,
  });
  final VolumesModel? volumes;
  final FolderScanViewModel model;
  final CleanupViewModel cleanup;
  final UninstallViewModel? uninstall;
  final ValueChanged<Section> onNavigate;
  final ValueNotifier<ScanComparison?>? growth;
  final bool historyEnabled;
  final bool appsSupported;

  bool get _scanning =>
      (model.busy && !model.pickingExclusion && model.root != null) ||
      cleanup.scanning;

  Future<void> _scanNow() async {
    // Apps are listed and measured in the background for the dashboard.
    final apps = uninstall;
    if (appsSupported && apps != null && apps.apps == null && !apps.busy) {
      unawaited(apps.loadApps());
    }
    await Future.wait([model.startDefault(), cleanup.scan()]);
    await volumes?.load();
  }

  Future<void> _chooseFolder() =>
      Future.wait([model.start(), if (!cleanup.busy) cleanup.scan()]);

  Future<void> _scanAgain() =>
      Future.wait([model.rescan(), if (!cleanup.busy) cleanup.scan()]);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      model,
      cleanup,
      ?uninstall,
      ?growth,
      ?volumes,
    ]),
    builder: (context, _) {
      final result = model.result;
      final Widget body;
      if (_scanning) {
        body = _Progress(model: model, cleanup: cleanup);
      } else if (result != null) {
        body = _Findings(
          model: model,
          result: result,
          findings: _findings(result),
          onNavigate: onNavigate,
          onScanAgain: _scanAgain,
          onChangeFolder: _chooseFolder,
        );
      } else {
        body = _Start(
          model: model,
          onScanNow: _scanNow,
          onChooseFolder: _chooseFolder,
        );
      }
      return PageScroll(
        maxWidth: 860,
        children: [
          if (volumes != null) ...[
            _dashboard(),
            const SizedBox(height: CvSpace.xl),
            const Divider(color: CvColors.outlineSoft),
          ],
          body,
          if (model.error != null)
            Padding(
              padding: const EdgeInsets.only(top: CvSpace.lg),
              child: Callout(model.error!, tone: CalloutTone.caution),
            ),
          if (cleanup.error != null && !_scanning)
            Padding(
              padding: const EdgeInsets.only(top: CvSpace.sm),
              child: Callout(cleanup.error!, tone: CalloutTone.caution),
            ),
        ],
      );
    },
  );

  Widget _dashboard() {
    final result = model.result;
    final home = model.homeFolder();
    final scannedHome =
        result != null &&
        !model.busy &&
        home != null &&
        model.root != null &&
        p.equals(p.normalize(model.root!), p.normalize(home));
    final junk = cleanup.found?.fold<int>(0, (s, j) => s + j.bytes);
    final dev = result?.devFolders
        .where((f) => f.projectMarker != null)
        .fold<int>(0, (s, f) => s + f.logicalBytes);
    final apps = uninstall?.appSizes.values.fold<int>(0, (s, b) => s + b);
    return StorageDashboard(
      volumes: volumes!,
      onNavigate: onNavigate,
      homeBytes: scannedHome ? result.totalBytes : null,
      junkBytes: junk,
      developerBytes: dev,
      appsBytes: appsSupported ? apps : null,
      appsMeasuring: appsSupported && (uninstall?.measuringSizes ?? false),
      appsSupported: appsSupported,
    );
  }

  List<_Finding> _findings(FolderScanResult result) {
    final byBytes = <_Finding>[];
    final junk = cleanup.found;
    if (junk != null && junk.isNotEmpty) {
      final bytes = junk.fold<int>(0, (s, j) => s + j.bytes);
      byBytes.add(
        _Finding(
          bytes: bytes,
          figure: formatBytes(bytes),
          title: 'Junk you can clean up',
          detail:
              'Caches, logs and temporary files in '
              '${plural(junk.length, 'location')}. You choose what goes.',
          action: 'Clean up',
          target: Section.cleanup,
        ),
      );
    }
    final large = [
      for (final f in result.files)
        if (f.bytes >= largeFileThreshold) f,
    ];
    if (large.isNotEmpty) {
      final bytes = large.fold<int>(0, (s, f) => s + f.bytes);
      byBytes.add(
        _Finding(
          bytes: bytes,
          figure: formatBytes(bytes),
          title: 'Your biggest files',
          detail: '${plural(large.length, 'file')} of 50 MiB or more.',
          action: 'Review files',
          target: Section.storage,
        ),
      );
    }
    if (model.findDevFolders && result.devFolders.isNotEmpty) {
      final bytes = result.devFolders.fold<int>(
        0,
        (s, f) => s + f.logicalBytes,
      );
      byBytes.add(
        _Finding(
          bytes: bytes,
          figure: formatBytes(bytes),
          title: 'Developer storage',
          detail:
              '${plural(result.devFolders.length, 'folder')} such as '
              'dependencies and build caches. Check them before removing.',
          action: 'Review',
          target: Section.developer,
        ),
      );
    }
    final comparison = growth?.value;
    if (historyEnabled && comparison != null && comparison.grew.isNotEmpty) {
      final bytes = comparison.grew.fold<int>(0, (s, g) => s + g.delta);
      byBytes.add(
        _Finding(
          bytes: bytes,
          figure: '+${formatBytes(bytes)}',
          title: 'What grew since ${formatDate(comparison.previous.time)}',
          detail: '${plural(comparison.grew.length, 'folder')} got bigger.',
          action: 'See folders',
          target: Section.spaceLens,
        ),
      );
    }
    byBytes.sort((a, b) => b.bytes.compareTo(a.bytes));
    final apps = uninstall?.apps;
    return [
      ...byBytes,
      if (appsSupported)
        _Finding(
          bytes: 0,
          figure: apps == null ? null : plural(apps.length, 'app'),
          title: 'Apps you no longer use',
          detail: 'Remove an app together with its leftover files.',
          action: 'Uninstall apps',
          target: Section.apps,
        ),
    ];
  }
}

class _Finding {
  const _Finding({
    required this.bytes,
    required this.figure,
    required this.title,
    required this.detail,
    required this.action,
    required this.target,
  });
  final int bytes;
  final String? figure;
  final String title;
  final String detail;
  final String action;
  final Section target;
}

String _homeLabel() =>
    Platform.isMacOS ? 'Your Mac at a glance' : 'Your computer at a glance';

const _heroStyle = TextStyle(
  fontSize: 30,
  height: 1.2,
  fontWeight: FontWeight.w700,
  letterSpacing: -.5,
);

const _bodyStyle = TextStyle(color: CvColors.muted, fontSize: 14, height: 1.5);

class _Start extends StatelessWidget {
  const _Start({
    required this.model,
    required this.onScanNow,
    required this.onChooseFolder,
  });
  final FolderScanViewModel model;
  final VoidCallback onScanNow;
  final VoidCallback onChooseFolder;

  @override
  Widget build(BuildContext context) {
    final supported = desktopScanSupported;
    final picking = model.busy && model.root == null && !model.pickingExclusion;
    final home = model.homeFolder();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: CvSpace.xl),
        Semantics(header: true, child: Text(_homeLabel(), style: _heroStyle)),
        const SizedBox(height: CvSpace.md),
        Text(
          supported
              ? 'Find out what takes up space. CLEANVerse looks through your '
                    'home folder and the usual cache locations. It only reads; '
                    'nothing is removed unless you confirm it.'
              : 'Scanning is available on desktop only.',
          style: _bodyStyle,
        ),
        const SizedBox(height: CvSpace.xxl),
        Wrap(
          spacing: CvSpace.lg,
          runSpacing: CvSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              onPressed: supported && !model.busy ? onScanNow : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(160, 52),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Scan now'),
            ),
            TextButton(
              onPressed: supported && !model.busy ? onChooseFolder : null,
              child: const Text('Choose another folder…'),
            ),
          ],
        ),
        const SizedBox(height: CvSpace.md),
        if (picking)
          Semantics(
            liveRegion: true,
            child: const Text(
              'Choose a folder to scan.',
              style: TextStyle(color: CvColors.muted),
            ),
          )
        else if (supported && home != null)
          OneLinePath(
            home,
            prefix: 'Scans ',
            style: const TextStyle(color: CvColors.muted, fontSize: 12),
          ),
      ],
    );
  }
}

/// One progress display for the folder scan and the junk check together.
class _Progress extends StatelessWidget {
  const _Progress({required this.model, required this.cleanup});
  final FolderScanViewModel model;
  final CleanupViewModel cleanup;

  @override
  Widget build(BuildContext context) {
    final folderBusy = model.busy && model.root != null;
    final progress = model.progress;
    final comparing = progress?.phase == ScanPhase.comparing;
    final folderStatus = !folderBusy
        ? 'Folder scan done.'
        : model.cancelling
        ? 'Stopping the scan…'
        : comparing
        ? 'Comparing files: ${progress!.compared} of ${progress.toCompare} checked.'
        : 'Scanning: ${progress?.filesSeen ?? 0} files found so far.';
    final junkStatus = cleanup.scanning
        ? 'Checking cache and log locations…'
        : 'Junk check done.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: CvSpace.xl),
        Semantics(
          header: true,
          child: const Text('Scanning…', style: _heroStyle),
        ),
        const SizedBox(height: CvSpace.sm),
        if (model.root != null)
          OneLinePath(
            model.root!,
            prefix: 'Folder: ',
            style: const TextStyle(color: CvColors.muted),
          ),
        const SizedBox(height: CvSpace.xl),
        const LinearProgressIndicator(),
        const SizedBox(height: CvSpace.lg),
        Semantics(liveRegion: true, child: Text(folderStatus)),
        const SizedBox(height: CvSpace.xs),
        Text(junkStatus, style: const TextStyle(color: CvColors.muted)),
        if (model.live != null && folderBusy) _SoFar(result: model.live!),
        const SizedBox(height: CvSpace.xl),
        Wrap(
          spacing: CvSpace.md,
          runSpacing: CvSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton(
              onPressed: folderBusy && !model.cancelling
                  ? () {
                      model.cancel();
                      cleanup.cancelScan();
                    }
                  : null,
              child: Text(model.cancelling ? 'Cancelling…' : 'Cancel'),
            ),
            const Text(
              'Cancelling keeps what was found so far.',
              style: TextStyle(color: CvColors.muted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

/// What the scan has found so far: updates every couple of seconds.
class _SoFar extends StatelessWidget {
  const _SoFar({required this.result});
  final FolderScanResult result;

  @override
  Widget build(BuildContext context) {
    final files = result.files.take(5).toList();
    final folders = [
      for (final f in result.folderSummaries)
        if (f.folderPath != null) f,
    ].take(3).toList();
    return Padding(
      padding: const EdgeInsets.only(top: CvSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatBytes(result.totalBytes)} found so far',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          if (folders.isNotEmpty) ...[
            const SizedBox(height: CvSpace.md),
            const Text(
              'Biggest folders so far',
              style: TextStyle(color: CvColors.muted, fontSize: 12),
            ),
            for (final f in folders)
              _SoFarRow(label: p.basename(f.label), bytes: f.bytes),
          ],
          if (files.isNotEmpty) ...[
            const SizedBox(height: CvSpace.md),
            const Text(
              'Biggest files so far',
              style: TextStyle(color: CvColors.muted, fontSize: 12),
            ),
            for (final f in files)
              _SoFarRow(label: p.basename(f.path), bytes: f.bytes),
          ],
        ],
      ),
    );
  }
}

class _SoFarRow extends StatelessWidget {
  const _SoFarRow({required this.label, required this.bytes});
  final String label;
  final int bytes;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: MiddleEllipsisText(label)),
        const SizedBox(width: CvSpace.md),
        Text(
          formatBytes(bytes),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

class _Findings extends StatelessWidget {
  const _Findings({
    required this.model,
    required this.result,
    required this.findings,
    required this.onNavigate,
    required this.onScanAgain,
    required this.onChangeFolder,
  });
  final FolderScanViewModel model;
  final FolderScanResult result;
  final List<_Finding> findings;
  final ValueChanged<Section> onNavigate;
  final VoidCallback onScanAgain;
  final VoidCallback onChangeFolder;

  @override
  Widget build(BuildContext context) {
    final root = model.root ?? '';
    final home = model.homeFolder();
    final scope = home != null && root == home
        ? 'your home folder'
        : displayName(root);
    final status = result.cancelled
        ? 'You stopped the scan early, so these results are partial.'
        : result.skipped > 0
        ? '${plural(result.skipped, 'item')} could not be read, so totals '
              'may be low.'
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: CvSpace.md),
        Semantics(header: true, child: Text(_homeLabel(), style: _heroStyle)),
        const SizedBox(height: CvSpace.sm),
        Semantics(
          liveRegion: true,
          child: Text(
            '${formatBytes(result.totalBytes)} in $scope · '
            '${plural(result.filesSeen, 'file')} read.',
            style: _bodyStyle,
          ),
        ),
        if (status != null)
          Padding(
            padding: const EdgeInsets.only(top: CvSpace.xs),
            child: Text(
              status,
              style: const TextStyle(color: CvColors.amber, fontSize: 13),
            ),
          ),
        const SizedBox(height: CvSpace.xl),
        if (findings.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: CvSpace.xl),
            child: Text(
              'Nothing big stands out. Open Storage to look around.',
              style: _bodyStyle,
            ),
          ),
        for (var i = 0; i < findings.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: CvColors.outlineSoft),
          _FindingRow(
            finding: findings[i],
            primary: i == 0,
            onPressed: () => onNavigate(findings[i].target),
          ),
        ],
        const SizedBox(height: CvSpace.xl),
        Wrap(
          spacing: CvSpace.sm,
          runSpacing: CvSpace.xs,
          children: [
            TextButton.icon(
              onPressed: model.busy ? null : onScanAgain,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Scan again'),
            ),
            TextButton.icon(
              onPressed: model.busy ? null : onChangeFolder,
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: const Text('Change folder'),
            ),
          ],
        ),
        const SizedBox(height: CvSpace.md),
        const Text(
          'Sizes are what the scan read. Shared or linked files can make the '
          'space you get back smaller. Nothing has been selected or removed.',
          style: TextStyle(color: CvColors.muted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }
}

class _FindingRow extends StatelessWidget {
  const _FindingRow({
    required this.finding,
    required this.primary,
    required this.onPressed,
  });
  final _Finding finding;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (finding.figure != null)
          Text(
            finding.figure!,
            style: const TextStyle(
              fontSize: 36,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        const SizedBox(height: CvSpace.xs),
        Text(
          finding.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(finding.detail, style: _bodyStyle),
      ],
    );
    final button = primary
        ? FilledButton(onPressed: onPressed, child: Text(finding.action))
        : OutlinedButton(onPressed: onPressed, child: Text(finding.action));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CvSpace.xl - 4),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 520
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  text,
                  const SizedBox(height: CvSpace.md),
                  button,
                ],
              )
            : Row(
                children: [
                  Expanded(child: text),
                  const SizedBox(width: CvSpace.xl),
                  button,
                ],
              ),
      ),
    );
  }
}
