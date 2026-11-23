import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:cleanverse/src/features/update/update_manifest.dart';

/// What happened after handing a verified download to the platform.
enum InstallResult {
  /// The app will close and relaunch on the new version.
  restarting,

  /// The installer or disk image was opened; the user finishes it.
  openedInstaller,

  /// The file was saved; the user installs it manually.
  savedOnly,
}

/// Hands a verified update to the operating system. Only called after the
/// user confirms. The previous version is kept for rollback on Windows and
/// for AppImage.
Future<InstallResult> installUpdate(UpdateAsset asset, File file) async {
  final exe = Platform.resolvedExecutable;
  if (Platform.isWindows && asset.kind == 'zip') {
    final installDir = p.dirname(exe);
    if (!await _writable(installDir)) {
      await Process.start('explorer.exe', ['/select,', file.path]);
      return InstallResult.savedOnly;
    }
    // The running exe cannot be replaced, so a small script waits for this
    // process to exit, swaps folders (keeping a backup) and relaunches.
    final script = File(p.join(file.parent.path, 'apply_update.ps1'));
    await script.writeAsString(r'''
param([int]$ProcessId, [string]$Zip, [string]$Target, [string]$Exe)
$ErrorActionPreference = 'Stop'
try { Wait-Process -Id $ProcessId -Timeout 60 } catch {}
$staging = Join-Path ([System.IO.Path]::GetDirectoryName($Zip)) 'staging'
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
Expand-Archive -LiteralPath $Zip -DestinationPath $staging -Force
$inner = Get-ChildItem $staging -Recurse -Filter ([System.IO.Path]::GetFileName($Exe)) | Select-Object -First 1
if (-not $inner) { throw 'Update package does not contain the app.' }
$backup = "$Target.previous"
if (Test-Path $backup) { Remove-Item $backup -Recurse -Force }
Copy-Item $Target $backup -Recurse -Force
try {
  Get-ChildItem $Target | Remove-Item -Recurse -Force
  Copy-Item (Join-Path $inner.DirectoryName '*') $Target -Recurse -Force
} catch {
  Get-ChildItem $Target | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  Copy-Item (Join-Path $backup '*') $Target -Recurse -Force
}
Start-Process -FilePath $Exe
''');
    await Process.start('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-WindowStyle',
      'Hidden',
      '-File',
      script.path,
      '-ProcessId',
      '$pid',
      '-Zip',
      file.path,
      '-Target',
      installDir,
      '-Exe',
      exe,
    ], mode: ProcessStartMode.detached);
    return InstallResult.restarting;
  }
  if (Platform.isMacOS && asset.kind == 'dmg') {
    await Process.run('open', [file.path]);
    return InstallResult.openedInstaller;
  }
  if (Platform.isLinux && asset.kind == 'appimage') {
    final current = Platform.environment['APPIMAGE'];
    if (current != null && await _writable(p.dirname(current))) {
      final backup = '$current.previous';
      await File(current).copy(backup);
      await file.copy('$current.new');
      await Process.run('chmod', ['+x', '$current.new']);
      await File('$current.new').rename(current);
      await Process.start(current, const [], mode: ProcessStartMode.detached);
      return InstallResult.restarting;
    }
  }
  // Fallback: reveal the verified file.
  if (Platform.isMacOS) {
    await Process.run('open', ['-R', file.path]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [file.parent.path]);
  } else if (Platform.isWindows) {
    await Process.start('explorer.exe', ['/select,', file.path]);
  }
  return InstallResult.savedOnly;
}

Future<bool> _writable(String directory) async {
  try {
    final probe = File(p.join(directory, '.cleanverse_write_test'));
    await probe.writeAsString('ok');
    await probe.delete();
    return true;
  } catch (_) {
    return false;
  }
}
