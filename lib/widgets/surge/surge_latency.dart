import 'package:flutter/painting.dart';

import 'surge_theme_extension.dart';

/// Latency thresholds shared by delay pills and the dashboard.
abstract final class SurgeLatency {
  /// Delays below this read as good; at or above, as slow.
  static const int slowFromMs = 600;
}

extension SurgeLatencyColors on SurgeTheme {
  /// Status colour for a measured delay: negative is a failure, then good
  /// below [SurgeLatency.slowFromMs], slow above it. `null` when untested.
  Color? latencyColor(int? delay) {
    if (delay == null) return null;
    if (delay < 0) return red;
    if (delay < SurgeLatency.slowFromMs) return green;
    return orange;
  }
}
