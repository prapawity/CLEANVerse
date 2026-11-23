// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/theme.dart';
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
    // Calm, dismissible note: one line of context and quiet text actions.
    return Container(
      margin: const EdgeInsets.only(bottom: CvSpace.lg),
      padding: const EdgeInsets.fromLTRB(CvSpace.md, CvSpace.md, CvSpace.md, 4),
      decoration: BoxDecoration(
        color: CvColors.sunken,
        borderRadius: BorderRadius.circular(CvRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: CvColors.muted,
            ),
          ),
          const SizedBox(width: CvSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Optional: allow Full Disk Access',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                const Text(
                  'macOS protects some folders, such as Mail and Safari data, so CLEANVerse '
                  'skips them and may show less than is there. Access never selects or '
                  'removes anything, and nothing leaves this computer.',
                  style: TextStyle(color: CvColors.muted, fontSize: 13),
                ),
                if (message != null) ...[
                  const SizedBox(height: CvSpace.xs),
                  Semantics(liveRegion: true, child: Text(message!)),
                ],
                Wrap(
                  spacing: CvSpace.xs,
                  children: [
                    TextButton(
                      onPressed: _open,
                      child: const Text('Open System Settings'),
                    ),
                    TextButton(
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
        ],
      ),
    );
  }
}
