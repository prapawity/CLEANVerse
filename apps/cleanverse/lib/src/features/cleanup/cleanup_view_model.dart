import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:cleanverse/src/data/protection.dart';

import 'package:cleanverse/src/features/cleanup/junk_catalog.dart';
import 'package:cleanverse/src/data/removal.dart';

class MeasuredJunk {
  const MeasuredJunk(this.target, this.bytes);
  final JunkTarget target;
  final int bytes;
  RemovalItem get item => target.toItem(bytes);
}

typedef JunkTargetLoader = Future<List<JunkTarget>> Function();

Future<List<JunkTarget>> defaultJunkTargets() => junkTargets(
  Platform.environment,
  windows: Platform.isWindows,
  macos: Platform.isMacOS,
);

/// Finds known junk locations, measures them, and removes what the user
/// selects. Nothing is selected automatically.
class CleanupViewModel extends ChangeNotifier {
  CleanupViewModel({JunkTargetLoader? loader, this.trash})
    : loader = loader ?? defaultJunkTargets;
  final JunkTargetLoader loader;
  final TrashBackend? trash;

  bool scanning = false;
  bool cleaning = false;
  bool _disposed = false;
  List<MeasuredJunk>? found;
  final Set<String> _selected = {};
  List<RemovalOutcome>? lastOutcomes;
  String? error;
  int progressDone = 0;
  int progressTotal = 0;

  bool get busy => scanning || cleaning;
  bool _stopScan = false;

  /// Stops measuring further locations; what was measured is kept.
  void cancelScan() {
    if (scanning) _stopScan = true;
  }

  bool isSelected(MeasuredJunk junk) => _selected.contains(junk.target.path);
  List<MeasuredJunk> get selected => [
    for (final junk in found ?? const <MeasuredJunk>[])
      if (_selected.contains(junk.target.path)) junk,
  ];
  int get selectedBytes => selected.fold(0, (s, j) => s + j.bytes);

  /// Locations labelled Safe. Offered by "Clean safe junk…", which only
  /// opens the confirmation; nothing here is selected.
  List<MeasuredJunk> get safe => [
    for (final junk in found ?? const <MeasuredJunk>[])
      if (junk.target.risk == JunkRisk.safe) junk,
  ];
  int get totalBytes =>
      (found ?? const <MeasuredJunk>[]).fold(0, (s, j) => s + j.bytes);

  List<MeasuredJunk> inGroup(JunkGroup group) => [
    for (final junk in found ?? const <MeasuredJunk>[])
      if (junk.target.group == group) junk,
  ];

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> scan({bool keepOutcomes = false}) async {
    if (busy) return;
    scanning = true;
    _stopScan = false;
    error = null;
    if (!keepOutcomes) lastOutcomes = null;
    _selected.clear();
    _notify();
    try {
      final targets = await loader();
      final measured = await Future.wait(
        targets.map((target) async {
          if (_stopScan) return null;
          final type = await FileSystemEntity.type(
            target.path,
            followLinks: false,
          );
          if (type != FileSystemEntityType.directory || _stopScan) return null;
          final bytes = await measureBytes(
            target.path,
            skipNames: target.keepNames,
          );
          return bytes == 0 ? null : MeasuredJunk(target, bytes);
        }),
      );
      final ignored = activeIgnoreList;
      found = [
        for (final junk in measured)
          if (junk != null && !(ignored?.covers(junk.target.path) ?? false))
            junk,
      ]..sort((a, b) => b.bytes.compareTo(a.bytes));
    } catch (_) {
      error = 'Could not check junk locations. Try again.';
    } finally {
      scanning = false;
      _notify();
    }
  }

  /// Removes an item from the list after the user ignores it.
  void hide(MeasuredJunk junk) {
    found = [
      for (final j in found ?? const <MeasuredJunk>[])
        if (j.target.path != junk.target.path) j,
    ];
    _selected.remove(junk.target.path);
    _notify();
  }

  void toggle(MeasuredJunk junk, bool value) {
    if (busy) return;
    value
        ? _selected.add(junk.target.path)
        : _selected.remove(junk.target.path);
    _notify();
  }

  void selectGroup(JunkGroup group, bool value) {
    if (busy) return;
    for (final junk in inGroup(group)) {
      value
          ? _selected.add(junk.target.path)
          : _selected.remove(junk.target.path);
    }
    _notify();
  }

  /// Removes [only] when given (the items the user just confirmed),
  /// otherwise the current selection.
  Future<List<RemovalOutcome>> clean({
    RemovalMode? override,
    List<MeasuredJunk>? only,
  }) async {
    final items = [for (final junk in only ?? selected) junk.item];
    if (busy || items.isEmpty) return const [];
    cleaning = true;
    progressDone = 0;
    progressTotal = items.length;
    _notify();
    try {
      final outcomes = await executeRemoval(
        items,
        override: override,
        trash: trash,
        onProgress: (done, total) {
          progressDone = done;
          _notify();
        },
      );
      lastOutcomes = outcomes;
      return outcomes;
    } finally {
      cleaning = false;
      _selected.clear();
      _notify();
      // Re-measure so the list reflects what is left.
      if (!_disposed) await scan(keepOutcomes: true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
