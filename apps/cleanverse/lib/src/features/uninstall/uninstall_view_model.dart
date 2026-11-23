import 'package:flutter/foundation.dart';

import 'package:cleanverse/src/data/removal.dart';
import 'package:cleanverse/src/features/uninstall/app_catalog.dart';

/// Lists apps, finds one app's leftovers, and moves what the user selects
/// to the Trash. Nothing is selected automatically.
class UninstallViewModel extends ChangeNotifier {
  UninstallViewModel({AppCatalog? catalog, this.trash})
    : catalog = catalog ?? AppCatalog();
  final AppCatalog catalog;
  final TrashBackend? trash;

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
    return [
      for (final a in apps ?? const <InstalledApp>[])
        if (q.isEmpty ||
            a.name.toLowerCase().contains(q) ||
            a.bundleId.toLowerCase().contains(q))
          a,
    ];
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
        measured.add(l.withBytes(await measureBytes(l.path)));
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
    super.dispose();
  }
}
