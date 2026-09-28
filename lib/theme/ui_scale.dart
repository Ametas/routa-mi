import 'package:flutter/widgets.dart';

/// The single responsive scale of the app.
///
/// Reference: a 384dp phone (1080px at 450dpi) at text scale 1.0. Every
/// viewport-dependent size is `reference value × [viewport]`, and controls
/// that grow with the accessibility text size add [moderatedText]. Text
/// itself is scaled once, globally, by the `TextScaler` installed in
/// `ThemeManager` (bounded by `minTextScale`/`maxTextScale`).
abstract final class UiScale {
  /// Logical extent the design is drawn at.
  static const double referenceExtent = 384;

  /// Bounds of the viewport factor: small phones shrink by at most 14 %,
  /// large phones and tablets grow by at most 7 %.
  static const double minViewport = 0.86;
  static const double maxViewport = 1.07;

  /// Viewport factor for a layout [extent] (usually the available width or
  /// the screen's shortest side).
  static double viewport(double extent) {
    return (extent / referenceExtent).clamp(minViewport, maxViewport);
  }

  /// Viewport factor of the screen, from its shortest side so that it does
  /// not change on rotation.
  static double viewportOf(BuildContext context) {
    return viewport(MediaQuery.sizeOf(context).shortestSide);
  }

  /// Half of the accessibility text growth, for controls that sit next to
  /// text (icons, buttons) and should keep breathing room without becoming
  /// disproportionately large.
  static double moderatedText(double textScale) {
    return (1 + (textScale - 1) * 0.5).clamp(0.92, 1.22);
  }

  static double moderatedTextOf(BuildContext context) {
    return moderatedText(MediaQuery.textScalerOf(context).scale(1));
  }
}
