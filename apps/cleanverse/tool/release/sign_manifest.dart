// Release helper for signed update manifests.
//
//   dart run tool/release/sign_manifest.dart keygen
//       Prints a new Ed25519 key pair. Store the private key as the GitHub
//       secret UPDATE_SIGNING_KEY and the public key as the repository
//       variable UPDATE_PUBLIC_KEY. Back up the private key: losing it
//       breaks updates for every installed copy.
//
//   UPDATE_SIGNING_KEY=... dart run tool/release/sign_manifest.dart manifest \
//       --repo owner/name --tag v1.2.3 --version 1.2.3 --out dist dist/*
//       Writes dist/latest.json and dist/latest.json.sig for the given assets.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: sign_manifest.dart keygen | manifest ...');
    exit(64);
  }
  final algorithm = Ed25519();
  if (args.first == 'keygen') {
    final pair = await algorithm.newKeyPair();
    final seed = await pair.extractPrivateKeyBytes();
    final public = await pair.extractPublicKey();
    stdout.writeln('UPDATE_SIGNING_KEY (secret): ${base64Encode(seed)}');
    stdout.writeln(
      'UPDATE_PUBLIC_KEY (public):  ${base64Encode(public.bytes)}',
    );
    return;
  }
  if (args.first != 'manifest') {
    stderr.writeln('Unknown command ${args.first}');
    exit(64);
  }
  String option(String name) {
    final index = args.indexOf('--$name');
    if (index < 0 || index + 1 >= args.length) {
      stderr.writeln('Missing --$name');
      exit(64);
    }
    return args[index + 1];
  }

  final repo = option('repo');
  final tag = option('tag');
  final version = option('version');
  final out = option('out');
  final optionValues = {
    for (final name in ['repo', 'tag', 'version', 'out', 'notes'])
      if (args.contains('--$name')) args[args.indexOf('--$name') + 1],
  };
  final files = [
    for (var i = 1; i < args.length; i++)
      if (!args[i].startsWith('--') && !optionValues.contains(args[i])) args[i],
  ];
  final notesIndex = args.indexOf('--notes');
  final notes = notesIndex < 0 ? '' : args[notesIndex + 1];

  final seedText = Platform.environment['UPDATE_SIGNING_KEY'] ?? '';
  if (seedText.isEmpty) {
    stderr.writeln('UPDATE_SIGNING_KEY is not set.');
    exit(1);
  }
  final pair = await algorithm.newKeyPairFromSeed(base64Decode(seedText));

  final platforms = <String, Map<String, Object>>{};
  for (final path in files) {
    final name = p.basename(path);
    final lower = name.toLowerCase();
    final (key, kind) = lower.endsWith('.dmg')
        ? ('macos-universal', 'dmg')
        : lower.endsWith('.appimage')
        ? ('linux-x64', 'appimage')
        : lower.contains('windows') && lower.endsWith('.zip')
        ? ('windows-x64', 'zip')
        : lower.contains('linux') && lower.endsWith('.tar.gz')
        ? ('linux-x64', 'tar.gz')
        : ('', '');
    if (key.isEmpty) continue;
    // Prefer an AppImage over a tarball for Linux self-update.
    if (platforms[key]?['kind'] == 'appimage') continue;
    final file = File(path);
    final digest = await crypto.sha256.bind(file.openRead()).first;
    platforms[key] = {
      'url':
          'https://github.com/$repo/releases/download/$tag/${Uri.encodeComponent(name)}',
      'sha256': digest.toString(),
      'size': await file.length(),
      'kind': kind,
    };
  }
  if (platforms.isEmpty) {
    stderr.writeln('No release assets matched.');
    exit(1);
  }
  final manifest = utf8.encode(
    const JsonEncoder.withIndent('  ').convert({
      'version': version,
      'notes': notes,
      'pub_date': DateTime.now().toUtc().toIso8601String(),
      'platforms': platforms,
    }),
  );
  final signature = await algorithm.sign(manifest, keyPair: pair);
  await Directory(out).create(recursive: true);
  await File(p.join(out, 'latest.json')).writeAsBytes(manifest);
  await File(p.join(out, 'latest.json.sig'))
      .writeAsString(base64Encode(signature.bytes));
  stdout.writeln('Signed manifest for ${platforms.keys.join(', ')}');
}
