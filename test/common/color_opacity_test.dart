import 'package:fl_clash/common/color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opacityNN getters match the percentage in their name', () {
    const base = Color(0xFF123456);
    final cases = <int, Color>{
      80: base.opacity80,
      60: base.opacity60,
      50: base.opacity50,
      38: base.opacity38,
      30: base.opacity30,
      15: base.opacity15,
      12: base.opacity12,
      10: base.opacity10,
      3: base.opacity3,
      0: base.opacity0,
    };
    for (final MapEntry(key: percent, value: color) in cases.entries) {
      expect(
        color.a,
        closeTo(percent / 100, 0.5 / 255 + 1e-9),
        reason: 'opacity$percent',
      );
      expect(color.withAlpha(255), base, reason: 'opacity$percent keeps RGB');
    }
  });
}
