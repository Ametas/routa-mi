import 'package:fl_clash/widgets/surge/surge_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duration scale is the Material 3 motion steps', () {
    const values = SurgeDuration.values;
    expect(values.first, Durations.short1);
    expect(values.last, Durations.extralong4);
    for (var i = 1; i < values.length; i++) {
      expect(values[i], greaterThan(values[i - 1]));
    }
  });

  test('durations snap to the nearest step, ties up', () {
    Duration ms(int value) => Duration(milliseconds: value);
    expect(SurgeDuration.snap(ms(110)), SurgeDuration.short2);
    expect(SurgeDuration.snap(ms(125)), SurgeDuration.short3);
    expect(SurgeDuration.snap(ms(180)), SurgeDuration.short4);
    expect(SurgeDuration.snap(ms(220)), SurgeDuration.short4);
    expect(SurgeDuration.snap(ms(280)), SurgeDuration.medium2);
    expect(SurgeDuration.snap(ms(5000)), SurgeDuration.extralong4);
  });

  test('transition roles sit on the scale', () {
    const transitions = <Duration>[
      SurgeMotion.press,
      SurgeMotion.state,
      SurgeMotion.reveal,
      SurgeMotion.container,
      SurgeMotion.scroll,
      SurgeMotion.pageEnter,
      SurgeMotion.pageExit,
      SurgeMotion.sheetEnter,
      SurgeMotion.sheetExit,
      SurgeMotion.statusLightPulse,
      SurgeMotion.fade,
      SurgeMotion.contentSwap,
      SurgeMotion.menu,
      SurgeMotion.chart,
    ];
    for (final duration in transitions) {
      expect(SurgeDuration.values, contains(duration));
    }
  });
}
