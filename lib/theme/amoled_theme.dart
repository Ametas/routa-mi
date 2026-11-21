import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/theme/app_color_source.dart';
import 'package:fl_clash/theme/static_theme.dart';
import 'package:fl_clash/widgets/surge/surge_tokens.dart';
import 'package:flutter/material.dart';

/// The AMOLED dark theme (design artifact "RoutaMi AMOLED"): true black
/// surfaces, so OLED pixels stay off, separated by hairlines; white text and
/// one bright accent. Filled accents carry black text.
abstract final class AmoledTheme {
  static const black = Color(0xFF000000);

  /// The accent on black: text, the start button, toggles, selection.
  static Color accent(AmoledAccent accent) => switch (accent) {
    AmoledAccent.violet => const Color(0xFFA78BFA),
    AmoledAccent.cyan => const Color(0xFF22D3EE),
    AmoledAccent.lime => const Color(0xFFA3E635),
    AmoledAccent.rose => const Color(0xFFFB7185),
  };

  /// The selected row: the accent at about 15 % over black.
  static Color _selected(AmoledAccent accent) => switch (accent) {
    AmoledAccent.violet => const Color(0xFF221B36),
    AmoledAccent.cyan => const Color(0xFF0A2A31),
    AmoledAccent.lime => const Color(0xFF1F2A0E),
    AmoledAccent.rose => const Color(0xFF33141B),
  };

  /// The dashboard's connected fill, under white text.
  static Color _deep(AmoledAccent accent) => switch (accent) {
    AmoledAccent.violet => const Color(0xFF6D28D9),
    AmoledAccent.cyan => const Color(0xFF0E7490),
    AmoledAccent.lime => const Color(0xFF3F6212),
    AmoledAccent.rose => const Color(0xFFBE123C),
  };

  /// The dark spec that replaces [preset]'s own when AMOLED is on.
  static StaticThemeSpec spec(StaticThemePreset preset, AmoledAccent accent) {
    final color = AmoledTheme.accent(accent);
    return StaticThemeSpec(
      preset: preset,
      brightness: Brightness.dark,
      colors: SurgeColors(
        background: black,
        card: black,
        elevatedCard: const Color(0xFF0C0B10),
        primary: color,
        onPrimary: black,
        green: const Color(0xFF4ADE80),
        purple: const Color(0xFFF07EEB),
        orange: const Color(0xFFFBBF24),
        red: const Color(0xFFF87171),
        textPrimary: const Color(0xFFFFFFFF),
        textSecondary: const Color(0xFFC4BFD2),
        separator: const Color(0xFF2E2A38),
        fill: const Color(0xFF15121D),
        selectedFill: _selected(accent),
        navBar: black,
        navBorder: const Color(0xFF3A3645),
        shadow: const Color(0x99000000),
        inactive: const Color(0xFF8A849B),
        inactiveVariant: const Color(0xFFA39DB3),
      ),
      stateColors: SurgeStateColors(
        toggleActive: color,
        onToggleActive: black,
        heroStart: color,
        heroPause: const Color(0xFFFF9F0A),
        heroStop: const Color(0xFFFF453A),
        onHeroAction: black,
      ),
      dashboard: SurgeDashboardTones(
        inactive: const Color(0xFF2F2942),
        inactiveVariant: const Color(0xFF5B5373),
        active: _deep(accent),
        activeSecondary: const Color(0xFF15803D),
      ),
    );
  }
}

extension ThemePropsStaticSpec on ThemeProps {
  /// The curated palette in use: AMOLED in dark mode when it is on.
  StaticThemeSpec staticSpec(Brightness brightness) {
    if (pureBlack && brightness == Brightness.dark) {
      return AmoledTheme.spec(staticPreset, amoledAccent);
    }
    return StaticThemeSpec.resolve(staticPreset, brightness);
  }
}
