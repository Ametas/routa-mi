import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('alpha scale is ascending within 0..1', () {
    const values = SurgeAlpha.values;
    expect(values.first, 0);
    expect(values.last, 1);
    for (var i = 1; i < values.length; i++) {
      expect(values[i], greaterThan(values[i - 1]));
    }
  });

  test('alpha snaps to the nearest step, ties up', () {
    expect(SurgeAlpha.snap(0.025), SurgeAlpha.a04);
    expect(SurgeAlpha.snap(0.06), SurgeAlpha.a08);
    expect(SurgeAlpha.snap(0.1), SurgeAlpha.a12);
    expect(SurgeAlpha.snap(0.14), SurgeAlpha.a16);
    expect(SurgeAlpha.snap(0.5), SurgeAlpha.a48);
    expect(SurgeAlpha.snap(0.55), SurgeAlpha.a62);
    expect(SurgeAlpha.snap(0.78), SurgeAlpha.a82);
    expect(SurgeAlpha.snap(0.96), SurgeAlpha.full);
  });

  group('SurgeShadows', () {
    final light = SurgeTheme.light();
    final dark = SurgeTheme.dark();

    List<double> alphas(List<BoxShadow> shadows) =>
        shadows.map((shadow) => shadow.color.a).toList();

    test('levels use scale alphas and the theme shadow hue', () {
      final levels = <List<BoxShadow> Function(SurgeTheme)>[
        SurgeShadows.hairline,
        SurgeShadows.raised,
        SurgeShadows.knob,
        SurgeShadows.card,
        SurgeShadows.bar,
        SurgeShadows.floating,
      ];
      for (final level in levels) {
        final shadows = level(light);
        expect(shadows, isNotEmpty);
        expect(alphas(level(dark)), alphas(shadows));
        for (final shadow in shadows) {
          expect(
            SurgeAlpha.values,
            contains(closeTo(shadow.color.a, 1 / 255)),
            reason: 'alpha ${shadow.color.a} is off the scale',
          );
          expect(shadow.color.r, closeTo(light.shadow.r, 1e-6));
        }
      }
    });

    test('ambient keeps the theme density', () {
      expect(SurgeShadows.ambient(light).single.color, light.shadow);
      expect(SurgeShadows.ambient(dark).single.color, dark.shadow);
    });

    test('halo fades out at alpha none', () {
      final halo = SurgeShadows.halo(Colors.green, alpha: SurgeAlpha.none);
      expect(halo.single.color.a, 0);
    });
  });
}
