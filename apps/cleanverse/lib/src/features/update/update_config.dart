/// Release channel settings. The public key is the Ed25519 key whose private
/// half signs `latest.json` in CI (secret `UPDATE_SIGNING_KEY`). Generate a
/// pair with `dart run tool/release/sign_manifest.dart keygen`.
///
/// An empty key disables update checks, so local and forked builds never
/// trust unsigned updates.
class UpdateConfig {
  const UpdateConfig({
    required this.repository,
    required this.publicKeyBase64,
    this.allowedHosts = const {
      'github.com',
      'objects.githubusercontent.com',
      'release-assets.githubusercontent.com',
    },
  });
  final String repository;
  final String publicKeyBase64;
  final Set<String> allowedHosts;
}

const updateConfig = UpdateConfig(
  repository: 'prapawity/CLEANVerse',
  // Can also be injected at build time:
  //   flutter build windows --dart-define=CLEANVERSE_UPDATE_KEY=<base64>
  publicKeyBase64: String.fromEnvironment('CLEANVERSE_UPDATE_KEY'),
);
