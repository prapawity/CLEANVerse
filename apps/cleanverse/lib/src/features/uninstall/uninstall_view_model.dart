import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:cleanverse/src/data/removal.dart';
import 'package:cleanverse/src/features/uninstall/app_catalog.dart';

/// Measures a path in bytes. Replaceable in tests so no real I/O runs.
typedef SizeMeasurer = Future<int> Function(String path);

enum AppSort { name, size }

/// Lists apps, finds one app's leftovers, and moves what the user selects
/// to the Trash. Nothing is selected automatically.
class UninstallViewModel extends ChangeNotifier {
  UninstallViewModel({
    AppCatalog? catalog,
    this.trash,
    SizeMeasurer? measure,
    this.sizeConcurrency = 3,
  }) : catalog = catalog ?? AppCatalog(),
       measure = measure ?? ((path) => measureBytes(path));
  final AppCatalog catalog;
  final TrashBackend? trash;
  final SizeMeasurer measure;

  /// How many app bundles are measured at once in the background.
  final int sizeConcurrency;

  /// Bundle sizes measured so far, by app path. Missing means "Measuring…".
  final Map<String, int> appSizes = {};
  bool measuringSizes = false;
  AppSort sort = AppSort.name;
  int _sizeRun = 0;

  /// Size order captured when the user picks "Size" while sizes are still
  /// being measured, so rows don't jump around. Cleared when measuring ends.
  Map<String, int>? _frozenOrder;

  bool loadingApps = false;
  bool loadingLeftovers = false;
  bool removing = false;
  bool _disposed = false;
  List<InstalledApp>? apps;
  String query = '';
  InstalledApp? selectedApp;
  List<Leftover>? leftovers;
  bool? running;
  List<RemovalOutcome>? lastOutcomes;
  final Set<String> _selected = {};

  bool get busy => loadingApps || loadingLeftovers || removing;

