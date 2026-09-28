import 'package:flutter/material.dart';

import 'surge_theme_extension.dart';
import 'surge_tokens.dart';

/// Elevation levels. Every shadow in the app is one of these. The shadow hue
/// comes from the theme; the density is fixed per level ([SurgeAlpha]),
/// except [ambient], which keeps the theme's own density (faint in light
/// mode, denser in dark mode).
abstract final class SurgeShadows {
  /// Small badges and dots; density follows the theme.
  static List<BoxShadow> ambient(SurgeTheme surge) => [
    BoxShadow(color: surge.shadow, blurRadius: 8, offset: const Offset(0, 2)),
  ];

  /// Two-layer hairline lift for docked controls.
  static List<BoxShadow> hairline(SurgeTheme surge) => [
    BoxShadow(
      color: surge.shadow.withValues(alpha: SurgeAlpha.a08),
      blurRadius: 3,
      offset: const Offset(0, 0.5),
    ),
    BoxShadow(
      color: surge.shadow.withValues(alpha: SurgeAlpha.a04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  /// A selected segment, row or small raised element.
  static List<BoxShadow> raised(SurgeTheme surge) => [
    BoxShadow(
      color: surge.shadow.withValues(alpha: SurgeAlpha.a12),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  /// Switch knobs: a tight, dense shadow under a small circle.
  static List<BoxShadow> knob(SurgeTheme surge) => [
    BoxShadow(
      color: surge.shadow.withValues(alpha: SurgeAlpha.a62),
      blurRadius: 5,
      offset: const Offset(0, 2),
    ),
  ];

  /// Cards resting on the page.
  static List<BoxShadow> card(SurgeTheme surge) => [
    BoxShadow(
      color: surge.shadow.withValues(alpha: SurgeAlpha.a62),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  /// Bars that sit above scrolling content (bottom navigation).
  static List<BoxShadow> bar(SurgeTheme surge) => [
    BoxShadow(
      color: surge.shadow.withValues(alpha: SurgeAlpha.a16),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: surge.shadow.withValues(alpha: SurgeAlpha.a08),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];

  /// Menus, popups and floating selections.
  static List<BoxShadow> floating(SurgeTheme surge) => [
    BoxShadow(
      color: surge.shadow.withValues(alpha: SurgeAlpha.a16),
      blurRadius: 16,
      spreadRadius: -2,
      offset: const Offset(0, 6),
    ),
  ];

  /// Soft OS action buttons; tuned per brightness in [SurgeOpacity].
  static List<BoxShadow> action(SurgeTheme surge, {required bool isDark}) => [
    BoxShadow(
      color: surge.shadow.withValues(
        alpha: isDark
            ? surge.opacity.actionShadowDark
            : surge.opacity.actionShadowLight,
      ),
      blurRadius: surge.controls.actionShadowBlur,
      offset: Offset(0, surge.controls.actionShadowOffsetY),
    ),
  ];

  /// Coloured drop shadow under an accent surface; [scale] follows the
  /// layout scale of the caller.
  static List<BoxShadow> glow(Color color, {double scale = 1}) => [
    BoxShadow(
      color: color.withValues(alpha: SurgeAlpha.a24),
      blurRadius: 14 * scale,
      offset: Offset(0, 6 * scale),
    ),
  ];

  /// Coloured halo around a status indicator; [alpha] may animate to zero.
  static List<BoxShadow> halo(Color color, {double alpha = SurgeAlpha.a38}) => [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      blurRadius: 8,
      spreadRadius: 1,
    ),
  ];
}
