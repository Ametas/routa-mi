import 'dart:io';

import 'package:fl_clash/common/update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('githubProxyUrl', () {
    test('prefixes supported GitHub HTTPS URLs', () {
      expect(
        githubProxyUrl('https://api.github.com/repos/a/b/releases/latest'),
        'https://gh-proxy.com/https://api.github.com/repos/a/b/releases/latest',
      );
      expect(
        githubProxyUrl('https://github.com/a/b/releases/download/v1/app.apk'),
        'https://gh-proxy.com/https://github.com/a/b/releases/download/v1/app.apk',
      );
    });

    test('rejects unsupported or insecure URLs', () {
      expect(githubProxyUrl('http://github.com/a/b'), isNull);
      expect(githubProxyUrl('https://example.com/app.apk'), isNull);
      expect(githubProxyUrl('not a URL'), isNull);
    });
  });

  test('download candidates prefer mirror and retain official fallback', () {
    const official =
        'https://github.com/a/b/releases/download/v1/app-arm64-v8a.apk';
    expect(githubReleaseDownloadUrls(official), [
      'https://gh-proxy.com/$official',
      official,
    ]);
  });

  group('githubAssetSha256', () {
    test('parses a valid GitHub asset digest', () {
      final hash = 'a' * 64;
      expect(githubAssetSha256('sha256:$hash'), hash);
    });

    test('rejects missing or malformed digests', () {
      expect(githubAssetSha256(null), isNull);
      expect(githubAssetSha256('sha512:${'a' * 64}'), isNull);
      expect(githubAssetSha256('sha256:abc'), isNull);
    });
  });

  test('verifies file SHA-256', () async {
    final directory = await Directory.systemTemp.createTemp('update-hash-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}app.apk');
    await file.writeAsString('SlClash');

    expect(
      await fileMatchesSha256(
        file.path,
        '5538b8b9bd981df507c7a62dfd0a6b134a12818a57655c5e06aa94b32c9ce6ab',
      ),
      isTrue,
    );
    expect(await fileMatchesSha256(file.path, '0' * 64), isFalse);
  });

  test('each platform picks its own release asset', () {
    Map<String, dynamic> asset(String name) => {
      'name': name,
      'browser_download_url': 'https://github.com/x/$name',
    };
    final release = {
      'assets': [
        asset('RoutaMi-v0.4.0-arm64-v8a.apk.sha256'),
        asset('RoutaMi-v0.4.0-windows-x64-setup.exe.sha256'),
        asset('RoutaMi-v0.4.0-windows-x64.zip'),
        asset('RoutaMi-v0.4.0-windows-x64-setup.exe'),
        asset('RoutaMi-v0.4.0-arm64-v8a.apk'),
      ],
    };
    expect(
      resolveUpdateAsset(release, windows: true)?['name'],
      'RoutaMi-v0.4.0-windows-x64-setup.exe',
    );
    expect(
      resolveUpdateAsset(release, windows: false)?['name'],
      'RoutaMi-v0.4.0-arm64-v8a.apk',
    );
    expect(
      resolveUpdateAsset({
        'assets': [asset('RoutaMi-v0.3.0-arm64-v8a.apk')],
      }, windows: true),
      isNull,
      reason: 'a release without a Windows installer offers no update',
    );
  });
}
