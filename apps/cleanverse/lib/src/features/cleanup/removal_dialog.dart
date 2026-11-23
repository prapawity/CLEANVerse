// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;

import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/data/removal.dart';

enum ModeChoice { recommended, trash, permanent }

extension on ModeChoice {
  RemovalMode? get override => switch (this) {
    ModeChoice.recommended => null,
    ModeChoice.trash => RemovalMode.trash,
    ModeChoice.permanent => RemovalMode.permanent,
  };
}

String trashName() =>
    defaultTargetPlatform == TargetPlatform.windows ? 'Recycle Bin' : 'Trash';

/// Final confirmation. Returns the chosen override (null = recommended per
/// item) wrapped in a record, or null if the user cancelled.
Future<({RemovalMode? override, bool dryRun})?> confirmRemoval(
  BuildContext context, {
  required String title,
  required List<RemovalItem> items,
  List<String> warnings = const [],
  ModeChoice initial = ModeChoice.recommended,
  bool allowModeChoice = true,
}) {
  final bin = trashName();
  var choice = initial;
  final total = items.fold<int>(0, (s, i) => s + i.bytes);
  final permanentCount = items
      .where((i) => i.recommended == RemovalMode.permanent)
      .length;
  return showDialog<({RemovalMode? override, bool dryRun})>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final effective = [
          for (final item in items) choice.override ?? item.recommended,
        ];
        final permanent = effective
            .where((m) => m == RemovalMode.permanent)
            .length;
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 620,
            // Bounded height so the item list can be lazy; every item is
            // still listed and reachable by scrolling.
            height: (MediaQuery.sizeOf(context).height * .7).clamp(
              240.0,
              640.0,
            ),
            child: Scrollbar(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${plural(items.length, 'item')} · ${formatBytes(total)} observed',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: CvSpace.md),
                        if (!allowModeChoice)
                          Text(
                            'Everything is moved to the $bin, so you can put it back. '
                            'Space is freed after you empty the $bin.',
                          )
                        else
                          RadioGroup<ModeChoice>(
                            groupValue: choice,
                            onChanged: (value) =>
                                setState(() => choice = value ?? choice),
                            child: Column(
                              children: [
                                RadioListTile<ModeChoice>(
                                  value: ModeChoice.recommended,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Recommended for each item',
                                  ),
                                  subtitle: Text(
                                    '$permanentCount rebuildable caches deleted permanently; '
                                    'the rest moved to the $bin.',
                                  ),
                                ),
                                RadioListTile<ModeChoice>(
                                  value: ModeChoice.trash,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('Move everything to the $bin'),
                                  subtitle: Text(
                                    'Can be restored. Space is freed only after you empty the $bin.',
                                  ),
                                ),
                                RadioListTile<ModeChoice>(
                                  value: ModeChoice.permanent,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Delete everything permanently',
                                  ),
                                  subtitle: const Text(
                                    'Frees space now. Cannot be undone.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (permanent > 0)
                          Callout(
                            '$permanent ${permanent == 1 ? 'item' : 'items'} will be deleted permanently and cannot be restored.',
                            tone: CalloutTone.caution,
                          ),
                        for (final warning in warnings)
                          Callout(warning, tone: CalloutTone.caution),
                        const Divider(height: 24),
                      ],
                    ),
                  ),
                  SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            effective[i] == RemovalMode.permanent
                                ? Icons.delete_forever_outlined
                                : Icons.restore_from_trash_outlined,
                            size: 18,
                            color: effective[i] == RemovalMode.permanent
                                ? CvColors.rose
                                : CvColors.mint,
                            semanticLabel: effective[i] == RemovalMode.permanent
                                ? 'Delete permanently'
                                : 'Move to $bin',
                          ),
                          const SizedBox(width: CvSpace.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${items[i].label} · ${formatBytes(items[i].bytes)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SelectableText(
                                  items[i].scope == RemovalScope.contents
                                      ? 'Contents of ${items[i].path}'
                                      : items[i].path,
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
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(dialogContext)
                      .pop((override: choice.override, dryRun: true)),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Preview (dry run)'),
            ),
            FilledButton(
              style: permanent > 0
                  ? FilledButton.styleFrom(
                      backgroundColor: CvColors.rose,
                      foregroundColor: CvColors.onCyan,
                    )
                  : null,
              onPressed: () =>
                  Navigator.of(dialogContext)
                      .pop((override: choice.override, dryRun: false)),
              child: Text(
                permanent == items.length
                    ? 'Delete permanently'
                    : permanent == 0
                    ? 'Move to $bin'
                    : 'Clean ${plural(items.length, 'item')}',
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Per-item results, separating space freed now from items in the bin.
Future<void> showRemovalResults(
  BuildContext context,
  List<RemovalOutcome> outcomes,
) {
  final bin = trashName();
  final freed = outcomes.fold<int>(0, (s, o) => s + o.freedBytes);
  final trashed = outcomes
      .where((o) => o.status == RemovalStatus.movedToTrash)
      .fold<int>(0, (s, o) => s + o.item.bytes);
  final problems = outcomes
      .where(
        (o) =>
            o.status == RemovalStatus.failed ||
            o.status == RemovalStatus.partial ||
            o.status == RemovalStatus.skipped,
      )
      .length;
  String statusLabel(RemovalOutcome o) => switch (o.status) {
    RemovalStatus.removed => 'Deleted · ${formatBytes(o.freedBytes)} freed',
    RemovalStatus.movedToTrash => 'Moved to $bin',
    RemovalStatus.partial =>
      'Partly cleaned · ${formatBytes(o.freedBytes)} freed',
    RemovalStatus.skipped => 'Skipped',
    RemovalStatus.failed => 'Not cleaned',
    RemovalStatus.previewed => 'Would be cleaned',
  };
  final preview =
      outcomes.every(
        (o) =>
            o.status == RemovalStatus.previewed ||
            o.status == RemovalStatus.skipped,
      ) &&
      outcomes.any((o) => o.status == RemovalStatus.previewed);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        preview ? 'Preview: nothing was removed' : 'Cleanup finished',
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (preview)
                Text(
                  '${plural(outcomes.where((o) => o.status == RemovalStatus.previewed).length, 'item')} would be cleaned. '
                  'Close this and choose Clean to go ahead.',
                  style: Theme.of(context).textTheme.titleMedium,
                )
              else
                Text(
                  '${formatBytes(freed)} freed now',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              if (trashed > 0)
                Text(
                  '${formatBytes(trashed)} moved to the $bin. Empty it to free that space.',
                  style: const TextStyle(color: CvColors.muted),
                ),
              if (problems > 0)
                Padding(
                  padding: const EdgeInsets.only(top: CvSpace.sm),
                  child: Callout(
                    '${plural(problems, 'item')} could not be fully cleaned. Files in use are left alone.',
                    tone: CalloutTone.caution,
                  ),
                ),
              const Divider(height: 24),
              for (final o in outcomes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.item.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        statusLabel(o),
                        style: TextStyle(
                          color:
                              o.status == RemovalStatus.removed ||
                                  o.status == RemovalStatus.movedToTrash ||
                                  o.status == RemovalStatus.previewed
                              ? CvColors.mint
                              : CvColors.amber,
                          fontSize: 12,
                        ),
                      ),
                      if (o.message != null)
                        Text(
                          o.message!,
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
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

/// Confirm → (optional dry-run preview, repeatable) → remove → results.
/// Returns the outcomes of the real run, or null if cancelled.
Future<List<RemovalOutcome>?> runRemovalFlow(
  BuildContext context, {
  required String title,
  required List<RemovalItem> items,
  List<String> warnings = const [],
  Future<List<RemovalOutcome>> Function(RemovalMode? override)? execute,
  bool allowModeChoice = true,
}) async {
  while (true) {
    if (!context.mounted) return null;
    final choice = await confirmRemoval(
      context,
      title: title,
      items: items,
      warnings: warnings,
      allowModeChoice: allowModeChoice,
    );
    if (choice == null || !context.mounted) return null;
    if (choice.dryRun) {
      final preview = await executeRemoval(
        items,
        override: choice.override,
        dryRun: true,
      );
      if (!context.mounted) return null;
      await showRemovalResults(context, preview);
      continue; // back to the confirmation
    }
    final outcomes = execute == null
        ? await executeRemoval(items, override: choice.override)
        : await execute(choice.override);
    if (!context.mounted) return outcomes;
    if (outcomes.isNotEmpty) await showRemovalResults(context, outcomes);
    return outcomes;
  }
}
