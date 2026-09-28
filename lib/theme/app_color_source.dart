import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/theme/static_theme.dart';
import 'package:flutter/material.dart';

/// Where the app colours come from. Derived from [ThemeProps], which keeps
/// the SlClash storage format:
/// - `dynamicColor: true` — Material You (wallpaper / system accent);
/// - `dynamicColor: false` + `primaryColor` null or [legacyGraySeedColor] —
///   one of the curated [StaticThemePreset]s;
/// - `dynamicColor: false` + any other `primaryColor` — a user accent.
enum AppColorSource { dynamicColor, preset, accent }

/// Scheme variant for user accents: keeps the generated primary close to
/// the picked colour (the stored `schemeVariant` defaults to monochrome,
/// which would drop the hue).
const accentSchemeVariant = DynamicSchemeVariant.fidelity;

/// Accent offered by default in the picker; the default theme stays the
/// gray/black preset (see `defaultThemeProps`).
const defaultAccentColor = 0xFF0A84FF;

/// Seed for the dark scheme when no accent is chosen.
const defaultAccentColorDark = 0xFF4DA3FF;

extension ThemePropsColorSource on ThemeProps {
  AppColorSource get colorSource {
    if (dynamicColor) {
      return AppColorSource.dynamicColor;
    }
    if (primaryColor == null || primaryColor == legacyGraySeedColor) {
      return AppColorSource.preset;
    }
    return AppColorSource.accent;
  }

  StaticThemePreset get staticPreset => primaryColor == legacyGraySeedColor
      ? StaticThemePreset.grayBlack
      : StaticThemePreset.blueWhite;

  /// Accent colours shown in the picker: the stored palette without the
  /// preset sentinel, always including [defaultAccentColor].
  List<int> get accentPalette {
    return {
      defaultAccentColor,
      ...primaryColors,
    }.where((color) => color != legacyGraySeedColor).toList();
  }
}

ColorScheme accentColorScheme(int seed, Brightness brightness) {
  return ColorScheme.fromSeed(
    seedColor: Color(seed),
    brightness: brightness,
    dynamicSchemeVariant: accentSchemeVariant,
  );
}
