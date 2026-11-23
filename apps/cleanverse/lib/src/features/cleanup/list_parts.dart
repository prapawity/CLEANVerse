// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/theme.dart';

/// A path on one line. Long paths are shortened with an ellipsis; the full
/// path is in the tooltip and in screen-reader text.
class PathText extends StatelessWidget {
  const PathText(this.path, {super.key, this.prefix = ''});
  final String path;
  final String prefix;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: path,
    waitDuration: const Duration(milliseconds: 400),
    child: Text(
      '$prefix$path',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: const TextStyle(color: CvColors.muted, fontSize: 12),
    ),
  );
}

/// Size figure aligned at the end of a row.
class SizeText extends StatelessWidget {
  const SizeText(this.text, {super.key, this.muted = false});
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.end,
    style: TextStyle(
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: muted ? CvColors.muted : CvColors.text,
    ),
  );
}

/// Thin divider between list rows, instead of a box around each row.
const rowDivider = Divider(
  height: 1,
  thickness: 1,
  color: CvColors.outlineSoft,
);

/// Pinned action bar content: a status sentence and one action.
class SelectionBar extends StatelessWidget {
  const SelectionBar({super.key, required this.status, required this.action});
  final String status;
  final Widget action;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: CvSpace.lg,
    runSpacing: CvSpace.sm,
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Semantics(
        liveRegion: true,
        child: Text(
          status,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      action,
    ],
  );
}
