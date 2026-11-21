import 'dart:convert';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/theme/amoled_theme.dart';
import 'package:fl_clash/theme/app_color_source.dart';
import 'package:fl_clash/theme/static_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void _expectContrast(Color fg, Color bg, double minimum) {
  expect(
    _contrast(fg, bg),
    greaterThanOrEqualTo(minimum),
    reason:
        '${fg.toARGB32().toRadixString(16)} on ${bg.toARGB32().toRadixString(16)}',
  );
}

void main() {
  const white = Color(0xFFFFFFFF);

  for (final accent in AmoledAccent.values) {
    group('AMOLED ${accent.name}', () {
      final spec = AmoledTheme.spec(StaticThemePreset.routa, accent);
      final colors = spec.colors;

      test('the page, cards and navigation are true black', () {
        expect(spec.brightness, Brightness.dark);
        expect(colors.background, AmoledTheme.black);
        expect(colors.card, AmoledTheme.black);
        expect(colors.navBar, AmoledTheme.black);
        // Cards are told apart by their hairline, which must show on black.
        _expectContrast(colors.separator, AmoledTheme.black, 1.4);
      });

      test('text and the accent read on every surface', () {
        for (final surface in [
          colors.background,
          colors.elevatedCard,
          colors.fill,
          colors.selectedFill,
        ]) {
          _expectContrast(colors.textPrimary, surface, 7);
          _expectContrast(colors.textSecondary, surface, 7);
          _expectContrast(colors.primary, surface, 4.5);
        }
        for (final semantic in [
          colors.green,
          colors.purple,
          colors.orange,
          colors.red,
        ]) {
          _expectContrast(semantic, colors.card, 4.5);
        }
      });

      test('filled accents carry black text', () {
        final state = spec.stateColors;
        _expectContrast(colors.onPrimary, colors.primary, 4.5);
        _expectContrast(state.onToggleActive, state.toggleActive, 4.5);
        for (final fill in [state.heroStart, state.heroPause, state.heroStop]) {
          _expectContrast(state.onHeroAction, fill, 4.5);
        }
      });

      test('the dashboard hero keeps its white text', () {
        final tones = spec.dashboard!;
        for (final fill in [
          tones.inactive,
          tones.active,
          tones.activeSecondary,
        ]) {
          _expectContrast(white, fill, 4.5);
        }
      });
    });
  }

  group('staticSpec', () {
    const routa = ThemeProps(
      dynamicColor: false,
      primaryColor: routaPresetColor,
    );

    test('AMOLED replaces the dark palette only', () {
      final amoled = routa.copyWith(
        pureBlack: true,
        amoledAccent: AmoledAccent.lime,
      );
      final dark = amoled.staticSpec(Brightness.dark);
      expect(dark.colors.background, AmoledTheme.black);
      expect(dark.colors.primary, AmoledTheme.accent(AmoledAccent.lime));
      expect(dark.preset, StaticThemePreset.routa);
      expect(
        amoled.staticSpec(Brightness.light),
        same(StaticThemeSpec.routaLight),
      );
    });

    test('without AMOLED the preset keeps its own palettes', () {
      expect(
        routa.staticSpec(Brightness.dark),
        same(StaticThemeSpec.routaDark),
      );
      expect(
        routa.staticSpec(Brightness.light),
        same(StaticThemeSpec.routaLight),
      );
    });

    test('the accent survives a settings round trip', () {
      final props = routa.copyWith(
        pureBlack: true,
        amoledAccent: AmoledAccent.rose,
      );
      final restored = ThemeProps.fromJson(
        jsonDecode(jsonEncode(props.toJson())) as Map<String, Object?>,
      );
      expect(restored.pureBlack, isTrue);
      expect(restored.amoledAccent, AmoledAccent.rose);
      // Older settings without the field fall back to violet.
      expect(ThemeProps.fromJson(const {}).amoledAccent, AmoledAccent.violet);
    });
  });
}
