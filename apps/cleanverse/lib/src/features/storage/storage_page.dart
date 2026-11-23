// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// Storage area: biggest files, folders and duplicates as tabs.
///
/// Each tab page owns its scrolling (lazy slivers, pinned selection bar), so
/// pass the pages directly, not wrapped in another scroll view. A wrapped
/// page still works but loses laziness.
class StoragePage extends StatefulWidget {
  const StoragePage({
    super.key,
    required this.files,
    required this.folders,
    required this.duplicates,
    this.initialTab = 0,
  });
  final Widget files;
  final Widget folders;
  final Widget duplicates;
  final int initialTab;

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    initialIndex: widget.initialTab,
    child: Column(
      children: [
        const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Biggest files'),
            Tab(text: 'Folders'),
            Tab(text: 'Duplicates'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [widget.files, widget.folders, widget.duplicates],
          ),
        ),
      ],
    ),
  );
}
