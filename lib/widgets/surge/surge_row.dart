import 'package:flutter/material.dart';

import 'surge_pressable.dart';
import 'surge_theme_extension.dart';
import 'surge_tokens.dart';

/// The one list-row layout: optional leading, title (+ subtitle), optional
/// trailing, pressable across the full width. `ListItem`,
/// `DecorationListItem` and [SurgeListTile] are thin wrappers over it with
/// their own metrics.
class SurgeRow extends StatelessWidget {
  const SurgeRow({
    super.key,
    required this.title,
    required this.contentPadding,
    required this.minVerticalPadding,
    required this.titleAlignment,
    this.subtitle,
    this.leading,
    this.trailing,
    this.dense,
    this.visualDensity,
    this.backgroundColor,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.horizontalTitleGap,
    this.minTileHeight,
    this.onTap,
    this.enabled = true,
    this.leadingColor,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool? dense;
  final VisualDensity? visualDensity;
  final Color? backgroundColor;
  final TextStyle? titleTextStyle;
  final TextStyle? subtitleTextStyle;
  final double? horizontalTitleGap;
  final double? minTileHeight;
  final double minVerticalPadding;
  final EdgeInsets contentPadding;
  final ListTileTitleAlignment titleAlignment;
  final VoidCallback? onTap;
  final bool enabled;

  /// Icon colour for [leading]; the primary colour by default.
  final Color? leadingColor;

  double get _baseMinHeight {
    if (minTileHeight != null) {
      return minTileHeight!;
    }
    if (dense == true) {
      return subtitle == null ? 48 : 60;
    }
    return subtitle == null ? 56 : 68;
  }

  CrossAxisAlignment get _rowAlignment {
    return switch (titleAlignment) {
      ListTileTitleAlignment.top => CrossAxisAlignment.start,
      ListTileTitleAlignment.bottom => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.center,
    };
  }

  EdgeInsets get _effectivePadding {
    final adjustment = visualDensity?.baseSizeAdjustment ?? Offset.zero;
    final verticalAdjustment = adjustment.dy / 2;
    return contentPadding.copyWith(
      top: contentPadding.top + minVerticalPadding + verticalAdjustment,
      bottom: contentPadding.bottom + minVerticalPadding + verticalAdjustment,
    );
  }

  TextStyle _titleStyle(BuildContext context, SurgeTheme surge) {
    return titleTextStyle ??
        context.typography.rowTitle.copyWith(color: surge.textPrimary);
  }

  TextStyle _subtitleStyle(BuildContext context, SurgeTheme surge) {
    return subtitleTextStyle ??
        context.typography.supporting.copyWith(color: surge.textSecondary);
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final effectiveMinHeight =
        (_baseMinHeight + (visualDensity?.baseSizeAdjustment.dy ?? 0))
            .clamp(0.0, double.infinity)
            .toDouble();
    final gap = horizontalTitleGap ?? 12;

    return SurgePressable(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      scaleFeedback: false,
      overlayInsets: EdgeInsets.symmetric(vertical: surge.spacing.hairline),
      overlayBaseColor: backgroundColor ?? surge.card,
      child: Material(
        color: backgroundColor ?? Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: effectiveMinHeight),
          child: Padding(
            padding: _effectivePadding,
            child: Row(
              crossAxisAlignment: _rowAlignment,
              children: [
                if (leading != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(
                      color: leadingColor ?? surge.primary,
                      size: 21,
                    ),
                    child: leading!,
                  ),
                  SizedBox(width: gap),
                ],
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: _titleStyle(context, surge),
                    child: subtitle == null
                        ? title
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              title,
                              const SizedBox(height: SurgeSpace.xs),
                              DefaultTextStyle.merge(
                                style: _subtitleStyle(context, surge),
                                child: subtitle!,
                              ),
                            ],
                          ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: SurgeSpace.m),
                  IconTheme.merge(
                    data: IconThemeData(color: surge.textSecondary, size: 21),
                    child: trailing!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
