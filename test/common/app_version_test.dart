import 'package:fl_clash/common/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a release is newer than its own release candidates', () {
    expect(isNewerAppVersion('v0.1.0', '0.1.0-rc.1'), isTrue);
    expect(isNewerAppVersion('v0.1.0-rc.1', '0.1.0'), isFalse);
    expect(isNewerAppVersion('v0.1.0-rc.2', '0.1.0-rc.1'), isTrue);
    expect(isNewerAppVersion('v0.1.0-rc.10', '0.1.0-rc.9'), isTrue);
    expect(isNewerAppVersion('v0.1.1-rc.1', '0.1.0'), isTrue);
  });

  test('plain versions compare numerically', () {
    expect(isNewerAppVersion('v0.1.0', '0.1.0'), isFalse);
    expect(isNewerAppVersion('v0.2.0', '0.1.9'), isTrue);
    expect(isNewerAppVersion('v0.10.0', '0.9.0'), isTrue);
    expect(isNewerAppVersion('v0.1.0', '0.2.0'), isFalse);
    expect(compareAppVersions('1', '1.0.0'), 0);
  });

  test('build metadata does not make a version newer', () {
    expect(isNewerAppVersion('v0.1.0', '0.1.0+1790000000'), isFalse);
    expect(compareAppVersions('0.1.0+2', '0.1.0+1'), 0);
  });

  test('anything that is not a version is never an update', () {
    expect(compareAppVersions('nightly', '0.1.0'), isNull);
    expect(isNewerAppVersion('', '0.1.0'), isFalse);
    expect(isNewerAppVersion('v0.2.0', 'unknown'), isFalse);
  });
}
