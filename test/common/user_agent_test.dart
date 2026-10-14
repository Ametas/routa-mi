import 'dart:io';

import 'package:fl_clash/common/user_agent.dart';
import 'package:fl_clash/enum/profile_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app comes first, then the profile core', () {
    expect(
      subscriptionUserAgent(appVersion: '0.1.0', mihomoVersion: 'v1.19.31'),
      'RoutaMi/0.1.0 mihomo/1.19.31',
    );
    expect(
      subscriptionUserAgent(appVersion: '0.1.0', core: ProfileCore.xray),
      'RoutaMi/0.1.0 xray/$xrayCoreVersion',
    );
  });

  test('a build without the mihomo version still names the core', () {
    expect(
      subscriptionUserAgent(appVersion: '0.1.0', mihomoVersion: ''),
      'RoutaMi/0.1.0 mihomo',
    );
  });

  test('the Xray version matches core/go.mod', () {
    final goMod = File('core/go.mod').readAsStringSync();
    // Go pseudo-semver of Xray releases: v1.YYMMDD.0 is release YY.M.DD.
    final match = RegExp(
      r'github\.com/xtls/xray-core v1\.(\d\d)(\d\d)(\d\d)\.0',
    ).firstMatch(goMod)!;
    final release =
        '${int.parse(match[1]!)}.${int.parse(match[2]!)}.${int.parse(match[3]!)}';
    expect(xrayCoreVersion, release);
  });
}
