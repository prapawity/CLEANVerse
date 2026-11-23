import 'dart:io';

/// Home folder used for the default developer scan, or null if unknown.
String? defaultScanRoot([Map<String, String>? env]) {
  final e = env ?? Platform.environment;
  final home = e['HOME'] ?? e['USERPROFILE'];
  return home == null || home.isEmpty ? null : home;
}
