import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/common/constant.dart';

const githubUpdateApiUrl =
    'https://api.github.com/repos/$repository/releases/latest';
const githubProxyPrefix = 'https://gh-proxy.com/';

String? githubProxyUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return null;
  if (uri.host != 'github.com' && uri.host != 'api.github.com') return null;
  return '$githubProxyPrefix$url';
}

List<String> githubReleaseDownloadUrls(String officialUrl) {
  final mirrorUrl = githubProxyUrl(officialUrl);
  return [?mirrorUrl, officialUrl];
}

String? githubAssetSha256(Object? digest) {
  final value = digest?.toString().trim().toLowerCase();
  if (value == null || !value.startsWith('sha256:')) return null;
  final hash = value.substring('sha256:'.length);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) return null;
  return hash;
}

Future<bool> fileMatchesSha256(String path, String expectedSha256) async {
  final actual = await sha256.bind(File(path).openRead()).first;
  return actual.toString().toLowerCase() == expectedSha256.toLowerCase();
}

/// Suffix of the Windows installer in a RoutaMi release.
const windowsInstallerSuffix = '-windows-x64-setup.exe';

/// The release asset this platform installs: the Windows installer, or the
/// arm64 APK on Android.
Map<String, dynamic>? resolveUpdateAsset(
  Map<String, dynamic> release, {
  required bool windows,
}) {
  final assets = release['assets'];
  if (assets is! List) return null;
  bool hasUrl(Map<String, dynamic> asset) =>
      asset['browser_download_url']?.toString().isNotEmpty == true;
  String name(Map<String, dynamic> asset) =>
      asset['name']?.toString().toLowerCase() ?? '';
  final candidates = assets.whereType<Map<String, dynamic>>().where(hasUrl);
  if (windows) {
    return candidates
        .where((asset) => name(asset).endsWith(windowsInstallerSuffix))
        .firstOrNull;
  }
  final apks = candidates.where((asset) => name(asset).endsWith('.apk'));
  return apks.where((asset) => name(asset).contains('arm64-v8a')).firstOrNull ??
      apks.firstOrNull;
}
