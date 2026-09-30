import 'package:fl_clash/common/icons.dart';
import 'package:fl_clash/theme/ui_scale.dart';
import 'package:fl_clash/widgets/surge/soft_os_metrics.dart';
import 'package:fl_clash/widgets/surge/surge_pressable.dart';
import 'package:fl_clash/widgets/surge/surge_theme_extension.dart';
import 'package:fl_clash/widgets/surge/surge_tokens.dart';
import 'package:flutter/material.dart';

/// Surface, hairline and text colours of a label capsule.
@immutable
class SurgeTagColors {
  const SurgeTagColors({
    required this.background,
    required this.border,
    required this.foreground,
  });

  /// Quiet grey capsule: profile type, chain names, an untested delay.
  factory SurgeTagColors.neutral(SurgeTheme surge) {
    return SurgeTagColors(
      background: surge.textSecondary.withValues(alpha: SurgeAlpha.a04),
      border: surge.separator.withValues(alpha: SurgeAlpha.a38),
      foreground: surge.textPrimary.withValues(alpha: SurgeAlpha.a72),
    );
  }

  /// Tinted capsule: counters, selection totals, a measured delay.
  factory SurgeTagColors.accent(Color color) {
    return SurgeTagColors(
      background: color.withValues(alpha: SurgeAlpha.a12),
      border: color.withValues(alpha: SurgeAlpha.a24),
      foreground: color.withValues(alpha: SurgeAlpha.a92),
    );
  }

  final Color background;
  final Color border;
  final Color foreground;

  SurgeTagColors copyWith({
    Color? background,
    Color? border,
    Color? foreground,
  }) {
    return SurgeTagColors(
      background: background ?? this.background,
      border: border ?? this.border,
      foreground: foreground ?? this.foreground,
    );
  }
}

enum SurgeTagSize {
  /// Status-pill height from [SoftOsMetrics]; the text grows with the same
  /// moderated share of the accessibility scale, so it keeps fitting.
  regular,

  /// Hugs the text; for counters inside rows and headers.
  compact,
}

/// The label capsule ("метка"): a short piece of text in a hairline stadium.
///
/// Neutral without [color], accent-tinted with it. Capsules that act as
/// buttons with icons or loading state are [SoftOsStatusPill]; a tag may
/// still take an [onTap] (a chain name that filters the list) or an
/// [onRemove] (a search keyword: a close mark follows the label and a tap
/// anywhere on the tag removes it).
class SurgeTag extends StatelessWidget {
  const SurgeTag({
    super.key,
    required this.label,
    this.color,
    this.size = SurgeTagSize.regular,
    this.minWidth,
    this.maxWidth,
    this.textStyle,
    this.onTap,
    this.onRemove,
  }) : assert(onTap == null || onRemove == null);

  final String label;
  final Color? color;
  final SurgeTagSize size;

  /// Baseline extents, scaled with [SoftOsMetrics].
  final double? minWidth;
  final double? maxWidth;

  /// Replaces the badge type style; the tag colour is applied on top.
  final TextStyle? textStyle;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final colors = color == null
        ? SurgeTagColors.neutral(surge)
        : SurgeTagColors.accent(color!);
    final regular = size == SurgeTagSize.regular;
    final radius = BorderRadius.circular(surge.radii.button);
    final textScaler = regular
        ? TextScaler.linear(UiScale.moderatedTextOf(context))
        : MediaQuery.textScalerOf(context);
    Widget text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textScaler: regular ? textScaler : null,
      style: (textStyle ?? context.typography.badgeLabel).copyWith(
        color: colors.foreground,
      ),
    );
    if (onRemove != null) {
      text = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: text),
          const SizedBox(width: SurgeSpace.xs),
          Icon(
            SurgeIcons.close,
            size: textScaler.scale(SurgeIconSize.micro),
            color: colors.foreground,
          ),
        ],
      );
    }
    Widget tag = Container(
      height: regular ? metrics.value(surge.controls.statusPillHeight) : null,
      constraints: BoxConstraints(
        minWidth: minWidth == null ? 0 : metrics.value(minWidth!),
        maxWidth: maxWidth == null ? double.infinity : metrics.value(maxWidth!),
      ),
      padding: regular
          ? EdgeInsets.symmetric(
              horizontal: metrics.value(
                surge.controls.statusPillHorizontalPadding,
              ),
            )
          : const EdgeInsets.symmetric(
              horizontal: SurgeSpace.s,
              vertical: SurgeSpace.xs,
            ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: radius,
        border: Border.all(color: colors.border, width: surge.spacing.hairline),
      ),
      // Shrink-wraps the text (a Container alignment would stretch the tag
      // to the full width of a bounded parent).
      child: Align(widthFactor: 1, heightFactor: 1, child: text),
    );
    final action = onTap ?? onRemove;
    if (action != null) {
      tag = SurgePressable(
        compact: true,
        borderRadius: radius,
        onTap: action,
        // Read together with the label: "Delete, <label>".
        semanticLabel: onRemove == null
            ? null
            : MaterialLocalizations.of(context).deleteButtonTooltip,
        child: tag,
      );
    }
    return tag;
  }
}
