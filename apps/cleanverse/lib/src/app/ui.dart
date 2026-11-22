import 'dart:math' as math;

// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
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
