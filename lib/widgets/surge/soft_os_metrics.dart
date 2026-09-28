import 'dart:math' as math;

import 'package:fl_clash/theme/ui_scale.dart';
import 'package:flutter/material.dart';

/// Responsive sizing for the Soft OS control family, derived from the
/// app-wide [UiScale]: the viewport factor times a moderated share of the
/// accessibility text scale.
class SoftOsMetrics {
  const SoftOsMetrics._({required this.scale});

  static const double baselineShortestSide = UiScale.referenceExtent;
  static const double minimumTapExtent = 44;

  final double scale;

  factory SoftOsMetrics.of(BuildContext context) {
    return SoftOsMetrics._(
      scale: (UiScale.viewportOf(context) * UiScale.moderatedTextOf(context))
          .clamp(0.86, 1.28),
    );
  }

  double value(double baseline) => baseline * scale;

  double tap(double baseline) => math.max(minimumTapExtent, value(baseline));
}
