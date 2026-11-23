// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/data/app_icons.dart';

/// The real icon of an app or file when available (macOS), otherwise
/// [fallback]. Decorative: the row's text names the item.
class AppIcon extends StatefulWidget {
  const AppIcon(
    this.path, {
    super.key,
    this.size = 32,
    this.fallback = Icons.apps_rounded,
    this.icons,
  });
  final String path;
  final double size;
  final IconData fallback;
  final AppIcons? icons;

  @override
  State<AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<AppIcon> {
  late Future<dynamic> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AppIcon old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.size != widget.size) _load();
  }

  void _load() {
    final dpr =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    _future = (widget.icons ?? AppIcons.instance).png(
      widget.path,
      size: (widget.size * dpr).round(),
    );
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: widget.size,
      child: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            return Icon(
              widget.fallback,
              size: widget.size * .75,
              color: CvColors.violet,
            );
          }
          return Image.memory(
            bytes,
            width: widget.size,
            height: widget.size,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          );
        },
      ),
    ),
  );
}
