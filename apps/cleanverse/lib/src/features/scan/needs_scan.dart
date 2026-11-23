// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/app/theme.dart';
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
      message: 'Scan from Home first. One scan fills every Storage tab.',
      action: FilledButton(
        onPressed: () => onNavigate(Section.home),
        child: const Text('Go to Home'),
      ),
    );
  }
  return null;
}

/// Scroll container for Storage tabs.
///
/// With bounded height it is a [PageScroll], so slivers stay lazy and the
/// bottom bar stays pinned. When a caller still places the page inside an
/// outer scroll view (unbounded height), it falls back to a shrink-wrapped
/// list so the page keeps working.
class StorageScroll extends StatelessWidget {
  const StorageScroll({
    super.key,
    this.header = const [],
    this.slivers = const [],
    this.bottomBar,
  });
  final List<Widget> header;
  final List<Widget> slivers;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.hasBoundedHeight) {
        return PageScroll(
          slivers: [
            SliverList.list(children: header),
            ...slivers,
          ],
          bottomBar: bottomBar,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomScrollView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            slivers: [
              SliverList.list(children: header),
              ...slivers,
            ],
          ),
          if (bottomBar != null)
            Padding(
              padding: const EdgeInsets.only(top: CvSpace.md),
              child: bottomBar,
            ),
        ],
      );
    },
  );
}
