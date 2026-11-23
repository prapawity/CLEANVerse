import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:cleanverse/src/features/settings/app_settings.dart';
import 'package:cleanverse/src/features/update/installer.dart';
import 'package:cleanverse/src/features/update/update_manifest.dart';
import 'package:cleanverse/src/features/update/update_service.dart';

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  installing,
  error,
}

/// Coordinates update checks. Automatic checks run at most once a day and
/// only download after the user chooses to update.
class UpdateViewModel extends ChangeNotifier {
  UpdateViewModel({
    required this.settings,
    UpdateService? service,
    Future<String> Function()? currentVersion,
    this.install = installUpdate,
  }) : service = service ?? UpdateService(),
       _currentVersion = currentVersion ?? _packageVersion;
  final AppSettings settings;
  final UpdateService service;
  final Future<String> Function() _currentVersion;
  final Future<InstallResult> Function(UpdateAsset, File) install;

  static Future<String> _packageVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  UpdateStatus status = UpdateStatus.idle;
  String? version;
  UpdateManifest? available;
  String? error;
  double progress = 0;
  InstallResult? result;
  bool _disposed = false;

  void _set(UpdateStatus value) {
    status = value;
    if (!_disposed) notifyListeners();
  }

  bool get configured => service.configured;

  /// Called on startup.
  Future<void> checkIfDue() async {
    try {
      version ??= await _currentVersion();
    } catch (_) {
      return; // No platform info (for example in tests).
    }
    if (!_disposed) notifyListeners();
    if (!configured || !settings.autoCheckUpdates) return;
    final last = settings.lastUpdateCheck;
    if (last != null && DateTime.now().difference(last).inHours < 24) return;
    await check(automatic: true);
  }

  Future<void> check({bool automatic = false}) async {
    if (status == UpdateStatus.checking || status == UpdateStatus.downloading) {
      return;
    }
    error = null;
    _set(UpdateStatus.checking);
    try {
      version ??= await _currentVersion();
      final current = SemVer.tryParse(version!);
      final manifest = await service.fetchManifest();
      settings.lastUpdateCheck = DateTime.now();
      await settings.save();
      final key = currentPlatformKey();
      final newer =
          current != null &&
          !manifest.version.isPrerelease &&
          manifest.version > current &&
          key != null &&
          manifest.platforms.containsKey(key);
      final skipped =
          automatic && settings.skippedVersion == manifest.version.toString();
      available = newer && !skipped ? manifest : null;
      _set(available == null ? UpdateStatus.upToDate : UpdateStatus.available);
    } on UpdateException catch (e) {
      error = e.message;
      // Quiet on automatic checks; shown only when the user asked.
      _set(automatic ? UpdateStatus.idle : UpdateStatus.error);
    } catch (_) {
      error = 'Could not check for updates.';
      _set(automatic ? UpdateStatus.idle : UpdateStatus.error);
    }
  }

  Future<void> skip() async {
    final manifest = available;
    if (manifest == null) return;
    settings.skippedVersion = manifest.version.toString();
    await settings.save();
    available = null;
    _set(UpdateStatus.upToDate);
  }

  Future<void> downloadAndInstall() async {
    final manifest = available;
    final key = currentPlatformKey();
    final asset = key == null ? null : manifest?.platforms[key];
    if (asset == null) return;
    progress = 0;
    error = null;
    _set(UpdateStatus.downloading);
    try {
      final dir = await Directory.systemTemp.createTemp('cleanverse_update');
      final file = await service.download(
        asset,
        dir,
        onProgress: (value) {
          progress = value;
          if (!_disposed) notifyListeners();
        },
      );
      _set(UpdateStatus.installing);
      result = await install(asset, file);
      if (result == InstallResult.restarting) {
        // Give the helper a moment, then exit so files can be replaced.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        exit(0);
      }
      _set(UpdateStatus.available);
    } on UpdateException catch (e) {
      error = e.message;
      _set(UpdateStatus.error);
    } catch (_) {
      error = 'The update could not be installed.';
      _set(UpdateStatus.error);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
