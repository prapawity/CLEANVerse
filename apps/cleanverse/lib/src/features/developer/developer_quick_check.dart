import 'dart:io';

import 'package:flutter/foundation.dart' show listEquals;
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:cleanverse/src/features/developer/tool_commands_panel.dart';
import 'package:cleanverse/src/features/developer/docker_panel.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';

/// Checks known locations only. It does not traverse, calculate sizes or delete.
class DeveloperQuickCheck extends StatefulWidget {
  const DeveloperQuickCheck({
    super.key,
    required this.enabled,
    required this.exclusions,
  });
  final bool enabled;
  final List<String> exclusions;

  @override
  State<DeveloperQuickCheck> createState() => _DeveloperQuickCheckState();
}

class _DeveloperQuickCheckState extends State<DeveloperQuickCheck> {
  bool checking = false;
  bool checked = false;
  int skipped = 0;
  List<DevFolder> found = [];
  @override
  void didUpdateWidget(covariant DeveloperQuickCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.exclusions, widget.exclusions)) {
      checked = false;
      found = [];
    }
  }

  Future<void> check() async {
    if (checking) return;
    setState(() {
      checking = true;
      checked = false;
      found = [];
      skipped = 0;
    });
    final candidates = globalCacheCandidates(
      Platform.environment,
      windows: Platform.isWindows,
      macos: Platform.isMacOS,
    );
    final exclusions = List<String>.of(widget.exclusions);
    final results = <DevFolder>[];
    var ignored = 0;
    for (final candidate in candidates) {
      final path = p.normalize(candidate.path);
      if (exclusions.any(
        (excluded) => p.equals(excluded, path) || p.isWithin(excluded, path),
      )) {
        ignored++;
        continue;
      }
      try {
        final type = await FileSystemEntity.type(path, followLinks: false);
        if (type == FileSystemEntityType.directory) {
          results.add(candidate);
        } else if (type != FileSystemEntityType.notFound) {
          ignored++;
        }
      } on FileSystemException {
        ignored++;
      }
    }
    if (!mounted) return;
    if (!listEquals(exclusions, widget.exclusions)) {
      setState(() {
        checking = false;
      });
      return;
    }
    setState(() {
      found = results;
      skipped = ignored;
      checked = true;
      checking = false;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 14),
      FilledButton.tonalIcon(
        onPressed: widget.enabled && !checking ? check : null,
        icon: const Icon(Icons.bolt_outlined),
        label: Text(checking ? 'Checking locations…' : 'Find tool caches'),
      ),
      const SizedBox(height: 8),
      const Text(
        'Checks known tool locations without scanning their contents. Sizes are not calculated. Project folders still need a folder scan.',
        style: TextStyle(color: Color(0xffb2bfd4), fontSize: 12, height: 1.4),
      ),
      if (checking) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ],
      if (checked) ...[
        const SizedBox(height: 16),
        Text(
          '${found.length} possible tool locations found',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (found.isEmpty)
          const Text(
            'No known locations found. Custom tool settings may use other paths.',
          ),
        if (skipped > 0) Text('$skipped locations excluded or unavailable.'),
        for (final folder in found)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folder.category,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                SelectableText(
                  folder.path,
                  style: const TextStyle(
                    color: Color(0xffb2bfd4),
                    fontSize: 12,
                  ),
                ),
                Text(
                  folder.locationSource ?? 'Possible location',
                  style: const TextStyle(
                    color: Color(0xffb2bfd4),
                    fontSize: 12,
                  ),
                ),
                Text(
                  folder.note,
                  style: const TextStyle(
                    color: Color(0xffb2bfd4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Locations are candidates, not proof of active settings. Nothing is deleted.',
          style: TextStyle(color: Color(0xffb2bfd4), fontSize: 12, height: 1.4),
        ),
      ],
      DockerPanel(enabled: widget.enabled),
      ToolCommandsPanel(enabled: widget.enabled, windows: Platform.isWindows),
    ],
  );
}
