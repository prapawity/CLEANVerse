// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/features/developer/docker.dart';

/// Docker usage with clear states (not installed, not running, ready) and
/// cleaning through Docker's own prune commands.
class DockerPanel extends StatefulWidget {
  const DockerPanel({super.key, required this.enabled, this.tools});
  final bool enabled;
  final DockerTools? tools;

  @override
  State<DockerPanel> createState() => _DockerPanelState();
}

class _DockerPanelState extends State<DockerPanel> {
  late final DockerTools tools = widget.tools ?? DockerTools();
  DockerReport? report;
  bool busy = false;
  String? status;
  String? lastResult;

  Future<void> _check() async {
    setState(() {
      busy = true;
      status = 'Checking Docker…';
      lastResult = null;
    });
    final value = await tools.usage();
    if (!mounted) return;
    setState(() {
      report = value;
      busy = false;
      status = null;
    });
  }

  Future<void> _start() async {
    setState(() {
      busy = true;
      status = 'Starting Docker Desktop… this can take a minute.';
    });
    final started = await tools.startDesktop();
    if (!mounted) return;
    if (!started) {
      setState(() {
        busy = false;
        status = null;
        lastResult = 'Docker Desktop could not be started automatically. Open it yourself, then check again.';
      });
      return;
    }
    final value = await tools.waitUntilReady(cancelled: () => !mounted);
    if (!mounted) return;
    setState(() {
      report = value;
      busy = false;
      status = null;
    });
  }

  Future<void> _prune(DockerPrune kind) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clean Docker ${kind.label.toLowerCase()}?'),
        content: Text(
          '${kind.description}\n\nRuns: docker ${kind.args.join(' ')}\n'
          'Docker removes only items that are not in use. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clean'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      status = 'Cleaning ${kind.label.toLowerCase()}…';
    });
    final result = await tools.prune(kind);
    final refreshed = await tools.usage();
    if (!mounted) return;
    setState(() {
      busy = false;
      status = null;
      lastResult = '${kind.label}: $result';
      report = refreshed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = report;
    final enabled = widget.enabled && !busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: CvSpace.lg),
        Row(
          children: [
            const Icon(Icons.dns_outlined, size: 18, color: CvColors.violet),
            const SizedBox(width: CvSpace.sm),
            const Expanded(
              child: Text(
                'Docker',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (current?.state == DockerState.ready)
              const StatusChip('Running', color: CvColors.mint),
            if (current?.state == DockerState.notRunning)
              const StatusChip('Not running', color: CvColors.amber),
          ],
        ),
        const Text(
          'Uses the Docker CLI and your active Docker context.',
          style: TextStyle(color: CvColors.muted, fontSize: 12),
        ),
        const SizedBox(height: CvSpace.sm),
        if (status != null)
          Padding(
            padding: const EdgeInsets.only(bottom: CvSpace.sm),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: CvSpace.sm),
                Expanded(
                  child: Semantics(liveRegion: true, child: Text(status!)),
                ),
              ],
            ),
          ),
        switch (current?.state) {
          null => OutlinedButton.icon(
            onPressed: enabled ? _check : null,
            icon: const Icon(Icons.storage_outlined),
            label: const Text('Check Docker usage'),
          ),
          DockerState.notInstalled => const Callout(
            'Docker is not installed, or the docker command is not on PATH.',
          ),
          DockerState.notRunning => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Callout(
                'Docker is installed but its engine is not running. '
                'Start Docker Desktop to see and clean its storage.',
                tone: CalloutTone.caution,
              ),
              Wrap(
                spacing: CvSpace.md,
                runSpacing: CvSpace.sm,
                children: [
                  FilledButton.icon(
                    onPressed: enabled ? _start : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Docker Desktop'),
                  ),
                  OutlinedButton(
                    onPressed: enabled ? _check : null,
                    child: const Text('Check again'),
                  ),
                ],
              ),
            ],
          ),
          DockerState.timedOut || DockerState.failed => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Callout(
                current!.state == DockerState.timedOut
                    ? 'Docker did not respond in time.'
                    : 'Docker reported an error: ${(current.detail ?? '').split('\n').first}',
                tone: CalloutTone.caution,
              ),
              OutlinedButton(
                onPressed: enabled ? _check : null,
                child: const Text('Check again'),
              ),
            ],
          ),
          DockerState.ready => _Usage(
            report: current!,
            enabled: enabled,
            onPrune: _prune,
            onRefresh: _check,
          ),
        },
        if (lastResult != null)
          Padding(
            padding: const EdgeInsets.only(top: CvSpace.sm),
            child: Text(lastResult!, style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
  }
}

class _Usage extends StatelessWidget {
  const _Usage({
    required this.report,
    required this.enabled,
    required this.onPrune,
    required this.onRefresh,
  });
  final DockerReport report;
  final bool enabled;
  final ValueChanged<DockerPrune> onPrune;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (report.rows.isEmpty)
        const Text('Docker reported no storage.')
      else
        for (final row in report.rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.type,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Flexible(
                  flex: 3,
                  child: Text(
                    '${row.size} · ${row.total} total, ${row.active} active · reclaimable ${row.reclaimable}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: CvColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      const SizedBox(height: CvSpace.md),
      Wrap(
        spacing: CvSpace.sm,
        runSpacing: CvSpace.sm,
        children: [
          for (final kind in DockerPrune.values)
            OutlinedButton(
              onPressed: enabled ? () => onPrune(kind) : null,
              child: Text('Clean ${kind.label.toLowerCase()}'),
            ),
          TextButton.icon(
            onPressed: enabled ? onRefresh : null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ],
      ),
    ],
  );
}
