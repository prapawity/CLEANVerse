import 'dart:math' as math;

// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'package:cleanverse/src/app/theme.dart';

String formatBytes(int bytes) {
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  double value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}

String formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}

String plural(int count, String one, [String? many]) =>
    '$count ${count == 1 ? one : (many ?? '${one}s')}';

/// Basename for display, falling back to the full path for roots.
String displayName(String path) {
  final name = p.basename(path);
  return name.isEmpty ? path : name;
}

IconData iconForCategory(String category) => switch (category) {
  'Images' => Icons.image_outlined,
  'Videos' => Icons.movie_outlined,
  'Audio' => Icons.music_note_outlined,
  'Documents' => Icons.description_outlined,
  'Archives & disk images' => Icons.inventory_2_outlined,
  'Code & configuration' => Icons.code_rounded,
  'Build output' => Icons.construction_rounded,
  _ => Icons.insert_drive_file_outlined,
};

/// Title + one-line purpose at the top of each workspace page.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(height: CvSpace.xs),
        Text(subtitle, style: const TextStyle(color: CvColors.muted)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: CvSpace.xl),
      child: trailing == null
          ? text
          : Wrap(
              spacing: CvSpace.lg,
              runSpacing: CvSpace.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [text, trailing!],
            ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CvSpace.xl),
    this.color = CvColors.panel,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(CvRadius.lg),
      border: Border.all(color: CvColors.outline),
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.detail});
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: CvSpace.xl, bottom: CvSpace.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (detail != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              detail!,
              style: const TextStyle(color: CvColors.muted, fontSize: 13),
            ),
          ),
      ],
    ),
  );
}

enum CalloutTone { info, caution }

/// Compact explanation of scope, accuracy or safety limits.
class Callout extends StatelessWidget {
  const Callout(this.text, {super.key, this.tone = CalloutTone.info});
  final String text;
  final CalloutTone tone;

  @override
  Widget build(BuildContext context) {
    final caution = tone == CalloutTone.caution;
    final accent = caution ? CvColors.amber : CvColors.cyan;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: CvSpace.md),
      padding: const EdgeInsets.all(CvSpace.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(CvRadius.sm),
        border: Border.all(color: accent.withValues(alpha: .3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            caution ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            size: 18,
            color: accent,
            semanticLabel: caution ? 'Caution' : 'Note',
          ),
          const SizedBox(width: CvSpace.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small labelled status pill. Text carries the meaning, color reinforces it.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: .4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Shown when a page needs a scan result or an opt-in option first.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.symmetric(horizontal: CvSpace.xl, vertical: 40),
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: CvColors.raised,
            borderRadius: BorderRadius.circular(CvRadius.md),
          ),
          child: Icon(icon, color: CvColors.violet, size: 26),
        ),
        const SizedBox(height: CvSpace.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: CvSpace.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CvColors.muted),
          ),
        ),
        if (action != null) ...[const SizedBox(height: CvSpace.xl), action!],
      ],
    ),
  );
}

/// Proportional horizontal bar with an accessible text summary.
class ProportionBar extends StatelessWidget {
  const ProportionBar({
    super.key,
    required this.values,
    required this.semanticLabel,
    this.height = 14,
  });
  final List<int> values;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = values.fold<int>(0, (sum, v) => sum + v);
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: total == 0
                ? const ColoredBox(color: CvColors.raised)
                : Row(
                    children: [
                      for (var i = 0; i < values.length; i++)
                        if (values[i] > 0)
                          Expanded(
                            // Keep tiny segments visible but proportional.
                            flex: math.max(1, values[i] * 1000 ~/ total),
                            child: Container(
                              margin: EdgeInsets.only(
                                right: i == values.length - 1 ? 0 : 2,
                              ),
                              color: CvColors.seriesAt(i),
                            ),
                          ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class Swatch extends StatelessWidget {
  const Swatch(this.color, {super.key});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

/// A path on one line, cut with an ellipsis when it does not fit. The full
/// path is in the tooltip.
/// One line of text that, when too long, keeps the start and the end and
/// puts "…" in the middle, so a path keeps its file name visible.
class MiddleEllipsisText extends StatelessWidget {
  const MiddleEllipsisText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  static String fit(
    String text,
    double maxWidth,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    bool fits(String value) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        maxLines: 1,
        textDirection: direction,
        textScaler: scaler,
      )..layout();
      final ok = painter.width <= maxWidth;
      painter.dispose();
      return ok;
    }

    if (!maxWidth.isFinite || fits(text)) return text;
    // Largest number of kept characters that fits, split ~40/60 so the
    // end (file name) gets more room.
    var low = 0;
    var high = text.length;
    String build(int keep) {
      final head = (keep * .4).floor();
      final tail = keep - head;
      return '${text.substring(0, head)}…${text.substring(text.length - tail)}';
    }

    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (fits(build(mid))) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return build(low);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final effective = DefaultTextStyle.of(context).style.merge(style);
      final shown = fit(
        text,
        constraints.maxWidth,
        effective,
        MediaQuery.textScalerOf(context),
        Directionality.of(context),
      );
      return Text(
        shown,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: style,
        semanticsLabel: text,
      );
    },
  );
}

/// A path on one line: shortened in the middle so the file name stays
/// visible, the full path in a tooltip and in screen-reader text, and an
/// optional copy button.
class PathLine extends StatelessWidget {
  const PathLine(
    this.path, {
    super.key,
    this.prefix = '',
    this.style = const TextStyle(color: CvColors.muted, fontSize: 12),
    this.copy = false,
  });
  final String path;
  final String prefix;
  final TextStyle? style;
  final bool copy;

  @override
  Widget build(BuildContext context) {
    final text = Tooltip(
      message: path,
      waitDuration: const Duration(milliseconds: 400),
      child: MiddleEllipsisText('$prefix$path', style: style),
    );
    if (!copy) return text;
    return Row(
      children: [
        Flexible(child: text),
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

/// Page body that owns its scrolling. The shell gives each page the full
/// content area; pages put lazy lists in [slivers] and keep selection
/// actions in [bottomBar], which stays visible. Content is centered at
/// [maxWidth] with responsive gutters.
class PageScroll extends StatefulWidget {
  const PageScroll({
    super.key,
    this.children = const [],
    this.slivers = const [],
    this.bottomBar,
    this.maxWidth = 1080,
  });

  /// Simple, short content placed before [slivers].
  final List<Widget> children;
  final List<Widget> slivers;
  final Widget? bottomBar;
  final double maxWidth;

  @override
  State<PageScroll> createState() => _PageScrollState();
}

class _PageScrollState extends State<PageScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final gutter = wide ? 40.0 : 16.0;
      final side = ((constraints.maxWidth - widget.maxWidth) / 2).clamp(
        gutter,
        double.infinity,
      );
      return Column(
        children: [
          Expanded(
            child: Scrollbar(
              controller: _controller,
              child: CustomScrollView(
                controller: _controller,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(side, wide ? 32 : 20, side, 0),
                    sliver: SliverList.list(children: widget.children),
                  ),
                  for (final sliver in widget.slivers)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: side),
                      sliver: sliver,
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 48)),
                ],
              ),
            ),
          ),
          if (widget.bottomBar != null)
            Container(
              decoration: const BoxDecoration(
                color: CvColors.sidebar,
                border: Border(top: BorderSide(color: CvColors.outlineSoft)),
              ),
              padding: EdgeInsets.symmetric(horizontal: side, vertical: 12),
              child: widget.bottomBar,
            ),
        ],
      );
    },
  );
}
