import 'package:fl_clash/theme/ui_scale.dart';
import 'package:flutter/material.dart';

/// Page geometry of the home screen.
///
/// The reference viewport is the user's 384dp-wide phone: geometry scales
/// with the viewport width, typography is owned by the semantic text roles.
@immutable
class DashboardResponsiveLayout {
  const DashboardResponsiveLayout._({
    required this.geometryScale,
    required this.pageHorizontalPadding,
    required this.pageTopPadding,
    required this.cardGap,
    required this.contentMaxWidth,
  });

  static const double referenceViewportWidth = UiScale.referenceExtent;
  static const double wideBreakpoint = 600;
  static const double wideContentMaxWidth = 520;
  static const double scrollEndBottomGap = 30;

  final double geometryScale;
  final double pageHorizontalPadding;
  final double pageTopPadding;
  final double cardGap;
  final double contentMaxWidth;

  /// Scales a visual token whose reference value is measured on the 384dp
  /// reference viewport.
  double geometry(double referenceValue) => referenceValue * geometryScale;

  double get cardRadius => geometry(26);

  factory DashboardResponsiveLayout.fromViewport({
    required double viewportWidth,
  }) {
    final isWide = viewportWidth > wideBreakpoint;
    final geometryScale = UiScale.viewport(viewportWidth);
    return DashboardResponsiveLayout._(
      geometryScale: geometryScale,
      pageHorizontalPadding: isWide ? 32.0 : 18 * geometryScale,
      pageTopPadding: 16 * geometryScale,
      cardGap: 16 * geometryScale,
      contentMaxWidth: isWide ? wideContentMaxWidth : double.infinity,
    );
  }
}
