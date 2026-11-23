import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import 'package:cleanverse/src/features/update/update_config.dart';
import 'package:cleanverse/src/features/update/update_manifest.dart';

class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Platform key used in `latest.json`, or null when updates are unsupported.
String? currentPlatformKey() {
  if (Platform.isWindows) return 'windows-x64';
  if (Platform.isMacOS) return 'macos-universal';
  if (Platform.isLinux) return 'linux-x64';
  return null;
}

/// Checks GitHub Releases through a static, signed `latest.json`
/// (no API rate limit), and downloads assets with hash verification.
/// Nothing is installed without the user's confirmation.
class UpdateService {
  UpdateService({HttpClient Function()? client, this.config = updateConfig})
    : _client = client ?? HttpClient.new;
  final HttpClient Function() _client;
  final UpdateConfig config;

  bool get configured => config.publicKeyBase64.isNotEmpty;

  Future<List<int>> _get(
    Uri url, {
    int maxBytes = 64 * 1024,
    void Function(int received)? onBytes,
    IOSink? sink,
  }) async {
    var current = url;
    final client = _client()..connectionTimeout = const Duration(seconds: 15);
    try {
      for (var hop = 0; hop < 6; hop++) {
        if (current.scheme != 'https' ||
            !config.allowedHosts.contains(current.host)) {
          throw UpdateException('Blocked download from ${current.host}.');
        }
        final request = await client.getUrl(current);
        request.followRedirects = false;
        request.headers.set(HttpHeaders.userAgentHeader, 'CLEANVerse-updater');
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          if (location == null) break;
          current = current.resolve(location);
          continue;
        }
        if (response.statusCode != 200) {
          await response.drain<void>();
          throw UpdateException(
            response.statusCode == 404
                ? 'No published release was found.'
                : 'Update server returned ${response.statusCode}.',
          );
        }
        final bytes = <int>[];
        var received = 0;
        await for (final chunk in response) {
          received += chunk.length;
          if (received > maxBytes) {
            throw const UpdateException('Download is larger than expected.');
          }
          if (sink != null) {
            sink.add(chunk);
          } else {
            bytes.addAll(chunk);
          }
          onBytes?.call(received);
        }
        return bytes;
      }
      throw const UpdateException('Too many redirects.');
    } on SocketException {
      throw const UpdateException('No internet connection.');
    } on TimeoutException {
      throw const UpdateException('The update server did not respond.');
    } finally {
      client.close(force: true);
    }
  }

  /// Fetches and verifies the manifest. Throws [UpdateException] when the
  /// signature does not match the key built into this app.
  Future<UpdateManifest> fetchManifest() async {
    if (!configured) {
      throw const UpdateException('Updates are not configured for this build.');
    }
    final base =
        'https://github.com/${config.repository}/releases/latest/download';
    final manifestBytes = await _get(Uri.parse('$base/latest.json'));
    final signature = utf8.decode(
      await _get(Uri.parse('$base/latest.json.sig'), maxBytes: 1024),
    );
    if (!await verifySignature(manifestBytes, signature.trim())) {
      throw const UpdateException(
        'The update information is not signed by the CLEANVerse publisher.',
      );
    }
    return UpdateManifest.parse(utf8.decode(manifestBytes));
  }

  Future<bool> verifySignature(
    List<int> message,
    String signatureBase64,
  ) async {
    try {
      final algorithm = Ed25519();
      return await algorithm.verify(
        message,
        signature: Signature(
          base64Decode(signatureBase64),
          publicKey: SimplePublicKey(
            base64Decode(config.publicKeyBase64),
            type: KeyPairType.ed25519,
          ),
        ),
      );
    } on FormatException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Downloads [asset] into [directory], checking size and SHA-256.
  Future<File> download(
    UpdateAsset asset,
    Directory directory, {
    void Function(double progress)? onProgress,
  }) async {
    final name = p.basename(asset.url.path);
    if (name.isEmpty || name.contains('..')) {
      throw const UpdateException('Invalid download name.');
    }
    final file = File(p.join(directory.path, name));
    final sink = file.openWrite();
    try {
      await _get(
        asset.url,
        maxBytes: asset.size,
        sink: sink,
        onBytes: (received) => onProgress?.call(received / asset.size),
      );
    } finally {
      await sink.close();
    }
    if (await file.length() != asset.size) {
      await file.delete();
      throw const UpdateException('Download was incomplete.');
    }
    final digest = await crypto.sha256.bind(file.openRead()).first;
    if (digest.toString() != asset.sha256) {
      await file.delete();
      throw const UpdateException(
        'Downloaded file failed verification and was deleted.',
      );
    }
    return file;
  }
}
