import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

/// An outlined pill button (design 3.1: buttons are outlined, not filled).
/// [accent] draws the main action in the accent colour; [busy] shows a
/// spinner and ignores taps.
class OutlinePillButton extends StatelessWidget {
  const OutlinePillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.accent = false,
    this.busy = false,
    this.compact = false,
  });

  static const double height = 46;
  static const double compactHeight = 34;

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool accent;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final enabled = onPressed != null && !busy;
    final color = accent ? surge.primary : surge.textPrimary;
    final radius = BorderRadius.circular(surge.radii.button);
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: onPressed == null ? SurgeAlpha.a48 : SurgeAlpha.full,
        child: SurgePressable(
          onTap: enabled ? onPressed : null,
          borderRadius: radius,
          child: Container(
            height: compact ? compactHeight : height,
            padding: EdgeInsets.symmetric(
              horizontal: compact
                  ? SurgeSpace.m + SurgeSpace.xxs
                  : SurgeSpace.xl,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: accent ? surge.primary : surge.separator,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox.square(
                    dimension: SurgeIconSize.inline,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: surge.primary,
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: SurgeIconSize.inline, color: color),
                if (busy || icon != null) const SizedBox(width: SurgeSpace.s),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.controlLabel.copyWith(
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
