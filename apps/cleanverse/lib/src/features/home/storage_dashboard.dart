// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/data/volumes.dart';
import 'package:cleanverse/src/features/home/storage_breakdown.dart';

Color storageColor(StorageKind kind) => switch (kind) {
  StorageKind.junk => CvColors.amber,
  StorageKind.apps => CvColors.violet,
  StorageKind.developer => CvColors.cyan,
  StorageKind.files => CvColors.mint,
  StorageKind.other => const Color(0xff5b6282),
  StorageKind.free => CvColors.sunken,
};

Section? _targetFor(StorageKind kind, bool appsSupported) => switch (kind) {
  StorageKind.junk => Section.cleanup,
  StorageKind.apps => appsSupported ? Section.apps : null,
  StorageKind.developer => Section.developer,
  StorageKind.files => Section.storage,
  _ => null,
};

/// Dashboard for the drives: the system drive split into what can be
/// cleaned, apps, developer data, your files, system and free space; other
/// drives as compact rows. Figures are logical sizes, so slices are
/// approximate; the card says so.
class StorageDashboard extends StatelessWidget {
  const StorageDashboard({
    super.key,
    required this.volumes,
    required this.onNavigate,
    this.homeBytes,
    this.junkBytes,
    this.developerBytes,
    this.appsBytes,
    this.appsMeasuring = false,
    this.appsSupported = false,
  });
  final VolumesModel volumes;
  final ValueChanged<Section> onNavigate;

  /// Null until the home folder has been scanned.
  final int? homeBytes;
  final int? junkBytes;
  final int? developerBytes;
  final int? appsBytes;
  final bool appsMeasuring;
  final bool appsSupported;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: volumes,
    builder: (context, _) {
      final list = volumes.volumes;
      if (list == null) {
        return volumes.loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: CvSpace.xl),
                child: LinearProgressIndicator(),
              )
            : const SizedBox.shrink();
      }
      final drive = volumes.system;
      if (drive == null) return const SizedBox.shrink();
      final scanned = homeBytes != null;
      final slices = scanned
          ? breakdown(
              drive: drive,
              homeBytes: homeBytes,
              junkBytes: junkBytes ?? 0,
              developerBytes: developerBytes ?? 0,
              appsBytes: appsBytes ?? 0,
            )
          : [
              StorageSlice(StorageKind.other, drive.usedBytes),
              StorageSlice(StorageKind.free, drive.freeBytes),
            ];
      final others = [
        for (final v in list)
          if (!identical(v, drive)) v,
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drive.name,
                      style: const TextStyle(color: CvColors.muted),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: formatBytes(drive.freeBytes),
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          TextSpan(
                            text: '  free of ${formatBytes(drive.totalBytes)}',
                            style: const TextStyle(
                              color: CvColors.muted,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh drive sizes',
                onPressed: volumes.loading ? null : volumes.load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: CvSpace.md),
          _SegmentBar(slices: slices, total: drive.totalBytes),
          const SizedBox(height: CvSpace.md),
          if (!scanned)
            const Text(
              'Scan to see how much is junk, apps, developer data and your own files.',
              style: TextStyle(color: CvColors.muted),
            )
          else ...[
            for (final s in slices)
              _LegendRow(
                slice: s,
                measuring: s.kind == StorageKind.apps && appsMeasuring,
                onOpen: switch (_targetFor(s.kind, appsSupported)) {
                  final target? => () => onNavigate(target),
                  null => null,
                },
              ),
            if (appsSupported && appsMeasuring && (appsBytes ?? 0) == 0)
              const _LegendNote('Apps: measuring sizes…'),
            const _LegendNote(
              'Sizes are what files report, so the slices are approximate.',
            ),
          ],
          if (others.isNotEmpty) ...[
            const SizedBox(height: CvSpace.xl),
            const Text(
              'Other drives',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: CvSpace.sm),
            for (final v in others) _DriveRow(volume: v),
          ],
        ],
      );
    },
  );
}

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.slices, required this.total});
  final List<StorageSlice> slices;
  final int total;

  @override
  Widget build(BuildContext context) {
    final label = [
      for (final s in slices) '${s.kind.label} ${formatBytes(s.bytes)}',
    ].join(', ');
    return Semantics(
      label: 'Drive usage: $label',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 22,
            decoration: BoxDecoration(
              color: CvColors.sunken,
              border: Border.all(color: CvColors.outlineSoft),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                for (final s in slices)
                  if (s.kind != StorageKind.free && s.bytes > 0)
                    Expanded(
                      flex: total == 0
                          ? 1
                          : (s.bytes * 1000 ~/ total).clamp(1, 1000),
                      child: Container(
                        margin: const EdgeInsets.only(right: 1),
                        color: storageColor(s.kind),
                      ),
                    ),
                Expanded(
                  flex: total == 0
                      ? 1
                      : (slices.last.bytes * 1000 ~/ total).clamp(1, 1000),
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, this.onOpen, this.measuring = false});
  final StorageSlice slice;
  final VoidCallback? onOpen;
  final bool measuring;

  @override
  Widget build(BuildContext context) {
    final free = slice.kind == StorageKind.free;
    final junk = slice.kind == StorageKind.junk;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(CvRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: storageColor(slice.kind),
                borderRadius: BorderRadius.circular(3),
                border: free ? Border.all(color: CvColors.outline) : null,
              ),
            ),
            const SizedBox(width: CvSpace.md),
            Expanded(
              child: Text(
                slice.kind.label,
                style: TextStyle(
                  fontWeight: junk ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              measuring
                  ? '${formatBytes(slice.bytes)}+'
                  : formatBytes(slice.bytes),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: junk ? CvColors.amber : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(
              width: 28,
              child: onOpen == null
                  ? null
                  : const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: CvColors.muted,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendNote extends StatelessWidget {
  const _LegendNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: CvSpace.sm),
    child: Text(
      text,
      style: const TextStyle(color: CvColors.muted, fontSize: 12),
    ),
  );
}

class _DriveRow extends StatelessWidget {
  const _DriveRow({required this.volume});
  final Volume volume;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(
          volume.removable ? Icons.usb_rounded : Icons.storage_rounded,
          size: 18,
          color: CvColors.muted,
        ),
        const SizedBox(width: CvSpace.md),
        Expanded(
          flex: 3,
          child: Text(volume.name, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: CvSpace.md),
        Expanded(
          flex: 4,
          child: Semantics(
            label: '${(volume.usedFraction * 100).round()} percent used',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: volume.usedFraction,
                minHeight: 6,
                backgroundColor: CvColors.sunken,
                color: volume.usedFraction > .9 ? CvColors.rose : CvColors.cyan,
              ),
            ),
          ),
        ),
        const SizedBox(width: CvSpace.md),
        Text(
          '${formatBytes(volume.freeBytes)} free',
          style: const TextStyle(
            color: CvColors.muted,
            fontSize: 12,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
