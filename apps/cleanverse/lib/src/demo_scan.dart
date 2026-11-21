import 'package:flutter/foundation.dart';

enum ScanStatus { idle, scanning, complete }

@immutable
class ScanItem {
  const ScanItem(this.name, this.size, this.category);
  final String name;
  final String size;
  final String category;
}

abstract interface class ScanRepository {
  Future<List<ScanItem>> scanExample();
}

/// Fixed examples; never accesses files or platform APIs.
class DemoScanRepository implements ScanRepository {
  @override
  Future<List<ScanItem>> scanExample() async => const [
    ScanItem('Holiday video.mp4', '1.2 GB', 'Large file'),
    ScanItem('Presentation copy.pdf', '42 MB', 'Possible duplicate'),
    ScanItem('Presentation.pdf', '42 MB', 'Possible duplicate'),
  ];
}

class ScanViewModel extends ChangeNotifier {
  ScanViewModel(this._repository);
  final ScanRepository _repository;
  ScanStatus status = ScanStatus.idle;
  List<ScanItem> items = const [];
  String? error;
  int _generation = 0;
  bool _disposed = false;

  Future<void> start() async {
    if (status == ScanStatus.scanning) return;
    final generation = ++_generation;
    status = ScanStatus.scanning;
    items = const [];
    error = null;
    notifyListeners();
    try {
      final result = await _repository.scanExample();
      if (_disposed || generation != _generation) return;
      items = List.unmodifiable(result);
      status = ScanStatus.complete;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      status = ScanStatus.idle;
      error = 'The example could not be loaded. Try again.';
    }
    if (!_disposed) notifyListeners();
  }

  void cancel() {
    _generation++;
    status = ScanStatus.idle;
    items = const [];
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
