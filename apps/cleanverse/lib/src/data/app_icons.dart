import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Loads real Finder icons for apps and files on macOS through a small
/// native channel. Returns null elsewhere or on failure; callers show a
/// generic icon instead. Icons are cached in memory only.
class AppIcons {
  AppIcons({MethodChannel? channel, bool? supported, this.maxCached = 400})
    : _channel = channel ?? const MethodChannel('cleanverse/app_icon'),
      supported = supported ?? defaultTargetPlatform == TargetPlatform.macOS;
  final MethodChannel _channel;
  final bool supported;
  final int maxCached;

  // Insertion-ordered: the oldest entry is evicted first.
  final Map<String, Future<Uint8List?>> _cache = {};

  static final AppIcons instance = AppIcons();

  Future<Uint8List?> png(String path, {int size = 64}) {
    if (!supported) return Future.value(null);
    final key = '$size:$path';
    final cached = _cache.remove(key);
    if (cached != null) return _cache[key] = cached;
    final future = _load(path, size);
    _cache[key] = future;
    while (_cache.length > maxCached) {
      _cache.remove(_cache.keys.first);
    }
    return future;
  }

  Future<Uint8List?> _load(String path, int size) async {
    try {
      return await _channel.invokeMethod<Uint8List>('iconPng', {
        'path': path,
        'size': size,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
