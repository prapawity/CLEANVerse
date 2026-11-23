// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/features/cleanup/full_disk_access.dart';

/// Optional macOS onboarding. Shown only when access is known to be
/// missing; CLEANVerse works without it and skips protected locations.
class FullDiskAccessBanner extends StatefulWidget {
  const FullDiskAccessBanner({super.key, this.check, this.openSettings});
  final Future<FullDiskAccess> Function()? check;
  final Future<bool> Function()? openSettings;

  @override
  State<FullDiskAccessBanner> createState() => _FullDiskAccessBannerState();
}

class _FullDiskAccessBannerState extends State<FullDiskAccessBanner> {
  FullDiskAccess? access;
  bool dismissed = false;
  String? message;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final value = await (widget.check ?? checkFullDiskAccess)();
    if (!mounted) return;
    setState(() {
      access = value;
      message = value == FullDiskAccess.granted
          ? 'Full Disk Access is on.'
          : (message == null
                ? null
                : 'Still off. macOS may need CLEANVerse to restart.');
    });
  }

  Future<void> _open() async {
    final ok = await (widget.openSettings ?? openFullDiskAccessSettings)();
    if (!mounted) return;
    setState(() {
      message = ok
          ? 'In System Settings, turn on CLEANVerse, then check again.'
          : 'Open System Settings → Privacy & Security → Full Disk Access.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (dismissed || access != FullDiskAccess.denied) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: CvSpace.lg),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: CvColors.amber),
                const SizedBox(width: CvSpace.sm),
                Expanded(
                  child: Text(
                    'Optional: allow Full Disk Access',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CvSpace.sm),
            const Text(
              'macOS protects some folders, such as Mail and Safari data. Without access, '
              'CLEANVerse skips them and may show less than is there. You can keep using '
              'CLEANVerse without it. Access never makes anything selected or removed '
              'automatically, and nothing leaves this computer.',
              style: TextStyle(color: CvColors.muted),
            ),
            if (message != null) ...[
              const SizedBox(height: CvSpace.sm),
              Semantics(liveRegion: true, child: Text(message!)),
            ],
            const SizedBox(height: CvSpace.md),
            Wrap(
              spacing: CvSpace.sm,
              runSpacing: CvSpace.sm,
              children: [
                FilledButton.icon(
                  onPressed: _open,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Open System Settings'),
                ),
                OutlinedButton(
                  onPressed: _check,
                  child: const Text('Check again'),
                ),
                TextButton(
                  onPressed: () => setState(() => dismissed = true),
                  child: const Text('Not now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
