import 'dart:convert';

import 'package:cleanverse/src/features/update/update_config.dart';
import 'package:cleanverse/src/features/update/update_manifest.dart';
import 'package:cleanverse/src/features/update/update_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semantic versions compare correctly', () {
    SemVer v(String s) => SemVer.tryParse(s)!;
    expect(v('1.2.0') > v('1.1.9'), isTrue);
    expect(v('v1.10.0') > v('1.9.9'), isTrue);
    expect(v('1.0.0') > v('1.0.0-beta.1'), isTrue);
    expect(v('1.0.0+5'), v('1.0.0'));
    expect(SemVer.tryParse('latest'), isNull);
  });

  test('manifest keeps only valid https assets', () {
    final manifest = UpdateManifest.parse(
      jsonEncode({
        'version': '1.1.0',
        'platforms': {
          'windows-x64': {
            'url': 'https://github.com/a/b/releases/download/v1.1.0/x.zip',
            'sha256': 'a' * 64,
            'size': 10,
            'kind': 'zip',
          },
          'linux-x64': {
            'url': 'http://example.com/x.tar.gz',
            'sha256': 'a' * 64,
            'size': 10,
          },
          'macos-universal': {
            'url': 'https://github.com/x.dmg',
            'sha256': 'short',
            'size': 10,
          },
        },
      }),
    );
    expect(manifest.version.toString(), '1.1.0');
    expect(manifest.platforms.keys, ['windows-x64']);
  });

  test('signatures verify only with the pinned key', () async {
    final algorithm = Ed25519();
    final pair = await algorithm.newKeyPair();
    final other = await algorithm.newKeyPair();
    final message = utf8.encode('{"version":"1.1.0"}');
    final signature = base64Encode(
      (await algorithm.sign(message, keyPair: pair)).bytes,
    );
    UpdateService serviceFor(SimplePublicKey key) => UpdateService(
      config: UpdateConfig(
        repository: 'x/y',
        publicKeyBase64: base64Encode(key.bytes),
      ),
    );
    final good = serviceFor(await pair.extractPublicKey());
    final wrong = serviceFor(await other.extractPublicKey());
    expect(await good.verifySignature(message, signature), isTrue);
    expect(await wrong.verifySignature(message, signature), isFalse);
    expect(
      await good.verifySignature(utf8.encode('tampered'), signature),
      isFalse,
    );
    expect(await good.verifySignature(message, 'not base64!'), isFalse);
  });

  test('unconfigured builds refuse to check', () async {
    final service = UpdateService(
      config: const UpdateConfig(repository: 'x/y', publicKeyBase64: ''),
    );
    expect(service.configured, isFalse);
    await expectLater(service.fetchManifest(), throwsA(isA<UpdateException>()));
  });
}
