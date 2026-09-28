import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SurgePalette', () {
    test('contentOn picks the readable colour', () {
      expect(
        SurgePalette.contentOn(const Color(0xFF0A84FF)),
        SurgePalette.onFill,
      );
      expect(
        SurgePalette.contentOn(const Color(0xFF101010)),
        SurgePalette.onFill,
      );
      expect(
        SurgePalette.contentOn(const Color(0xFFF2F2F2)),
        SurgePalette.scrim,
      );
    });

    test('shade darkens towards the scrim', () {
      const base = Color(0xFF34C759);
      expect(SurgePalette.shade(base, 0), base);
      expect(SurgePalette.shade(base, 1), SurgePalette.scrim);
      final shaded = SurgePalette.shade(base, 0.16);
      expect(shaded.computeLuminance(), lessThan(base.computeLuminance()));
    });
  });

  group('latencyColor', () {
    for (final surge in [SurgeTheme.light(), SurgeTheme.dark()]) {
      test('follows the theme status colours', () {
        expect(surge.latencyColor(null), isNull);
        expect(surge.latencyColor(-1), surge.red);
        expect(surge.latencyColor(1), surge.green);
        expect(surge.latencyColor(SurgeLatency.slowFromMs - 1), surge.green);
        expect(surge.latencyColor(SurgeLatency.slowFromMs), surge.orange);
      });
    }
  });
}
