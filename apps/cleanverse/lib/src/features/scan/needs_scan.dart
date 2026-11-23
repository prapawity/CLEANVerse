// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// One-line path with ellipsis, the full path in a tooltip, and a copy
/// action. The path goes to the local clipboard only.
class PathLine extends StatelessWidget {
  const PathLine(this.path, {super.key});
  final String path;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(
        child: Tooltip(
          message: path,
          waitDuration: const Duration(milliseconds: 400),
          child: Text(
            path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: CvColors.muted, fontSize: 12),
          ),
        ),
      ),
      IconButton(
        tooltip: 'Copy path',
        visualDensity: VisualDensity.compact,
        iconSize: 16,
        icon: const Icon(Icons.copy_rounded, color: CvColors.muted),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: path));
          if (!context.mounted) return;
          ScaffoldMessenger.maybeOf(context)
              ?.showSnackBar(const SnackBar(content: Text('Path copied')));
        },
      ),
    ],
  );
}

/// Quiet "Show N more" button under a bounded list.
class ShowMoreButton extends StatelessWidget {
  const ShowMoreButton({
    super.key,
    required this.remaining,
    required this.onPressed,
    this.step = 50,
  });
  final int remaining;
  final int step;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: CvSpace.md),
    child: Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          'Show ${remaining < step ? remaining : step} more of $remaining',
        ),
      ),
    ),
  );
}

/// Pinned selection bar: one sentence and one primary action.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.summary,
    required this.actionLabel,
    required this.onAction,
  });
  final String summary;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: CvSpace.lg,
    runSpacing: CvSpace.sm,
    crossAxisAlignment: WrapCrossAlignment.center,
    alignment: WrapAlignment.spaceBetween,
    children: [
      Text(summary, style: const TextStyle(fontWeight: FontWeight.w600)),
      FilledButton(onPressed: onAction, child: Text(actionLabel)),
    ],
  );
}
