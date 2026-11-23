// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/features/example/demo_scan.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';

/// Sample results that never touch the user's files.
class ExamplePage extends StatelessWidget {
  const ExamplePage({super.key, required this.model});
  final ScanViewModel model;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => PageScroll(
      maxWidth: 760,
      children: [
        const PageHeader(
          title: 'Sample data',
          subtitle: 'See sample results without scanning your files.',
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Callout(
              'This preview uses example data only. It does not access or change files on your device.',
            ),
            if (model.status == ScanStatus.scanning)
              OutlinedButton(
                onPressed: model.cancel,
                child: const Text('Cancel preview'),
              )
            else
              FilledButton.icon(
                onPressed: model.start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  model.status == ScanStatus.complete
                      ? 'Run example again'
                      : 'Show example results',
                ),
              ),
            if (model.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  model.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (model.status == ScanStatus.scanning)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (model.status == ScanStatus.complete) ...[
              const SectionTitle(
                'Example results',
                detail: 'These are not files from your device.',
              ),
              for (final item in model.items)
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      iconForCategory(item.category),
                      color: CvColors.violet,
                    ),
                    title: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(item.category),
                    trailing: Text(item.size),
                  ),
                ),
            ],
          ],
        ),
      ],
    ),
  );
}