  List<InstalledApp> get visibleApps {
    final q = query.trim().toLowerCase();
    final list = [
      for (final a in apps ?? const <InstalledApp>[])
        if (q.isEmpty ||
            a.name.toLowerCase().contains(q) ||
            a.bundleId.toLowerCase().contains(q))
          a,
    ];
    int byName(InstalledApp a, InstalledApp b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    final frozen = _frozenOrder;
    if (sort == AppSort.size && frozen != null) {
      list.sort((a, b) {
        final c = (frozen[a.path] ?? 1 << 30).compareTo(
          frozen[b.path] ?? 1 << 30,
        );
        return c != 0 ? c : byName(a, b);
      });
    } else if (sort == AppSort.size) {
      // Measured apps first, biggest first; unmeasured keep name order.
      list.sort((a, b) {
        final sa = appSizes[a.path];
        final sb = appSizes[b.path];
        if (sa == null && sb == null) return byName(a, b);
        if (sa == null) return 1;
        if (sb == null) return -1;
        final c = sb.compareTo(sa);
        return c != 0 ? c : byName(a, b);
      });
    } else {
      list.sort(byName);
    }
    return list;
  }

  void setSort(AppSort value) {
    sort = value;
    _frozenOrder = null;
    if (value == AppSort.size && measuringSizes) {
      final ordered = visibleApps;
      _frozenOrder = {
        for (var i = 0; i < ordered.length; i++) ordered[i].path: i,
      };
    }
    _notify();
  }

  /// Measures bundle sizes in the background, a few at a time, so the
  /// list is usable straight away.
  Future<void> _measureApps(List<InstalledApp> list) async {
    final run = ++_sizeRun;
    final queue = [
      for (final a in list)
        if (!appSizes.containsKey(a.path)) a,
    ];
    if (queue.isEmpty) return;
    measuringSizes = true;
    _notify();
    var next = 0;
    Future<void> worker() async {
      while (!_disposed && run == _sizeRun && next < queue.length) {
        final app = queue[next++];
        int bytes;
        try {
          bytes = await measure(app.path);
        } catch (_) {
          bytes = 0;
        }
        if (_disposed || run != _sizeRun) return;
        appSizes[app.path] = bytes;
        _notify();
      }
    }

    await Future.wait([
      for (var i = 0; i < sizeConcurrency.clamp(1, 16); i++) worker(),
    ]);
    if (run == _sizeRun) {
      measuringSizes = false;
      _frozenOrder = null;
      _notify();
    }
  }

  List<Leftover> get removable => [
    for (final l in leftovers ?? const <Leftover>[])
      if (l.removable) l,
  ];
  List<Leftover> get systemWide => [
    for (final l in leftovers ?? const <Leftover>[])
      if (!l.removable) l,
  ];
  List<Leftover> get selected => [
    for (final l in removable)
      if (_selected.contains(l.path)) l,
  ];
  int get selectedBytes => selected.fold(0, (s, l) => s + l.bytes);
  bool isSelected(Leftover l) => _selected.contains(l.path);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setQuery(String value) {
    query = value;
    _notify();
  }

  Future<void> loadApps() async {
    if (busy) return;
    loadingApps = true;
    _notify();
    try {
      apps = await catalog.listApps();
    } finally {
      loadingApps = false;
      _notify();
    }
    final list = apps;
    if (list != null && !_disposed) unawaited(_measureApps(list));
  }

  Future<void> open(InstalledApp app, {bool keepOutcomes = false}) async {
    if (removing) return;
    selectedApp = app;
    leftovers = null;
    running = null;
    if (!keepOutcomes) lastOutcomes = null;
    _selected.clear();
    loadingLeftovers = true;
    _notify();
    try {
      final found = await catalog.findLeftovers(app);
      final measured = <Leftover>[];
      for (final l in found) {
        int bytes;
        try {
          bytes = await measure(l.path);
        } catch (_) {
          bytes = 0;
        }
        measured.add(l.withBytes(bytes));
      }
      if (selectedApp != app) return;
      leftovers = measured;
      running = await catalog.isRunning(app);
    } finally {
      loadingLeftovers = false;
      _notify();
    }
  }

  void close() {
    if (removing) return;
    selectedApp = null;
    leftovers = null;
    lastOutcomes = null;
    _selected.clear();
    _notify();
  }

  void toggle(Leftover l, bool value) {
    if (busy || !l.removable) return;
    value ? _selected.add(l.path) : _selected.remove(l.path);
    _notify();
  }

  /// Explicit user action; still followed by the confirmation dialog.
  void selectAll(bool value) {
    if (busy) return;
    _selected.clear();
    if (value) _selected.addAll(removable.map((l) => l.path));
    _notify();
  }

  /// Always moves to the Trash; [override] is ignored on purpose so no
  /// caller can turn an uninstall into a permanent deletion.
  Future<List<RemovalOutcome>> remove({RemovalMode? override}) async {
    final app = selectedApp;
    if (app == null || busy) return const [];
    removing = true;
    _notify();
    try {
      // Re-check right before acting: never remove a running app.
      running = await catalog.isRunning(app);
      if (running == true) {
        return lastOutcomes = const [];
      }
      final items = [for (final l in selected) l.toItem(_label(app, l))];
      final outcomes = await executeRemoval(
        items,
        override: RemovalMode.trash,
        trash: trash,
      );
      lastOutcomes = outcomes;
      return outcomes;
    } finally {
      removing = false;
      _notify();
      if (!_disposed && app == selectedApp) {
        await open(app, keepOutcomes: true);
        if (lastOutcomes != null &&
            lastOutcomes!.any(
              (o) =>
                  o.item.path == app.path &&
                  (o.status == RemovalStatus.movedToTrash ||
                      o.status == RemovalStatus.removed),
            )) {
          apps = [
            for (final a in apps ?? const <InstalledApp>[])
              if (a.path != app.path) a,
          ];
          _notify();
        }
      }
    }
  }

  String _label(InstalledApp app, Leftover l) =>
      '${app.name} · ${l.kind.label}';

  @override
  void dispose() {
    _disposed = true;
    _sizeRun++;
    super.dispose();
  }
}
