// Release version comparison for the in-app updater.
//
// `utils.compareVersions` (upstream) only knows `x.y.z+build` and throws on
// prerelease tags like `0.1.0-rc.1`, so an rc build could never see a
// newer release. This follows SemVer precedence: `0.1.0-rc.1 < 0.1.0`.

/// Positive when [a] is newer than [b], null when either is not a version.
/// A leading `v` and `+build` metadata are ignored.
int? compareAppVersions(String a, String b) {
  final left = _AppVersion.tryParse(a);
  final right = _AppVersion.tryParse(b);
  if (left == null || right == null) return null;
  return left.compareTo(right);
}

/// Whether the release [tag] is newer than the installed [current] version.
bool isNewerAppVersion(String tag, String current) =>
    (compareAppVersions(tag, current) ?? 0) > 0;

class _AppVersion implements Comparable<_AppVersion> {
  const _AppVersion(this.core, this.prerelease);

  final List<int> core;
  final List<String> prerelease;

  static final _pattern = RegExp(
    r'^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
  );

  static _AppVersion? tryParse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) return null;
    return _AppVersion([
      for (var i = 1; i <= 3; i++) int.parse(match.group(i) ?? '0'),
    ], match.group(4)?.split('.') ?? const []);
  }

  @override
  int compareTo(_AppVersion other) {
    for (var i = 0; i < 3; i++) {
      final result = core[i].compareTo(other.core[i]);
      if (result != 0) return result;
    }
    // A release ranks above its own prereleases.
    if (prerelease.isEmpty) return other.prerelease.isEmpty ? 0 : 1;
    if (other.prerelease.isEmpty) return -1;
    for (var i = 0; i < prerelease.length && i < other.prerelease.length; i++) {
      final result = _compareIdentifier(prerelease[i], other.prerelease[i]);
      if (result != 0) return result;
    }
    return prerelease.length.compareTo(other.prerelease.length);
  }

  static int _compareIdentifier(String a, String b) {
    final x = int.tryParse(a);
    final y = int.tryParse(b);
    if (x != null && y != null) return x.compareTo(y);
    if (x != null) return -1;
    if (y != null) return 1;
    return a.compareTo(b);
  }
}
