import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Visible strings name the app RoutaMi. FlClash and SlClash may only appear
/// where the app credits them as its origin.
const _attributionKeys = {'aboutDescription', 'changelog010Item1'};

void main() {
  for (final file in Directory('arb').listSync().whereType<File>()) {
    test('${file.path} does not brand the app as SlClash or FlClash', () {
      final strings = jsonDecode(file.readAsStringSync()) as Map;
      final offenders = [
        for (final MapEntry(:key, :value) in strings.entries)
          if (value is String &&
              !_attributionKeys.contains(key) &&
              RegExp(r'SlClash|FlClash', caseSensitive: false).hasMatch(value))
            key,
      ];
      expect(offenders, isEmpty);
    });
  }

  test('Android shows RoutaMi in notifications and VPN settings', () {
    final sources = [
      'android/service/src/main/java/com/follow/clash/service/VpnService.kt',
      'android/service/src/main/java/com/follow/clash/service/modules/NotificationModule.kt',
      'android/service/src/main/java/com/follow/clash/service/FilesProvider.kt',
      'android/common/src/main/java/com/follow/clash/common/GlobalState.kt',
      'android/common/src/main/java/com/follow/clash/common/Ext.kt',
    ];
    for (final path in sources) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('"FlClash"')),
        reason: path,
      );
    }
    // The import scheme stays: subscription providers link flclash://.
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:scheme="flclash"'),
    );
  });
}
