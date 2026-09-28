import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/theme/app_color_source.dart';
import 'package:fl_clash/theme/static_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThemeProps.colorSource', () {
    test('dynamic colour wins over any stored primary colour', () {
      const props = ThemeProps(dynamicColor: true, primaryColor: 0xFFFF0000);
      expect(props.colorSource, AppColorSource.dynamicColor);
    });

    test('null or the gray sentinel select a curated preset', () {
      const blue = ThemeProps(dynamicColor: false, primaryColor: null);
      const gray = ThemeProps(
        dynamicColor: false,
        primaryColor: legacyGraySeedColor,
      );
      expect(blue.colorSource, AppColorSource.preset);
      expect(blue.staticPreset, StaticThemePreset.blueWhite);
      expect(gray.colorSource, AppColorSource.preset);
      expect(gray.staticPreset, StaticThemePreset.grayBlack);
    });

    test('any other colour with dynamic off is a user accent', () {
      const props = ThemeProps(dynamicColor: false, primaryColor: 0xFF665390);
      expect(props.colorSource, AppColorSource.accent);
    });

    test('the default theme stays the gray/black preset', () {
      expect(defaultThemeProps.colorSource, AppColorSource.preset);
      expect(defaultThemeProps.staticPreset, StaticThemePreset.grayBlack);
    });
  });

  test(
    'accent palette starts with the default accent and hides the sentinel',
    () {
      const props = ThemeProps(
        primaryColors: [0xFF795548, legacyGraySeedColor, defaultAccentColor],
      );
      expect(props.accentPalette, [defaultAccentColor, 0xFF795548]);
    },
  );

  test('accent scheme keeps the picked hue in both brightnesses', () {
    const seed = 0xFF03A9F4;
    final seedHue = HSLColor.fromColor(const Color(seed)).hue;
    for (final brightness in Brightness.values) {
      final scheme = accentColorScheme(seed, brightness);
      expect(scheme.brightness, brightness);
      final hue = HSLColor.fromColor(scheme.primary).hue;
      expect((hue - seedHue).abs(), lessThan(15), reason: '$brightness');
    }
  });
}
