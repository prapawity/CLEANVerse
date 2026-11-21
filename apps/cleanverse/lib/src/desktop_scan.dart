import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';

class LargeFile {
  const LargeFile(this.path, this.bytes);
  final String path;
  final int bytes;
}

class FolderScanResult {
  const FolderScanResult(this.files, this.skipped, this.cancelled);
  final List<LargeFile> files;
  final int skipped;
  final bool cancelled;
}

abstract interface class FolderScanner {
  Future<FolderScanResult> scan(String path, bool Function() cancelled);
}

class LocalFolderScanner implements FolderScanner {
  @override
  Future<FolderScanResult> scan(String path, bool Function() cancelled) async {
    final root = Directory(path);
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FileSystemException(
        'Selected folder is unavailable or is a link.',
      );
    }
    final pending = <Directory>[root];
    final files = <LargeFile>[];
    var skipped = 0;
    while (pending.isNotEmpty && !cancelled()) {
      final directory = pending.removeLast();
      try {
        if (await FileSystemEntity.type(directory.path, followLinks: false) !=
            FileSystemEntityType.directory) {
          skipped++;
          continue;
        }
        await for (final entity in directory.list(followLinks: false)) {
          if (cancelled()) break;
          try {
            final type = await FileSystemEntity.type(
              entity.path,
              followLinks: false,
            );
            if (type == FileSystemEntityType.directory) {
              pending.add(Directory(entity.path));
            } else if (type == FileSystemEntityType.file) {
              final stat = await entity.stat();
              if (stat.type == FileSystemEntityType.file) {
                if (files.length < 100 || stat.size > files.last.bytes) {
                  files.add(LargeFile(entity.path, stat.size));
                  files.sort((a, b) => b.bytes.compareTo(a.bytes));
                  if (files.length > 100) files.removeLast();
                }
              } else {
                skipped++;
              }
            } else {
              skipped++;
            }
          } on FileSystemException {
            skipped++;
          }
        }
      } on FileSystemException {
        skipped++;
      }
    }
    files.sort((a, b) => b.bytes.compareTo(a.bytes));
    return FolderScanResult(
      List.unmodifiable(files.take(100)),
      skipped,
      cancelled(),
    );
  }
}

class FolderScanViewModel extends ChangeNotifier {
  FolderScanViewModel(this.scanner, this.pickFolder);
  final FolderScanner scanner;
  final Future<String?> Function() pickFolder;
  bool busy = false;
  bool _cancelled = false;
  bool _disposed = false;
  String? root;
  String? error;
  FolderScanResult? result;

  Future<void> start() async {
    if (busy) return;
    busy = true;
    _cancelled = false;
    error = null;
    result = null;
    root = null;
    notifyListeners();
    try {
      final selected = await pickFolder();
      if (_disposed || _cancelled || selected == null) return;
      root = selected;
      notifyListeners();
      result = await scanner.scan(selected, () => _cancelled || _disposed);
    } catch (_) {
      error = 'Unable to scan this folder. Check access and try again.';
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void cancel() {
    _cancelled = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelled = true;
    super.dispose();
  }
}

Future<String?> chooseFolder() =>
    getDirectoryPath(confirmButtonText: 'Choose folder');
