// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/features/scan/desktop_scan.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/features/scan/smart_scan_page.dart';

/// Shared state for review pages before a scan exists or while one runs.
/// Returns null when the page can show results.
Widget? needsScan(
  FolderScanViewModel model,
  ValueChanged<Section> onNavigate, {
  required IconData icon,
  required String title,
}) {
  if (model.busy && model.root != null && !model.pickingExclusion) {
    return ScanProgressPanel(model: model);
  }
  if (model.result == null) {
    return EmptyState(
      icon: icon,
      title: title,
      message: 'Run a scan first. Results from one scan appear in every review area.',
      action: FilledButton.icon(
        onPressed: () => onNavigate(Section.home),
        icon: const Icon(Icons.radar_rounded, size: 19),
        label: const Text('Go to Smart Scan'),
      ),
    );
  }
  return null;
}
