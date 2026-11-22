import 'dart:convert';

/// Semantic version (major.minor.patch[-pre]). Build metadata is ignored.
class SemVer implements Comparable<SemVer> {
  const SemVer(this.major, this.minor, this.patch, [this.pre = '']);
  final int major;
  final int minor;
  final int patch;
  final String pre;

  static SemVer? tryParse(String input) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+.*)?$',
    ).firstMatch(input.trim());
    if (match == null) return null;
    return SemVer(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
      match[4] ?? '',
    );
  }

  bool get isPrerelease => pre.isNotEmpty;

  @override
  int compareTo(SemVer other) {
    for (final (a, b) in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      if (a != b) return a.compareTo(b);
    }
    if (pre == other.pre) return 0;
    if (pre.isEmpty) return 1; // 1.0.0 > 1.0.0-beta
    if (other.pre.isEmpty) return -1;
    return pre.compareTo(other.pre);
  }

  bool operator >(SemVer other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is SemVer && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, pre);

  @override
  String toString() => '$major.$minor.$patch${pre.isEmpty ? '' : '-$pre'}';
}

class UpdateAsset {
  const UpdateAsset({
    required this.url,
    required this.sha256,
    required this.size,
    required this.kind,
  });
  final Uri url;

  /// Lowercase hex SHA-256 of the asset.
  final String sha256;
  final int size;

  /// zip (Windows folder), dmg (macOS), appimage or tar.gz (Linux).
  final String kind;
}

/// Contents of `latest.json`, published with every release and signed
/// (detached Ed25519 signature in `latest.json.sig`).
class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.notes,
    required this.published,
    required this.platforms,
  });
  final SemVer version;
  final String notes;
  final DateTime? published;
  final Map<String, UpdateAsset> platforms;

  static UpdateManifest parse(String source) {
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Manifest is not an object.');
    }
    final version = SemVer.tryParse('${json['version']}');
    if (version == null) throw const FormatException('Invalid version.');
    final platforms = <String, UpdateAsset>{};
    final raw = json['platforms'];
    if (raw is Map<String, dynamic>) {
      raw.forEach((key, value) {
        if (value is! Map<String, dynamic>) return;
        final url = Uri.tryParse('${value['url']}');
        final sha = '${value['sha256']}'.toLowerCase();
        final size = value['size'];
        if (url == null ||
            url.scheme != 'https' ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha) ||
            size is! int ||
            size <= 0) {
          return;
        }
        platforms[key] = UpdateAsset(
          url: url,
          sha256: sha,
          size: size,
          kind: '${value['kind'] ?? 'zip'}',
        );
      });
    }
    return UpdateManifest(
      version: version,
      notes: '${json['notes'] ?? ''}',
      published: DateTime.tryParse('${json['pub_date'] ?? ''}'),
      platforms: platforms,
    );
  }
}
