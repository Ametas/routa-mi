import 'package:fl_clash/theme/ui_scale.dart';
import 'package:fl_clash/widgets/surge/soft_os_metrics.dart';
import 'package:fl_clash/widgets/surge/surge_latency.dart';
import 'package:fl_clash/widgets/surge/surge_motion.dart';
import 'package:fl_clash/widgets/surge/surge_pressable.dart';
import 'package:fl_clash/widgets/surge/surge_tag.dart';
import 'package:fl_clash/widgets/surge/surge_theme_extension.dart';
import 'package:fl_clash/widgets/surge/surge_tokens.dart';
import 'package:flutter/material.dart';

enum SurgeMetricState { idle, loading, value, error }

/// Shared compact metric shell used by delay and future status metrics.
class SurgeMetricBadge extends StatelessWidget {
  const SurgeMetricBadge({
    super.key,
    required this.state,
    required this.label,
    required this.colors,
    this.onTap,
    this.width = 64,
  });

  final SurgeMetricState state;
  final String label;
  final SurgeTagColors colors;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final height = metrics.value(surge.controls.statusPillHeight);
    return SurgePressable(
      compact: true,
      borderRadius: BorderRadius.circular(height / 2),
      onTap: onTap,
      child: SizedBox(
        width: metrics.value(width),
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
              color: colors.border,
              width: surge.spacing.hairline,
            ),
          ),
          child: AnimatedSwitcher(
            duration: SurgeMotion.state,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.center,
              children: [...previousChildren, ?currentChild],
            ),
            child: Center(
              key: ValueKey(label),
              child: state == SurgeMetricState.loading
                  ? SizedBox.square(
                      dimension: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: colors.foreground,
                      ),
                    )
                  : Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      // Grows with the pill, not with the raw text scale.
                      textScaler: TextScaler.linear(
                        UiScale.moderatedTextOf(context),
                      ),
                      style: context.typography.badgeLabel.copyWith(
                        color: colors.foreground,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared Soft OS delay-test control for a single proxy.
class SurgeDelayPill extends StatelessWidget {
  const SurgeDelayPill({super.key, required this.delay, required this.onTap});

  final int? delay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final isTesting = delay == 0;
    final isUntested = delay == null;
    final isTimeout = delay != null && delay! < 0;
    final isSuccess = delay != null && delay! > 0;
    final neutral = SurgeTagColors.neutral(surge);
    final colors = isSuccess
        ? SurgeTagColors.accent(surge.latencyColor(delay) ?? surge.green)
        : isTimeout
        ? SurgeTagColors.accent(surge.red)
        : isTesting
        ? neutral.copyWith(
            foreground: surge.textSecondary.withValues(alpha: SurgeAlpha.a82),
          )
        : neutral;

    final label = isUntested
        ? 'Test'
        : isTesting
        ? ''
        : isSuccess
        ? '$delay ms'
        : 'Timeout';

    return SurgeMetricBadge(
      state: isTesting
          ? SurgeMetricState.loading
          : isTimeout
          ? SurgeMetricState.error
          : isSuccess
          ? SurgeMetricState.value
          : SurgeMetricState.idle,
      label: label,
      colors: colors,
      onTap: onTap,
    );
  }
}
